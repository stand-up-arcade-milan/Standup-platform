# Report di qualità dei dati storici

Generato da `scripts/dati/importa_storici.py` il 24/10/2026 22:56. Non contiene dati personali.

## Righe nel file e nel database

| Fonte | Tabella | Righe nel file | Righe nel database | Esito |
|---|---|---:|---:|---|
| BIGLIETTERIA | `biglietto` | 78.275 | 78.275 | uguali |
| TORNELLI | `accesso` | 100.741 | 100.741 | uguali |
| SCANNER_STAND | `visita_stand_ora` | 2.451 | 2.451 | uguali |
| CONTATTI_STAND | `contatto_stand` | 1.707 | 1.707 | uguali |

## Controlli di integrità

| Controllo | Righe | Atteso | Esito |
|---|---:|---|---|
| Ordini senza biglietti | 0 | 0 | ok |
| Biglietti con importo zero ma categoria a pagamento | 0 | 0 | ok |
| Accessi con esito INGRESSO e persone = 0 | 0 | 0 | ok |
| Accessi rifiutati con persone > 0 | 0 | 0 | ok |
| Accessi fuori dai giorni di fiera | 0 | 0 | ok |
| Biglietti venduti dopo la fine della fiera | 0 | 0 | ok |
| Ingressi in un giorno diverso da quello valido del biglietto | 0 | 0 | ok |
| Persone entrate diverse dalle persone del biglietto | 0 | 0 | ok |
| Codici letti ai varchi che non esistono in biglietteria | 70 | informativo | da leggere |
| Scansioni stand fuori dall'orario 8-18 | 0 | informativo | da leggere |
| Contatti senza assegnazione dello stand all'espositore | 0 | 0 | ok |
| Contatti di minori usabili per il marketing | 0 | 0 | ok |
| Contatti con consenso diverso da SI usabili per il marketing | 0 | 0 | ok |
| Contatti senza email nella tabella riservata | 0 | 0 | ok |
| Fasce mancanti che hanno invece una rilevazione | 0 | 0 | ok |

## Registro delle anomalie

Conteggio dei flag scritti sulle righe, per tabella ed edizione. Le righe non si correggono, si segnalano.

| Tabella | Edizione | Flag | Righe |
|---|---:|---|---:|
| `accesso` | 2024 | PROVINCIA_MANCANTE | 3.312 |
| `accesso` | 2024 | FASCIA_ETA_MANCANTE | 1.767 |
| `accesso` | 2024 | RIUTILIZZO_IMMEDIATO_RESPINTO | 195 |
| `accesso` | 2024 | BIGLIETTO_INESISTENTE_IN_BIGLIETTERIA | 35 |
| `accesso` | 2025 | PROVINCIA_MANCANTE | 3.941 |
| `accesso` | 2025 | FASCIA_ETA_MANCANTE | 2.189 |
| `accesso` | 2025 | RIUTILIZZO_IMMEDIATO_RESPINTO | 221 |
| `accesso` | 2025 | BIGLIETTO_INESISTENTE_IN_BIGLIETTERIA | 35 |
| `biglietto` | 2024 | ACQUISTO_REGISTRATO_DOPO_INGRESSO | 4.853 |
| `biglietto` | 2024 | PROVINCIA_MANCANTE | 2.600 |
| `biglietto` | 2024 | FASCIA_ETA_MANCANTE | 1.382 |
| `biglietto` | 2024 | SCONTO_SU_BIGLIETTO_GRATUITO | 678 |
| `biglietto` | 2024 | EARLY10_USATO_DURANTE_FIERA | 160 |
| `biglietto` | 2025 | ACQUISTO_REGISTRATO_DOPO_INGRESSO | 5.993 |
| `biglietto` | 2025 | PROVINCIA_MANCANTE | 3.060 |
| `biglietto` | 2025 | RIDOTTO_8_14_CON_TITOLARE_14_17 | 1.858 |
| `biglietto` | 2025 | FASCIA_ETA_MANCANTE | 1.719 |
| `biglietto` | 2025 | SCONTO_SU_BIGLIETTO_GRATUITO | 760 |
| `biglietto` | 2025 | EARLY10_USATO_DURANTE_FIERA | 228 |
| `contatto_stand` | 2025 | CONTATTO_IN_FASCIA_SENZA_SCANSIONI | 80 |
| `contatto_stand` | 2025 | PROVINCIA_MANCANTE | 43 |
| `contatto_stand` | 2025 | STESSA_EMAIL_CON_ETA_O_PROVINCIA_DIVERSE | 38 |
| `contatto_stand` | 2025 | MINORE | 14 |
| `contatto_stand` | 2025 | CONSENSO_MANCANTE | 9 |
| `visita_stand_ora` | 2025 | FUORI_ORARIO_VALORE_ANOMALO | 1 |

## Campi non dichiarati

| Tabella | Campo | Edizione | Righe | Non dichiarati | Quota |
|---|---|---:|---:|---:|---:|
| `biglietto` | `fascia_eta` | 2024 | 35.719 | 1.382 | 3.9% |
| `biglietto` | `fascia_eta` | 2025 | 42.556 | 1.719 | 4.0% |
| `biglietto` | `provincia` | 2024 | 35.719 | 2.600 | 7.3% |
| `biglietto` | `provincia` | 2025 | 42.556 | 3.060 | 7.2% |
| `biglietto` | `minore` | 2024 | 35.719 | 966 | 2.7% |
| `biglietto` | `minore` | 2025 | 42.556 | 1.201 | 2.8% |
| `contatto_stand` | `fascia_eta` | 2025 | 1.707 | 0 | 0.0% |
| `contatto_stand` | `provincia` | 2025 | 1.707 | 43 | 2.5% |

## Righe scartate in pulizia

| Fonte | Motivo | Righe |
|---|---|---:|
| TORNELLI 2025 | LETTURA_DOPPIA_ENTRO_10_SECONDI | 1.139 |
| TORNELLI 2024 | LETTURA_DOPPIA_ENTRO_10_SECONDI | 936 |
