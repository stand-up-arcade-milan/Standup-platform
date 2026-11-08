#!/usr/bin/env python3
"""Normalizza gli export Arcade in file locali pronti per l'importazione."""

import argparse
import csv
import json
import re
import unicodedata
from collections import Counter, defaultdict
from datetime import date, datetime, time
from decimal import Decimal, InvalidOperation
from pathlib import Path
from zoneinfo import ZoneInfo

from openpyxl import load_workbook

RADICE = Path(__file__).resolve().parents[2]
FUSO = ZoneInfo("Europe/Rome")
GIORNI_FIERA = {2024: date(2024, 12, 20), 2025: date(2025, 12, 19)}
EVENTI = [
    "id_evento", "edizione", "fonte", "evento", "data", "ora", "giorno_fiera",
    "padiglione", "luogo", "id_riferimento", "id_ordine", "id_espositore",
    "categoria_biglietto", "giorno_valido", "fascia_eta", "minore", "provincia",
    "codice_sconto", "quantita", "importo_eur", "interesse", "motivo_rifiuto",
    "controllo_qualita",
]
CONTATTI = [
    "id_contatto", "email", "consenso_marketing", "utilizzabile_marketing",
    "motivo_esclusione", "email_su_piu_stand",
]
CODICI = {
    "FASCIA_ETA_MANCANTE": "La fascia d'età non è dichiarata; resta NON_DICHIARATO.",
    "PROVINCIA_MANCANTE": "La provincia non è dichiarata; resta NON_DICHIARATO.",
    "ACQUISTO_REGISTRATO_DOPO_INGRESSO": "L'orario sorgente di registrazione segue il primo ingresso; si conserva ma non si interpreta come ora di vendita.",
    "RIDOTTO_FASCIA_14_17": "Biglietto ridotto associato a una fascia 14-17; si conserva e si segnala.",
    "SCONTO_SU_BIGLIETTO_GRATUITO": "Codice sconto su biglietto gratuito; si conserva e si segnala.",
    "EARLY10_USATO_DURANTE_FIERA": "Codice EARLY10 registrato durante la fiera; si conserva e si separa nelle analisi.",
    "BIGLIETTO_INESISTENTE_IN_BIGLIETTERIA": "Codice assente dalla biglietteria: l'accesso non viene contato come ingresso.",
    "GIORNO_NON_VALIDO": "Il biglietto risulta usato fuori dal giorno di validità; l'esito viene trattato come rifiutato.",
    "RIUTILIZZO_IMMEDIATO_RESPINTO": "Rifiuto entro due minuti da un ingresso valido dello stesso biglietto; si conserva come rifiuto.",
    "LETTURA_DOPPIA_ENTRO_10_SECONDI": "Lettura ripetuta dello stesso biglietto con il medesimo esito entro dieci secondi; la ripetizione è scartata.",
    "FUORI_ORARIO_VALORE_ANOMALO": "Rilevazione dello stand fuori dalle fasce 09:00-18:00; si conserva ma non entra nei KPI orari.",
    "FASCIA_STAND_MANCANTE": "Nessuna rilevazione nella fascia; non si inventa un conteggio.",
    "MINORE_14_17": "Contatto di una persona di 14-17 anni; escluso dall'uso marketing.",
    "CONSENSO_MANCANTE": "Il consenso non è compilato; trattato come NON_DICHIARATO e non utilizzabile.",
    "EMAIL_CONFLITTO": "La stessa email compare su stand diversi con fascia d'età o provincia discordante; esclusa dall'uso marketing.",
    "CONTATTO_IN_FASCIA_SENZA_SCANSIONI": "Contatto presente in una fascia senza scansioni registrate; si conserva e si segnala.",
    "ABBINATO_PER_NOME": "Contratto collegato a un espositore tramite corrispondenza univoca del nome normalizzato.",
    "PACCHETTO_NON_DICHIARATO": "Il foglio non dichiara il pacchetto BASE o PREMIUM.",
    "ACCONTO_IMPORTO_NON_PRESENTE": "La fonte riporta la data di pagamento dell'acconto, ma non l'importo.",
    "SALDO_IMPORTO_NON_PRESENTE": "La fonte riporta la data di pagamento del saldo, ma non l'importo.",
    "LISTINO_INCOMPLETO": "Voce senza unità o prezzo; non viene caricata nel listino utilizzabile.",
    "SCONTO_NORMALIZZATO_DA_FRAZIONE": "La percentuale sorgente era espressa come frazione (es. 0,05); convertita in punti percentuali.",
}

PROVINCE = {
    "milano": "MI", "monza e brianza": "MB", "bergamo": "BG", "varese": "VA",
    "torino": "TO", "brescia": "BS", "como": "CO", "pavia": "PV", "lecco": "LC",
    "novara": "NO", "lodi": "LO", "verona": "VR", "padova": "PD", "piacenza": "PC",
    "bologna": "BO", "parma": "PR", "genova": "GE", "napoli": "NA", "firenze": "FI",
    "roma": "RM", "cremona": "CR",
}
CANALI = {"online": "ONLINE", "cassa": "CASSA", "rivenditore partner": "RIVENDITORE_PARTNER"}
SCONTI = {"": "NESSUNO", "scuola": "SCUOLA", "studenti": "STUDENTI", "early10": "EARLY10"}
INTERESSI = {
    "beta test": "BETA_TEST", "newsletter": "NEWSLETTER", "evento": "EVENTO",
    "prodotto": "PRODOTTO", "lavoro/stage": "LAVORO_STAGE",
}


def fold(value):
    return unicodedata.normalize("NFKD", str(value or "")).encode("ascii", "ignore").decode().casefold().strip()


def read_csv(path):
    with path.open(encoding="utf-8-sig", newline="") as file:
        sample = file.read(8192)
        file.seek(0)
        dialect = csv.Sniffer().sniff(sample, delimiters=",;")
        return list(csv.DictReader(file, dialect=dialect))


def write_csv(path, columns, rows):
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8", newline="") as file:
        writer = csv.DictWriter(file, fieldnames=columns, extrasaction="ignore")
        writer.writeheader()
        writer.writerows(rows)


def dt_locale(raw):
    return datetime.strptime(str(raw).strip(), "%d/%m/%Y %H:%M").replace(tzinfo=FUSO)


def parse_date(value):
    if value in (None, ""):
        return None
    if isinstance(value, datetime):
        return value.date()
    if isinstance(value, date):
        return value
    for fmt in ("%d/%m/%Y", "%Y-%m-%d", "%d-%m-%Y"):
        try:
            return datetime.strptime(str(value).strip(), fmt).date()
        except ValueError:
            pass
    raise ValueError("data non riconosciuta")


def money(value):
    return Decimal(str(value).strip().replace("€", "").replace(" ", "").replace(",", ".")).quantize(Decimal("0.01"))


def raw_row(row, line_number):
    return json.dumps({"riga_fonte": line_number, "dati": row}, ensure_ascii=False, sort_keys=True)


def amount(value):
    return format(Decimal(value).quantize(Decimal("0.01")), "f")


def day_number(year, value):
    start = GIORNI_FIERA[year]
    delta = (value - start).days
    return delta + 1 if 0 <= delta <= 2 else 0


def province(value):
    raw = str(value or "").strip()
    if not raw:
        return "NON_DICHIARATO"
    key = fold(raw)
    return PROVINCE.get(key, raw.upper())


def age_band(value):
    raw = str(value or "").strip()
    if not raw:
        return "NON_DICHIARATO"
    return "FAMIGLIA" if fold(raw) == "famiglia" else raw


def ticket_category(value):
    raw = fold(value)
    if "3gg" in raw or "3 giorni" in raw:
        return "ABBONAMENTO_3GG"
    if "family" in raw:
        return "FAMILY"
    if "business" in raw:
        return "BUSINESS"
    if "vip" in raw:
        return "VIP"
    if "stamp" in raw or "accredito" in raw:
        return "STAMPA"
    if "omaggio" in raw or "gratuito" in raw or "under 8" in raw or "u8" in raw:
        return "GRATUITO_U8"
    if "ridotto" in raw:
        return "RIDOTTO"
    if "intero" in raw:
        return "INTERO"
    raise ValueError("tipo biglietto non riconosciuto")


def event_row(**values):
    row = {field: "" for field in EVENTI}
    row.update(values)
    row["controllo_qualita"] = "|".join(sorted(set(values.get("flags", [])))) or "OK"
    row.pop("flags", None)
    return row


def load_workbook_data(path):
    workbook = load_workbook(path, read_only=True, data_only=True)

    def sheet(name):
        rows = workbook[name].iter_rows(values_only=True)
        headers = [str(value or "").strip() for value in next(rows)]
        return [dict(zip(headers, row)) for row in rows]

    return {name: sheet(name) for name in (
        "Espositori", "Planimetria", "Listino_2026", "Contratti", "Righe_contratto"
    )}


def commercial_data(path):
    sheets = load_workbook_data(path)
    exhibitors, stands, catalog = [], [], []
    excluded = Counter()
    source_exhibitors = {}

    for row in sheets["Espositori"]:
        code = str(row.get("id_espositore") or "").strip()
        name = str(row.get("ragione_sociale") or "").strip()
        if not code or not name:
            excluded["ESPOSITORE_SENZA_ID_O_NOME"] += 1
            continue
        email = str(row.get("email_referente") or "").strip()
        email_ok = bool(re.fullmatch(r"[^\s@]+@[^\s@]+\.[^\s@]+", email))
        item = {
            "id_espositore": code,
            "ragione_sociale": name,
            "partita_iva": str(row.get("partita_iva") or "").strip() or None,
            "settore": str(row.get("settore") or "").strip() or None,
            "citta": str(row.get("citta") or "").strip() or None,
            "referente": str(row.get("referente") or "").strip() or None,
            "email_referente": email.casefold() if email_ok else None,
            "flag_qualita": [] if email_ok or not email else ["EMAIL_REFERENTE_NON_VALIDA"],
        }
        exhibitors.append(item)
        source_exhibitors[code] = item

    name_index = defaultdict(set)
    for item in exhibitors:
        name_index[fold(item["ragione_sociale"])].add(item["id_espositore"])

    for row in sheets["Planimetria"]:
        code = str(row.get("codice_stand") or "").strip()
        pavilion = str(row.get("padiglione") or "").strip().upper()
        position = str(row.get("posizione") or "").strip()
        try:
            area = money(row.get("mq"))
            active_raw = row.get("attivo_dal")
            if isinstance(active_raw, (datetime, date)):
                active_year = active_raw.year
            elif active_raw in (None, ""):
                active_year = None
            else:
                active_year = int(float(active_raw))
            if not code or pavilion not in {"P1", "P2", "P3"} or not position or area <= 0:
                raise ValueError("planimetria incompleta")
            if active_year is not None and not 2000 <= active_year <= 2100:
                raise ValueError("anno di attivazione non valido")
        except (ValueError, InvalidOperation):
            excluded["STAND_PLANIMETRIA_NON_VALIDO"] += 1
            continue
        stands.append({
            "codice_stand": code, "padiglione": pavilion,
            "nome_padiglione": str(row.get("nome_padiglione") or "").strip() or None,
            "superficie_mq": amount(area), "posizione": position,
            "attivo_dal": str(active_year) if active_year else None,
        })

    catalog_codes = set()
    for row in sheets["Listino_2026"]:
        code = str(row.get("codice") or "").strip()
        description = str(row.get("voce") or "").strip()
        unit_raw = str(row.get("unita") or "").strip()
        try:
            price = money(row.get("prezzo_unitario_eur"))
            unit_key = fold(unit_raw).replace(" ", "")
            if unit_key in {"m2", "m²"}:
                unit = "MQ"
                kind = "STAND"
            elif unit_key == "%suarea":
                unit = "PERCENTUALE_MQ"
                kind = "SERVIZIO"
            elif unit_key == "%":
                unit = "PERCENTUALE"
                kind = "SERVIZIO"
            elif unit_key == "pacchetto":
                unit = "FORFAIT"
                kind = "PACCHETTO"
            elif unit_key in {"cad.", "cad"}:
                unit = "FORFAIT"
                kind = "SERVIZIO"
            else:
                raise ValueError("unità non riconosciuta")
            if not code or not description or price < 0:
                raise ValueError("voce incompleta")
        except (InvalidOperation, ValueError, TypeError):
            excluded["LISTINO_INCOMPLETO"] += 1
            continue
        item = {
            "codice_voce": code, "descrizione": description, "tipo": kind,
            "unita": unit, "prezzo_eur": amount(price),
            "disponibilita_sorgente": str(row.get("disponibilita") or "").strip() or None,
            "nota_sorgente": str(row.get("note") or "").strip() or None,
        }
        catalog.append(item)
        catalog_codes.add(code)

    contracts_raw = sheets["Contratti"]
    contracts_by_id = {}
    excluded_contracts = []
    linked_pairs = set()
    for index, row in enumerate(contracts_raw, start=2):
        source_id = str(row.get("id_contratto") or "").strip()
        year = int(row["edizione"])
        exhibitor_id = str(row.get("id_espositore") or "").strip()
        matched_by_name = False
        if exhibitor_id not in source_exhibitors:
            matches = name_index.get(fold(row.get("ragione_sociale")), set())
            if len(matches) != 1:
                excluded["CONTRATTO_ESPOSITORE_NON_RICONCILIABILE"] += 1
                excluded_contracts.append({"id_contratto": source_id, "riga_fonte": index,
                                           "motivo": "ESPOSITORE_NON_RICONCILIABILE"})
                continue
            exhibitor_id = next(iter(matches))
            matched_by_name = True
        pair = (year, exhibitor_id)
        if pair in linked_pairs:
            excluded["PIU_CONTRATTI_PER_ESPOSITORE_EDIZIONE"] += 1
            excluded_contracts.append({"id_contratto": source_id, "riga_fonte": index,
                                       "motivo": "PIU_CONTRATTI_PER_ESPOSITORE_EDIZIONE"})
            continue
        stand = str(row.get("codice_stand") or "").strip()
        pavilion = stand.split("-", 1)[0].upper()
        if not stand or pavilion not in {"P1", "P2", "P3"}:
            excluded["CONTRATTO_STAND_NON_RICONCILIABILE"] += 1
            excluded_contracts.append({"id_contratto": source_id, "riga_fonte": index,
                                       "motivo": "STAND_NON_RICONCILIABILE"})
            continue
        try:
            gross = money(row.get("imponibile_listino_eur"))
            net = money(row.get("imponibile_eur"))
            source_discount = Decimal(str(row.get("sconto_pct") or 0))
            discount_pct = source_discount * 100 if 0 <= source_discount <= 1 else source_discount
            if not (0 <= discount_pct <= 100) or gross < 0 or net < 0:
                raise ValueError("importo o sconto fuori intervallo")
            signed = parse_date(row.get("data_firma"))
            deposit_due = parse_date(row.get("acconto_scadenza"))
            deposit_paid = parse_date(row.get("acconto_pagato_il"))
            balance_due = parse_date(row.get("saldo_scadenza"))
            balance_paid = parse_date(row.get("saldo_pagato_il"))
        except (InvalidOperation, TypeError, ValueError):
            excluded["CONTRATTO_CON_IMPORTI_O_DATE_NON_VALIDI"] += 1
            excluded_contracts.append({"id_contratto": source_id, "riga_fonte": index,
                                       "motivo": "IMPORTI_O_DATE_NON_VALIDI"})
            continue
        flags = ["PACCHETTO_NON_DICHIARATO"]
        if matched_by_name:
            flags.append("ABBINATO_PER_NOME")
        if discount_pct != source_discount:
            flags.append("SCONTO_NORMALIZZATO_DA_FRAZIONE")
        if deposit_paid:
            flags.append("ACCONTO_IMPORTO_NON_PRESENTE")
        if balance_paid:
            flags.append("SALDO_IMPORTO_NON_PRESENTE")
        if gross and (gross * (1 - discount_pct / 100)).quantize(Decimal("0.01")) != net:
            flags.append("TOTALE_NON_COINCIDE_CON_SCONTO")
        contract = {
            "id_contratto": source_id, "riga_fonte": index, "edizione": year,
            "id_espositore": exhibitor_id, "abbinato_per_nome": matched_by_name,
            "codice_stand": stand, "stato": "ACCONTO_RICEVUTO" if deposit_paid else "FIRMATA" if signed else "INVIATA",
            "sconto_percentuale": str(discount_pct.quantize(Decimal("0.01"))),
            "imponibile_listino_eur": amount(gross), "imponibile_netto_eur": amount(net),
            "data_firma": signed.isoformat() if signed else None,
            "acconto_scadenza": deposit_due.isoformat() if deposit_due else None,
            "acconto_pagato_il": deposit_paid.isoformat() if deposit_paid else None,
            "saldo_scadenza": balance_due.isoformat() if balance_due else None,
            "saldo_pagato_il": balance_paid.isoformat() if balance_paid else None,
            "rinnovo": fold(row.get("rinnovo")) in {"si", "s", "true", "1"},
            "flag_qualita": flags,
        }
        contracts_by_id[source_id] = contract
        linked_pairs.add(pair)

    lines = []
    contract_totals = defaultdict(Decimal)
    for index, row in enumerate(sheets["Righe_contratto"], start=2):
        contract_id = str(row.get("id_contratto") or "").strip()
        if contract_id not in contracts_by_id:
            continue
        try:
            quantity = Decimal(str(row.get("quantita")))
            unit_price = money(row.get("prezzo_unitario_eur"))
            line_amount = money(row.get("importo_eur"))
            if quantity <= 0 or unit_price < 0 or line_amount < 0:
                raise ValueError("quantità o importo fuori intervallo")
        except (InvalidOperation, ValueError, TypeError):
            excluded["RIGA_CONTRATTO_NON_VALIDA"] += 1
            continue
        contract_totals[contract_id] += line_amount
        code = str(row.get("codice_voce") or "").strip()
        lines.append({
            "id_contratto": contract_id, "numero_riga": index,
            "codice_voce_sorgente": code,
            "descrizione": str(row.get("descrizione") or "").strip(),
            "quantita": str(quantity), "prezzo_unitario_eur": amount(unit_price),
            "importo_eur": amount(line_amount), "presente_nel_listino": code in catalog_codes,
        })
    for contract_id, total in contract_totals.items():
        if total != Decimal(contracts_by_id[contract_id]["imponibile_listino_eur"]):
            contracts_by_id[contract_id]["flag_qualita"].append("RIGHE_CONTRATTO_NON_RICONCILIATE")

    return {
        "espositori": exhibitors, "stand": stands, "listino": catalog,
        "contratti": list(contracts_by_id.values()), "righe_contratto": lines,
        "contratti_esclusi": excluded_contracts, "conteggi_esclusioni": dict(excluded),
        "conteggi_sorgente": {name: len(rows) for name, rows in sheets.items()},
    }


def prepare(source, target):
    original = {
        "ticket24": source / "biglietteria_2024.csv",
        "ticket25": source / "biglietteria_2025.csv",
        "gate24": source / "tornelli_2024.csv",
        "gate25": source / "tornelli_2025.csv",
        "visits": source / "visite_stand_2025.csv",
        "contacts": source / "contatti_stand_2025.csv",
        "workbook": source / "ARCADE_Commerciale.xlsx",
    }
    missing = [str(path) for path in original.values() if not path.is_file()]
    if missing:
        raise FileNotFoundError("Fonti mancanti: " + ", ".join(missing))

    raw_tickets = {2024: read_csv(original["ticket24"]), 2025: read_csv(original["ticket25"])}
    tickets, ticket_events = {}, []
    excluded = []
    ticket_flags = Counter()
    for year, rows in raw_tickets.items():
        for line, row in enumerate(rows, start=2):
            try:
                registered = dt_locale(row["Data acquisto"])
                category = ticket_category(row["Tipo biglietto"])
                channel = CANALI[fold(row["Canale"])]
                quantity = int(row["Persone"])
                price = money(row["Prezzo"])
                valid_raw = str(row.get("Giorno valido") or "").strip()
                valid_day = None if fold(valid_raw) in {"3 giorni", "tutti"} else datetime.strptime(valid_raw, "%d/%m/%Y").date()
                code = str(row["ID biglietto"]).strip()
                order = str(row["ID ordine"]).strip()
                if not code or not order or quantity < 1 or price < 0:
                    raise ValueError("chiave o importo non valido")
            except (KeyError, ValueError, InvalidOperation, TypeError):
                excluded.append({"fonte": f"BIGLIETTERIA_{year}", "motivo": "RIGA_NON_VALIDA", "riga_originale": raw_row(row, line)})
                continue
            age_raw = str(row.get("Fascia eta titolare") or "").strip()
            age = age_band(age_raw)
            minore = "SI" if age in {"0-7", "8-13", "14-17"} else "NO" if age in {"18-24", "25-34", "35-44", "45+"} else "NON_DICHIARATO"
            p = province(row.get("Provincia"))
            discount_raw = fold(row.get("Codice sconto"))
            if discount_raw not in SCONTI:
                excluded.append({"fonte": f"BIGLIETTERIA_{year}", "motivo": "SCONTO_NON_RICONOSCIUTO", "riga_originale": raw_row(row, line)})
                continue
            flags = []
            if not age_raw:
                flags.append("FASCIA_ETA_MANCANTE")
            if p == "NON_DICHIARATO":
                flags.append("PROVINCIA_MANCANTE")
            if category == "RIDOTTO" and age == "14-17":
                flags.append("RIDOTTO_FASCIA_14_17")
            if category == "GRATUITO_U8" and SCONTI[discount_raw] != "NESSUNO":
                flags.append("SCONTO_SU_BIGLIETTO_GRATUITO")
            if SCONTI[discount_raw] == "EARLY10" and day_number(year, registered.date()) > 0:
                flags.append("EARLY10_USATO_DURANTE_FIERA")
            code_key = (year, code)
            if code_key in tickets:
                excluded.append({"fonte": f"BIGLIETTERIA_{year}", "motivo": "CODICE_BIGLIETTO_DUPLICATO", "riga_originale": raw_row(row, line)})
                continue
            ticket = {
                "code": code, "order": order, "registered": registered, "category": category,
                "day": valid_day, "age": age, "minor": minore, "province": p,
                "discount": SCONTI[discount_raw], "quantity": quantity, "price": price,
                "flags": flags,
            }
            tickets[code_key] = ticket
            ticket_events.append(event_row(
                id_evento=f"BIGLIETTO-{year}-{code}", edizione=year, fonte="BIGLIETTERIA",
                evento="VENDITA", data=registered.date().isoformat(), ora=registered.time().replace(tzinfo=None).isoformat(),
                giorno_fiera=day_number(year, registered.date()), luogo=channel, id_riferimento=code,
                id_ordine=order, categoria_biglietto=category,
                giorno_valido=valid_day.isoformat() if valid_day else "TUTTI", fascia_eta=age,
                minore=minore, provincia=p, codice_sconto=SCONTI[discount_raw], quantita=quantity,
                importo_eur=amount(price), flags=flags,
            ))

    raw_access = {2024: read_csv(original["gate24"]), 2025: read_csv(original["gate25"])}
    accesses, first_entry = [], {}
    removed_duplicates = Counter()
    for year, rows in raw_access.items():
        parsed = []
        for line, row in enumerate(rows, start=2):
            try:
                if year == 2024:
                    stamp = datetime.strptime(f"{row['data']} {row['ora']}", "%d/%m/%Y %H:%M:%S").replace(tzinfo=FUSO)
                    code, gate_raw, accepted = row["codice"].strip(), row["varco"], row["esito"].strip() == "1"
                else:
                    stamp = datetime.fromisoformat(row["timestamp_utc"].strip().replace("Z", "+00:00")).astimezone(FUSO)
                    code, gate_raw, accepted = row["ticket_code"].strip(), row["gate_id"], row["result"].strip() == "OK"
                gate = re.sub(r"\s+", "-", str(gate_raw).strip().upper())
                if gate not in {"P1-NORD", "P1-SUD", "P2-OVEST", "P3-EST"} or not code:
                    raise ValueError("varco o codice non valido")
                parsed.append({"year": year, "row": row, "line": line, "stamp": stamp,
                               "code": code, "gate": gate, "accepted": accepted})
            except (KeyError, ValueError, TypeError):
                excluded.append({"fonte": f"TORNELLI_{year}", "motivo": "RIGA_NON_VALIDA", "riga_originale": raw_row(row, line)})
        parsed.sort(key=lambda item: (item["code"], item["stamp"], item["line"]))
        previous_raw = {}
        for item in parsed:
            code = item["code"]
            previous = previous_raw.get(code)
            seconds = (item["stamp"] - previous["stamp"]).total_seconds() if previous else None
            if previous and 0 <= seconds <= 10 and previous["accepted"] == item["accepted"]:
                removed_duplicates[year] += 1
                excluded.append({"fonte": f"TORNELLI_{year}", "motivo": "LETTURA_DOPPIA_ENTRO_10_SECONDI",
                                 "riga_originale": raw_row(item["row"], item["line"])})
                previous_raw[code] = item
                continue

            ticket = tickets.get((year, code))
            flags = []
            reason = ""
            if not ticket:
                flags.append("BIGLIETTO_INESISTENTE_IN_BIGLIETTERIA")
                accepted = False
                reason = "BIGLIETTO_NON_VALIDO"
            else:
                accepted = item["accepted"]
                if ticket["province"] == "NON_DICHIARATO":
                    flags.append("PROVINCIA_MANCANTE")
                if ticket["age"] == "NON_DICHIARATO":
                    flags.append("FASCIA_ETA_MANCANTE")
                if ticket["day"] and ticket["day"] != item["stamp"].date() and accepted:
                    accepted = False
                    reason = "GIORNO_NON_VALIDO"
                    flags.append("GIORNO_NON_VALIDO")
                elif not accepted and previous and previous["accepted"] and seconds is not None and 0 <= seconds <= 120:
                    reason = "GIA_USATO"
                    flags.append("RIUTILIZZO_IMMEDIATO_RESPINTO")
            if accepted:
                first_entry[(year, code)] = min(first_entry.get((year, code), item["stamp"]), item["stamp"])
            accesses.append({**item, "accepted_normalized": accepted, "reason": reason, "flags": flags})
            previous_raw[code] = item

    for event in ticket_events:
        ticket = tickets[(int(event["edizione"]), event["id_riferimento"])]
        entry = first_entry.get((int(event["edizione"]), event["id_riferimento"]))
        if entry and ticket["registered"] > entry:
            ticket["flags"].append("ACQUISTO_REGISTRATO_DOPO_INGRESSO")
            event["controllo_qualita"] = "|".join(sorted(set(ticket["flags"])))

    access_events = []
    for item in accesses:
        year, code, stamp = item["year"], item["code"], item["stamp"]
        ticket = tickets.get((year, code))
        accepted = item["accepted_normalized"]
        flags = item["flags"]
        access_events.append(event_row(
            id_evento=f"TORNELLO-{year}-{item['line']}", edizione=year, fonte="TORNELLI",
            evento="INGRESSO" if accepted else "INGRESSO_RIFIUTATO", data=stamp.date().isoformat(),
            ora=stamp.time().replace(tzinfo=None).isoformat(), giorno_fiera=day_number(year, stamp.date()),
            padiglione=item["gate"].split("-", 1)[0], luogo=item["gate"], id_riferimento=code,
            categoria_biglietto=ticket["category"] if ticket else "",
            quantita=ticket["quantity"] if accepted and ticket else 0,
            motivo_rifiuto=item["reason"], flags=flags,
        ))

    visits_raw = read_csv(original["visits"])
    visits, scan_counts, seen_slots, all_stands, scan_days = [], Counter(), set(), set(), set()
    for line, row in enumerate(visits_raw, start=2):
        try:
            code = str(row["codice_stand"]).strip()
            day = date.fromisoformat(str(row["data"]).strip())
            hour = datetime.strptime(str(row["ora"]).strip(), "%H:%M").time()
            quantity = int(row["scansioni"])
            pavilion = code.split("-", 1)[0].upper()
            if not code or pavilion not in {"P1", "P2", "P3"} or quantity < 0:
                raise ValueError("rilevazione non valida")
        except (KeyError, ValueError, TypeError):
            excluded.append({"fonte": "SCANNER_STAND", "motivo": "RIGA_NON_VALIDA", "riga_originale": raw_row(row, line)})
            continue
        key = (code, day, hour)
        if key in seen_slots:
            excluded.append({"fonte": "SCANNER_STAND", "motivo": "FASCIA_DUPLICATA", "riga_originale": raw_row(row, line)})
            continue
        seen_slots.add(key)
        all_stands.add(code)
        scan_days.add(day)
        scan_counts[(code, day, hour.hour)] = quantity
        flags = ["FUORI_ORARIO_VALORE_ANOMALO"] if not 9 <= hour.hour <= 18 or quantity > 500 else []
        stamp = datetime.combine(day, hour)
        visits.append(event_row(
            id_evento=f"VISITA-2025-{code}-{day.isoformat()}-{hour.strftime('%H%M')}",
            edizione=2025, fonte="SCANNER_STAND", evento="VISITE_STAND_ORA",
            data=day.isoformat(), ora=hour.isoformat(), giorno_fiera=day_number(2025, day),
            padiglione=pavilion, luogo=code,
            id_riferimento=f"VISITA-2025-{code}-{day.isoformat()}-{hour.strftime('%H%M')}",
            quantita=quantity, flags=flags,
        ))

    raw_contacts = read_csv(original["contacts"])
    email_groups = defaultdict(list)
    for row in raw_contacts:
        email_groups[str(row.get("email") or "").strip().casefold()].append(row)
    conflict_emails = set()
    multi_stand_emails = set()
    for email, rows in email_groups.items():
        if len(rows) < 2:
            continue
        if len({str(row.get("codice_stand") or "").strip() for row in rows}) > 1:
            multi_stand_emails.add(email)
        if len({(str(row.get("fascia_eta") or "").strip(), str(row.get("provincia") or "").strip().upper()) for row in rows}) > 1:
            conflict_emails.add(email)

    contact_rows, contact_events = [], []
    for line, row in enumerate(raw_contacts, start=2):
        try:
            code = str(row["id_contatto"]).strip()
            stand = str(row["codice_stand"]).strip()
            exhibitor = str(row["id_espositore"]).strip()
            stamp = datetime.fromisoformat(str(row["timestamp"]).strip())
            if stamp.tzinfo:
                stamp = stamp.astimezone(FUSO)
            else:
                stamp = stamp.replace(tzinfo=FUSO)
            email = str(row.get("email") or "").strip().casefold()
            if not code or not stand or not exhibitor or not re.fullmatch(r"[^\s@]+@[^\s@]+\.[^\s@]+", email):
                raise ValueError("chiave o email non valida")
        except (KeyError, ValueError, TypeError):
            excluded.append({"fonte": "CONTATTI_STAND", "motivo": "RIGA_NON_VALIDA", "riga_originale": raw_row(row, line)})
            continue
        age_raw = str(row.get("fascia_eta") or "").strip()
        age = age_band(age_raw)
        p = province(row.get("provincia"))
        consent_raw = fold(row.get("consenso_marketing"))
        consent = "SI" if consent_raw in {"si", "s", "true", "1"} else "NO" if consent_raw in {"no", "n", "false", "0"} else "NON_DICHIARATO"
        minor = age in {"0-7", "8-13", "14-17"}
        profile_conflict = email in conflict_emails
        flags = []
        if p == "NON_DICHIARATO":
            flags.append("PROVINCIA_MANCANTE")
        if minor:
            flags.append("MINORE_14_17")
        if consent == "NON_DICHIARATO":
            flags.append("CONSENSO_MANCANTE")
        if profile_conflict:
            flags.append("EMAIL_CONFLITTO")
        if scan_counts[(stand, stamp.date(), stamp.hour)] == 0:
            flags.append("CONTATTO_IN_FASCIA_SENZA_SCANSIONI")
        exclusion = "MINORE_14_17" if minor else "CONSENSO_MANCANTE" if consent != "SI" else "EMAIL_CONFLITTO" if profile_conflict else "NESSUNO"
        usable = exclusion == "NESSUNO" and age in {"18-24", "25-34", "35-44", "45+"}
        contact_rows.append({
            "id_contatto": code, "email": email, "consenso_marketing": consent,
            "utilizzabile_marketing": "SI" if usable else "NO", "motivo_esclusione": exclusion,
            "email_su_piu_stand": "SI" if email in multi_stand_emails else "NO",
        })
        pavilion = stand.split("-", 1)[0].upper()
        interest_key = fold(row.get("interesse"))
        if interest_key not in INTERESSI:
            excluded.append({"fonte": "CONTATTI_STAND", "motivo": "INTERESSE_NON_RICONOSCIUTO", "riga_originale": raw_row(row, line)})
            continue
        contact_events.append(event_row(
            id_evento=f"CONTATTO-2025-{code}", edizione=2025, fonte="CONTATTI_STAND",
            evento="CONTATTO", data=stamp.date().isoformat(), ora=stamp.time().replace(tzinfo=None).isoformat(),
            giorno_fiera=day_number(2025, stamp.date()), padiglione=pavilion, luogo=stand,
            id_riferimento=code, id_espositore=exhibitor, fascia_eta=age, provincia=p,
            interesse=INTERESSI[interest_key], flags=flags,
        ))

    all_stands.update(str(row.get("codice_stand") or "").strip() for row in raw_contacts)
    all_stands.discard("")
    missing_slots = []
    for day in sorted(scan_days):
        for code in sorted(all_stands):
            pavilion = code.split("-", 1)[0].upper()
            for hour in range(9, 19):
                if (code, day, time(hour)) not in seen_slots:
                    missing_slots.append({"codice_stand": code, "data": day.isoformat(), "ora": f"{hour:02d}:00:00"})

    all_events = ticket_events + access_events + visits + contact_events
    anomaly_counts = Counter()
    for event in all_events:
        source = event["fonte"]
        year = str(event["edizione"])
        for flag in event["controllo_qualita"].split("|"):
            if flag and flag != "OK":
                anomaly_counts[(source, year, flag)] += 1
    for year, count in removed_duplicates.items():
        anomaly_counts[("TORNELLI", str(year), "LETTURA_DOPPIA_ENTRO_10_SECONDI")] += count
    anomaly_counts[("SCANNER_STAND", "2025", "FASCIA_STAND_MANCANTE")] += len(missing_slots)

    anomalies = []
    grouped = defaultdict(int)
    for (source_name, year, code), count in anomaly_counts.items():
        grouped[(source_name, code)] += count
    for (source_name, code), count in sorted(grouped.items()):
        anomalies.append({
            "fonte": source_name, "codice": code, "descrizione": CODICI.get(code, "Anomalia rilevata durante la normalizzazione; valore originale mantenuto quando affidabile."),
            "righe_coinvolte": count,
            "gestione": CODICI.get(code, "Valore segnalato e non usato per inventare dati mancanti."),
        })

    workbook = commercial_data(original["workbook"])
    all_events.sort(key=lambda row: (int(row["edizione"]), row["data"], row["ora"], row["fonte"], row["id_evento"]))
    write_csv(target / "expodata_dataset_unificato.csv", EVENTI, all_events)
    write_csv(target / "contatti_commerciali_2025.csv", CONTATTI, contact_rows)
    write_csv(target / "fasce_orarie_mancanti_stand.csv", ["codice_stand", "data", "ora"], missing_slots)
    write_csv(target / "anomalie_riepilogo.csv", ["fonte", "codice", "descrizione", "righe_coinvolte", "gestione"], anomalies)
    write_csv(target / "scarti_righe_rimosse.csv", ["fonte", "motivo", "riga_originale"], excluded)
    target.mkdir(parents=True, exist_ok=True)
    (target / "commerciale_normalizzato.json").write_text(json.dumps(workbook, ensure_ascii=False, indent=2), encoding="utf-8")

    summary = Counter(event["fonte"] for event in all_events)
    print("Fonti normalizzate; conteggi aggregati:")
    for name, count in sorted(summary.items()):
        print(f"  {name}: {count}")
    print(f"Letture ai tornelli scartate come doppie: {sum(removed_duplicates.values())}")
    print(f"Fasce stand mancanti registrate senza conteggi inventati: {len(missing_slots)}")
    print(f"Contatti conservati: {len(contact_rows)}; utilizzabili per marketing: {sum(row['utilizzabile_marketing'] == 'SI' for row in contact_rows)}")
    print(f"Dati commerciali: {len(workbook['espositori'])} espositori, {len(workbook['stand'])} stand, {len(workbook['listino'])} voci listino, {len(workbook['contratti'])} contratti riconciliati, {len(workbook['righe_contratto'])} righe contratto")
    print(f"Esclusioni commerciali aggregate: {workbook['conteggi_esclusioni']}")
    print(f"File normalizzati locali (ignorati da Git): {target}")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--sorgenti", type=Path, default=RADICE / "dati-storici" / "originali" / "ARCADE_Milano_dati")
    parser.add_argument("--output", type=Path, default=RADICE / "dati-storici" / "normalizzati")
    args = parser.parse_args()
    prepare(args.sorgenti, args.output)


if __name__ == "__main__":
    main()
