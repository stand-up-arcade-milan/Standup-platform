# Report di qualità dei dati storici e commerciali

Generato da `scripts/dati/importa_storici.py` il 08/11/2026 06:31. Contiene solo conteggi aggregati, senza dati personali.

Le fonti originali e i file normalizzati restano in `dati-storici/`, esclusa da Git.

## Righe storiche normalizzate e database

| Fonte | Tabella | Edizione | Nel dataset | Nel database | Esito |
|---|---|---:|---:|---:|---|
| BIGLIETTERIA | `biglietto` | 2024 | 35.719 | 35.719 | ok |
| BIGLIETTERIA | `biglietto` | 2025 | 42.556 | 42.556 | ok |
| TORNELLI | `accesso` | 2024 | 45.888 | 45.888 | ok |
| TORNELLI | `accesso` | 2025 | 54.853 | 54.853 | ok |
| SCANNER_STAND | `visita_stand_ora` | 2025 | 2.451 | 2.451 | ok |
| CONTATTI_STAND | `contatto_stand` | 2025 | 1.707 | 1.707 | ok |

## Controlli di integrità

| Controllo | Righe | Atteso | Esito |
|---|---:|---|---|
| Ordini senza biglietti | 0 | 0 | ok |
| Biglietti a pagamento con importo zero | 0 | 0 | ok |
| Ingressi con zero persone | 0 | 0 | ok |
| Rifiuti con persone conteggiate | 0 | 0 | ok |
| Accessi fuori dalle date note dell'edizione | 0 | 0 | ok |
| Biglietti registrati dopo la fine della fiera | 0 | 0 | ok |
| Ingressi in un giorno diverso dal biglietto | 0 | 0 | ok |
| Persone entrate diverse dalla quantità del biglietto | 0 | 0 | ok |
| Codici ai varchi non presenti in biglietteria | 70 | informativo | da leggere |
| Rilevazioni stand fuori dalle fasce 09-18 | 1 | informativo | da leggere |
| Contatti senza assegnazione coerente | 0 | 0 | ok |
| Minori utilizzabili per marketing | 0 | 0 | ok |
| Contatti senza consenso utilizzabili | 0 | 0 | ok |
| Contatti privi della email riservata sorgente | 0 | 0 | ok |
| Fasce dichiarate mancanti con rilevazione effettiva | 0 | 0 | ok |
| Contratti storici con righe non riconciliate al lordo | 0 | 0 | ok |

## Anomalie segnalate sulle righe importate

I valori mancanti non sono inventati. Le righe anomale affidabili restano con un flag; le duplicazioni tecniche sono registrate negli scarti.

| Tabella | Edizione | Flag | Righe |
|---|---:|---|---:|
| `accesso` | 2024 | `PROVINCIA_MANCANTE` | 2.732 |
| `accesso` | 2024 | `FASCIA_ETA_MANCANTE` | 1.767 |
| `accesso` | 2024 | `RIUTILIZZO_IMMEDIATO_RESPINTO` | 195 |
| `accesso` | 2024 | `BIGLIETTO_INESISTENTE_IN_BIGLIETTERIA` | 35 |
| `accesso` | 2025 | `PROVINCIA_MANCANTE` | 3.259 |
| `accesso` | 2025 | `FASCIA_ETA_MANCANTE` | 2.189 |
| `accesso` | 2025 | `RIUTILIZZO_IMMEDIATO_RESPINTO` | 221 |
| `accesso` | 2025 | `BIGLIETTO_INESISTENTE_IN_BIGLIETTERIA` | 35 |
| `biglietto` | 2024 | `ACQUISTO_REGISTRATO_DOPO_INGRESSO` | 4.853 |
| `biglietto` | 2024 | `PROVINCIA_MANCANTE` | 2.158 |
| `biglietto` | 2024 | `RIDOTTO_FASCIA_14_17` | 1.561 |
| `biglietto` | 2024 | `FASCIA_ETA_MANCANTE` | 1.382 |
| `biglietto` | 2024 | `SCONTO_SU_BIGLIETTO_GRATUITO` | 558 |
| `biglietto` | 2024 | `EARLY10_USATO_DURANTE_FIERA` | 160 |
| `biglietto` | 2025 | `ACQUISTO_REGISTRATO_DOPO_INGRESSO` | 5.993 |
| `biglietto` | 2025 | `PROVINCIA_MANCANTE` | 2.525 |
| `biglietto` | 2025 | `RIDOTTO_FASCIA_14_17` | 1.858 |
| `biglietto` | 2025 | `FASCIA_ETA_MANCANTE` | 1.719 |
| `biglietto` | 2025 | `SCONTO_SU_BIGLIETTO_GRATUITO` | 645 |
| `biglietto` | 2025 | `EARLY10_USATO_DURANTE_FIERA` | 228 |
| `contatto_stand` | 2025 | `CONTATTO_IN_FASCIA_SENZA_SCANSIONI` | 80 |
| `contatto_stand` | 2025 | `EMAIL_CONFLITTO` | 38 |
| `contatto_stand` | 2025 | `MINORE_14_17` | 14 |
| `contatto_stand` | 2025 | `CONSENSO_MANCANTE` | 9 |
| `visita_stand_ora` | 2025 | `FUORI_ORARIO_VALORE_ANOMALO` | 1 |

## Campi non dichiarati

| Tabella | Campo | Edizione | Righe | Non dichiarati | Quota |
|---|---|---:|---:|---:|---:|
| `biglietto` | `fascia_eta` | 2024 | 35.719 | 1.382 | 3.9% |
| `biglietto` | `fascia_eta` | 2025 | 42.556 | 1.719 | 4.0% |
| `biglietto` | `provincia` | 2024 | 35.719 | 2.158 | 6.0% |
| `biglietto` | `provincia` | 2025 | 42.556 | 2.525 | 5.9% |
| `biglietto` | `minore` | 2024 | 35.719 | 3.709 | 10.4% |
| `biglietto` | `minore` | 2025 | 42.556 | 4.513 | 10.6% |
| `contatto_stand` | `fascia_eta` | 2025 | 1.707 | 0 | 0.0% |
| `contatto_stand` | `provincia` | 2025 | 1.707 | 0 | 0.0% |

## Dati commerciali

| Foglio | Righe sorgente | Importate | Esito |
|---|---:|---:|---|
| Espositori | 135 | 135 | ok |
| Planimetria 2026 | 130 | 130 | ok |
| Listino 2026 | 20 | 19 | parziale. motivato sotto |
| Contratti riconciliabili | 198 | 168 | parziale. motivato sotto |
| Righe dei contratti importati | 950 | 806 | parziale. motivato sotto |

### Decisioni applicate

- 58 contratti collegati all'espositore tramite corrispondenza univoca del nome normalizzato; gli altri sono collegati per ID.
- 30 contratti e 144 righe associate sono rimasti fuori dal database perché l'espositore non è identificabile senza ambiguità.
- 1 voce listino senza unità o prezzo è stata esclusa.
- Gli sconti sorgente espressi come frazioni (per esempio 0,05) sono convertiti in punti percentuali.
- Le voci non presenti nel listino sono conservate come righe storiche del contratto, senza inventare una voce attiva.
- Il pacchetto storico non dichiarato è mostrato come NON_DICHIARATO; la data dell'acconto non crea un importo di pagamento mancante.
- L'edizione 2026 resta PIANIFICATA senza date; la fonte non ne dichiara le date della fiera.

## Righe scartate

| Fonte | Motivo | Righe |
|---|---|---:|
| TORNELLI_2025 | `LETTURA_DOPPIA_ENTRO_10_SECONDI` | 1.139 |
| TORNELLI_2024 | `LETTURA_DOPPIA_ENTRO_10_SECONDI` | 936 |
