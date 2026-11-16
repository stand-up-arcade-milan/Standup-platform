#!/usr/bin/env python3
"""Simula una giornata di fiera inviando all'API i dati dei dispositivi (RF-05, RNF-08).

Pedane conta-persone (un conteggio al minuto per padiglione, anche quando è zero),
sensori AI agli stand (persone ferme al minuto) e rilevazioni del peso agli stand.
Usa gli stessi endpoint e lo stesso formato dei dispositivi veri, con fonte SIMULATA.

Con lo stesso seme la giornata è identica: gli eventId si ripetono e l'API, ricevendo
lo stesso payload, risponde 200 senza duplicare le righe. Il simulatore non scrive nel
database e non usa dati personali.

Esempi:
    # anteprima senza inviare nulla
    python scripts/dati/simula_giornata.py --giorno 2026-12-04 --anteprima

    # giornata intera verso lo stack locale
    $env:ARCADE_DEVICE_TOKEN = node scripts/test/make-token.mjs DEVICE
    python scripts/dati/simula_giornata.py --giorno 2026-12-04

    # demo dal vivo: invia il minuto appena concluso, uno al minuto
    python scripts/dati/simula_giornata.py --tempo-reale
"""

import argparse
import json
import math
import os
import random
import sys
import time
import urllib.error
import urllib.request
from dataclasses import dataclass
from datetime import date, datetime, timedelta
from zoneinfo import ZoneInfo

FUSO = ZoneInfo("Europe/Rome")
ORA_DI_PICCO = 14.5      # metà pomeriggio
LARGHEZZA_PICCO = 3.0    # ore: quanto è larga la curva dell'affluenza
RICAMBIO_AL_MINUTO = 0.02  # quota dei presenti che entra ed esce ogni minuto oltre al flusso netto


@dataclass(frozen=True)
class Invio:
    percorso: str
    corpo: dict


def curva(ora: float) -> float:
    """Affluenza relativa tra 0 e 1 in funzione dell'ora del giorno."""
    x = (ora - ORA_DI_PICCO) / LARGHEZZA_PICCO
    return math.exp(-x * x)


def ora_decimale(istante: datetime) -> float:
    return istante.hour + istante.minute / 60


def rng_per(seme: int, *chiave: object) -> random.Random:
    """Generatore riproducibile per uno specifico dispositivo e minuto."""
    return random.Random(f"{seme}|" + "|".join(str(c) for c in chiave))


def iso(istante: datetime) -> str:
    return istante.isoformat(timespec="seconds")


def minuti(inizio: datetime, fine: datetime):
    corrente = inizio
    while corrente < fine:
        yield corrente
        corrente += timedelta(minutes=1)


def presenti_attesi(picco: int, istante: datetime, apertura: datetime, chiusura: datetime) -> int:
    """Presenti desiderati nel padiglione: zero all'apertura e alla chiusura, massimo al picco."""
    if istante <= apertura or istante >= chiusura:
        return 0
    valore = picco * curva(ora_decimale(istante))
    # rampa negli ultimi 30 minuti, così a fine giornata il padiglione si svuota
    minuti_alla_chiusura = (chiusura - istante).total_seconds() / 60
    if minuti_alla_chiusura < 30:
        valore *= minuti_alla_chiusura / 30
    return round(valore)


def conteggi_pedana(padiglione: str, picco: int, edizione: int, apertura: datetime, chiusura: datetime,
                    seme: int, fino_a: datetime | None = None) -> list[Invio]:
    """Un conteggio al minuto. entrati - usciti segue la curva, i presenti non scendono mai sotto zero."""
    invii = []
    presenti = 0
    picco = round(picco * rng_per(seme, "affluenza", padiglione).uniform(0.7, 1.1))  # padiglioni diversi tra loro
    fine = min(chiusura, fino_a) if fino_a else chiusura
    for minuto in minuti(apertura, fine):
        rng = rng_per(seme, "pedana", padiglione, minuto.isoformat())
        obiettivo = presenti_attesi(picco, minuto + timedelta(minutes=1), apertura, chiusura)
        ricambio = round(presenti * RICAMBIO_AL_MINUTO * rng.uniform(0.6, 1.4))
        netto = obiettivo - presenti
        entrati = max(0, netto) + ricambio
        usciti = min(presenti + entrati, max(0, -netto) + ricambio)
        presenti += entrati - usciti
        invii.append(Invio("/pedane/conteggi", {
            "eventId": f"sim-{edizione}-pedana-{padiglione}-{minuto:%Y%m%dT%H%M}",
            "edizione": edizione,
            "padiglione": padiglione,
            "minuto": iso(minuto),
            "entrati": entrati,
            "usciti": usciti,
            "fonte": "SIMULATA",
        }))
    return invii


def conteggi_sensore(codice_stand: str, edizione: int, apertura: datetime, chiusura: datetime,
                     seme: int, fino_a: datetime | None = None) -> list[Invio]:
    """Nuove persone ferme davanti allo stand in ciascun minuto, solo numeri."""
    invii = []
    attrattiva = rng_per(seme, "attrattiva", codice_stand).uniform(0.5, 2.5)
    fine = min(chiusura, fino_a) if fino_a else chiusura
    for minuto in minuti(apertura, fine):
        rng = rng_per(seme, "sensore", codice_stand, minuto.isoformat())
        media = attrattiva * curva(ora_decimale(minuto))
        invii.append(Invio("/sensori-ai/conteggi", {
            "eventId": f"sim-{edizione}-sensore-{codice_stand}-{minuto:%Y%m%dT%H%M}",
            "edizione": edizione,
            "codiceStand": codice_stand,
            "minuto": iso(minuto),
            "nuovePersoneFermate": poisson(rng, media),
            "fonte": "SIMULATA",
        }))
    return invii


def rilevazioni_peso(codice_stand: str, edizione: int, apertura: datetime, chiusura: datetime, seme: int,
                     passo_minuti: int, peso_medio_kg: float, fino_a: datetime | None = None) -> list[Invio]:
    """Peso lordo sulla pedana dello stand: tara fissa più le persone presenti e un po' di rumore."""
    invii = []
    tara = round(rng_per(seme, "tara", codice_stand).uniform(15, 40), 1)
    capacita = rng_per(seme, "capacita", codice_stand).randint(6, 20)
    fine = min(chiusura, fino_a) if fino_a else chiusura
    for minuto in minuti(apertura, fine):
        if (minuto - apertura).total_seconds() // 60 % passo_minuti:
            continue
        rng = rng_per(seme, "peso", codice_stand, minuto.isoformat())
        persone = poisson(rng, capacita * curva(ora_decimale(minuto)))
        lordo = max(0.0, tara + persone * peso_medio_kg + rng.gauss(0, 6))
        invii.append(Invio("/rilevazioni/peso", {
            "eventId": f"sim-{edizione}-peso-{codice_stand}-{minuto:%Y%m%dT%H%M}",
            "edizione": edizione,
            "codiceStand": codice_stand,
            "rilevatoIl": iso(minuto),
            "pesoLordoKg": round(lordo, 1),
            "taraKg": tara,
            "fonte": "SIMULATA",
        }))
    return invii


def poisson(rng: random.Random, media: float) -> int:
    if media <= 0:
        return 0
    soglia, k, p = math.exp(-media), 0, 1.0
    while True:
        p *= rng.random()
        if p <= soglia:
            return k
        k += 1


class Api:
    def __init__(self, base: str, token: str | None, timeout: float = 15):
        self.base = base.rstrip("/")
        self.token = token
        self.timeout = timeout

    def _richiesta(self, metodo: str, percorso: str, corpo: dict | None = None):
        dati = json.dumps(corpo).encode() if corpo is not None else None
        req = urllib.request.Request(self.base + percorso, data=dati, method=metodo)
        req.add_header("Accept", "application/json")
        if dati is not None:
            req.add_header("Content-Type", "application/json")
        if self.token and metodo != "GET":
            req.add_header("Authorization", f"Bearer {self.token}")
        with urllib.request.urlopen(req, timeout=self.timeout) as risposta:
            return risposta.status, json.loads(risposta.read() or b"{}")

    def mappa(self, edizione: int) -> dict:
        return self._richiesta("GET", f"/mappa?edizione={edizione}")[1]

    def invia(self, invio: Invio) -> int:
        try:
            return self._richiesta("POST", invio.percorso, invio.corpo)[0]
        except urllib.error.HTTPError as errore:
            return errore.code


def leggi_mappa(api: Api, edizione: int) -> tuple[list[str], list[str]]:
    mappa = api.mappa(edizione)
    padiglioni, stand = [], []
    for voce in mappa.get("padiglioni", []):
        padiglioni.append(voce["padiglione"]["codice"])
        stand.extend(s["codice"] for s in voce.get("stands", []))
    return padiglioni, stand


def prepara(args, padiglioni: list[str], stand: list[str], giorno: date, fino_a: datetime | None) -> list[Invio]:
    apertura = datetime.combine(giorno, datetime.strptime(args.dalle, "%H:%M").time(), FUSO)
    chiusura = datetime.combine(giorno, datetime.strptime(args.alle, "%H:%M").time(), FUSO)
    if chiusura <= apertura:
        raise SystemExit("L'orario di chiusura deve venire dopo l'apertura.")
    invii: list[Invio] = []
    if "pedane" in args.solo:
        for codice in padiglioni:
            invii += conteggi_pedana(codice, args.picco, args.edizione, apertura, chiusura, args.seme, fino_a)
    stand_scelti = stand[: args.max_stand]
    if "sensori" in args.solo:
        for codice in stand_scelti:
            invii += conteggi_sensore(codice, args.edizione, apertura, chiusura, args.seme, fino_a)
    if "peso" in args.solo:
        for codice in stand_scelti:
            invii += rilevazioni_peso(codice, args.edizione, apertura, chiusura, args.seme,
                                      args.passo_peso, args.peso_medio, fino_a)
    return invii


def invia_tutti(api: Api, invii: list[Invio]) -> dict[str, int]:
    esiti: dict[str, int] = {}
    for invio in invii:
        stato = api.invia(invio)
        chiave = f"{invio.percorso} {stato}"
        esiti[chiave] = esiti.get(chiave, 0) + 1
        if stato in (401, 403):
            print(f"Token rifiutato ({stato}): serve un token con ruolo DEVICE.", file=sys.stderr)
            break
    return esiti


def argomenti(argv=None):
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("--api", default=os.environ.get("ARCADE_API_URL", "http://localhost:8080/api/v1"))
    p.add_argument("--token", default=os.environ.get("ARCADE_DEVICE_TOKEN"), help="token con ruolo DEVICE")
    p.add_argument("--edizione", type=int, default=2026)
    p.add_argument("--giorno", type=date.fromisoformat, help="giorno da simulare, AAAA-MM-GG")
    p.add_argument("--dalle", default="09:00")
    p.add_argument("--alle", default="20:00")
    p.add_argument("--seme", type=int, default=2026)
    p.add_argument("--solo", default="pedane,sensori,peso", type=lambda v: set(v.split(",")),
                   help="quali dispositivi simulare: pedane, sensori, peso")
    p.add_argument("--padiglioni", type=lambda v: v.split(","), help="codici separati da virgola; di default dalla mappa")
    p.add_argument("--stand", type=lambda v: v.split(","), help="codici separati da virgola; di default dalla mappa")
    p.add_argument("--max-stand", type=int, default=10, help="quanti stand simulare per sensori e peso")
    p.add_argument("--picco", type=int, default=800, help="presenti al picco per padiglione")
    p.add_argument("--passo-peso", type=int, default=5, help="minuti tra due rilevazioni del peso")
    p.add_argument("--peso-medio", type=float, default=70, help="kg per persona, come parametri_stima")
    p.add_argument("--anteprima", action="store_true", help="stampa i payload in JSON Lines senza inviarli")
    p.add_argument("--tempo-reale", action="store_true", help="invia un minuto alla volta, per la demo dal vivo")
    a = p.parse_args(argv)
    sconosciuti = a.solo - {"pedane", "sensori", "peso"}
    if sconosciuti:
        p.error(f"dispositivi sconosciuti: {', '.join(sorted(sconosciuti))}")
    if not a.giorno and not a.tempo_reale:
        p.error("serve --giorno oppure --tempo-reale")
    return a


def main(argv=None) -> int:
    args = argomenti(argv)
    api = Api(args.api, args.token)

    padiglioni, stand = args.padiglioni, args.stand
    if padiglioni is None or stand is None:
        try:
            da_mappa = leggi_mappa(api, args.edizione)
        except (urllib.error.URLError, OSError) as errore:
            print(f"Mappa non raggiungibile su {args.api}: {errore}. Indicare --padiglioni e --stand.", file=sys.stderr)
            return 2
        padiglioni = padiglioni if padiglioni is not None else da_mappa[0]
        stand = stand if stand is not None else da_mappa[1]
    if not padiglioni:
        print("Nessun padiglione da simulare.", file=sys.stderr)
        return 2

    if not args.anteprima and not args.token:
        print("Manca il token DEVICE: --token o ARCADE_DEVICE_TOKEN.", file=sys.stderr)
        return 2

    if not args.tempo_reale:
        invii = prepara(args, padiglioni, stand, args.giorno, None)
        if args.anteprima:
            for invio in invii:
                print(json.dumps({"percorso": invio.percorso, **invio.corpo}, ensure_ascii=False))
            return 0
        esiti = invia_tutti(api, invii)
        for chiave, numero in sorted(esiti.items()):
            print(f"{chiave}: {numero}")
        return 0 if all(int(k.split()[-1]) in (200, 201) for k in esiti) else 1

    # Tempo reale: ogni minuto ricalcola la giornata fino al minuto concluso e invia solo quello nuovo.
    inviati: set[str] = set()
    print("Simulazione dal vivo avviata, Ctrl+C per fermarla.")
    try:
        while True:
            adesso = datetime.now(FUSO).replace(second=0, microsecond=0)
            invii = [i for i in prepara(args, padiglioni, stand, adesso.date(), adesso)
                     if i.corpo["eventId"] not in inviati]
            if args.anteprima:
                for invio in invii:
                    print(json.dumps({"percorso": invio.percorso, **invio.corpo}, ensure_ascii=False))
            else:
                esiti = invia_tutti(api, invii)
                if esiti:
                    print(f"{adesso:%H:%M} " + ", ".join(f"{k}: {v}" for k, v in sorted(esiti.items())))
            inviati.update(i.corpo["eventId"] for i in invii)
            time.sleep(max(1.0, 60 - datetime.now(FUSO).second))
    except KeyboardInterrupt:
        print("\nSimulazione fermata.")
        return 0


if __name__ == "__main__":
    sys.exit(main())
