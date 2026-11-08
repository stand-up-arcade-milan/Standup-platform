#!/usr/bin/env python3
"""Importa i CSV normalizzati e il foglio commerciale nel PostgreSQL locale."""

import argparse
import csv
import json
import os
import re
import sys
import unicodedata
from collections import Counter, defaultdict
from datetime import datetime
from pathlib import Path
from uuid import NAMESPACE_URL, uuid5

import psycopg
from psycopg import sql

RADICE = Path(__file__).resolve().parents[2]
FILE = {
    "eventi": "expodata_dataset_unificato.csv",
    "contatti": "contatti_commerciali_2025.csv",
    "fasce_mancanti": "fasce_orarie_mancanti_stand.csv",
    "anomalie": "anomalie_riepilogo.csv",
    "scarti": "scarti_righe_rimosse.csv",
}


def migration_state(con, version):
    """Riconosce migrazioni già eseguite da initdb, anche senza il registro locale."""
    checks = {
        "V001": ["SELECT to_regclass('arcade.edizione') IS NOT NULL",
                 "SELECT to_regclass('arcade.biglietto') IS NOT NULL",
                 "SELECT to_regclass('arcade.accesso') IS NOT NULL"],
        "V002": ["SELECT (SELECT count(*) FROM arcade.edizione WHERE anno IN (2024,2025)) = 2",
                 "SELECT (SELECT count(*) FROM arcade.categoria_biglietto) = 8",
                 "SELECT (SELECT count(*) FROM arcade.canale_vendita) = 3"],
        "V003": ["SELECT to_regclass('arcade.v_registro_anomalie') IS NOT NULL",
                 "SELECT to_regclass('arcade.v_stand_riepilogo') IS NOT NULL",
                 "SELECT to_regclass('arcade.v_ingressi_per_ora') IS NOT NULL"],
        "V004": ["SELECT count(*) = 2 FROM pg_roles WHERE rolname IN ('arcade_lettura','arcade_dati_personali')"],
        "V005": ["SELECT to_regclass('arcade.dizionario_dati') IS NOT NULL"],
        "V006": ["SELECT count(*) > 0 FROM pg_policies WHERE schemaname='arcade' AND tablename='contatto_stand'"],
        "V007": ["SELECT to_regclass('arcade.passaggio_pedana') IS NOT NULL",
                 "SELECT to_regclass('arcade.lead_magnet') IS NOT NULL",
                 "SELECT to_regclass('arcade.v_mql_stand') IS NOT NULL"],
        "V008": ["SELECT to_regclass('arcade.scansione_stand') IS NOT NULL",
                 "SELECT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='arcade' AND table_name='edizione' AND column_name='sede')",
                 "SELECT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='arcade' AND table_name='accesso' AND column_name='motivo_rifiuto')"],
        "V009": ["SELECT to_regclass('arcade.pratica') IS NOT NULL",
                 "SELECT to_regclass('arcade.invito_espositore') IS NOT NULL",
                 "SELECT to_regclass('arcade.v_pratica') IS NOT NULL"],
        "V010": ["SELECT to_regclass('arcade.espositore_riservato') IS NOT NULL",
                 "SELECT to_regclass('arcade.planimetria_stand') IS NOT NULL",
                 "SELECT to_regclass('arcade.contratto_storico') IS NOT NULL"],
        "V011": ["SELECT to_regclass('arcade.acquisizione_evento') IS NOT NULL",
                 "SELECT to_regclass('arcade.recupero_password') IS NOT NULL",
                 "SELECT to_regclass('arcade.revoca_registrazione_visitatore') IS NOT NULL"],
        "V012": ["SELECT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='arcade' AND table_name='contatto_stand' AND column_name='consenso_espositori')",
                 "SELECT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='arcade' AND table_name='scansione_stand' AND column_name='id_lead_magnet')"],
        "V013": ["SELECT is_nullable='YES' FROM information_schema.columns WHERE table_schema='arcade' AND table_name='documento_pratica' AND column_name='url'"],
        "V014": ["SELECT count(*) = 2 FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace WHERE n.nspname='arcade' AND p.proname IN ('pratica_controlla','pratica_alla_firma') AND p.proconfig IS NOT NULL"],
    }
    values = [bool(con.execute(query).fetchone()[0]) for query in checks[version]]
    if all(values):
        return "present"
    if any(values):
        return "partial"
    return "missing"


def execute_many(con, statement, rows):
    """Psycopg 3 executemany helper; bulk execution belongs to a cursor."""
    with con.cursor() as cursor:
        cursor.executemany(statement, rows)


def applica_migrazioni(con):
    con.execute("""CREATE TABLE IF NOT EXISTS public.schema_migrazioni (
        versione text PRIMARY KEY, applicata_il timestamptz NOT NULL DEFAULT now())""")
    con.commit()
    applicate = []
    for path in sorted((RADICE / "database" / "migrations").glob("V*.sql")):
        version = path.name.split("__", 1)[0]
        if con.execute("SELECT 1 FROM public.schema_migrazioni WHERE versione = %s", (version,)).fetchone():
            con.commit()
            continue
        state = migration_state(con, version)
        con.commit()
        if state == "partial":
            raise RuntimeError(f"Schema {version} parziale: interrotto senza modificare dati; verificare la migrazione.")
        with con.transaction():
            if state == "missing":
                con.execute(path.read_text(encoding="utf-8"), prepare=False)
                applicate.append(path.name)
            con.execute("INSERT INTO public.schema_migrazioni (versione) VALUES (%s) ON CONFLICT DO NOTHING", (version,))
    return applicate


def load_stage(con, folder):
    schema = "staging_import_" + uuid5(NAMESPACE_URL, str(datetime.now().timestamp())).hex[:16]
    con.execute(sql.SQL("CREATE SCHEMA {}").format(sql.Identifier(schema)))
    counts = {}
    for name, filename in FILE.items():
        path = folder / filename
        if not path.is_file():
            raise FileNotFoundError(f"File normalizzato mancante: {path}")
        with path.open(encoding="utf-8-sig", newline="") as file:
            fields = next(csv.reader(file))
        definitions = sql.SQL(", ").join(sql.SQL("{}").format(sql.Identifier(field)) + sql.SQL(" text") for field in fields)
        con.execute(sql.SQL("CREATE TABLE {}.{} ({})").format(sql.Identifier(schema), sql.Identifier(name), definitions))
        copy_query = sql.SQL("COPY {}.{} FROM STDIN WITH (FORMAT CSV, HEADER TRUE)").format(
            sql.Identifier(schema), sql.Identifier(name))
        with con.cursor() as cur, path.open("rb") as file:
            with cur.copy(copy_query) as copy:
                first = True
                while block := file.read(1 << 20):
                    if first and block.startswith(b"\xef\xbb\xbf"):
                        block = block[3:]
                    first = False
                    copy.write(block)
        counts[name] = con.execute(sql.SQL("SELECT count(*) FROM {}.{}").format(
            sql.Identifier(schema), sql.Identifier(name))).fetchone()[0]
    return schema, counts


def controlla_stage(con, schema):
    ref = sql.Identifier(schema)
    duplicate = con.execute(sql.SQL(
        "SELECT count(*) FROM (SELECT id_evento FROM {}.eventi GROUP BY id_evento HAVING count(*) > 1) d"
    ).format(ref)).fetchone()[0]
    if duplicate:
        raise ValueError(f"Dataset normalizzato non valido: {duplicate} identificativi evento duplicati.")
    unmatched = con.execute(sql.SQL("""
        SELECT count(*) FROM {}.eventi e WHERE e.fonte='CONTATTI_STAND'
        AND NOT EXISTS (SELECT 1 FROM {}.contatti c WHERE c.id_contatto=e.id_riferimento)
    """).format(ref, ref)).fetchone()[0]
    if unmatched:
        raise ValueError(f"Dataset normalizzato non valido: {unmatched} contatti senza dettaglio riservato.")


def normalized_key(value):
    ascii_value = unicodedata.normalize("NFKD", str(value or "")).encode("ascii", "ignore").decode().casefold()
    return re.sub(r"[^a-z0-9]+", "_", ascii_value).strip("_") or "non_classificato"


def importa_commerciale(con, path):
    with path.open(encoding="utf-8") as file:
        data = json.load(file)
    exhibitors = data["espositori"]
    sectors = {}
    for item in exhibitors:
        sector = item.get("settore")
        if sector:
            sectors.setdefault(normalized_key(sector), sector)

    execute_many(con, """
        INSERT INTO arcade.espositore (id_espositore, ragione_sociale) VALUES (%s,%s)
        ON CONFLICT (id_espositore) DO UPDATE
        SET ragione_sociale=coalesce(arcade.espositore.ragione_sociale, EXCLUDED.ragione_sociale)
    """, [(x["id_espositore"], x["ragione_sociale"]) for x in exhibitors])
    execute_many(con, """
        INSERT INTO arcade.profilo_espositore (id_espositore, nome_pubblico)
        VALUES (%s,%s) ON CONFLICT (id_espositore) DO NOTHING
    """, [(x["id_espositore"], x["ragione_sociale"]) for x in exhibitors])
    execute_many(con, """
        INSERT INTO arcade.espositore_riservato
            (id_espositore, partita_iva, settore, citta, referente, email_referente)
        VALUES (%s,%s,%s,%s,%s,%s) ON CONFLICT (id_espositore) DO NOTHING
    """, [(x["id_espositore"], x.get("partita_iva"), x.get("settore"), x.get("citta"),
           x.get("referente"), x.get("email_referente")) for x in exhibitors])
    execute_many(con, """
        INSERT INTO arcade.categoria_espositore (codice,nome) VALUES (%s,%s) ON CONFLICT DO NOTHING
    """, list(sectors.items()))
    execute_many(con, """
        INSERT INTO arcade.espositore_categoria (id_espositore,codice_categoria) VALUES (%s,%s) ON CONFLICT DO NOTHING
    """, [(x["id_espositore"], normalized_key(x["settore"])) for x in exhibitors if x.get("settore")])

    pavilions = {}
    for item in data["stand"]:
        pavilions.setdefault(item["padiglione"], item.get("nome_padiglione"))
    for contract in data["contratti"]:
        pavilions.setdefault(contract["codice_stand"].split("-", 1)[0].upper(), None)
    execute_many(con, """
        INSERT INTO arcade.padiglione (codice,nome) VALUES (%s,%s)
        ON CONFLICT (codice) DO UPDATE SET nome=coalesce(arcade.padiglione.nome, EXCLUDED.nome)
    """, list(pavilions.items()))

    stand_seeds = {x["codice_stand"]: (x["padiglione"], x["superficie_mq"]) for x in data["stand"]}
    for contract in data["contratti"]:
        stand_seeds.setdefault(contract["codice_stand"], (contract["codice_stand"].split("-", 1)[0].upper(), None))
    execute_many(con, """
        INSERT INTO arcade.stand (codice,padiglione,superficie_mq) VALUES (%s,%s,%s)
        ON CONFLICT (codice) DO NOTHING
    """, [(code, pavilion, area) for code, (pavilion, area) in stand_seeds.items()])
    execute_many(con, """
        INSERT INTO arcade.planimetria_stand
            (anno,codice_stand,padiglione,nome_padiglione,superficie_mq,posizione,attivo_dal)
        VALUES (2026,%s,%s,%s,%s,%s,%s) ON CONFLICT (anno,codice_stand) DO NOTHING
    """, [(x["codice_stand"], x["padiglione"], x.get("nome_padiglione"), x["superficie_mq"],
           x["posizione"], int(x["attivo_dal"]) if x.get("attivo_dal") else None) for x in data["stand"]])
    execute_many(con, """
        INSERT INTO arcade.listino_voce
            (anno,codice_voce,descrizione,tipo,unita,prezzo_eur,disponibilita_sorgente,nota_sorgente)
        VALUES (2026,%s,%s,%s,%s,%s,%s,%s) ON CONFLICT (anno,codice_voce) DO NOTHING
    """, [(x["codice_voce"], x["descrizione"], x["tipo"], x["unita"], x["prezzo_eur"],
           x.get("disponibilita_sorgente"), x.get("nota_sorgente")) for x in data["listino"]])

    practices = {}
    imported = set()
    skipped_pairs = 0
    contracts = sorted(data["contratti"], key=lambda item: (item["edizione"], item["id_contratto"]))
    for item in contracts:
        source_id = item["id_contratto"]
        practice_id = uuid5(NAMESPACE_URL, f"standup-platform:contratto:{source_id}")
        key = (item["edizione"], item["id_espositore"])
        existing = con.execute("""
            SELECT id_pratica FROM arcade.pratica WHERE anno=%s AND id_espositore=%s
        """, key).fetchone()
        if existing and str(existing[0]) != str(practice_id):
            skipped_pairs += 1
            continue
        previous = practices.get((item["edizione"] - 1, item["id_espositore"])) if item["rinnovo"] else None
        con.execute("""
            INSERT INTO arcade.pratica
                (id_pratica,anno,id_espositore,codice_stand,stato,pacchetto,sconto_percentuale,id_pratica_precedente)
            VALUES (%s,%s,%s,%s,%s,'NON_DICHIARATO',%s,%s)
            ON CONFLICT (id_pratica) DO NOTHING
        """, (practice_id, item["edizione"], item["id_espositore"], item["codice_stand"],
              item["stato"], item["sconto_percentuale"], previous))
        practices[key] = practice_id
        imported.add(source_id)
        con.execute("""
            INSERT INTO arcade.assegnazione_stand (anno,codice_stand,id_espositore)
            VALUES (%s,%s,%s) ON CONFLICT DO NOTHING
        """, (item["edizione"], item["codice_stand"], item["id_espositore"]))
        con.execute("""
            INSERT INTO arcade.contratto_storico
                (id_contratto_origine,id_pratica,imponibile_listino_eur,sconto_dichiarato_pct,
                 imponibile_netto_eur,data_firma,acconto_scadenza,acconto_pagato_il,
                 saldo_scadenza,saldo_pagato_il,rinnovo,abbinato_per_nome,flag_qualita)
            VALUES (%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s)
            ON CONFLICT (id_contratto_origine) DO NOTHING
        """, (source_id, practice_id, item["imponibile_listino_eur"], item["sconto_percentuale"],
              item["imponibile_netto_eur"], item.get("data_firma"), item.get("acconto_scadenza"),
              item.get("acconto_pagato_il"), item.get("saldo_scadenza"), item.get("saldo_pagato_il"),
              item["rinnovo"], item["abbinato_per_nome"], item["flag_qualita"]))

    execute_many(con, """
        INSERT INTO arcade.contratto_storico_riga
            (id_contratto_origine,numero_riga,codice_voce_sorgente,descrizione,quantita,
             prezzo_unitario_eur,importo_eur,presente_nel_listino)
        VALUES (%s,%s,%s,%s,%s,%s,%s,%s) ON CONFLICT DO NOTHING
    """, [(x["id_contratto"], x["numero_riga"], x["codice_voce_sorgente"], x["descrizione"],
           x["quantita"], x["prezzo_unitario_eur"], x["importo_eur"], x["presente_nel_listino"])
          for x in data["righe_contratto"] if x["id_contratto"] in imported])

    return {
        "espositori": len(exhibitors), "planimetria": len(data["stand"]),
        "listino": len(data["listino"]), "contratti_risolti": len(imported),
        "righe_contratto": sum(x["id_contratto"] in imported for x in data["righe_contratto"]),
        "contratti_abbinati_per_nome": sum(x["abbinato_per_nome"] for x in contracts if x["id_contratto"] in imported),
        "coppie_occupate_non_importate": skipped_pairs,
        "conteggi_esclusioni": data["conteggi_esclusioni"],
        "conteggi_sorgente": data["conteggi_sorgente"],
        "righe_escluse_dai_contratti": data["conteggi_sorgente"].get("Righe_contratto", 0) - sum(x["id_contratto"] in imported for x in data["righe_contratto"]),
    }


CONTROLLI = [
    ("Ordini senza biglietti", "SELECT count(*) FROM arcade.ordine o WHERE NOT EXISTS (SELECT 1 FROM arcade.biglietto b WHERE b.id_ordine=o.id_ordine)", 0),
    ("Biglietti a pagamento con importo zero", "SELECT count(*) FROM arcade.biglietto WHERE importo_eur=0 AND categoria IN ('INTERO','FAMILY','BUSINESS')", 0),
    ("Ingressi con zero persone", "SELECT count(*) FROM arcade.accesso WHERE esito='INGRESSO' AND persone=0", 0),
    ("Rifiuti con persone conteggiate", "SELECT count(*) FROM arcade.accesso WHERE esito='INGRESSO_RIFIUTATO' AND persone>0", 0),
    ("Accessi fuori dalle date note dell'edizione", "SELECT count(*) FROM arcade.accesso a JOIN arcade.edizione e USING (anno) WHERE e.inizio_fiera IS NOT NULL AND (a.letto_il AT TIME ZONE 'Europe/Rome')::date NOT BETWEEN e.inizio_fiera AND e.fine_fiera", 0),
    ("Biglietti registrati dopo la fine della fiera", "SELECT count(*) FROM arcade.biglietto b JOIN arcade.edizione e USING (anno) WHERE e.fine_fiera IS NOT NULL AND (b.registrato_il AT TIME ZONE 'Europe/Rome')::date>e.fine_fiera", 0),
    ("Ingressi in un giorno diverso dal biglietto", """SELECT count(*) FROM arcade.accesso a JOIN arcade.biglietto b ON b.codice=a.codice_biglietto WHERE a.esito='INGRESSO' AND b.giorno_valido IS NOT NULL AND (a.letto_il AT TIME ZONE 'Europe/Rome')::date<>b.giorno_valido""", 0),
    ("Persone entrate diverse dalla quantità del biglietto", """SELECT count(*) FROM arcade.accesso a JOIN arcade.biglietto b ON b.codice=a.codice_biglietto WHERE a.esito='INGRESSO' AND a.persone<>b.quantita""", 0),
    ("Codici ai varchi non presenti in biglietteria", "SELECT count(*) FROM arcade.accesso a WHERE NOT EXISTS (SELECT 1 FROM arcade.biglietto b WHERE b.codice=a.codice_biglietto)", None),
    ("Rilevazioni stand fuori dalle fasce 09-18", "SELECT count(*) FROM arcade.visita_stand_ora WHERE extract(hour FROM ora_inizio AT TIME ZONE 'Europe/Rome') NOT BETWEEN 9 AND 18", None),
    ("Contatti senza assegnazione coerente", """SELECT count(*) FROM arcade.contatto_stand c WHERE NOT EXISTS (SELECT 1 FROM arcade.assegnazione_stand a WHERE a.anno=c.anno AND a.codice_stand=c.codice_stand AND a.id_espositore=c.id_espositore)""", 0),
    ("Minori utilizzabili per marketing", "SELECT count(*) FROM arcade.contatto_stand WHERE utilizzabile_marketing AND motivo_esclusione<>'NESSUNO'", 0),
    ("Contatti senza consenso utilizzabili", "SELECT count(*) FROM arcade.contatto_stand WHERE utilizzabile_marketing AND consenso_marketing<>'SI'", 0),
    ("Contatti privi della email riservata sorgente", """SELECT count(*) FROM arcade.contatto_stand c WHERE NOT EXISTS (SELECT 1 FROM arcade.contatto_riservato r WHERE r.id_contatto=c.id_contatto)""", 0),
    ("Fasce dichiarate mancanti con rilevazione effettiva", """SELECT count(*) FROM arcade.fascia_stand_mancante m JOIN arcade.visita_stand_ora v USING (codice_stand,ora_inizio)""", 0),
    ("Contratti storici con righe non riconciliate al lordo", """SELECT count(*) FROM arcade.contratto_storico h WHERE h.imponibile_listino_eur <> (SELECT coalesce(sum(r.importo_eur),0) FROM arcade.contratto_storico_riga r WHERE r.id_contratto_origine=h.id_contratto_origine)""", 0),
]


def source_database_counts(con, schema):
    tables = {
        "BIGLIETTERIA": "biglietto", "TORNELLI": "accesso",
        "SCANNER_STAND": "visita_stand_ora", "CONTATTI_STAND": "contatto_stand",
    }
    result = []
    for source, table in tables.items():
        expected = con.execute(sql.SQL("SELECT edizione,count(*) FROM {}.eventi WHERE fonte=%s GROUP BY edizione ORDER BY edizione").format(
            sql.Identifier(schema)), (source,)).fetchall()
        for year, rows in expected:
            actual = con.execute(sql.SQL("SELECT count(*) FROM arcade.{} WHERE anno=%s").format(sql.Identifier(table)), (year,)).fetchone()[0]
            result.append((source, table, year, rows, actual))
    return result


def counts(con, controls):
    return [(title, con.execute(query).fetchone()[0], expected) for title, query, expected in controls]


def profile_missing(con):
    result = []
    for table, field in [("biglietto", "fascia_eta"), ("biglietto", "provincia"), ("biglietto", "minore"),
                         ("contatto_stand", "fascia_eta"), ("contatto_stand", "provincia")]:
        query = sql.SQL("SELECT anno,count(*),count(*) FILTER (WHERE {}='NON_DICHIARATO') FROM arcade.{} GROUP BY anno ORDER BY anno").format(
            sql.Identifier(field), sql.Identifier(table))
        result.extend((table, field, *row) for row in con.execute(query).fetchall())
    return result


def scrivi_report(path, reconciliation, control_rows, missing, commercial, migration_names, scarto_counts, event_flags):
    lines = [
        "# Report di qualità dei dati storici e commerciali", "",
        f"Generato da `scripts/dati/importa_storici.py` il {datetime.now():%d/%m/%Y %H:%M}. Contiene solo conteggi aggregati, senza dati personali.", "",
        "Le fonti originali e i file normalizzati restano in `dati-storici/`, esclusa da Git.", "",
        "## Righe storiche normalizzate e database", "",
        "| Fonte | Tabella | Edizione | Nel dataset | Nel database | Esito |", "|---|---|---:|---:|---:|---|",
    ]
    for source, table, year, expected, actual in reconciliation:
        lines.append(f"| {source} | `{table}` | {year} | {expected:,} | {actual:,} | {'ok' if expected == actual else 'DA VERIFICARE'} |".replace(",", "."))
    lines += ["", "## Controlli di integrità", "", "| Controllo | Righe | Atteso | Esito |", "|---|---:|---|---|"]
    for title, value, expected in control_rows:
        label = "informativo" if expected is None else str(expected)
        status = "da leggere" if expected is None else ("ok" if value == expected else "DA VERIFICARE")
        lines.append(f"| {title} | {value:,} | {label} | {status} |".replace(",", "."))
    lines += ["", "## Anomalie segnalate sulle righe importate", "",
              "I valori mancanti non sono inventati. Le righe anomale affidabili restano con un flag; le duplicazioni tecniche sono registrate negli scarti.", "",
              "| Tabella | Edizione | Flag | Righe |", "|---|---:|---|---:|"]
    for table, year, flag, total in event_flags:
        lines.append(f"| `{table}` | {year} | `{flag}` | {total:,} |".replace(",", "."))
    lines += ["", "## Campi non dichiarati", "", "| Tabella | Campo | Edizione | Righe | Non dichiarati | Quota |", "|---|---|---:|---:|---:|---:|"]
    for table, field, year, total, blank in missing:
        lines.append(f"| `{table}` | `{field}` | {year} | {total:,} | {blank:,} | {100 * blank / total:.1f}% |".replace(",", "."))
    lines += ["", "## Dati commerciali", "", "| Foglio | Righe sorgente | Importate | Esito |", "|---|---:|---:|---|"]
    if commercial:
        for sheet, source_rows, imported_rows in [
            ("Espositori", commercial["conteggi_sorgente"]["Espositori"], commercial["espositori"]),
            ("Planimetria 2026", commercial["conteggi_sorgente"]["Planimetria"], commercial["planimetria"]),
            ("Listino 2026", commercial["conteggi_sorgente"]["Listino_2026"], commercial["listino"]),
            ("Contratti riconciliabili", commercial["conteggi_sorgente"]["Contratti"], commercial["contratti_risolti"]),
            ("Righe dei contratti importati", commercial["conteggi_sorgente"]["Righe_contratto"], commercial["righe_contratto"]),
        ]:
            lines.append(f"| {sheet} | {source_rows:,} | {imported_rows:,} | {'ok' if source_rows == imported_rows else 'parziale, motivato sotto'} |".replace(",", "."))
        lines += ["", "### Decisioni applicate", "",
                  f"- {commercial['contratti_abbinati_per_nome']} contratti collegati all'espositore tramite corrispondenza univoca del nome normalizzato; gli altri sono collegati per ID.",
                  f"- {commercial['conteggi_esclusioni'].get('CONTRATTO_ESPOSITORE_NON_RICONCILIABILE', 0)} contratti e {commercial['righe_escluse_dai_contratti']} righe associate sono rimasti fuori dal database perché l'espositore non è identificabile senza ambiguità.",
                  f"- {commercial['conteggi_esclusioni'].get('LISTINO_INCOMPLETO', 0)} voce listino senza unità o prezzo è stata esclusa.",
                  "- Gli sconti sorgente espressi come frazioni (per esempio 0,05) sono convertiti in punti percentuali.",
                  "- Le voci non presenti nel listino sono conservate come righe storiche del contratto, senza inventare una voce attiva.",
                  "- Il pacchetto storico non dichiarato è mostrato come NON_DICHIARATO; la data dell'acconto non crea un importo di pagamento mancante.",
                  "- L'edizione 2026 resta PIANIFICATA senza date; la fonte non ne dichiara le date della fiera."]
    lines += ["", "## Righe scartate", "", "| Fonte | Motivo | Righe |", "|---|---|---:|"]
    for source, reason, total in scarto_counts:
        lines.append(f"| {source} | `{reason}` | {total:,} |".replace(",", "."))
    if migration_names:
        lines += ["", "## Migrazioni applicate in questa esecuzione", ""]
        lines.extend(f"- `{name}`" for name in migration_names)
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text("\n".join(lines) + "\n", encoding="utf-8")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--dsn", default=os.environ.get("DATABASE_URL"), help="connessione PostgreSQL locale; in alternativa impostare DATABASE_URL")
    parser.add_argument("--dati", type=Path, default=RADICE / "dati-storici" / "normalizzati")
    parser.add_argument("--commerciale", type=Path, default=RADICE / "dati-storici" / "normalizzati" / "commerciale_normalizzato.json")
    parser.add_argument("--report", type=Path, default=RADICE / "docs" / "report-qualita-dati.md")
    args = parser.parse_args()
    if not args.dsn:
        parser.error("specificare --dsn oppure impostare DATABASE_URL nell'ambiente")

    with psycopg.connect(args.dsn) as con:
        migrations = applica_migrazioni(con)
        print("Migrazioni eseguite:", ", ".join(migrations) or "nessuna; schema già allineato")
        commercial_data = json.loads(args.commerciale.read_text(encoding="utf-8"))
        with con.transaction():
            schema, staged = load_stage(con, args.dati)
            controlla_stage(con, schema)
            before = sum(con.execute(f"SELECT count(*) FROM arcade.{table}").fetchone()[0]
                         for table in ("biglietto", "accesso", "visita_stand_ora", "contatto_stand"))
            import_id = con.execute("""
                INSERT INTO arcade.importazione (file,righe_lette) VALUES (%s,%s) RETURNING id_importazione
            """, (", ".join(FILE.values()) + ", ARCADE_Commerciale.xlsx", sum(staged.values()) + sum(commercial_data["conteggi_sorgente"].values()))).fetchone()[0]
            commercial = importa_commerciale(con, args.commerciale)
            transform = (Path(__file__).parent / "trasforma.sql").read_text(encoding="utf-8")
            transform = transform.replace("staging.", f"{schema}.")
            con.execute(transform, prepare=False)
            con.execute(sql.SQL("""
                UPDATE arcade.scarto_importazione s SET id_importazione=%s
                WHERE s.id_importazione IS NULL AND EXISTS (
                    SELECT 1 FROM {}.scarti x
                    WHERE x.fonte=s.fonte AND x.motivo=s.motivo AND x.riga_originale=s.riga_originale)
            """).format(sql.Identifier(schema)), (import_id,))
            after = sum(con.execute(f"SELECT count(*) FROM arcade.{table}").fetchone()[0]
                        for table in ("biglietto", "accesso", "visita_stand_ora", "contatto_stand"))
            con.execute("""
                UPDATE arcade.importazione SET terminata_il=now(),righe_caricate=%s,righe_scartate=%s
                WHERE id_importazione=%s
            """, (after - before, staged["scarti"], import_id))
            reconciliation = source_database_counts(con, schema)
            control_rows = counts(con, CONTROLLI)
            missing = profile_missing(con)
            event_flags = con.execute("""
                SELECT tabella,anno,flag,righe FROM arcade.v_registro_anomalie
                ORDER BY tabella,anno,righe DESC,flag
            """).fetchall()
            scarto_counts = con.execute("""
                SELECT fonte,motivo,count(*) FROM arcade.scarto_importazione
                GROUP BY fonte,motivo ORDER BY count(*) DESC,fonte,motivo
            """).fetchall()
            con.execute(sql.SQL("DROP SCHEMA {} CASCADE").format(sql.Identifier(schema)))

        scrivi_report(args.report, reconciliation, control_rows, missing, commercial,
                      migrations, scarto_counts, event_flags)
        print(f"Importazione locale {import_id}: {sum(staged.values())} righe evento/staging, {after-before} righe nuove nel dominio storico.")
        print(f"Storico commerciale: {commercial['espositori']} espositori sorgente, {commercial['planimetria']} stand, {commercial['listino']} voci listino, {commercial['contratti_risolti']} contratti, {commercial['righe_contratto']} righe contratto.")
        print(f"Esclusioni commerciali aggregate: {commercial['conteggi_esclusioni']}")
        print(f"Report aggregato: {args.report}")
        mismatches = [(source, table, year, expected, actual) for source, table, year, expected, actual in reconciliation if expected != actual]
        failed = [title for title, value, expected in control_rows if expected is not None and value != expected]
        if mismatches or failed or commercial["coppie_occupate_non_importate"]:
            print("Verifiche da rivedere:", {"riconciliazioni": len(mismatches), "controlli": failed,
                                            "coppie_pratica_occupate": commercial["coppie_occupate_non_importate"]})
            return 2
        print("Importazione completata: riconciliazioni e controlli superati.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
