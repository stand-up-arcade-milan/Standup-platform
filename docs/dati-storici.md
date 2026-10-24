# Dati storici 2024 e 2025

Documento di lavoro del team **Stand up**. Descrive i dati delle due edizioni precedenti di ARCADE Milano, che cosa permettono di calcolare, che cosa manca e come importarli. Lo schema è nelle [migrazioni](../database/migrations), la governance dei dati in [`governance-dati.md`](governance-dati.md).

Torna al [README](../README.md) · [Blueprint digitale](blueprint-digitale.md)

I file originali non stanno nella repository: pesano oltre 30 MB e contengono dati di contatto di persone. Qui ci sono solo la descrizione, le regole e lo schema.

## 1. File ricevuti

| File | Contenuto |
| --- | --- |
| `expodata_dataset_unificato.csv` | Registro unico degli eventi: 183.174 righe e 22 colonne, con biglietteria, tornelli, scanner e contatti |
| `contatti_commerciali_2025.csv` | 1.707 contatti raccolti agli stand nel 2025, con email e consenso marketing |
| `anomalie_riepilogo.csv` | Registro delle anomalie trovate, con codice, righe coinvolte e gestione adottata |
| `scarti_righe_rimosse.csv` | 2.075 letture doppie dei tornelli eliminate, con la riga originale |
| `fasce_orarie_mancanti_stand.csv` | 70 combinazioni stand, giorno e ora senza dati |
| `dati_superflui.csv` | Campi superflui o ricavabili, con la decisione presa |

Il dataset è già stato ripulito: date in formato ISO, orari in ora italiana, province e tipi di biglietto uniformati, e una colonna `controllo_qualita` su ogni riga.

## 2. Che cosa contiene

| Fonte | Evento | 2024 | 2025 |
| --- | --- | ---: | ---: |
| Biglietteria | Vendita | 35.719 | 42.556 |
| Tornelli | Ingresso | 45.658 | 54.597 |
| Tornelli | Ingresso rifiutato | 230 | 256 |
| Scanner degli stand | Visite per ora e stand | non disponibile | 2.451 |
| Contatti agli stand | Contatto | non disponibile | 1.707 |

Date della fiera: 20, 21 e 22 dicembre 2024, e 19, 20 e 21 dicembre 2025. Le vendite partono a luglio. Ci sono 3 padiglioni (P1, P2, P3), 4 varchi (P1-NORD, P1-SUD, P2-OVEST, P3-EST) e 84 stand con altrettanti espositori, presenti solo nel 2025.

### Colonne del registro unico

| Colonna | Significato |
| --- | --- |
| `id_evento` | Identificativo unico della riga |
| `edizione`, `fonte`, `evento` | Anno, origine del dato e tipo di evento |
| `data`, `ora`, `giorno_fiera` | Data e ora locali. `giorno_fiera` è 0 prima della fiera e da 1 a 3 durante |
| `padiglione`, `luogo` | Padiglione e varco o stand. Per le vendite `luogo` è il canale: ONLINE, CASSA o RIVENDITORE_PARTNER |
| `id_riferimento` | Codice del biglietto, della visita o del contatto, secondo l'evento |
| `id_ordine`, `id_espositore` | Ordine di acquisto ed espositore, quando pertinenti |
| `categoria_biglietto`, `giorno_valido` | Una delle 8 categorie e il giorno di validità, oppure TUTTI per l'abbonamento |
| `fascia_eta`, `minore`, `provincia` | Dati del titolare, spesso NON_DICHIARATO |
| `codice_sconto`, `interesse` | Sconto applicato e interesse indicato nel contatto |
| `quantita`, `importo_eur` | Persone e importo della vendita, oppure numero di scansioni |
| `controllo_qualita` | OK, oppure uno o più codici di anomalia separati da una barra verticale |

Le 8 categorie di biglietto sono Intero, Ridotto, Family, Business, VIP, Stampa, Abbonamento 3 giorni e Gratuito sotto gli 8 anni. Un Family vale 4 persone.

## 3. Numeri principali

| | 2024 | 2025 |
| --- | ---: | ---: |
| Persone nei biglietti venduti | 42.979 | 51.259 |
| Incassi dei biglietti | circa 944.000 € | circa 1.246.000 € |
| Ingressi ai tornelli | 45.658 | 54.597 |

Gli ingressi crescono di circa il 20%, mentre gli incassi dei biglietti di circa il 32%. Nel 2025 le visite agli stand sono 36.213 nelle fasce orarie dalle 8 alle 18.

## 4. Che cosa si può calcolare

| Indicatore | Stato | Note |
| --- | --- | --- |
| Visitatori, venduti e entrati, con confronto tra le edizioni | Calcolabile | Va scelta la definizione: biglietti venduti, ingressi o persone uniche |
| Ingressi per ora, giorno e varco | Calcolabile | Dai tornelli |
| Incassi dei biglietti per canale e categoria | Calcolabile | Dalla biglietteria |
| Visite e contatti per stand | Calcolabile solo per il 2025 | Il 2024 non ha dati degli stand |
| Picco di presenza e saturazione | Non calcolabile così com'è | Mancano le uscite, ci sono solo gli ingressi |
| Ricavo per m² | Non calcolabile | Mancano i contratti degli stand, i prezzi e le superfici |
| Costo per contatto | Non calcolabile | Mancano i costi |

### Soluzioni proposte per i vuoti

Il cliente preferisce proposte già complete, quindi per ogni vuoto c'è una scelta di partenza, da dichiarare nei report:

- **Presenze.** Stima della presenza come ingressi delle ultime N ore, con N pari a 4 come parametro modificabile, e indicazione chiara che è una stima.
- **Ricavo per m².** Listino e superfici degli stand dei tre padiglioni da richiedere. Fino ad allora, valori simulati e dichiarati come tali.
- **Costo per contatto.** Costi come parametro per edizione, con valori simulati e dichiarati.

## 5. Anomalie

### Già gestite nel dataset

| Codice | Che cosa è | Righe | Gestione |
| --- | --- | ---: | --- |
| FILE_DUPLICATO | File dei tornelli 2024 caricato due volte | 46.824 | Usata una sola copia |
| TIPI_BIGLIETTO_RINOMINATI | Nomi diversi tra 2024 e 2025 | 78.275 | Ricondotti a 8 categorie |
| FUSO_ORARIO_UTC | Orari 2025 in UTC, quelli 2024 in ora locale | 55.992 | Convertiti in ora italiana |
| FORMATI_DIVERSI | Separatori, date, esiti e varchi diversi | 102.816 | Uniformati |
| PROVINCIA_FORMATI_MISTI | MI, MILANO e Milano | 29.516 | Sigla automobilistica |
| LETTURA_DOPPIA | Stesso biglietto letto due volte in 10 secondi | 2.075 | Righe rimosse e conservate negli scarti |

### Da segnalare con un flag

| Codice | Che cosa è | Righe |
| --- | --- | ---: |
| ACQUISTO_DOPO_INGRESSO | Orario di acquisto successivo al primo passaggio al varco | circa 10.850 |
| PICCO_FUORI_ORARIO | Lo stand P1-A02 ha 912 scansioni alle 8 di mattina, a fiera chiusa | 1 |
| BIGLIETTO_INESISTENTE | Codici letti ai varchi che non esistono in biglietteria | 70 |
| RIUTILIZZO_RESPINTO | Lettura respinta pochi secondi dopo un ingresso valido | 416 |
| EARLY10_DURANTE_FIERA | Sconto early bird usato nei giorni di fiera | 388 |
| RIDOTTO_FASCIA | Ridotto 8-14 con titolare di 14-17 anni | 1.858 |
| CODICI_SENZA_EFFETTO | SCUOLA e STUDENTI non cambiano il prezzo | 13.746 |
| EMAIL_INCOERENTE | Stessa email su più stand con dati diversi | 38 |
| CONTATTO_SENZA_SCANSIONI | Contatto in una fascia in cui lo scanner segna zero | 80 |

### Non sono errori

I 2.787 biglietti mai passati ai varchi sono veri no-show e restano nei dati. I valori NON_DICHIARATO per provincia e fascia d'età restano tali, e non si inventano.

### Scelte di partenza per i punti da chiarire

| Punto | Scelta proposta |
| --- | --- |
| Orario di acquisto dopo l'ingresso | Considerarlo orario di registrazione e non usarlo per le analisi orarie delle vendite |
| Picco di P1-A02 | Escluderlo dai KPI e tenerlo nel registro |
| Sconto EARLY10 in fiera | Tenerlo come dato e mostrarlo separato |
| SCUOLA e STUDENTI | Tenerli come tracciamento del canale |
| Biglietti inesistenti e riutilizzi | Contarli come ingressi rifiutati, mai come visitatori |

## 6. Privacy

- Le **email** dei contatti stanno in una tabella separata, con accesso limitato, e non nel registro unico.
- Nel 2025 ci sono 14 contatti di ragazzi di 14-17 anni, esclusi dal marketing per prudenza, e 9 senza consenso.
- Per i report agli espositori si mostrano contatti e conteggi **solo del proprio stand**.
- Fascia d'età e provincia sono dati del titolare del biglietto: nei report si aggregano.
- I dati personali dei contatti non vanno nella repository né nei mockup.

## 7. Importazione

Lo script [`scripts/dati/importa_storici.py`](../scripts/dati/importa_storici.py) esegue tutto in un comando:

```
pip install -r scripts/dati/requirements.txt
python scripts/dati/importa_storici.py --dsn "postgresql://utente:password@localhost/arcade" --dati ./dati-storici
```

1. Applica le migrazioni non ancora applicate.
2. Carica i cinque file in staging, senza trasformarli.
3. Si ferma se trova `id_evento` duplicati o contatti senza riga nel file dei contatti.
4. Trasforma lo staging nello schema con [`trasforma.sql`](../scripts/dati/trasforma.sql).
5. Scrive il registro dell'importazione e il [report di qualità](report-qualita-dati.md).
6. Elimina lo staging, perché contiene le email.

Regole:
- `id_evento` è la chiave di ogni riga, così il caricamento si può ripetere senza duplicare: una seconda esecuzione carica 0 righe.
- Le righe con anomalia non si correggono né si cancellano: si conserva il flag di `controllo_qualita`.
- Data e ora diventano un unico orario con fuso Europe/Rome.
- Il codice termina con errore se i totali del file e del database non coincidono o se un controllo di integrità non passa.
- I CSV restano fuori dal repository.

## 8. Schema

```mermaid
erDiagram
    EDIZIONE ||--o{ ORDINE : contiene
    ORDINE ||--|{ BIGLIETTO : comprende
    CATEGORIA_BIGLIETTO ||--o{ BIGLIETTO : classifica
    EDIZIONE ||--o{ ACCESSO : registra
    VARCO ||--o{ ACCESSO : rileva
    PADIGLIONE ||--o{ VARCO : ospita
    PADIGLIONE ||--o{ STAND : ospita
    ESPOSITORE ||--o{ ASSEGNAZIONE_STAND : riceve
    STAND ||--o{ ASSEGNAZIONE_STAND : assegnato
    EDIZIONE ||--o{ ASSEGNAZIONE_STAND : vale_per
    STAND ||--o{ VISITA_STAND_ORA : misura
    STAND ||--o{ CONTATTO_STAND : raccoglie
    CONTATTO_STAND ||--o| CONTATTO_RISERVATO : ha
    IMPORTAZIONE ||--o{ SCARTO_IMPORTAZIONE : produce
```

La bozza include anche le tabelle per la stima dal peso, `rilevazione_peso` e `parametri_stima`, previste dal modello dati del README.
