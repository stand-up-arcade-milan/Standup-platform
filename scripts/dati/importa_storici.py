#!/usr/bin/env python3
"""Importa i dati storici 2024 e 2025 in PostgreSQL, con profilazione e registro delle anomalie.

Uso:
    python scripts/dati/importa_storici.py --dsn "postgresql://utente:password@localhost/arcade" --dati ./dati-storici

Fasi:
    1. applica le migrazioni di database/migrations non ancora applicate
    2. carica i file in staging, senza trasformarli
    3. controlla lo staging, si ferma se trova chiavi duplicate
    4. trasforma da staging allo schema (trasforma.sql), ripetibile
    5. registra l'importazione e scrive il report di qualità
    6. elimina lo staging, perché contiene le email

I file CSV non si versionano: contengono dati personali. Stanno fuori dal repository.
"""
import argparse
import re
import sys
from datetime import datetime
from pathlib import Path

import psycopg

RADICE = Path(__file__).resolve().parents[2]
FILE = {
    "eventi": "expodata_dataset_unificato.csv",
    "contatti": "contatti_commerciali_2025.csv",
    "fasce_mancanti": "fasce_orarie_mancanti_stand.csv",
    "anomalie": "anomalie_riepilogo.csv",
    "scarti": "scarti_righe_rimosse.csv",
}


def colonne(percorso):
    with open(percorso, encoding="utf-8-sig") as f:
        return f.readline().strip().split(",")


def applica_migrazioni(con):
    con.execute("CREATE TABLE IF NOT EXISTS public.schema_migrazioni (versione text PRIMARY KEY, applicata_il timestamptz DEFAULT now())")
    fatte = {r[0] for r in con.execute("SELECT versione FROM public.schema_migrazioni")}
    nuove = []
    for p in sorted((RADICE / "database" / "migrations").glob("V*.sql")):
        versione = p.name.split("__")[0]
        if versione in fatte:
            continue
        con.execute(p.read_text(encoding="utf-8"))
        con.execute("INSERT INTO public.schema_migrazioni (versione) VALUES (%s)", (versione,))
        nuove.append(p.name)
    con.commit()
    return nuove


def carica_staging(con, dati):
    con.execute("DROP SCHEMA IF EXISTS staging CASCADE")
    con.execute("CREATE SCHEMA staging")
    righe = {}
    for nome, file in FILE.items():
        percorso = dati / file
        if not percorso.exists():
            sys.exit(f"File mancante: {percorso}")
        cols = colonne(percorso)
        con.execute("CREATE TABLE staging.{} ({})".format(nome, ", ".join(f'"{c}" text' for c in cols)))
        with con.cursor() as cur, open(percorso, "rb") as f:
            with cur.copy(f"COPY staging.{nome} FROM STDIN WITH (FORMAT csv, HEADER true)") as copy:
                primo = True
                while blocco := f.read(1 << 20):
                    if primo and blocco.startswith(b"\xef\xbb\xbf"):
                        blocco = blocco[3:]
                    primo = False
                    copy.write(blocco)
        righe[nome] = con.execute(f"SELECT count(*) FROM staging.{nome}").fetchone()[0]
    # i valori vuoti del CSV sono stringhe vuote nei campi testo: si trattano come NULL solo dove serve, in trasforma.sql
    con.commit()
    return righe


def controlla_staging(con):
    doppi = con.execute("SELECT count(*) FROM (SELECT id_evento FROM staging.eventi GROUP BY id_evento HAVING count(*) > 1) x").fetchone()[0]
    if doppi:
        sys.exit(f"Staging non valido: {doppi} id_evento duplicati")
    mancanti = con.execute("""SELECT count(*) FROM staging.eventi e
        WHERE e.fonte = 'CONTATTI_STAND' AND NOT EXISTS (SELECT 1 FROM staging.contatti c WHERE c.id_contatto = e.id_riferimento)""").fetchone()[0]
    if mancanti:
        sys.exit(f"Staging non valido: {mancanti} contatti senza riga nel file dei contatti")



# (titolo, sql, atteso) : atteso 0 = deve restituire zero, None = dato da leggere
CONTROLLI = [
    ("Ordini senza biglietti", "SELECT count(*) FROM ordine o WHERE NOT EXISTS (SELECT 1 FROM biglietto b WHERE b.id_ordine = o.id_ordine)", 0),
    ("Biglietti con importo zero ma categoria a pagamento", "SELECT count(*) FROM biglietto WHERE importo_eur = 0 AND categoria IN ('INTERO','FAMILY','BUSINESS')", 0),
    ("Accessi con esito INGRESSO e persone = 0", "SELECT count(*) FROM accesso WHERE esito = 'INGRESSO' AND persone = 0", 0),
    ("Accessi rifiutati con persone > 0", "SELECT count(*) FROM accesso WHERE esito = 'INGRESSO_RIFIUTATO' AND persone > 0", 0),
    ("Accessi fuori dai giorni di fiera",
     "SELECT count(*) FROM accesso a JOIN edizione e USING (anno) WHERE (a.letto_il AT TIME ZONE 'Europe/Rome')::date NOT BETWEEN e.inizio_fiera AND e.fine_fiera", 0),
    ("Biglietti venduti dopo la fine della fiera",
     "SELECT count(*) FROM biglietto b JOIN edizione e USING (anno) WHERE (b.registrato_il AT TIME ZONE 'Europe/Rome')::date > e.fine_fiera", 0),
    ("Ingressi in un giorno diverso da quello valido del biglietto",
     """SELECT count(*) FROM accesso a JOIN biglietto b ON b.codice = a.codice_biglietto
        WHERE a.esito = 'INGRESSO' AND b.giorno_valido IS NOT NULL AND (a.letto_il AT TIME ZONE 'Europe/Rome')::date <> b.giorno_valido""", 0),
    ("Persone entrate diverse dalle persone del biglietto",
     """SELECT count(*) FROM accesso a JOIN biglietto b ON b.codice = a.codice_biglietto
        WHERE a.esito = 'INGRESSO' AND a.persone <> b.quantita""", 0),
    ("Codici letti ai varchi che non esistono in biglietteria",
     "SELECT count(*) FROM accesso a WHERE NOT EXISTS (SELECT 1 FROM biglietto b WHERE b.codice = a.codice_biglietto)", None),
    ("Scansioni stand fuori dall'orario 8-18",
     "SELECT count(*) FROM visita_stand_ora WHERE extract(hour FROM ora_inizio AT TIME ZONE 'Europe/Rome') NOT BETWEEN 8 AND 18", None),
    ("Contatti senza assegnazione dello stand all'espositore",
     """SELECT count(*) FROM contatto_stand c WHERE NOT EXISTS (SELECT 1 FROM assegnazione_stand a
        WHERE a.anno = c.anno AND a.codice_stand = c.codice_stand AND a.id_espositore = c.id_espositore)""", 0),
    ("Contatti di minori usabili per il marketing", "SELECT count(*) FROM contatto_stand WHERE utilizzabile_marketing AND motivo_esclusione <> 'NESSUNO'", 0),
    ("Contatti con consenso diverso da SI usabili per il marketing", "SELECT count(*) FROM contatto_stand WHERE utilizzabile_marketing AND consenso_marketing <> 'SI'", 0),
    ("Contatti senza email nella tabella riservata", "SELECT count(*) FROM contatto_stand c WHERE NOT EXISTS (SELECT 1 FROM contatto_riservato r WHERE r.id_contatto = c.id_contatto)", 0),
    ("Fasce mancanti che hanno invece una rilevazione",
     "SELECT count(*) FROM fascia_stand_mancante m JOIN visita_stand_ora v USING (codice_stand, ora_inizio)", 0),
]


def esegui_controlli(con):
    return [(t, con.execute(sql).fetchone()[0], atteso) for t, sql, atteso in CONTROLLI]


def riconciliazione(con):
    """Righe nel file contro righe nel database, per fonte."""
    righe = []
    for fonte, evento, tabella in [
        ("BIGLIETTERIA", "VENDITA", "biglietto"),
        ("TORNELLI", None, "accesso"),
        ("SCANNER_STAND", "VISITE_STAND_ORA", "visita_stand_ora"),
        ("CONTATTI_STAND", "CONTATTO", "contatto_stand"),
    ]:
        nel_file = con.execute("SELECT count(*) FROM staging.eventi WHERE fonte = %s", (fonte,)).fetchone()[0]
        nel_db = con.execute(f"SELECT count(*) FROM {tabella}").fetchone()[0]
        righe.append((fonte, tabella, nel_file, nel_db))
    return righe


def profilo_vuoti(con):
    out = []
    for tabella, col in [("biglietto", "fascia_eta"), ("biglietto", "provincia"), ("biglietto", "minore"),
                         ("contatto_stand", "fascia_eta"), ("contatto_stand", "provincia")]:
        for anno, tot, nd in con.execute(
            f"SELECT anno, count(*), count(*) FILTER (WHERE {col} = 'NON_DICHIARATO') FROM {tabella} GROUP BY anno ORDER BY anno"
        ):
            out.append((tabella, col, anno, tot, nd))
    return out


def scrivi_report(con, percorso, ric, ctrl, nuove_migrazioni):
    L = ["# Report di qualità dei dati storici", "",
         f"Generato da `scripts/dati/importa_storici.py` il {datetime.now():%d/%m/%Y %H:%M}. Non contiene dati personali.", "",
         "## Righe nel file e nel database", "",
         "| Fonte | Tabella | Righe nel file | Righe nel database | Esito |", "|---|---|---:|---:|---|"]
    for fonte, tab, f, d in ric:
        L.append(f"| {fonte} | `{tab}` | {f:,} | {d:,} | {'uguali' if f == d else 'DIVERSE'} |".replace(",", "."))
    L += ["", "## Controlli di integrità", "", "| Controllo | Righe | Atteso | Esito |", "|---|---:|---|---|"]
    for t, n, atteso in ctrl:
        if atteso is None:
            esito, att = "da leggere", "informativo"
        else:
            esito, att = ("ok" if n == atteso else "DA VERIFICARE"), str(atteso)
        L.append(f"| {t} | {n:,} | {att} | {esito} |".replace(",", "."))
    L += ["", "## Registro delle anomalie", "",
          "Conteggio dei flag scritti sulle righe, per tabella ed edizione. Le righe non si correggono, si segnalano.", "",
          "| Tabella | Edizione | Flag | Righe |", "|---|---:|---|---:|"]
    for tab, anno, flag, n in con.execute("SELECT tabella, anno, flag, righe FROM v_registro_anomalie ORDER BY tabella, anno, righe DESC"):
        L.append(f"| `{tab}` | {anno} | {flag} | {n:,} |".replace(",", "."))
    L += ["", "## Campi non dichiarati", "", "| Tabella | Campo | Edizione | Righe | Non dichiarati | Quota |", "|---|---|---:|---:|---:|---:|"]
    for tab, col, anno, tot, nd in profilo_vuoti(con):
        L.append(f"| `{tab}` | `{col}` | {anno} | {tot:,} | {nd:,} | {100 * nd / tot:.1f}% |".replace(",", "."))
    L += ["", "## Righe scartate in pulizia", "", "| Fonte | Motivo | Righe |", "|---|---|---:|"]
    for fonte, motivo, n in con.execute("SELECT fonte, motivo, count(*) FROM scarto_importazione GROUP BY 1, 2 ORDER BY 3 DESC"):
        L.append(f"| {fonte} | {motivo} | {n:,} |".replace(",", "."))
    if nuove_migrazioni:
        L += ["", "## Migrazioni applicate in questa esecuzione", ""] + [f"- `{m}`" for m in nuove_migrazioni]
    percorso.write_text("\n".join(L) + "\n", encoding="utf-8")


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--dsn", required=True, help="stringa di connessione PostgreSQL")
    ap.add_argument("--dati", required=True, type=Path, help="cartella con i CSV")
    ap.add_argument("--report", type=Path, default=RADICE / "docs" / "report-qualita-dati.md")
    ap.add_argument("--tieni-staging", action="store_true", help="non eliminare lo staging a fine importazione")
    a = ap.parse_args()

    with psycopg.connect(a.dsn) as con:
        nuove = applica_migrazioni(con)
        print("Migrazioni applicate:", ", ".join(nuove) or "nessuna nuova")

        righe = carica_staging(con, a.dati)
        print("Staging:", righe)
        controlla_staging(con)

        id_imp = con.execute("INSERT INTO arcade.importazione (file, righe_lette) VALUES (%s, %s) RETURNING id_importazione",
                             (", ".join(FILE.values()), sum(righe.values()))).fetchone()[0]
        prima = sum(con.execute(f"SELECT count(*) FROM arcade.{t}").fetchone()[0]
                    for t in ("biglietto", "accesso", "visita_stand_ora", "contatto_stand"))
        con.execute((Path(__file__).parent / "trasforma.sql").read_text(encoding="utf-8"))
        con.execute("UPDATE arcade.scarto_importazione SET id_importazione = %s WHERE id_importazione IS NULL", (id_imp,))
        dopo = sum(con.execute(f"SELECT count(*) FROM arcade.{t}").fetchone()[0]
                   for t in ("biglietto", "accesso", "visita_stand_ora", "contatto_stand"))
        con.execute("UPDATE arcade.importazione SET terminata_il = now(), righe_caricate = %s, righe_scartate = %s WHERE id_importazione = %s",
                    (dopo - prima, righe["scarti"], id_imp))
        con.commit()
        print(f"Importazione {id_imp}: nuove righe {dopo - prima:,}".replace(",", "."))

        con.execute("SET search_path TO arcade")
        ric = riconciliazione(con)
        ctrl = esegui_controlli(con)
        scrivi_report(con, a.report, ric, ctrl, nuove)
        print("Report:", a.report)

        if not a.tieni_staging:
            con.execute("DROP SCHEMA staging CASCADE")
            con.commit()

        problemi = [t for t, n, att in ctrl if att is not None and n != att] + [f for f, _, x, y in ric if x != y]
        if problemi:
            print("DA VERIFICARE:", problemi)
            sys.exit(2)
        print("Tutti i controlli superati")


if __name__ == "__main__":
    main()
