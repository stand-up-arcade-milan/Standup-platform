"""Controlla che docs/modello-er.md non resti indietro rispetto al database.

Il dizionario dati si rigenera da solo (genera_doc_dizionario.py), mentre i diagrammi
del modello ER sono scritti a mano, perché decidere cosa mostrare e cosa lasciare fuori
è una scelta di chi legge. Questo script non li riscrive: verifica soltanto che ogni
tabella del database sia nominata almeno una volta nel documento, e segnala quelle che
mancano e quelle che non esistono più.

Uso, con lo stack locale avviato:

    python scripts/dati/verifica_modello_er.py \
        --dsn postgresql://arcade_admin:arcade_dev_only@localhost:5432/arcade

Esce con codice 1 se qualcosa non torna, così può stare nella CI.
"""

from __future__ import annotations

import argparse
import pathlib
import re
import sys

import psycopg

# Tabelle che per scelta non compaiono nei diagrammi: vanno motivate qui, non ignorate in silenzio.
ESCLUSE: dict[str, str] = {
    "dizionario_dati": "è il dizionario stesso, descritto a parte",
}


def tabelle_del_database(dsn: str) -> set[str]:
    sql = """
        SELECT table_name
        FROM information_schema.tables
        WHERE table_schema = 'arcade' AND table_type = 'BASE TABLE'
    """
    with psycopg.connect(dsn) as conn, conn.cursor() as cur:
        cur.execute(sql)
        return {r[0] for r in cur.fetchall()}


def nomi_citati(testo: str) -> set[str]:
    """Parole che possono essere nomi di tabella, dentro il documento."""
    return set(re.findall(r"[a-z][a-z0-9_]{2,}", testo))


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--dsn", required=True, help="Stringa di connessione a PostgreSQL")
    ap.add_argument("--doc", default="docs/modello-er.md", help="Documento da controllare")
    args = ap.parse_args()

    percorso = pathlib.Path(args.doc)
    if not percorso.exists():
        print(f"{percorso}: non esiste", file=sys.stderr)
        return 1

    testo = percorso.read_text(encoding="utf-8")
    citate = nomi_citati(testo)
    nel_database = tabelle_del_database(args.dsn)

    mancanti = sorted(t for t in nel_database - citate if t not in ESCLUSE)
    # Nomi che sembrano tabelle del progetto ma non esistono più nel database.
    sospette = sorted(
        n for n in citate
        if n.startswith(("contratto_", "membro_", "identita_", "planimetria_", "recupero_"))
        and n not in nel_database and not n.startswith("v_")
    )

    if mancanti:
        print("Tabelle nel database e non nel modello ER:", file=sys.stderr)
        for t in mancanti:
            print(f"  - {t}", file=sys.stderr)
    if sospette:
        print("Nomi citati nel modello ER e non presenti nel database:", file=sys.stderr)
        for t in sospette:
            print(f"  - {t}", file=sys.stderr)

    if mancanti or sospette:
        print(
            f"\n{percorso} è da aggiornare: {len(nel_database)} tabelle nel database, "
            f"{len(mancanti)} non citate.",
            file=sys.stderr,
        )
        return 1

    print(f"{percorso}: tutte le {len(nel_database)} tabelle del database sono citate.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
