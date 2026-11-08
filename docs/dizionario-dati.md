# Dizionario dati

Descrive ogni colonna del database: significato, livello di sensibilità e titolare. Le sezioni fino alla V007 sono generate da `scripts/dati/genera_dizionario.py`; le migrazioni V008–V014 registrano nel database le colonne aggiunte successivamente, nella tabella `arcade.dizionario_dati`. Per le strutture commerciali e di importazione storica introdotte da V010–V013, il dettaglio puntuale è tracciato negli `INSERT` di descrizione delle rispettive migrazioni. La V014 stabilizza il `search_path` delle funzioni trigger.

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

## padiglione (colonne aggiunte nella V007)

Superficie e capienza per presenze e saturazione. Titolare: Organizzazione. Livello della tabella: INTERNO.

| Colonna | Descrizione | Livello |
|---|---|---|
| `superficie_mq` | Superficie utile del padiglione in metri quadri | INTERNO |
| `capienza` | Persone ammesse contemporaneamente nel padiglione | INTERNO |

## parametri_stima (colonna aggiunta nella V007)

Soglia di avviso della saturazione. Titolare: Data Engineering. Livello della tabella: INTERNO.

| Colonna | Descrizione | Livello |
|---|---|---|
| `soglia_avviso` | Quota della capienza oltre cui lo staff riceve un avviso, 0,80 di partenza | INTERNO |

## stand (colonne aggiunte nella V007)

Posizione dello stand per la mappa interattiva. Titolare: Organizzazione. Livello della tabella: PUBBLICO.

| Colonna | Descrizione | Livello |
|---|---|---|
| `fila` | Fila dello stand nella griglia della mappa | PUBBLICO |
| `colonna` | Colonna dello stand nella griglia della mappa | PUBBLICO |

## passaggio_pedana

Conteggi al minuto delle pedane conta-persone, simulati nella demo. Titolare: Controllo accessi. Livello della tabella: INTERNO.

| Colonna | Descrizione | Livello |
|---|---|---|
| `anno` | Edizione | INTERNO |
| `padiglione` | Padiglione della pedana | INTERNO |
| `minuto` | Minuto del conteggio | INTERNO |
| `entrati` | Persone entrate nel padiglione in quel minuto | INTERNO |
| `usciti` | Persone uscite dal padiglione in quel minuto | INTERNO |
| `fonte` | SIMULATA o SENSORE | INTERNO |

## conteggio_sensore_stand

Persone ferme davanti allo stand contate dal sensore AI, senza immagini. Titolare: Controllo accessi. Livello della tabella: INTERNO.

| Colonna | Descrizione | Livello |
|---|---|---|
| `anno` | Edizione | INTERNO |
| `codice_stand` | Stand del sensore | INTERNO |
| `minuto` | Minuto del conteggio | INTERNO |
| `nuove_persone_ferme` | Persone che si sono fermate davanti allo stand in quel minuto | INTERNO |
| `fonte` | SIMULATA o SENSORE | INTERNO |

## pacchetto_espositore

Pacchetto acquistato dall'espositore in ogni edizione. Titolare: Commerciale. Livello della tabella: INTERNO.

| Colonna | Descrizione | Livello |
|---|---|---|
| `anno` | Edizione | INTERNO |
| `id_espositore` | Espositore | INTERNO |
| `livello` | BASE oppure PREMIUM, il PREMIUM include la stima dal peso | INTERNO |

## registrazione_visitatore

Registrazione dal modulo del portale, senza nome né email. Titolare: Marketing. Livello della tabella: RISERVATO.

| Colonna | Descrizione | Livello |
|---|---|---|
| `id_registrazione` | Numero progressivo | INTERNO |
| `anno` | Edizione | INTERNO |
| `registrato_il` | Orario della registrazione | INTERNO |
| `provincia` | Provincia dichiarata, quasi-identificatore | RISERVATO |
| `fascia_eta` | Fascia d'età dichiarata, solo adulti, quasi-identificatore | RISERVATO |
| `consenso_marketing` | Consenso a offerte e novità di ARCADE Milano | RISERVATO |
| `consenso_espositori` | Consenso a essere contattato dagli espositori visitati | RISERVATO |
| `consensi_aggiornati_il` | Ultima modifica o revoca dei consensi | RISERVATO |
| `profilabile` | Vero solo con consenso marketing e fascia d'età adulta dichiarata | RISERVATO |

## registrazione_riservata

Nome ed email del visitatore registrato, separati dal resto. Titolare: Marketing. Livello della tabella: PERSONALE.

| Colonna | Descrizione | Livello |
|---|---|---|
| `id_registrazione` | Registrazione di appartenenza | PERSONALE |
| `nome` | Nome del visitatore | PERSONALE |
| `email` | Email del visitatore | PERSONALE |

## interesse_visitatore

Interessi scelti nel modulo. Titolare: Marketing. Livello della tabella: RISERVATO.

| Colonna | Descrizione | Livello |
|---|---|---|
| `id_registrazione` | Registrazione di appartenenza | RISERVATO |
| `interesse` | Interesse scelto nel modulo | RISERVATO |

## lead_magnet

Ciò che il visitatore riceve in cambio del contatto. Titolare: Marketing. Livello della tabella: INTERNO.

| Colonna | Descrizione | Livello |
|---|---|---|
| `id_lead_magnet` | Numero progressivo | INTERNO |
| `anno` | Edizione | INTERNO |
| `id_espositore` | Espositore che lo offre, vuoto se lo offre ARCADE Milano | INTERNO |
| `tipo` | Accesso beta, codice sconto, contenuto esclusivo, torneo, estrazione o demo privata | PUBBLICO |
| `titolo` | Nome mostrato al visitatore | PUBBLICO |
| `interesse` | Interesse che il lead magnet conferma | PUBBLICO |
| `attivo` | Visibile nel portale e allo stand | INTERNO |

## contatto_stand (colonna aggiunta nella V007)

Collegamento tra contatto e lead magnet. Titolare: Marketing. Livello della tabella: INTERNO.

| Colonna | Descrizione | Livello |
|---|---|---|
| `id_lead_magnet` | Lead magnet che ha generato il contatto, vuoto per i dati storici | INTERNO |

## edizione (colonne aggiunte nella V008)

| Colonna | Descrizione | Livello |
|---|---|---|
| `sede` | Sede della fiera | PUBBLICO |
| `stato` | PIANIFICATA, ATTIVA oppure CONCLUSA | INTERNO |

## padiglione (colonne aggiunte nella V008)

| Colonna | Descrizione | Livello |
|---|---|---|
| `nome` | Nome leggibile del padiglione | PUBBLICO |

## stand (colonne aggiunte nella V008)

| Colonna | Descrizione | Livello |
|---|---|---|
| `disponibile` | Falso se lo stand è tolto dalla vendita, per esempio per un vincolo di allestimento | INTERNO |

## accesso (colonne aggiunte nella V008)

| Colonna | Descrizione | Livello |
|---|---|---|
| `motivo_rifiuto` | Perché l'ingresso è stato rifiutato, vuoto per gli ingressi e per i rifiuti storici | INTERNO |

## parametri_stima (colonne aggiunte nella V008)

| Colonna | Descrizione | Livello |
|---|---|---|
| `costi_edizione_eur` | Costi dell'edizione, parametro del costo per MQL, simulato finché il cliente non lo fornisce | INTERNO |

## registrazione_riservata (colonne aggiunte nella V008)

| Colonna | Descrizione | Livello |
|---|---|---|
| `token_revoca_hash` | Impronta del token con cui il visitatore modifica i consensi, il token in chiaro non si conserva | RISERVATO |

## scansione_stand

Scansioni 2026 di uno stand, una riga per scansione. Titolare: Controllo accessi. Livello della tabella: RISERVATO. Aggiunta nella V008.

| Colonna | Descrizione | Livello |
|---|---|---|
| `id_evento` | Chiave del registro unico, per ripetere un invio senza duplicati | INTERNO |
| `anno` | Edizione | INTERNO |
| `codice_stand` | Stand dove è avvenuta la scansione | INTERNO |
| `operatore_id` | Identificativo di chi ha scansionato, solo interno | RISERVATO |
| `rilevata_il` | Orario della scansione | INTERNO |
| `ticket_ref` | Identificativo pseudonimizzato del biglietto, non contiene nome o email | RISERVATO |
| `id_contatto` | Contatto creato dalla scansione, vuoto se il visitatore non lo ha lasciato | INTERNO |
| `duplicata` | Vero se lo stesso biglietto era già stato scansionato nello stand, non viene conteggiata | INTERNO |
| `registrata_il` | Orario in cui il sistema ha registrato la scansione | INTERNO |

## parametri_stima (colonne aggiunte nella V009)

| Colonna | Descrizione | Livello |
|---|---|---|
| `soglia_sconto_approvazione` | Sconto in percentuale oltre il quale serve l'approvazione, 10 di partenza | INTERNO |

## categoria_espositore

Categorie degli espositori mostrate nel portale. Titolare: Organizzazione. Livello della tabella: PUBBLICO. Aggiunta nella V009.

| Colonna | Descrizione | Livello |
|---|---|---|
| `codice` | Codice della categoria | PUBBLICO |
| `nome` | Nome mostrato nel portale | PUBBLICO |

## profilo_espositore

Profilo pubblico dell'espositore. Titolare: Organizzazione. Livello della tabella: PUBBLICO. Aggiunta nella V009.

| Colonna | Descrizione | Livello |
|---|---|---|
| `id_espositore` | Espositore | PUBBLICO |
| `nome_pubblico` | Nome mostrato nel portale | PUBBLICO |
| `descrizione` | Presentazione dell'espositore | PUBBLICO |
| `logo_url` | Indirizzo del logo | PUBBLICO |
| `sito_web` | Sito dell'espositore | PUBBLICO |
| `in_evidenza` | Vero se l'espositore è messo in evidenza nel portale | PUBBLICO |

## espositore_categoria

Categorie di ogni espositore. Titolare: Organizzazione. Livello della tabella: PUBBLICO. Aggiunta nella V009.

| Colonna | Descrizione | Livello |
|---|---|---|
| `id_espositore` | Espositore | PUBBLICO |
| `codice_categoria` | Categoria dell'espositore | PUBBLICO |

## listino_voce

Listino prezzi per edizione, al netto di IVA. Titolare: Commerciale. Livello della tabella: INTERNO. Aggiunta nella V009.

| Colonna | Descrizione | Livello |
|---|---|---|
| `anno` | Edizione | INTERNO |
| `codice_voce` | Codice della voce di listino | INTERNO |
| `descrizione` | Nome leggibile della voce | INTERNO |
| `tipo` | STAND, PACCHETTO oppure SERVIZIO | INTERNO |
| `unita` | MQ se il prezzo è per metro quadro, FORFAIT se è a corpo | INTERNO |
| `prezzo_eur` | Prezzo al netto di IVA, simulato finché il cliente non fornisce il listino | INTERNO |

## pratica

Pratica commerciale di un espositore, dal preventivo al contratto. Titolare: Commerciale. Livello della tabella: INTERNO. Aggiunta nella V009.

| Colonna | Descrizione | Livello |
|---|---|---|
| `id_pratica` | Identificativo della pratica | INTERNO |
| `anno` | Edizione | INTERNO |
| `id_espositore` | Espositore della pratica | INTERNO |
| `codice_stand` | Stand scelto, obbligatorio dopo la bozza | INTERNO |
| `stato` | BOZZA, INVIATA, FIRMATA oppure ACCONTO_RICEVUTO, solo in avanti | INTERNO |
| `pacchetto` | BASE o PREMIUM, alla firma diventa il pacchetto dell'espositore | INTERNO |
| `sconto_percentuale` | Sconto sull'imponibile del listino | INTERNO |
| `approvazione_richiesta` | Vero se lo sconto supera la soglia, calcolato dal database | INTERNO |
| `id_pratica_precedente` | Pratica dell'edizione precedente da cui nasce il rinnovo | INTERNO |
| `creata_il` | Orario di creazione | INTERNO |
| `aggiornata_il` | Orario dell'ultima modifica, aggiornato dal database | INTERNO |

## voce_pratica

Voci del listino acquistate in una pratica, con il prezzo applicato. Titolare: Commerciale. Livello della tabella: INTERNO. Aggiunta nella V009.

| Colonna | Descrizione | Livello |
|---|---|---|
| `id_pratica` | Pratica di appartenenza | INTERNO |
| `anno` | Edizione della pratica e del listino | INTERNO |
| `codice_voce` | Voce di listino acquistata | INTERNO |
| `quantita` | Metri quadri o numero di forfait | INTERNO |
| `prezzo_unitario_eur` | Prezzo applicato al momento dell'offerta, resta invariato se il listino cambia | INTERNO |

## documento_pratica

Documenti collegati a una pratica, conservati su SharePoint. Titolare: Commerciale. Livello della tabella: INTERNO. Aggiunta nella V009.

| Colonna | Descrizione | Livello |
|---|---|---|
| `id_documento` | Identificativo del documento | INTERNO |
| `id_pratica` | Pratica di appartenenza | INTERNO |
| `tipo` | OFFERTA, CONTRATTO oppure ALTRO | INTERNO |
| `nome` | Nome del file | INTERNO |
| `url` | Collegamento al documento su SharePoint | INTERNO |
| `creato_il` | Orario di creazione | INTERNO |

## acconto

Acconti ricevuti per una pratica. Titolare: Commerciale. Livello della tabella: INTERNO. Aggiunta nella V009.

| Colonna | Descrizione | Livello |
|---|---|---|
| `id_acconto` | Identificativo dell'acconto | INTERNO |
| `id_pratica` | Pratica di appartenenza | INTERNO |
| `importo_eur` | Importo ricevuto, i pagamenti non passano dalla piattaforma | INTERNO |
| `ricevuto_il` | Quando l'acconto è stato ricevuto | INTERNO |
| `riferimento` | Riferimento del bonifico o della ricevuta | INTERNO |

## richiesta

Richieste arrivate dal sito, senza i dati di contatto. Titolare: Commerciale. Livello della tabella: INTERNO. Aggiunta nella V009.

| Colonna | Descrizione | Livello |
|---|---|---|
| `id_richiesta` | Identificativo della richiesta | INTERNO |
| `tipo` | ESPOSITORE oppure VISITATORE | INTERNO |
| `stato` | NUOVA, IN_LAVORAZIONE oppure CHIUSA | INTERNO |
| `anno` | Edizione richiesta | INTERNO |
| `azienda` | Nome dell'azienda che chiede lo stand | INTERNO |
| `categoria` | Categoria indicata nella richiesta | INTERNO |
| `metri_quadri_desiderati` | Metri quadri richiesti | INTERNO |
| `note` | Note libere della richiesta | INTERNO |
| `consenso_privacy` | Consenso al trattamento dei dati per gestire la richiesta | INTERNO |
| `consenso_marketing` | Consenso a ricevere novità, per le richieste dei visitatori | INTERNO |
| `id_pratica` | Pratica creata dalla richiesta | INTERNO |
| `creata_il` | Orario della richiesta | INTERNO |

## richiesta_riservata

Nome e email di chi ha fatto la richiesta, unico dato personale diretto di questa area. Titolare: Commerciale. Livello della tabella: PERSONALE. Aggiunta nella V009.

| Colonna | Descrizione | Livello |
|---|---|---|
| `id_richiesta` | Richiesta di appartenenza | PERSONALE |
| `referente` | Nome del referente o del visitatore | PERSONALE |
| `email` | Email del referente o del visitatore | PERSONALE |

## account_espositore

Account di accesso degli espositori. Titolare: Sicurezza. Livello della tabella: PERSONALE. Aggiunta nella V009.

| Colonna | Descrizione | Livello |
|---|---|---|
| `id_account` | Identificativo dell'account | INTERNO |
| `id_espositore` | Espositore a cui è collegato l'account | INTERNO |
| `email` | Email di accesso | PERSONALE |
| `password_hash` | Impronta della password, mai la password | RISERVATO |
| `attivo` | Falso se l'account è disattivato | INTERNO |
| `creato_il` | Orario di attivazione | INTERNO |
| `ultimo_accesso` | Orario dell'ultimo accesso | INTERNO |

## invito_espositore

Inviti monouso per attivare un account. Titolare: Sicurezza. Livello della tabella: PERSONALE. Aggiunta nella V009.

| Colonna | Descrizione | Livello |
|---|---|---|
| `token_hash` | Impronta del token dell'invito, il token in chiaro non si conserva | RISERVATO |
| `id_espositore` | Espositore invitato | INTERNO |
| `email` | Email a cui è stato inviato l'invito | PERSONALE |
| `scade_il` | Scadenza dell'invito | INTERNO |
| `usato_il` | Quando l'invito è stato usato, vuoto se ancora valido | INTERNO |

## avviso

Avvisi di servizio per visitatori, espositori e staff. Titolare: Organizzazione. Livello della tabella: INTERNO. Aggiunta nella V009.

| Colonna | Descrizione | Livello |
|---|---|---|
| `id_avviso` | Identificativo dell'avviso | INTERNO |
| `titolo` | Titolo dell'avviso | PUBBLICO |
| `testo` | Testo dell'avviso | PUBBLICO |
| `pubblico` | A chi è rivolto: VISITATORI, ESPOSITORI oppure STAFF | INTERNO |
| `pubblicato_il` | Orario di pubblicazione | INTERNO |
| `attivo` | Falso se l'avviso è stato disattivato | INTERNO |

## lotto_kpi

Lotti di KPI calcolati da BAD e ricevuti dall'API. Titolare: Data Engineering. Livello della tabella: INTERNO. Aggiunta nella V009.

| Colonna | Descrizione | Livello |
|---|---|---|
| `batch_id` | Identificativo stabile del lotto, rende ripetibile l'invio | INTERNO |
| `anno` | Edizione dei KPI | INTERNO |
| `calcolato_il` | Quando BAD ha calcolato i KPI | INTERNO |
| `formula_versione` | Versione delle formule usate | INTERNO |
| `intervallo_dati_dal` | Inizio dei dati usati nel calcolo | INTERNO |
| `intervallo_dati_al` | Fine dei dati usati nel calcolo | INTERNO |
| `ricevuto_il` | Quando il lotto è stato ricevuto | INTERNO |

## kpi_osservazione

Singolo valore di KPI dentro un lotto. Titolare: Data Engineering. Livello della tabella: INTERNO. Aggiunta nella V009.

| Colonna | Descrizione | Livello |
|---|---|---|
| `id_osservazione` | Numero progressivo | INTERNO |
| `batch_id` | Lotto di appartenenza | INTERNO |
| `codice` | Codice dell'indicatore, per esempio picco_presenza | INTERNO |
| `valore` | Valore calcolato | INTERNO |
| `unita` | Unità di misura, per esempio persone o euro | INTERNO |
| `periodo_dal` | Inizio del periodo misurato | INTERNO |
| `periodo_al` | Fine del periodo misurato | INTERNO |
| `dimensioni` | Filtri come padiglione, stand o categoria, mai dati personali | INTERNO |
| `fonte` | Tabelle o sistemi da cui nasce il valore | INTERNO |
| `qualita` | OK, ATTENZIONE oppure DA_VERIFICARE | INTERNO |
| `flag_qualita` | Anomalie che riguardano il valore | INTERNO |
| `stimato` | Vero se il valore è una stima e non un conteggio | INTERNO |
| `simulato` | Vero se i dati di partenza sono simulati | INTERNO |
| `nota` | Nota esplicativa facoltativa | INTERNO |
