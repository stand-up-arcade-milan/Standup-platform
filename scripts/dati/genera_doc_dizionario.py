"""Genera docs/dizionario-dati.md leggendo il database.

Il dizionario vive nella tabella arcade.dizionario_dati: ogni migrazione che aggiunge
una colonna aggiunge anche la sua riga, e un controllo alla fine della migrazione
fallisce se qualcuno se ne dimentica. Questo script trasforma quella tabella in un
documento leggibile, quindi il documento non si scrive mai a mano.

Uso, con lo stack locale avviato:

    python scripts/dati/genera_doc_dizionario.py \
        --dsn postgresql://arcade_admin:arcade_dev_only@localhost:5432/arcade

Se una tabella non compare qui sotto in AREE, lo script lo segnala e la mette in
"Altre tabelle": va aggiunta all'area giusta insieme alla migrazione che la crea.
"""

from __future__ import annotations

import argparse
import datetime
import pathlib
import sys

import psycopg

# Ordine delle aree nel documento, e tabelle di ciascuna.
AREE: dict[str, list[str]] = {
    "Edizione e luoghi": [
        "edizione", "padiglione", "varco", "stand", "planimetria_stand", "parametri_stima",
    ],
    "Biglietteria": [
        "categoria_biglietto", "canale_vendita", "ordine", "biglietto",
    ],
    "Controllo accessi": [
        "accesso", "scansione_stand", "acquisizione_evento",
    ],
    "Presenze e sensori": [
        "passaggio_pedana", "conteggio_sensore_stand", "rilevazione_peso",
        "visita_stand_ora", "fascia_stand_mancante",
    ],
    "Espositori": [
        "espositore", "espositore_riservato", "assegnazione_stand", "profilo_espositore",
        "categoria_espositore", "espositore_categoria", "pacchetto_espositore",
    ],
    "Area commerciale": [
        "listino_voce", "pratica", "voce_pratica", "documento_pratica", "acconto",
        "richiesta", "richiesta_riservata", "contratto_storico", "contratto_storico_riga",
    ],
    "Visitatori e consensi": [
        "registrazione_visitatore", "registrazione_riservata", "interesse_visitatore",
        "lead_magnet", "contatto_stand", "contatto_riservato",
        "revoca_registrazione_visitatore",
    ],
    "Identità e accesso": [
        "account_espositore", "invito_espositore", "recupero_password",
        "fornitore_identita", "identita_esterna", "auth_login_rate_limit",
    ],
    "Registro degli accessi": [
        "audit_event",
    ],
    "Operatività in fiera": [
        "membro_staff", "membro_staff_riservato", "turno", "assegnazione_turno", "avviso",
    ],
    "Qualità dei dati": [
        "importazione", "scarto_importazione", "catalogo_anomalia",
    ],
    "Indicatori": [
        "lotto_kpi", "kpi_osservazione",
    ],
}

# Una riga per tabella: a cosa serve.
DESCRIZIONI: dict[str, str] = {
    "edizione": "Calendario delle edizioni della fiera. Un'edizione può essere pianificata prima che le date siano confermate",
    "padiglione": "Padiglioni della fiera",
    "varco": "Varchi con tornello, ognuno serve un padiglione",
    "stand": "Stand della fiera, con la superficie di riferimento",
    "planimetria_stand": "Posizione e superficie dello stand in una singola edizione, senza sovrascrivere lo storico",
    "parametri_stima": "Parametri usati nelle stime: ore di permanenza, peso medio, capienza, costi e soglia di sconto",
    "categoria_biglietto": "Tipi di biglietto uniformati tra le edizioni, con le persone incluse",
    "canale_vendita": "Canali di vendita dei biglietti",
    "ordine": "Ordini di acquisto, raggruppano più biglietti",
    "biglietto": "Un biglietto venduto, senza nome né contatto del titolare",
    "accesso": "Passaggi ai tornelli, ingressi e rifiuti, con il motivo del rifiuto",
    "scansione_stand": "Scansioni dei badge allo stand, una riga per scansione",
    "acquisizione_evento": "Eventi già ricevuti dall'API, per non registrare due volte lo stesso invio",
    "passaggio_pedana": "Conteggi delle pedane all'ingresso dello stand",
    "conteggio_sensore_stand": "Persone ferme davanti allo stand, rilevate dal sensore",
    "rilevazione_peso": "Rilevazioni di peso dello stand, usate per stimare le presenze",
    "visita_stand_ora": "Scansioni orarie di uno stand, aggregate",
    "fascia_stand_mancante": "Ore senza rilevazione, scanner spento o dato perso",
    "espositore": "Espositori, con il solo identificativo",
    "espositore_riservato": "Dati anagrafici e di contatto dell'espositore",
    "assegnazione_stand": "Quale espositore occupa quale stand in ogni edizione",
    "profilo_espositore": "Profilo pubblico mostrato nel portale",
    "categoria_espositore": "Categorie merceologiche degli espositori",
    "espositore_categoria": "Categorie di ogni espositore",
    "pacchetto_espositore": "Livello del pacchetto acquistato, che decide quali indicatori riceve",
    "listino_voce": "Listino prezzi per edizione, al netto di IVA",
    "pratica": "Pratica commerciale di un espositore, dal preventivo al contratto",
    "voce_pratica": "Voci di listino acquistate in una pratica, con il prezzo applicato",
    "documento_pratica": "Documenti collegati a una pratica",
    "acconto": "Acconti ricevuti per una pratica",
    "richiesta": "Richieste arrivate dal sito, senza i dati di contatto",
    "richiesta_riservata": "Nome ed email di chi ha fatto la richiesta",
    "contratto_storico": "Contratti delle edizioni passate, come riportati nella fonte",
    "contratto_storico_riga": "Righe dei contratti storici",
    "registrazione_visitatore": "Registrazione del visitatore e consensi dichiarati",
    "registrazione_riservata": "Email del visitatore e token per modificare i consensi",
    "interesse_visitatore": "Interessi dichiarati dal visitatore",
    "lead_magnet": "Contenuti offerti in cambio del contatto",
    "contatto_stand": "Contatti raccolti dallo stand, senza email",
    "contatto_riservato": "Email dei contatti, unico dato personale diretto dei contatti",
    "revoca_registrazione_visitatore": "Token con cui il visitatore modifica o revoca i consensi",
    "account_espositore": "Account di accesso degli espositori",
    "invito_espositore": "Inviti monouso per la prima attivazione di un account",
    "recupero_password": "Token monouso per reimpostare la password",
    "auth_login_rate_limit": "Conteggio dei tentativi di accesso falliti, per bloccare chi insiste",
    "audit_event": "Registro degli accessi ai dati personali e delle operazioni amministrative, senza token né contenuti",
    "fornitore_identita": "Fornitori di identità esterni abilitati",
    "identita_esterna": "Collegamento tra un account e l'identità data da Google o Microsoft",
    "membro_staff": "Persone dello staff in fiera, senza nome né recapiti",
    "membro_staff_riservato": "Nome e recapiti dello staff",
    "turno": "Turni del personale, a un varco oppure in un padiglione",
    "assegnazione_turno": "Chi copre quale turno",
    "avviso": "Avvisi di servizio per visitatori, espositori e staff",
    "importazione": "Registro delle importazioni dei dati",
    "scarto_importazione": "Righe rimosse in pulizia, con il motivo",
    "catalogo_anomalia": "Anomalie trovate in pulizia e come sono state gestite",
    "lotto_kpi": "Lotti di indicatori calcolati da BAD e ricevuti dall'API",
    "kpi_osservazione": "Singolo valore di indicatore dentro un lotto",
}

ORDINE_LIVELLI = ["PUBBLICO", "INTERNO", "RISERVATO", "PERSONALE"]

INTESTAZIONE = """# Dizionario dati

Descrive ogni colonna del database: significato, livello di sensibilità e titolare.

**Questo file è generato.** Non modificarlo a mano: la fonte è la tabella
`arcade.dizionario_dati`, che ogni migrazione riempie per le colonne che aggiunge.
Un controllo in fondo a ogni migrazione fallisce se una colonna resta senza descrizione.
Per rigenerarlo, con lo stack locale avviato:

```
python scripts/dati/genera_doc_dizionario.py --dsn postgresql://arcade_admin:arcade_dev_only@localhost:5432/arcade
```

| Livello | Significato | Chi può vederlo |
|---|---|---|
| PUBBLICO | Può comparire sul portale | Tutti |
| INTERNO | Dato operativo senza persone identificabili | Organizzazione e team |
| RISERVATO | Quasi-identificatore o dato di uno solo | Proprietario, oppure solo aggregato |
| PERSONALE | Identifica una persona | Solo chi gestisce i dati personali |
"""


def leggi(dsn: str) -> dict[str, list[tuple[str, str, str, str]]]:
    """Ritorna {tabella: [(colonna, tipo, descrizione, sensibilita)]} in ordine di colonna."""
    sql = """
        SELECT d.tabella, d.colonna, d.tipo, d.descrizione, d.sensibilita, d.titolare
        FROM arcade.dizionario_dati d
        JOIN information_schema.columns c
          ON c.table_schema = 'arcade' AND c.table_name = d.tabella AND c.column_name = d.colonna
        ORDER BY d.tabella, c.ordinal_position
    """
    tabelle: dict[str, list[tuple[str, str, str, str]]] = {}
    titolari: dict[str, str] = {}
    with psycopg.connect(dsn) as conn, conn.cursor() as cur:
        cur.execute(sql)
        for tabella, colonna, tipo, descrizione, sensibilita, titolare in cur.fetchall():
            tabelle.setdefault(tabella, []).append((colonna, tipo, descrizione, sensibilita))
            titolari.setdefault(tabella, titolare)
    return tabelle, titolari


def livello_tabella(colonne) -> str:
    return max((c[3] for c in colonne), key=ORDINE_LIVELLI.index)


def genera(tabelle, titolari) -> str:
    note = list(INTESTAZIONE.rstrip().split("\n"))
    note.append("")
    note.append(f"Generato il {datetime.date.today().strftime('%d/%m/%Y')} "
                f"su {len(tabelle)} tabelle e {sum(len(c) for c in tabelle.values())} colonne.")
    note.append("")

    viste = dict(AREE)
    collocate = {t for lista in AREE.values() for t in lista}
    orfane = sorted(set(tabelle) - collocate)
    if orfane:
        viste["Altre tabelle"] = orfane
        print(f"Attenzione: tabelle senza area: {', '.join(orfane)}", file=sys.stderr)

    for area, lista in viste.items():
        presenti = [t for t in lista if t in tabelle]
        if not presenti:
            continue
        note += [f"## {area}", ""]
        for tabella in presenti:
            colonne = tabelle[tabella]
            descrizione = DESCRIZIONI.get(tabella, "Da descrivere")
            note += [
                f"### {tabella}",
                "",
                f"{descrizione}. Titolare: {titolari[tabella]}. "
                f"Livello della tabella: {livello_tabella(colonne)}.",
                "",
                "| Colonna | Tipo | Descrizione | Livello |",
                "|---|---|---|---|",
            ]
            note += [f"| `{c}` | `{t}` | {d} | {s} |" for c, t, d, s in colonne]
            note.append("")
    return "\n".join(note) + "\n"


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--dsn", required=True, help="Stringa di connessione a PostgreSQL")
    ap.add_argument("--out", default="docs/dizionario-dati.md", help="File da scrivere")
    args = ap.parse_args()

    tabelle, titolari = leggi(args.dsn)
    if not tabelle:
        print("Il dizionario nel database è vuoto: migrazioni non applicate?", file=sys.stderr)
        return 1

    percorso = pathlib.Path(args.out)
    percorso.parent.mkdir(parents=True, exist_ok=True)
    percorso.write_text(genera(tabelle, titolari), encoding="utf-8")
    print(f"{percorso}: {len(tabelle)} tabelle, "
          f"{sum(len(c) for c in tabelle.values())} colonne")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
