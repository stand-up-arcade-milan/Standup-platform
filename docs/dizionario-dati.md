# Dizionario dati

Descrive ogni colonna del database: significato, livello di sensibilità e titolare. È generato da `scripts/dati/genera_dizionario.py` e vive anche nel database, nella tabella `arcade.dizionario_dati`.

| Livello | Significato | Chi può vederlo |
|---|---|---|
| PUBBLICO | Può comparire sul portale | Tutti |
| INTERNO | Dato operativo senza persone identificabili | Organizzazione e team |
| RISERVATO | Quasi-identificatore o dato di uno solo | Proprietario, oppure solo aggregato |
| PERSONALE | Identifica una persona | Solo il responsabile dei dati |

## edizione

Calendario delle edizioni della fiera. Titolare: Organizzazione. Livello della tabella: INTERNO.

| Colonna | Descrizione | Livello |
|---|---|---|
| `anno` | Anno dell'edizione, chiave | INTERNO |
| `inizio_vendite` | Primo giorno di vendita dei biglietti | INTERNO |
| `inizio_fiera` | Primo giorno di fiera | INTERNO |
| `fine_fiera` | Ultimo giorno di fiera | INTERNO |

## categoria_biglietto

Tipi di biglietto uniformati tra 2024 e 2025. Titolare: Biglietteria. Livello della tabella: INTERNO.

| Colonna | Descrizione | Livello |
|---|---|---|
| `codice` | Codice della categoria | INTERNO |
| `descrizione` | Nome leggibile | INTERNO |
| `persone_incluse` | Persone che entrano con un biglietto, 4 per il Family | INTERNO |

## canale_vendita

Canali di vendita. Titolare: Biglietteria. Livello della tabella: INTERNO.

| Colonna | Descrizione | Livello |
|---|---|---|
| `codice` | Codice del canale | INTERNO |
| `descrizione` | Nome leggibile | INTERNO |

## padiglione

Padiglioni della fiera. Titolare: Organizzazione. Livello della tabella: PUBBLICO.

| Colonna | Descrizione | Livello |
|---|---|---|
| `codice` | Codice del padiglione | PUBBLICO |

## varco

Varchi con tornello. Titolare: Controllo accessi. Livello della tabella: INTERNO.

| Colonna | Descrizione | Livello |
|---|---|---|
| `codice` | Codice del varco | INTERNO |
| `padiglione` | Padiglione servito dal varco | INTERNO |

## stand

Stand della fiera. Titolare: Organizzazione. Livello della tabella: INTERNO.

| Colonna | Descrizione | Livello |
|---|---|---|
| `codice` | Codice dello stand, per esempio P1-A02 | INTERNO |
| `padiglione` | Padiglione dello stand | INTERNO |
| `superficie_mq` | Superficie in metri quadri, da ricevere dal cliente | INTERNO |

## espositore

Espositori, anonimi nei dati ricevuti. Titolare: Organizzazione. Livello della tabella: INTERNO.

| Colonna | Descrizione | Livello |
|---|---|---|
| `id_espositore` | Codice dell'espositore | INTERNO |
| `ragione_sociale` | Ragione sociale, non presente nei dati ricevuti | INTERNO |

## assegnazione_stand

Quale espositore occupa quale stand in ogni edizione. Titolare: Organizzazione. Livello della tabella: INTERNO.

| Colonna | Descrizione | Livello |
|---|---|---|
| `anno` | Edizione | INTERNO |
| `codice_stand` | Stand assegnato | INTERNO |
| `id_espositore` | Espositore che lo occupa | INTERNO |

## ordine

Ordini di vendita, raggruppano più biglietti. Titolare: Biglietteria. Livello della tabella: INTERNO.

| Colonna | Descrizione | Livello |
|---|---|---|
| `id_ordine` | Codice dell'ordine | INTERNO |
| `anno` | Edizione | INTERNO |
| `canale` | Canale di vendita dell'ordine | INTERNO |

## biglietto

Un biglietto venduto, senza nome né contatto del titolare. Titolare: Biglietteria. Livello della tabella: INTERNO.

| Colonna | Descrizione | Livello |
|---|---|---|
| `codice` | Codice del biglietto, letto ai varchi | INTERNO |
| `id_evento` | Chiave della riga nel registro unico, per ripetere il caricamento | INTERNO |
| `id_ordine` | Ordine di appartenenza | INTERNO |
| `anno` | Edizione | INTERNO |
| `categoria` | Categoria del biglietto | INTERNO |
| `giorno_valido` | Giorno di validità, vuoto se valido tutti i giorni | INTERNO |
| `registrato_il` | Orario di registrazione della vendita, ora italiana | INTERNO |
| `fascia_eta` | Fascia d'età del titolare, quasi-identificatore | RISERVATO |
| `minore` | Titolare minorenne, tutela minori | RISERVATO |
| `provincia` | Provincia di residenza, quasi-identificatore | RISERVATO |
| `codice_sconto` | Codice sconto usato | INTERNO |
| `quantita` | Persone coperte dal biglietto | INTERNO |
| `importo_eur` | Importo pagato in euro | INTERNO |
| `flag_qualita` | Anomalie rilevate sulla riga, vuoto se nessuna | INTERNO |

## accesso

Passaggi ai tornelli, ingressi e rifiuti. Titolare: Controllo accessi. Livello della tabella: INTERNO.

| Colonna | Descrizione | Livello |
|---|---|---|
| `id_evento` | Chiave della riga nel registro unico | INTERNO |
| `anno` | Edizione | INTERNO |
| `varco` | Varco del passaggio | INTERNO |
| `letto_il` | Orario della lettura, ora italiana | INTERNO |
| `codice_biglietto` | Codice letto, senza vincolo perché 70 codici non esistono in biglietteria | INTERNO |
| `esito` | INGRESSO oppure INGRESSO_RIFIUTATO | INTERNO |
| `persone` | Persone entrate, 0 per i rifiuti | INTERNO |
| `flag_qualita` | Anomalie rilevate sulla riga | INTERNO |

## visita_stand_ora

Scansioni orarie di uno stand, aggregate, nessun visitatore identificabile. Titolare: Espositore. Livello della tabella: RISERVATO.

| Colonna | Descrizione | Livello |
|---|---|---|
| `id_riferimento` | Codice della rilevazione oraria | RISERVATO |
| `id_evento` | Chiave della riga nel registro unico | RISERVATO |
| `anno` | Edizione | RISERVATO |
| `codice_stand` | Stand | RISERVATO |
| `ora_inizio` | Inizio dell'ora, ora italiana | RISERVATO |
| `scansioni` | Scansioni nell'ora | RISERVATO |
| `flag_qualita` | Anomalie rilevate sulla riga | RISERVATO |

## fascia_stand_mancante

Ore senza rilevazione, scanner spento o dato perso. Titolare: Espositore. Livello della tabella: INTERNO.

| Colonna | Descrizione | Livello |
|---|---|---|
| `codice_stand` | Stand | INTERNO |
| `ora_inizio` | Ora mancante, ora italiana | INTERNO |

## contatto_stand

Contatti raccolti dallo stand, senza email. Titolare: Espositore. Livello della tabella: RISERVATO.

| Colonna | Descrizione | Livello |
|---|---|---|
| `id_contatto` | Codice del contatto | RISERVATO |
| `id_evento` | Chiave della riga nel registro unico | RISERVATO |
| `anno` | Edizione | RISERVATO |
| `codice_stand` | Stand che ha raccolto il contatto | RISERVATO |
| `id_espositore` | Espositore proprietario del contatto, base del filtro per espositore | RISERVATO |
| `raccolto_il` | Orario di raccolta, ora italiana | RISERVATO |
| `fascia_eta` | Fascia d'età dichiarata, quasi-identificatore | RISERVATO |
| `provincia` | Provincia dichiarata, quasi-identificatore | RISERVATO |
| `interesse` | Interesse espresso dal visitatore | RISERVATO |
| `consenso_marketing` | Consenso al marketing dato dal visitatore | RISERVATO |
| `utilizzabile_marketing` | Vero se il contatto si può usare per il marketing | RISERVATO |
| `motivo_esclusione` | Perché non è utilizzabile, per esempio minore di 14-17 anni | RISERVATO |
| `email_su_piu_stand` | Stessa email lasciata a più stand | RISERVATO |
| `flag_qualita` | Anomalie rilevate sulla riga | RISERVATO |

## contatto_riservato

Email dei contatti, unico dato personale diretto. Titolare: Responsabile dati. Livello della tabella: PERSONALE.

| Colonna | Descrizione | Livello |
|---|---|---|
| `id_contatto` | Contatto a cui appartiene l'email | PERSONALE |
| `email` | Indirizzo email del visitatore | PERSONALE |

## importazione

Registro delle importazioni. Titolare: Data Engineering. Livello della tabella: INTERNO.

| Colonna | Descrizione | Livello |
|---|---|---|
| `id_importazione` | Numero dell'importazione | INTERNO |
| `file` | File importato | INTERNO |
| `iniziata_il` | Inizio | INTERNO |
| `terminata_il` | Fine | INTERNO |
| `righe_lette` | Righe lette dal file | INTERNO |
| `righe_caricate` | Righe caricate nelle tabelle | INTERNO |
| `righe_scartate` | Righe scartate in pulizia | INTERNO |

## scarto_importazione

Righe rimosse in pulizia, con il motivo. Titolare: Data Engineering. Livello della tabella: INTERNO.

| Colonna | Descrizione | Livello |
|---|---|---|
| `id` | Numero progressivo | INTERNO |
| `id_importazione` | Importazione che ha registrato lo scarto | INTERNO |
| `fonte` | Fonte della riga | INTERNO |
| `motivo` | Motivo dello scarto | INTERNO |
| `riga_originale` | Riga come ricevuta | INTERNO |

## catalogo_anomalia

Anomalie trovate in pulizia e come sono gestite. Titolare: Data Engineering. Livello della tabella: INTERNO.

| Colonna | Descrizione | Livello |
|---|---|---|
| `fonte` | Fonte dei dati | INTERNO |
| `codice` | Codice dell'anomalia | INTERNO |
| `descrizione` | Descrizione | INTERNO |
| `righe_coinvolte` | Righe coinvolte | INTERNO |
| `gestione` | Come è stata gestita | INTERNO |

## parametri_stima

Parametri della stima delle presenze. Titolare: Data Engineering. Livello della tabella: INTERNO.

| Colonna | Descrizione | Livello |
|---|---|---|
| `anno` | Edizione | INTERNO |
| `ore_permanenza` | Ore di permanenza per stimare le presenze dagli ingressi | INTERNO |
| `peso_medio_kg` | Peso medio di una persona | INTERNO |
| `soglia_rumore_kg` | Variazione di peso da ignorare come rumore | INTERNO |
| `persone_per_mq` | Capienza di persone per metro quadro | INTERNO |

## rilevazione_peso

Rilevazioni di peso dello stand, simulate nella demo. Titolare: Controllo accessi. Livello della tabella: INTERNO.

| Colonna | Descrizione | Livello |
|---|---|---|
| `id` | Numero progressivo | INTERNO |
| `anno` | Edizione | INTERNO |
| `codice_stand` | Stand | INTERNO |
| `rilevato_il` | Orario della lettura | INTERNO |
| `peso_lordo_kg` | Peso totale letto | INTERNO |
| `tara_kg` | Peso a vuoto | INTERNO |
| `fonte` | SIMULATA o SENSORE | INTERNO |
