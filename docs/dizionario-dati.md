# Dizionario dati

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

Il database contiene 60 tabelle e 368 colonne.

## Edizione e luoghi

### edizione

Calendario delle edizioni della fiera. Un'edizione può essere pianificata prima che le date siano confermate. Titolare: Organizzazione. Livello della tabella: INTERNO.

| Colonna | Tipo | Descrizione | Livello |
|---|---|---|---|
| `anno` | `smallint` | Anno dell'edizione, chiave | INTERNO |
| `inizio_vendite` | `date` | Primo giorno di vendita dei biglietti | INTERNO |
| `inizio_fiera` | `date` | Primo giorno di fiera | INTERNO |
| `fine_fiera` | `date` | Ultimo giorno di fiera | INTERNO |
| `sede` | `text` | Sede della fiera | PUBBLICO |
| `stato` | `text` | PIANIFICATA, ATTIVA oppure CONCLUSA | INTERNO |

### padiglione

Padiglioni della fiera. Titolare: Organizzazione. Livello della tabella: INTERNO.

| Colonna | Tipo | Descrizione | Livello |
|---|---|---|---|
| `codice` | `text` | Codice del padiglione | PUBBLICO |
| `superficie_mq` | `numeric(9,2)` | Superficie utile del padiglione in metri quadri | INTERNO |
| `capienza` | `integer` | Persone ammesse contemporaneamente nel padiglione | INTERNO |
| `nome` | `text` | Nome leggibile del padiglione | PUBBLICO |

### varco

Varchi con tornello, ognuno serve un padiglione. Titolare: Controllo accessi. Livello della tabella: INTERNO.

| Colonna | Tipo | Descrizione | Livello |
|---|---|---|---|
| `codice` | `text` | Codice del varco | INTERNO |
| `padiglione` | `text` | Padiglione servito dal varco | INTERNO |

### stand

Stand della fiera, con la superficie di riferimento. Titolare: Organizzazione. Livello della tabella: INTERNO.

| Colonna | Tipo | Descrizione | Livello |
|---|---|---|---|
| `codice` | `text` | Codice dello stand, per esempio P1-A02 | INTERNO |
| `padiglione` | `text` | Padiglione dello stand | INTERNO |
| `superficie_mq` | `numeric(8,2)` | Superficie in metri quadri, da ricevere dal cliente | INTERNO |
| `fila` | `smallint` | Fila dello stand nella griglia della mappa | PUBBLICO |
| `colonna` | `smallint` | Colonna dello stand nella griglia della mappa | PUBBLICO |
| `disponibile` | `boolean` | Falso se lo stand è tolto dalla vendita, per esempio per un vincolo di allestimento | INTERNO |

### planimetria_stand

Posizione e superficie dello stand in una singola edizione, senza sovrascrivere lo storico. Titolare: Organizzazione. Livello della tabella: INTERNO.

| Colonna | Tipo | Descrizione | Livello |
|---|---|---|---|
| `anno` | `smallint` | Edizione della planimetria | INTERNO |
| `codice_stand` | `text` | Codice dello stand | PUBBLICO |
| `padiglione` | `text` | Padiglione dello stand in questa edizione | PUBBLICO |
| `nome_padiglione` | `text` | Nome del padiglione | PUBBLICO |
| `superficie_mq` | `numeric(8,2)` | Superficie dello stand in metri quadrati | PUBBLICO |
| `posizione` | `text` | Posizione dello stand nella planimetria | PUBBLICO |
| `attivo_dal` | `smallint` | Anno di attivazione dello stand come indicato nella fonte | INTERNO |

### parametri_stima

Parametri usati nelle stime: ore di permanenza, peso medio, capienza, costi e soglia di sconto. Titolare: Data Engineering. Livello della tabella: INTERNO.

| Colonna | Tipo | Descrizione | Livello |
|---|---|---|---|
| `anno` | `smallint` | Edizione | INTERNO |
| `ore_permanenza` | `numeric(4,2)` | Ore di permanenza per stimare le presenze dagli ingressi | INTERNO |
| `peso_medio_kg` | `numeric(5,2)` | Peso medio di una persona | INTERNO |
| `soglia_rumore_kg` | `numeric(5,2)` | Variazione di peso da ignorare come rumore | INTERNO |
| `persone_per_mq` | `numeric(4,2)` | Capienza di persone per metro quadro | INTERNO |
| `soglia_avviso` | `numeric(3,2)` | Quota della capienza oltre cui lo staff riceve un avviso, 0,80 di partenza | INTERNO |
| `costi_edizione_eur` | `numeric(12,2)` | Costi dell'edizione, parametro del costo per MQL, simulato finché il cliente non lo fornisce | INTERNO |
| `soglia_sconto_approvazione` | `numeric(5,2)` | Sconto in percentuale oltre il quale serve l'approvazione, 10 di partenza | INTERNO |

## Biglietteria

### categoria_biglietto

Tipi di biglietto uniformati tra le edizioni, con le persone incluse. Titolare: Biglietteria. Livello della tabella: INTERNO.

| Colonna | Tipo | Descrizione | Livello |
|---|---|---|---|
| `codice` | `text` | Codice della categoria | INTERNO |
| `descrizione` | `text` | Nome leggibile | INTERNO |
| `persone_incluse` | `smallint` | Persone che entrano con un biglietto, 4 per il Family | INTERNO |

### canale_vendita

Canali di vendita dei biglietti. Titolare: Biglietteria. Livello della tabella: INTERNO.

| Colonna | Tipo | Descrizione | Livello |
|---|---|---|---|
| `codice` | `text` | Codice del canale | INTERNO |
| `descrizione` | `text` | Nome leggibile | INTERNO |

### ordine

Ordini di acquisto, raggruppano più biglietti. Titolare: Biglietteria. Livello della tabella: INTERNO.

| Colonna | Tipo | Descrizione | Livello |
|---|---|---|---|
| `id_ordine` | `text` | Codice dell'ordine | INTERNO |
| `anno` | `smallint` | Edizione | INTERNO |
| `canale` | `text` | Canale di vendita dell'ordine | INTERNO |

### biglietto

Un biglietto venduto, senza nome né contatto del titolare. Titolare: Biglietteria. Livello della tabella: RISERVATO.

| Colonna | Tipo | Descrizione | Livello |
|---|---|---|---|
| `codice` | `text` | Codice del biglietto, letto ai varchi | INTERNO |
| `id_evento` | `text` | Chiave della riga nel registro unico, per ripetere il caricamento | INTERNO |
| `id_ordine` | `text` | Ordine di appartenenza | INTERNO |
| `anno` | `smallint` | Edizione | INTERNO |
| `categoria` | `text` | Categoria del biglietto | INTERNO |
| `giorno_valido` | `date` | Giorno di validità, vuoto se valido tutti i giorni | INTERNO |
| `registrato_il` | `timestamp with time zone` | Orario di registrazione della vendita, ora italiana | INTERNO |
| `fascia_eta` | `text` | Fascia d'età del titolare, quasi-identificatore | RISERVATO |
| `minore` | `text` | Titolare minorenne, tutela minori | RISERVATO |
| `provincia` | `text` | Provincia di residenza, quasi-identificatore | RISERVATO |
| `codice_sconto` | `text` | Codice sconto usato | INTERNO |
| `quantita` | `smallint` | Persone coperte dal biglietto | INTERNO |
| `importo_eur` | `numeric(8,2)` | Importo pagato in euro | INTERNO |
| `flag_qualita` | `text[]` | Anomalie rilevate sulla riga, vuoto se nessuna | INTERNO |

## Controllo accessi

### accesso

Passaggi ai tornelli, ingressi e rifiuti, con il motivo del rifiuto. Titolare: Controllo accessi. Livello della tabella: INTERNO.

| Colonna | Tipo | Descrizione | Livello |
|---|---|---|---|
| `id_evento` | `text` | Chiave della riga nel registro unico | INTERNO |
| `anno` | `smallint` | Edizione | INTERNO |
| `varco` | `text` | Varco del passaggio | INTERNO |
| `letto_il` | `timestamp with time zone` | Orario della lettura, ora italiana | INTERNO |
| `codice_biglietto` | `text` | Codice letto, senza vincolo perché 70 codici non esistono in biglietteria | INTERNO |
| `esito` | `text` | INGRESSO oppure INGRESSO_RIFIUTATO | INTERNO |
| `persone` | `smallint` | Persone entrate, 0 per i rifiuti | INTERNO |
| `flag_qualita` | `text[]` | Anomalie rilevate sulla riga | INTERNO |
| `motivo_rifiuto` | `text` | Perché l'ingresso è stato rifiutato, vuoto per gli ingressi e per i rifiuti storici | INTERNO |

### scansione_stand

Scansioni dei badge allo stand, una riga per scansione. Titolare: Controllo accessi. Livello della tabella: RISERVATO.

| Colonna | Tipo | Descrizione | Livello |
|---|---|---|---|
| `id_evento` | `text` | Chiave del registro unico, per ripetere un invio senza duplicati | INTERNO |
| `anno` | `smallint` | Edizione | INTERNO |
| `codice_stand` | `text` | Stand dove è avvenuta la scansione | INTERNO |
| `operatore_id` | `text` | Identificativo di chi ha scansionato, solo interno | RISERVATO |
| `rilevata_il` | `timestamp with time zone` | Orario della scansione | INTERNO |
| `ticket_ref` | `text` | Identificativo pseudonimizzato del biglietto, non contiene nome o email | RISERVATO |
| `id_contatto` | `text` | Contatto creato dalla scansione, vuoto se il visitatore non lo ha lasciato | INTERNO |
| `duplicata` | `boolean` | Vero se lo stesso biglietto era già stato scansionato nello stand, non viene conteggiata | INTERNO |
| `registrata_il` | `timestamp with time zone` | Orario in cui il sistema ha registrato la scansione | INTERNO |
| `id_lead_magnet` | `bigint` | Lead magnet associato alla scansione | INTERNO |

### acquisizione_evento

Eventi già ricevuti dall'API, per non registrare due volte lo stesso invio. Titolare: Operazioni. Livello della tabella: RISERVATO.

| Colonna | Tipo | Descrizione | Livello |
|---|---|---|---|
| `event_id` | `text` | Identificativo idempotente dell’evento API | INTERNO |
| `tipo` | `text` | Tipo di rilevazione acquisita | INTERNO |
| `richiesta_hash` | `text` | Impronta SHA-256 della richiesta per confrontare i retry senza conservare il payload | RISERVATO |
| `ricevuto_il` | `timestamp with time zone` | Data di ricezione dell’evento | INTERNO |

## Presenze e sensori

### passaggio_pedana

Conteggi delle pedane all'ingresso dello stand. Titolare: Controllo accessi. Livello della tabella: INTERNO.

| Colonna | Tipo | Descrizione | Livello |
|---|---|---|---|
| `anno` | `smallint` | Edizione | INTERNO |
| `padiglione` | `text` | Padiglione della pedana | INTERNO |
| `minuto` | `timestamp with time zone` | Minuto del conteggio | INTERNO |
| `entrati` | `integer` | Persone entrate nel padiglione in quel minuto | INTERNO |
| `usciti` | `integer` | Persone uscite dal padiglione in quel minuto | INTERNO |
| `fonte` | `text` | SIMULATA o SENSORE | INTERNO |

### conteggio_sensore_stand

Persone ferme davanti allo stand, rilevate dal sensore. Titolare: Controllo accessi. Livello della tabella: INTERNO.

| Colonna | Tipo | Descrizione | Livello |
|---|---|---|---|
| `anno` | `smallint` | Edizione | INTERNO |
| `codice_stand` | `text` | Stand del sensore | INTERNO |
| `minuto` | `timestamp with time zone` | Minuto del conteggio | INTERNO |
| `nuove_persone_ferme` | `integer` | Persone che si sono fermate davanti allo stand in quel minuto, senza immagini | INTERNO |
| `fonte` | `text` | SIMULATA o SENSORE | INTERNO |

### rilevazione_peso

Rilevazioni di peso dello stand, usate per stimare le presenze. Titolare: Controllo accessi. Livello della tabella: INTERNO.

| Colonna | Tipo | Descrizione | Livello |
|---|---|---|---|
| `id` | `bigint` | Numero progressivo | INTERNO |
| `anno` | `smallint` | Edizione | INTERNO |
| `codice_stand` | `text` | Stand | INTERNO |
| `rilevato_il` | `timestamp with time zone` | Orario della lettura | INTERNO |
| `peso_lordo_kg` | `numeric(8,2)` | Peso totale letto | INTERNO |
| `tara_kg` | `numeric(8,2)` | Peso a vuoto | INTERNO |
| `fonte` | `text` | SIMULATA o SENSORE | INTERNO |

### visita_stand_ora

Scansioni orarie di uno stand, aggregate. Titolare: Espositore. Livello della tabella: RISERVATO.

| Colonna | Tipo | Descrizione | Livello |
|---|---|---|---|
| `id_riferimento` | `text` | Codice della rilevazione oraria | RISERVATO |
| `id_evento` | `text` | Chiave della riga nel registro unico | RISERVATO |
| `anno` | `smallint` | Edizione | RISERVATO |
| `codice_stand` | `text` | Stand | RISERVATO |
| `ora_inizio` | `timestamp with time zone` | Inizio dell'ora, ora italiana | RISERVATO |
| `scansioni` | `integer` | Scansioni nell'ora | RISERVATO |
| `flag_qualita` | `text[]` | Anomalie rilevate sulla riga | RISERVATO |

### fascia_stand_mancante

Ore senza rilevazione, scanner spento o dato perso. Titolare: Espositore. Livello della tabella: INTERNO.

| Colonna | Tipo | Descrizione | Livello |
|---|---|---|---|
| `codice_stand` | `text` | Stand | INTERNO |
| `ora_inizio` | `timestamp with time zone` | Ora mancante, ora italiana | INTERNO |

## Espositori

### espositore

Espositori, con il solo identificativo. Titolare: Organizzazione. Livello della tabella: INTERNO.

| Colonna | Tipo | Descrizione | Livello |
|---|---|---|---|
| `id_espositore` | `text` | Codice dell'espositore | INTERNO |
| `ragione_sociale` | `text` | Ragione sociale, non presente nei dati ricevuti | INTERNO |

### espositore_riservato

Dati anagrafici e di contatto dell'espositore. Titolare: Commerciale. Livello della tabella: PERSONALE.

| Colonna | Tipo | Descrizione | Livello |
|---|---|---|---|
| `id_espositore` | `text` | Identificativo dell’espositore | RISERVATO |
| `partita_iva` | `text` | Partita IVA dell’espositore | PERSONALE |
| `settore` | `text` | Settore dichiarato dall’espositore | INTERNO |
| `citta` | `text` | Città dell’espositore | RISERVATO |
| `referente` | `text` | Nome del referente commerciale | PERSONALE |
| `email_referente` | `text` | Email del referente commerciale | PERSONALE |

### assegnazione_stand

Quale espositore occupa quale stand in ogni edizione. Titolare: Organizzazione. Livello della tabella: INTERNO.

| Colonna | Tipo | Descrizione | Livello |
|---|---|---|---|
| `anno` | `smallint` | Edizione | INTERNO |
| `codice_stand` | `text` | Stand assegnato | INTERNO |
| `id_espositore` | `text` | Espositore che lo occupa | INTERNO |

### profilo_espositore

Profilo pubblico mostrato nel portale. Titolare: Organizzazione. Livello della tabella: PUBBLICO.

| Colonna | Tipo | Descrizione | Livello |
|---|---|---|---|
| `id_espositore` | `text` | Espositore | PUBBLICO |
| `nome_pubblico` | `text` | Nome mostrato nel portale | PUBBLICO |
| `descrizione` | `text` | Presentazione dell'espositore | PUBBLICO |
| `logo_url` | `text` | Indirizzo del logo | PUBBLICO |
| `sito_web` | `text` | Sito dell'espositore | PUBBLICO |
| `in_evidenza` | `boolean` | Vero se l'espositore è messo in evidenza nel portale | PUBBLICO |

### categoria_espositore

Categorie merceologiche degli espositori. Titolare: Organizzazione. Livello della tabella: PUBBLICO.

| Colonna | Tipo | Descrizione | Livello |
|---|---|---|---|
| `codice` | `text` | Codice della categoria | PUBBLICO |
| `nome` | `text` | Nome mostrato nel portale | PUBBLICO |

### espositore_categoria

Categorie di ogni espositore. Titolare: Organizzazione. Livello della tabella: PUBBLICO.

| Colonna | Tipo | Descrizione | Livello |
|---|---|---|---|
| `id_espositore` | `text` | Espositore | PUBBLICO |
| `codice_categoria` | `text` | Categoria dell'espositore | PUBBLICO |

### pacchetto_espositore

Livello del pacchetto acquistato, che decide quali indicatori riceve. Titolare: Commerciale. Livello della tabella: INTERNO.

| Colonna | Tipo | Descrizione | Livello |
|---|---|---|---|
| `anno` | `smallint` | Edizione | INTERNO |
| `id_espositore` | `text` | Espositore | INTERNO |
| `livello` | `text` | BASE oppure PREMIUM, il PREMIUM include la stima dal peso | INTERNO |

## Area commerciale

### listino_voce

Listino prezzi per edizione, al netto di IVA. Titolare: Commerciale. Livello della tabella: INTERNO.

| Colonna | Tipo | Descrizione | Livello |
|---|---|---|---|
| `anno` | `smallint` | Edizione | INTERNO |
| `codice_voce` | `text` | Codice della voce di listino | INTERNO |
| `descrizione` | `text` | Nome leggibile della voce | INTERNO |
| `tipo` | `text` | STAND, PACCHETTO oppure SERVIZIO | INTERNO |
| `unita` | `text` | MQ se il prezzo è per metro quadro, FORFAIT se è a corpo | INTERNO |
| `prezzo_eur` | `numeric(10,2)` | Prezzo al netto di IVA, simulato finché il cliente non fornisce il listino | INTERNO |
| `disponibilita_sorgente` | `text` | Disponibilità come indicata nel listino ricevuto | INTERNO |
| `nota_sorgente` | `text` | Nota come indicata nel listino ricevuto | INTERNO |

### pratica

Pratica commerciale di un espositore, dal preventivo al contratto. Titolare: Commerciale. Livello della tabella: INTERNO.

| Colonna | Tipo | Descrizione | Livello |
|---|---|---|---|
| `id_pratica` | `uuid` | Identificativo della pratica | INTERNO |
| `anno` | `smallint` | Edizione | INTERNO |
| `id_espositore` | `text` | Espositore della pratica | INTERNO |
| `codice_stand` | `text` | Stand scelto, obbligatorio dopo la bozza | INTERNO |
| `stato` | `text` | BOZZA, INVIATA, FIRMATA oppure ACCONTO_RICEVUTO, solo in avanti | INTERNO |
| `pacchetto` | `text` | BASE o PREMIUM, alla firma diventa il pacchetto dell'espositore | INTERNO |
| `sconto_percentuale` | `numeric(5,2)` | Sconto sull'imponibile del listino | INTERNO |
| `approvazione_richiesta` | `boolean` | Vero se lo sconto supera la soglia, calcolato dal database | INTERNO |
| `id_pratica_precedente` | `uuid` | Pratica dell'edizione precedente da cui nasce il rinnovo | INTERNO |
| `creata_il` | `timestamp with time zone` | Orario di creazione | INTERNO |
| `aggiornata_il` | `timestamp with time zone` | Orario dell'ultima modifica, aggiornato dal database | INTERNO |
| `firmata_il` | `timestamp with time zone` | Istante registrato dal flusso quando lo stato diventa FIRMATA | INTERNO |

### voce_pratica

Voci di listino acquistate in una pratica, con il prezzo applicato. Titolare: Commerciale. Livello della tabella: INTERNO.

| Colonna | Tipo | Descrizione | Livello |
|---|---|---|---|
| `id_pratica` | `uuid` | Pratica di appartenenza | INTERNO |
| `anno` | `smallint` | Edizione della pratica e del listino | INTERNO |
| `codice_voce` | `text` | Voce di listino acquistata | INTERNO |
| `quantita` | `numeric(10,3)` | Metri quadri o numero di forfait | INTERNO |
| `prezzo_unitario_eur` | `numeric(10,2)` | Prezzo applicato al momento dell'offerta, resta invariato se il listino cambia | INTERNO |

### documento_pratica

Documenti collegati a una pratica. Titolare: Commerciale. Livello della tabella: RISERVATO.

| Colonna | Tipo | Descrizione | Livello |
|---|---|---|---|
| `id_documento` | `uuid` | Identificativo del documento | INTERNO |
| `id_pratica` | `uuid` | Pratica di appartenenza | INTERNO |
| `tipo` | `text` | OFFERTA, CONTRATTO oppure ALTRO | INTERNO |
| `nome` | `text` | Nome del file | INTERNO |
| `url` | `text` | Collegamento al documento su SharePoint | INTERNO |
| `creato_il` | `timestamp with time zone` | Orario di creazione | INTERNO |
| `mime_type` | `text` | Tipo MIME del file archiviato | INTERNO |
| `dimensione_byte` | `bigint` | Dimensione del file archiviato in byte | INTERNO |
| `sha256` | `text` | Impronta SHA-256 per verificare l'integrita del file | INTERNO |
| `contenuto_pdf` | `bytea` | Documento PDF generato e archiviato nel database | RISERVATO |

### acconto

Acconti ricevuti per una pratica. Titolare: Commerciale. Livello della tabella: INTERNO.

| Colonna | Tipo | Descrizione | Livello |
|---|---|---|---|
| `id_acconto` | `uuid` | Identificativo dell'acconto | INTERNO |
| `id_pratica` | `uuid` | Pratica di appartenenza | INTERNO |
| `importo_eur` | `numeric(10,2)` | Importo ricevuto, i pagamenti non passano dalla piattaforma | INTERNO |
| `ricevuto_il` | `timestamp with time zone` | Quando l'acconto è stato ricevuto | INTERNO |
| `riferimento` | `text` | Riferimento del bonifico o della ricevuta | INTERNO |

### richiesta

Richieste arrivate dal sito, senza i dati di contatto. Titolare: Commerciale. Livello della tabella: INTERNO.

| Colonna | Tipo | Descrizione | Livello |
|---|---|---|---|
| `id_richiesta` | `uuid` | Identificativo della richiesta | INTERNO |
| `tipo` | `text` | ESPOSITORE oppure VISITATORE | INTERNO |
| `stato` | `text` | NUOVA, IN_LAVORAZIONE oppure CHIUSA | INTERNO |
| `anno` | `smallint` | Edizione richiesta | INTERNO |
| `azienda` | `text` | Nome dell'azienda che chiede lo stand | INTERNO |
| `categoria` | `text` | Categoria indicata nella richiesta | INTERNO |
| `metri_quadri_desiderati` | `numeric(8,2)` | Metri quadri richiesti | INTERNO |
| `note` | `text` | Note libere della richiesta | INTERNO |
| `consenso_privacy` | `boolean` | Consenso al trattamento dei dati per gestire la richiesta | INTERNO |
| `consenso_marketing` | `boolean` | Consenso a ricevere novità, per le richieste dei visitatori | INTERNO |
| `id_pratica` | `uuid` | Pratica creata dalla richiesta | INTERNO |
| `creata_il` | `timestamp with time zone` | Orario della richiesta | INTERNO |

### richiesta_riservata

Nome ed email di chi ha fatto la richiesta. Titolare: Commerciale. Livello della tabella: PERSONALE.

| Colonna | Tipo | Descrizione | Livello |
|---|---|---|---|
| `id_richiesta` | `uuid` | Richiesta di appartenenza | PERSONALE |
| `referente` | `text` | Nome del referente o del visitatore | PERSONALE |
| `email` | `text` | Email del referente o del visitatore | PERSONALE |

### contratto_storico

Contratti delle edizioni passate, come riportati nella fonte. Titolare: Commerciale. Livello della tabella: INTERNO.

| Colonna | Tipo | Descrizione | Livello |
|---|---|---|---|
| `id_contratto_origine` | `text` | Identificativo del contratto nella fonte | INTERNO |
| `id_pratica` | `uuid` | Pratica collegata al contratto storico | INTERNO |
| `imponibile_listino_eur` | `numeric(12,2)` | Imponibile di listino riportato nel contratto | INTERNO |
| `sconto_dichiarato_pct` | `numeric(5,2)` | Percentuale di sconto normalizzata dalla fonte | INTERNO |
| `imponibile_netto_eur` | `numeric(12,2)` | Imponibile netto riportato nel contratto | INTERNO |
| `data_firma` | `date` | Data di firma riportata nel contratto | INTERNO |
| `acconto_scadenza` | `date` | Scadenza dell’acconto | INTERNO |
| `acconto_pagato_il` | `date` | Data di pagamento dell’acconto senza importo disponibile | INTERNO |
| `saldo_scadenza` | `date` | Scadenza del saldo | INTERNO |
| `saldo_pagato_il` | `date` | Data di pagamento del saldo senza importo disponibile | INTERNO |
| `rinnovo` | `boolean` | Indicazione di rinnovo nella fonte | INTERNO |
| `abbinato_per_nome` | `boolean` | Collegamento fatto per corrispondenza esatta del nome normalizzato | INTERNO |
| `flag_qualita` | `text[]` | Anomalie del contratto storico | INTERNO |

### contratto_storico_riga

Righe dei contratti storici. Titolare: Commerciale. Livello della tabella: INTERNO.

| Colonna | Tipo | Descrizione | Livello |
|---|---|---|---|
| `id_contratto_origine` | `text` | Contratto di origine | INTERNO |
| `numero_riga` | `integer` | Numero della riga nel foglio sorgente | INTERNO |
| `codice_voce_sorgente` | `text` | Codice della voce nel contratto | INTERNO |
| `descrizione` | `text` | Descrizione della voce nel contratto | INTERNO |
| `quantita` | `numeric(10,3)` | Quantità riportata nel contratto | INTERNO |
| `prezzo_unitario_eur` | `numeric(10,2)` | Prezzo unitario riportato nel contratto | INTERNO |
| `importo_eur` | `numeric(12,2)` | Importo della riga riportato nel contratto | INTERNO |
| `presente_nel_listino` | `boolean` | Indica se il codice compare nel listino 2026 ricevuto | INTERNO |

## Visitatori e consensi

### registrazione_visitatore

Registrazione del visitatore e consensi dichiarati. Titolare: Marketing. Livello della tabella: RISERVATO.

| Colonna | Tipo | Descrizione | Livello |
|---|---|---|---|
| `id_registrazione` | `bigint` | Numero progressivo | INTERNO |
| `anno` | `smallint` | Edizione | INTERNO |
| `registrato_il` | `timestamp with time zone` | Orario della registrazione | INTERNO |
| `provincia` | `text` | Provincia dichiarata, quasi-identificatore | RISERVATO |
| `fascia_eta` | `text` | Fascia d'età dichiarata, solo adulti, quasi-identificatore | RISERVATO |
| `consenso_marketing` | `boolean` | Consenso a offerte e novità di ARCADE Milano | RISERVATO |
| `consenso_espositori` | `boolean` | Consenso a essere contattato dagli espositori visitati | RISERVATO |
| `consensi_aggiornati_il` | `timestamp with time zone` | Ultima modifica o revoca dei consensi | RISERVATO |
| `profilabile` | `boolean` | Vero solo con consenso marketing e fascia d'età adulta dichiarata | RISERVATO |

### registrazione_riservata

Email del visitatore e token per modificare i consensi. Titolare: Marketing. Livello della tabella: PERSONALE.

| Colonna | Tipo | Descrizione | Livello |
|---|---|---|---|
| `id_registrazione` | `bigint` | Registrazione di appartenenza | PERSONALE |
| `nome` | `text` | Nome del visitatore | PERSONALE |
| `email` | `text` | Email del visitatore | PERSONALE |
| `token_revoca_hash` | `text` | Impronta del token con cui il visitatore modifica i consensi, il token in chiaro non si conserva | RISERVATO |

### interesse_visitatore

Interessi dichiarati dal visitatore. Titolare: Marketing. Livello della tabella: RISERVATO.

| Colonna | Tipo | Descrizione | Livello |
|---|---|---|---|
| `id_registrazione` | `bigint` | Registrazione di appartenenza | RISERVATO |
| `interesse` | `text` | Interesse scelto nel modulo | RISERVATO |

### lead_magnet

Contenuti offerti in cambio del contatto. Titolare: Marketing. Livello della tabella: INTERNO.

| Colonna | Tipo | Descrizione | Livello |
|---|---|---|---|
| `id_lead_magnet` | `bigint` | Numero progressivo | INTERNO |
| `anno` | `smallint` | Edizione | INTERNO |
| `id_espositore` | `text` | Espositore che lo offre, vuoto se lo offre ARCADE Milano | INTERNO |
| `tipo` | `text` | Accesso beta, codice sconto, contenuto esclusivo, torneo, estrazione o demo privata | PUBBLICO |
| `titolo` | `text` | Nome mostrato al visitatore | PUBBLICO |
| `interesse` | `text` | Interesse che il lead magnet conferma | PUBBLICO |
| `attivo` | `boolean` | Visibile nel portale e allo stand | INTERNO |

### contatto_stand

Contatti raccolti dallo stand, senza email. Titolare: Espositore. Livello della tabella: PERSONALE.

| Colonna | Tipo | Descrizione | Livello |
|---|---|---|---|
| `id_contatto` | `text` | Codice del contatto | RISERVATO |
| `id_evento` | `text` | Chiave della riga nel registro unico | RISERVATO |
| `anno` | `smallint` | Edizione | RISERVATO |
| `codice_stand` | `text` | Stand che ha raccolto il contatto | RISERVATO |
| `id_espositore` | `text` | Espositore proprietario del contatto, base del filtro per espositore | RISERVATO |
| `raccolto_il` | `timestamp with time zone` | Orario di raccolta, ora italiana | RISERVATO |
| `fascia_eta` | `text` | Fascia d'età dichiarata, quasi-identificatore | RISERVATO |
| `provincia` | `text` | Provincia dichiarata, quasi-identificatore | RISERVATO |
| `interesse` | `text` | Interesse espresso dal visitatore | RISERVATO |
| `consenso_marketing` | `text` | Consenso al marketing dato dal visitatore | RISERVATO |
| `utilizzabile_marketing` | `boolean` | Vero se il contatto si può usare per il marketing | RISERVATO |
| `motivo_esclusione` | `text` | Perché non è utilizzabile, per esempio minore di 14-17 anni | RISERVATO |
| `email_su_piu_stand` | `boolean` | Stessa email lasciata a più stand | RISERVATO |
| `flag_qualita` | `text[]` | Anomalie rilevate sulla riga | RISERVATO |
| `id_lead_magnet` | `bigint` | Lead magnet che ha generato il contatto, vuoto per i dati storici | INTERNO |
| `consenso_espositori` | `boolean` | Consenso esplicito a condividere il contatto con l’espositore | PERSONALE |

### contatto_riservato

Email dei contatti, unico dato personale diretto dei contatti. Titolare: Responsabile dati. Livello della tabella: PERSONALE.

| Colonna | Tipo | Descrizione | Livello |
|---|---|---|---|
| `id_contatto` | `text` | Contatto a cui appartiene l'email | PERSONALE |
| `email` | `text` | Indirizzo email del visitatore | PERSONALE |

### revoca_registrazione_visitatore

Token con cui il visitatore modifica o revoca i consensi. Titolare: Privacy. Livello della tabella: PERSONALE.

| Colonna | Tipo | Descrizione | Livello |
|---|---|---|---|
| `token_hash` | `text` | Hash del token per aggiornare i consensi | RISERVATO |
| `id_registrazione` | `bigint` | Registrazione visitatore associata al token | PERSONALE |
| `usato_il` | `timestamp with time zone` | Data di consumo del token | RISERVATO |

## Identità e accesso

### account_direzione

Account di accesso della direzione di ARCADE. Titolare: Sicurezza. Livello della tabella: PERSONALE.

| Colonna | Tipo | Descrizione | Livello |
|---|---|---|---|
| `id_account` | `uuid` | Identificativo dell'account | INTERNO |
| `email` | `text` | Email di accesso | PERSONALE |
| `password_hash` | `text` | Impronta della password, mai la password | RISERVATO |
| `cognome` | `text` | Cognome della persona | PERSONALE |
| `nome` | `text` | Nome della persona | PERSONALE |
| `attivo` | `boolean` | Falso se l'account è disattivato | INTERNO |
| `created_at` | `timestamp with time zone` | Orario di creazione | INTERNO |
| `updated_at` | `timestamp with time zone` | Orario dell'ultima modifica | INTERNO |
| `ultimo_accesso` | `timestamp with time zone` | Orario dell'ultimo accesso | INTERNO |
| `email_verificata` | `boolean` | Vero se email verificata | INTERNO |

### account_espositore

Account di accesso degli espositori. Titolare: Sicurezza. Livello della tabella: PERSONALE.

| Colonna | Tipo | Descrizione | Livello |
|---|---|---|---|
| `id_account` | `uuid` | Identificativo dell'account | INTERNO |
| `id_espositore` | `text` | Espositore a cui è collegato l'account | INTERNO |
| `email` | `text` | Email di accesso | PERSONALE |
| `password_hash` | `text` | Impronta della password, mai la password | RISERVATO |
| `attivo` | `boolean` | Falso se l'account è disattivato | INTERNO |
| `creato_il` | `timestamp with time zone` | Orario di attivazione | INTERNO |
| `ultimo_accesso` | `timestamp with time zone` | Orario dell'ultimo accesso | INTERNO |
| `email_verificata` | `boolean` | Vero se email verificata | INTERNO |

### account_interno

Account di accesso di staff, commerciale e amministrazione. Titolare: Sicurezza. Livello della tabella: PERSONALE.

| Colonna | Tipo | Descrizione | Livello |
|---|---|---|---|
| `id_account` | `uuid` | Identificativo dell'account interno | RISERVATO |
| `email` | `text` | Email di accesso dell'account interno | PERSONALE |
| `password_hash` | `text` | Impronta della password, mai la password | RISERVATO |
| `ruolo` | `text` | Ruolo operativo: staff, commerciale o amministratore | INTERNO |
| `attivo` | `boolean` | Se l'account è attivo | INTERNO |
| `creato_il` | `timestamp with time zone` | Creazione dell'account | INTERNO |
| `ultimo_accesso` | `timestamp with time zone` | Ultimo accesso riuscito | INTERNO |

### invito_espositore

Inviti monouso per la prima attivazione di un account. Titolare: Sicurezza. Livello della tabella: PERSONALE.

| Colonna | Tipo | Descrizione | Livello |
|---|---|---|---|
| `token_hash` | `text` | Impronta del token dell'invito, il token in chiaro non si conserva | RISERVATO |
| `id_espositore` | `text` | Espositore invitato | INTERNO |
| `email` | `text` | Email a cui è stato inviato l'invito | PERSONALE |
| `scade_il` | `timestamp with time zone` | Scadenza dell'invito | INTERNO |
| `usato_il` | `timestamp with time zone` | Quando l'invito è stato usato, vuoto se ancora valido | INTERNO |

### recupero_password

Token monouso per reimpostare la password. Titolare: Identità. Livello della tabella: PERSONALE.

| Colonna | Tipo | Descrizione | Livello |
|---|---|---|---|
| `token_hash` | `text` | Hash del token monouso di recupero | RISERVATO |
| `id_account` | `uuid` | Account espositore che richiede il recupero | PERSONALE |
| `scade_il` | `timestamp with time zone` | Scadenza del token monouso | RISERVATO |
| `usato_il` | `timestamp with time zone` | Data di consumo del token | RISERVATO |

### fornitore_identita

Fornitori di identità esterni abilitati. Titolare: Sicurezza. Livello della tabella: INTERNO.

| Colonna | Tipo | Descrizione | Livello |
|---|---|---|---|
| `codice` | `text` | GOOGLE oppure MICROSOFT | PUBBLICO |
| `nome` | `text` | Nome mostrato sul pulsante di accesso | PUBBLICO |
| `attivo` | `boolean` | Falso per togliere il pulsante | INTERNO |

### identita_esterna

Collegamento tra un account e l'identità data da Google o Microsoft. Titolare: Sicurezza. Livello della tabella: PERSONALE.

| Colonna | Tipo | Descrizione | Livello |
|---|---|---|---|
| `fornitore` | `text` | Fornitore OAuth | INTERNO |
| `subject` | `text` | ID stabile dal fornitore | RISERVATO |
| `id_account` | `uuid` | Account collegato | INTERNO |
| `email_fornitore` | `text` | Email dal fornitore | PERSONALE |
| `collegata_il` | `timestamp with time zone` | Quando collegata | INTERNO |
| `ultimo_accesso` | `timestamp with time zone` | Ultimo accesso | INTERNO |

### auth_login_rate_limit

Conteggio dei tentativi di accesso falliti, per bloccare chi insiste. Titolare: Sicurezza. Livello della tabella: RISERVATO.

| Colonna | Tipo | Descrizione | Livello |
|---|---|---|---|
| `rate_key` | `text` | Impronta della chiave con cui si contano i tentativi di accesso, non contiene email | RISERVATO |
| `window_started` | `timestamp with time zone` | Inizio della finestra di conteggio | INTERNO |
| `attempt_count` | `integer` | Tentativi falliti nella finestra | INTERNO |
| `last_attempt` | `timestamp with time zone` | Ultimo tentativo registrato | INTERNO |
| `blocked_until` | `timestamp with time zone` | Fino a quando l'accesso resta bloccato | INTERNO |

## Registro degli accessi

### audit_event

Registro degli accessi ai dati personali e delle operazioni amministrative, senza token né contenuti. Titolare: Sicurezza. Livello della tabella: RISERVATO.

| Colonna | Tipo | Descrizione | Livello |
|---|---|---|---|
| `event_id` | `bigint` | Numero progressivo dell'evento registrato | INTERNO |
| `occurred_at` | `timestamp with time zone` | Quando è avvenuto l'accesso o l'operazione | INTERNO |
| `actor_ref` | `text` | Impronta di chi ha agito, non permette di risalire alla persona dal registro | RISERVATO |
| `actor_role` | `text` | Ruolo con cui è stata fatta l'operazione | INTERNO |
| `action` | `text` | Metodo della richiesta: GET, POST, PATCH oppure PUT | INTERNO |
| `resource` | `text` | Risorsa a cui si è acceduto, senza parametri né contenuti | INTERNO |

## Operatività in fiera

### membro_staff

Persone dello staff in fiera, senza nome né recapiti. Titolare: Organizzazione. Livello della tabella: INTERNO.

| Colonna | Tipo | Descrizione | Livello |
|---|---|---|---|
| `id_membro` | `uuid` | Identificativo della persona dello staff | INTERNO |
| `codice` | `text` | Sigla interna della persona, usata nei turni stampati | INTERNO |
| `ruolo` | `text` | Mansione prevalente: accoglienza, controllo accessi, info point, sicurezza, tecnico o capo turno | INTERNO |
| `attivo` | `boolean` | Falso se la persona non è più in servizio | INTERNO |

### membro_staff_riservato

Nome e recapiti dello staff. Titolare: Organizzazione. Livello della tabella: PERSONALE.

| Colonna | Tipo | Descrizione | Livello |
|---|---|---|---|
| `id_membro` | `uuid` | Persona dello staff | PERSONALE |
| `nome` | `text` | Nome e cognome della persona dello staff | PERSONALE |
| `email` | `text` | Email della persona dello staff | PERSONALE |
| `telefono` | `text` | Telefono della persona dello staff | PERSONALE |

### turno

Turni del personale, a un varco oppure in un padiglione. Titolare: Organizzazione. Livello della tabella: INTERNO.

| Colonna | Tipo | Descrizione | Livello |
|---|---|---|---|
| `id_turno` | `uuid` | Identificativo del turno | INTERNO |
| `anno` | `smallint` | Edizione | INTERNO |
| `varco` | `text` | Varco presidiato, vuoto se il turno è di padiglione | INTERNO |
| `padiglione` | `text` | Padiglione presidiato, vuoto se il turno è di varco | INTERNO |
| `mansione` | `text` | Cosa si fa in questo turno | INTERNO |
| `inizio` | `timestamp with time zone` | Inizio del turno | INTERNO |
| `fine` | `timestamp with time zone` | Fine del turno | INTERNO |
| `persone_previste` | `smallint` | Quante persone servono in questo turno | INTERNO |
| `note` | `text` | Note libere del turno | INTERNO |

### assegnazione_turno

Chi copre quale turno. Titolare: Organizzazione. Livello della tabella: INTERNO.

| Colonna | Tipo | Descrizione | Livello |
|---|---|---|---|
| `id_turno` | `uuid` | Turno assegnato | INTERNO |
| `id_membro` | `uuid` | Persona assegnata | INTERNO |
| `inizio` | `timestamp with time zone` | Inizio del turno, copiato dal turno e tenuto allineato dal database | INTERNO |
| `fine` | `timestamp with time zone` | Fine del turno, copiata dal turno e tenuta allineata dal database | INTERNO |
| `confermata` | `boolean` | Vero se la persona ha confermato la disponibilità | INTERNO |

### avviso

Avvisi di servizio per visitatori, espositori e staff. Titolare: Organizzazione. Livello della tabella: INTERNO.

| Colonna | Tipo | Descrizione | Livello |
|---|---|---|---|
| `id_avviso` | `uuid` | Identificativo dell'avviso | INTERNO |
| `titolo` | `text` | Titolo dell'avviso | PUBBLICO |
| `testo` | `text` | Testo dell'avviso | PUBBLICO |
| `pubblico` | `text` | A chi è rivolto: VISITATORI, ESPOSITORI oppure STAFF | INTERNO |
| `pubblicato_il` | `timestamp with time zone` | Orario di pubblicazione | INTERNO |
| `attivo` | `boolean` | Falso se l'avviso è stato disattivato | INTERNO |

## Qualità dei dati

### importazione

Registro delle importazioni dei dati. Titolare: Data Engineering. Livello della tabella: INTERNO.

| Colonna | Tipo | Descrizione | Livello |
|---|---|---|---|
| `id_importazione` | `bigint` | Numero dell'importazione | INTERNO |
| `file` | `text` | File importato | INTERNO |
| `iniziata_il` | `timestamp with time zone` | Inizio | INTERNO |
| `terminata_il` | `timestamp with time zone` | Fine | INTERNO |
| `righe_lette` | `integer` | Righe lette dal file | INTERNO |
| `righe_caricate` | `integer` | Righe caricate nelle tabelle | INTERNO |
| `righe_scartate` | `integer` | Righe scartate in pulizia | INTERNO |

### scarto_importazione

Righe rimosse in pulizia, con il motivo. Titolare: Data Engineering. Livello della tabella: INTERNO.

| Colonna | Tipo | Descrizione | Livello |
|---|---|---|---|
| `id` | `bigint` | Numero progressivo | INTERNO |
| `id_importazione` | `bigint` | Importazione che ha registrato lo scarto | INTERNO |
| `fonte` | `text` | Fonte della riga | INTERNO |
| `motivo` | `text` | Motivo dello scarto | INTERNO |
| `riga_originale` | `text` | Riga come ricevuta | INTERNO |

### catalogo_anomalia

Anomalie trovate in pulizia e come sono state gestite. Titolare: Data Engineering. Livello della tabella: INTERNO.

| Colonna | Tipo | Descrizione | Livello |
|---|---|---|---|
| `fonte` | `text` | Fonte dei dati | INTERNO |
| `codice` | `text` | Codice dell'anomalia | INTERNO |
| `descrizione` | `text` | Descrizione | INTERNO |
| `righe_coinvolte` | `integer` | Righe coinvolte | INTERNO |
| `gestione` | `text` | Come è stata gestita | INTERNO |

## Indicatori

### lotto_kpi

Lotti di indicatori calcolati da BAD e ricevuti dall'API. Titolare: Data Engineering. Livello della tabella: INTERNO.

| Colonna | Tipo | Descrizione | Livello |
|---|---|---|---|
| `batch_id` | `uuid` | Identificativo stabile del lotto, rende ripetibile l'invio | INTERNO |
| `anno` | `smallint` | Edizione dei KPI | INTERNO |
| `calcolato_il` | `timestamp with time zone` | Quando BAD ha calcolato i KPI | INTERNO |
| `formula_versione` | `text` | Versione delle formule usate | INTERNO |
| `intervallo_dati_dal` | `timestamp with time zone` | Inizio dei dati usati nel calcolo | INTERNO |
| `intervallo_dati_al` | `timestamp with time zone` | Fine dei dati usati nel calcolo | INTERNO |
| `ricevuto_il` | `timestamp with time zone` | Quando il lotto è stato ricevuto | INTERNO |

### kpi_osservazione

Singolo valore di indicatore dentro un lotto. Titolare: Data Engineering. Livello della tabella: INTERNO.

| Colonna | Tipo | Descrizione | Livello |
|---|---|---|---|
| `id_osservazione` | `bigint` | Numero progressivo | INTERNO |
| `batch_id` | `uuid` | Lotto di appartenenza | INTERNO |
| `codice` | `text` | Codice dell'indicatore, per esempio picco_presenza | INTERNO |
| `valore` | `numeric` | Valore calcolato | INTERNO |
| `unita` | `text` | Unità di misura, per esempio persone o euro | INTERNO |
| `periodo_dal` | `timestamp with time zone` | Inizio del periodo misurato | INTERNO |
| `periodo_al` | `timestamp with time zone` | Fine del periodo misurato | INTERNO |
| `dimensioni` | `jsonb` | Filtri come padiglione, stand o categoria, mai dati personali | INTERNO |
| `fonte` | `text[]` | Tabelle o sistemi da cui nasce il valore | INTERNO |
| `qualita` | `text` | OK, ATTENZIONE oppure DA_VERIFICARE | INTERNO |
| `flag_qualita` | `text[]` | Anomalie che riguardano il valore | INTERNO |
| `stimato` | `boolean` | Vero se il valore è una stima e non un conteggio | INTERNO |
| `simulato` | `boolean` | Vero se i dati di partenza sono simulati | INTERNO |
| `nota` | `text` | Nota esplicativa facoltativa | INTERNO |

