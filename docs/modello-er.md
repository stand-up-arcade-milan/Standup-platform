# Modello ER

Il diagramma descrive lo schema `arcade` di PostgreSQL così come lo costruiscono le [migrazioni](../database/migrations) da `V001` a `V026`. Se diagramma e SQL non coincidono, vale l'SQL. Il significato di ogni colonna è nel [dizionario dati](dizionario-dati.md).

## 1. Modello completo

Sono mostrate le chiavi e gli attributi principali. `PK` indica la chiave primaria e `FK` la chiave esterna. Per leggere meglio il disegno, i legami con `edizione` sono tracciati solo per `ordine` e `assegnazione_stand`, ma ogni tabella con la colonna `anno` ha una chiave esterna verso `edizione.anno`. Le tabelle di servizio dell'importazione sono elencate nel paragrafo 2.

```mermaid
erDiagram
    EDIZIONE ||--o| PARAMETRI_STIMA : "ha"
    EDIZIONE ||--o{ ORDINE : "contiene"
    EDIZIONE ||--o{ ASSEGNAZIONE_STAND : "assegna"

    CANALE_VENDITA ||--o{ ORDINE : "vende"
    ORDINE ||--|{ BIGLIETTO : "comprende"
    CATEGORIA_BIGLIETTO ||--o{ BIGLIETTO : "classifica"

    PADIGLIONE ||--o{ VARCO : "ospita"
    PADIGLIONE ||--o{ STAND : "ospita"
    PADIGLIONE ||--o{ PASSAGGIO_PEDANA : "conta"
    VARCO ||--o{ ACCESSO : "rileva"

    STAND ||--o{ ASSEGNAZIONE_STAND : "viene assegnato"
    ESPOSITORE ||--o{ ASSEGNAZIONE_STAND : "riceve"
    ESPOSITORE ||--o{ PACCHETTO_ESPOSITORE : "sceglie"
    ESPOSITORE |o--o{ LEAD_MAGNET : "offre"

    STAND ||--o{ VISITA_STAND_ORA : "misura"
    STAND ||--o{ CONTATTO_STAND : "raccoglie"
    ESPOSITORE ||--o{ CONTATTO_STAND : "riceve"
    LEAD_MAGNET |o--o{ CONTATTO_STAND : "genera"
    CONTATTO_STAND ||--o| CONTATTO_RISERVATO : "ha email in"

    STAND ||--o{ RILEVAZIONE_PESO : "pesa"
    STAND ||--o{ CONTEGGIO_SENSORE_STAND : "osserva"

    REGISTRAZIONE_VISITATORE ||--o| REGISTRAZIONE_RISERVATA : "ha nome ed email in"
    REGISTRAZIONE_VISITATORE ||--o{ INTERESSE_VISITATORE : "indica"

    EDIZIONE {
        smallint anno PK
        date inizio_vendite
        date inizio_fiera
        date fine_fiera
    }
    PARAMETRI_STIMA {
        smallint anno PK, FK
        numeric peso_medio_kg
        numeric soglia_rumore_kg
        numeric persone_per_mq
        numeric soglia_avviso
    }
    CANALE_VENDITA {
        text codice PK
        text descrizione
    }
    CATEGORIA_BIGLIETTO {
        text codice PK
        text descrizione
        smallint persone_incluse
    }
    ORDINE {
        text id_ordine PK
        smallint anno FK
        text canale FK
    }
    BIGLIETTO {
        text codice PK
        text id_ordine FK
        smallint anno FK
        text categoria FK
        date giorno_valido
        smallint quantita
        numeric importo_eur
    }
    PADIGLIONE {
        text codice PK
        numeric superficie_mq
        integer capienza
    }
    VARCO {
        text codice PK
        text padiglione FK
    }
    ACCESSO {
        text id_evento PK
        smallint anno FK
        text varco FK
        timestamptz letto_il
        text codice_biglietto
        text esito
        smallint persone
    }
    STAND {
        text codice PK
        text padiglione FK
        numeric superficie_mq
        smallint fila
        smallint colonna
    }
    ESPOSITORE {
        text id_espositore PK
        text ragione_sociale
    }
    ASSEGNAZIONE_STAND {
        smallint anno PK, FK
        text codice_stand PK, FK
        text id_espositore FK
    }
    PACCHETTO_ESPOSITORE {
        smallint anno PK, FK
        text id_espositore PK, FK
        text livello
    }
    VISITA_STAND_ORA {
        text id_riferimento PK
        smallint anno FK
        text codice_stand FK
        timestamptz ora_inizio
        integer scansioni
    }
    CONTATTO_STAND {
        text id_contatto PK
        smallint anno FK
        text codice_stand FK
        text id_espositore FK
        bigint id_lead_magnet FK
        text interesse
        boolean utilizzabile_marketing
    }
    CONTATTO_RISERVATO {
        text id_contatto PK, FK
        text email
    }
    LEAD_MAGNET {
        bigint id_lead_magnet PK
        smallint anno FK
        text id_espositore FK
        text tipo
        text titolo
        text interesse
        boolean attivo
    }
    RILEVAZIONE_PESO {
        bigint id PK
        smallint anno FK
        text codice_stand FK
        timestamptz rilevato_il
        numeric peso_lordo_kg
        numeric tara_kg
        text fonte
    }
    PASSAGGIO_PEDANA {
        text padiglione PK, FK
        timestamptz minuto PK
        smallint anno FK
        integer entrati
        integer usciti
        text fonte
    }
    CONTEGGIO_SENSORE_STAND {
        text codice_stand PK, FK
        timestamptz minuto PK
        smallint anno FK
        integer nuove_persone_ferme
        text fonte
    }
    REGISTRAZIONE_VISITATORE {
        bigint id_registrazione PK
        smallint anno FK
        text provincia
        text fascia_eta
        boolean consenso_marketing
        boolean consenso_espositori
        boolean profilabile
    }
    REGISTRAZIONE_RISERVATA {
        bigint id_registrazione PK, FK
        text nome
        text email
    }
    INTERESSE_VISITATORE {
        bigint id_registrazione PK, FK
        text interesse PK
    }
```

## 2. Come leggerlo

| Area | Tabelle | A cosa servono |
| --- | --- | --- |
| Riferimento | `edizione`, `padiglione`, `varco`, `stand`, `espositore`, `assegnazione_stand`, `categoria_biglietto`, `canale_vendita` | Anagrafiche comuni a tutte le edizioni. Un espositore occupa uno stand per edizione. |
| Biglietteria | `ordine`, `biglietto` | Ordini e biglietti, senza dati personali. Un biglietto può coprire più persone (`quantita`). |
| Accessi | `accesso` | Una riga per lettura al varco, con esito e numero di persone. |
| Stand e contatti | `visita_stand_ora`, `contatto_stand`, `contatto_riservato` | Scansioni per ora e contatti raccolti. L'email sta in una tabella separata. |
| Pacchetti e lead magnet | `pacchetto_espositore`, `lead_magnet` | BASE o PREMIUM per edizione, e ciò che il visitatore riceve in cambio del contatto. |
| Presenze | `passaggio_pedana`, `conteggio_sensore_stand`, `rilevazione_peso`, `parametri_stima` | Pedane nei padiglioni, sensori AI agli stand, stima dal peso e parametri di calcolo. |
| Visitatori registrati | `registrazione_visitatore`, `registrazione_riservata`, `interesse_visitatore` | Consensi separati e interessi. Nome ed email stanno in una tabella riservata. |
| Scansioni 2026 | `scansione_stand` | Una riga per scansione con operatore e biglietto pseudonimizzato. Le scansioni ripetute sono marcate `duplicata` e non contano. |
| Area commerciale | `listino_voce`, `pratica`, `voce_pratica`, `documento_pratica`, `acconto`, `richiesta`, `richiesta_riservata` | Dalla richiesta dal sito alla pratica firmata, con listino, sconti, documenti e acconti. Nome ed email del richiedente stanno in una tabella riservata. |
| Profilo e accesso | `profilo_espositore`, `categoria_espositore`, `espositore_categoria`, `account_espositore`, `invito_espositore`, `avviso` | Vetrina pubblica degli espositori, account con inviti monouso e avvisi di servizio. Password e token si conservano solo come impronta. |
| KPI da BAD | `lotto_kpi`, `kpi_osservazione` | Lotti di indicatori ricevuti dall'API, ripetibili grazie al `batch_id`. Nessun dato personale. |
| Servizio | `importazione`, `scarto_importazione`, `catalogo_anomalia`, `fascia_stand_mancante`, `dizionario_dati` | Tracciano i caricamenti, le righe scartate e le anomalie, e descrivono ogni colonna. |

## 3. Novità del SAL 1

La migrazione `V007` aggiunge pedane, sensori AI, pacchetti, registrazione del visitatore e lead magnet. Questo schema più piccolo mostra solo quelle tabelle e i loro legami.

```mermaid
erDiagram
    PADIGLIONE ||--o{ PASSAGGIO_PEDANA : "conta"
    STAND ||--o{ CONTEGGIO_SENSORE_STAND : "osserva"
    STAND ||--o{ RILEVAZIONE_PESO : "pesa"
    ESPOSITORE ||--o{ PACCHETTO_ESPOSITORE : "sceglie"
    ESPOSITORE |o--o{ LEAD_MAGNET : "offre"
    LEAD_MAGNET |o--o{ CONTATTO_STAND : "genera"
    REGISTRAZIONE_VISITATORE ||--o| REGISTRAZIONE_RISERVATA : "ha nome ed email in"
    REGISTRAZIONE_VISITATORE ||--o{ INTERESSE_VISITATORE : "indica"

    PASSAGGIO_PEDANA {
        text padiglione PK, FK
        timestamptz minuto PK
        integer entrati
        integer usciti
        text fonte
    }
    CONTEGGIO_SENSORE_STAND {
        text codice_stand PK, FK
        timestamptz minuto PK
        integer nuove_persone_ferme
        text fonte
    }
    RILEVAZIONE_PESO {
        text codice_stand FK
        numeric peso_lordo_kg
        numeric tara_kg
    }
    PACCHETTO_ESPOSITORE {
        smallint anno PK, FK
        text id_espositore PK, FK
        text livello
    }
    LEAD_MAGNET {
        bigint id_lead_magnet PK
        text tipo
        text titolo
        text interesse
    }
    CONTATTO_STAND {
        text id_contatto PK
        bigint id_lead_magnet FK
        boolean utilizzabile_marketing
    }
    REGISTRAZIONE_VISITATORE {
        bigint id_registrazione PK
        boolean consenso_marketing
        boolean consenso_espositori
        boolean profilabile
    }
    REGISTRAZIONE_RISERVATA {
        bigint id_registrazione PK, FK
        text nome
        text email
    }
    INTERESSE_VISITATORE {
        bigint id_registrazione PK, FK
        text interesse PK
    }
```

| Novità | Tabelle | Indicatori che alimentano |
| --- | --- | --- |
| Pedane conta-persone | `passaggio_pedana` | Persone presenti, picco di presenza, saturazione e visitatori per m² |
| Sensori AI agli stand | `conteggio_sensore_stand` | Persone ferme allo stand e resa dello stand |
| Pacchetto dell'espositore | `pacchetto_espositore` | Accesso alla stima dal peso, riservato al PREMIUM |
| Lead magnet | `lead_magnet`, `contatto_stand.id_lead_magnet` | Contatti qualificati (MQL), quota MQL e resa dei lead magnet |
| Registrazione del visitatore | `registrazione_visitatore`, `registrazione_riservata`, `interesse_visitatore` | Interessi del pubblico, solo come totali e solo per chi è profilabile |

## 4. Novità dalla V008 alla V026

La `V008` corregge lo schema dopo il confronto con il contratto OpenAPI: sede e stato dell'edizione, nome del padiglione, stand non disponibili, motivo del rifiuto agli ingressi, costi dell'edizione, token di revoca dei consensi, peso senza letture doppie e la tabella `scansione_stand`. Aggiunge anche le viste `v_stand_stato`, `v_visitatori_riepilogo`, `v_costo_per_mql` e `v_visite_stand_scansioni`.

La `V009` costruisce l'area commerciale, l'accesso degli espositori e i KPI ricevuti da BAD. Il disegno mostra solo queste tabelle.

```mermaid
erDiagram
    espositore ||--o{ pratica : "ha"
    stand ||--o{ pratica : "scelto in"
    pratica ||--o{ voce_pratica : contiene
    listino_voce ||--o{ voce_pratica : "prezzo da"
    pratica ||--o{ documento_pratica : ha
    pratica ||--o{ acconto : riceve
    pratica |o--o{ pratica : "rinnovo di"
    richiesta |o--o| pratica : genera
    richiesta ||--|| richiesta_riservata : "contatto in"
    espositore ||--o| profilo_espositore : mostra
    espositore ||--o{ espositore_categoria : appartiene
    categoria_espositore ||--o{ espositore_categoria : raggruppa
    espositore ||--o{ account_espositore : accede
    espositore ||--o{ invito_espositore : invitato
    stand ||--o{ scansione_stand : riceve
    contatto_stand |o--o{ scansione_stand : "nasce da"
    lotto_kpi ||--o{ kpi_osservazione : contiene
    pratica {
        uuid id_pratica PK
        smallint anno FK
        text id_espositore FK
        text codice_stand FK
        text stato
        text pacchetto
        numeric sconto_percentuale
        boolean approvazione_richiesta
    }
    voce_pratica {
        uuid id_pratica PK
        text codice_voce PK
        numeric quantita
        numeric prezzo_unitario_eur
    }
    listino_voce {
        smallint anno PK
        text codice_voce PK
        text tipo
        text unita
        numeric prezzo_eur
    }
    acconto {
        uuid id_acconto PK
        uuid id_pratica FK
        numeric importo_eur
        timestamptz ricevuto_il
    }
    documento_pratica {
        uuid id_documento PK
        uuid id_pratica FK
        text tipo
        text url
    }
    richiesta {
        uuid id_richiesta PK
        text tipo
        text stato
        text azienda
        boolean consenso_privacy
        uuid id_pratica FK
    }
    richiesta_riservata {
        uuid id_richiesta PK
        text referente
        text email
    }
    profilo_espositore {
        text id_espositore PK
        text nome_pubblico
        boolean in_evidenza
    }
    categoria_espositore {
        text codice PK
        text nome
    }
    espositore_categoria {
        text id_espositore PK
        text codice_categoria PK
    }
    account_espositore {
        uuid id_account PK
        text id_espositore FK
        text email
        text password_hash
    }
    invito_espositore {
        text token_hash PK
        text id_espositore FK
        timestamptz scade_il
        timestamptz usato_il
    }
    scansione_stand {
        text id_evento PK
        smallint anno FK
        text codice_stand FK
        text operatore_id
        text ticket_ref
        boolean duplicata
    }
    lotto_kpi {
        uuid batch_id PK
        smallint anno FK
        text formula_versione
    }
    kpi_osservazione {
        bigint id_osservazione PK
        uuid batch_id FK
        text codice
        numeric valore
        text qualita
    }
    espositore { text id_espositore PK }
    stand { text codice PK }
    contatto_stand { text id_contatto PK }
```

| Regola | Dove è garantita |
| --- | --- |
| Lo stato della pratica va solo avanti: BOZZA, INVIATA, FIRMATA, ACCONTO_RICEVUTO | Trigger `pratica_controlla` |
| Dopo la bozza la pratica ha uno stand | Vincolo di controllo su `pratica` |
| Lo sconto sopra la soglia (10 di partenza, in `parametri_stima`) richiede approvazione | Trigger `pratica_controlla`, colonna `approvazione_richiesta` |
| Alla firma lo stand viene assegnato e il pacchetto registrato, nella stessa transazione. Se lo stand è già assegnato o non disponibile la firma fallisce | Trigger `pratica_alla_firma` |
| Il prezzo applicato resta quello dell'offerta anche se il listino cambia | `voce_pratica.prezzo_unitario_eur` |
| Il ricavo per m² usa le pratiche firmate, al netto di IVA e sconti | Vista `v_ricavo_per_mq` |


### Dalla V010 alla V014: storico commerciale, idempotenza e consensi

La `V010` conserva dati commerciali storici, informazioni riservate degli espositori e planimetrie per edizione; consente inoltre di pianificare il 2026 senza inventare le date. La `V011` aggiunge le chiavi di idempotenza e i token monouso di recupero password e revoca consensi. La `V012` registra il consenso alla condivisione e il lead magnet della scansione. La `V013` permette di creare i metadati di un documento prima che sia configurato un archivio che fornisca un URL. La `V014` rende indipendente dal `search_path` della connessione il funzionamento dei trigger commerciali.

Tre tabelle di servizio non compaiono nei disegni perché non hanno legami interessanti: `acquisizione_evento` tiene gli identificativi degli eventi già ricevuti, così un invio ripetuto non viene contato due volte; `revoca_registrazione_visitatore` conserva l'impronta del token con cui il visitatore modifica o revoca i consensi; `dizionario_dati` è il dizionario stesso; `auth_login_rate_limit` conta i tentativi di accesso falliti e `audit_event` registra gli accessi ai dati personali.

```mermaid
erDiagram
    espositore ||--o| espositore_riservato : "anagrafica in"
    espositore ||--o{ pratica : ha
    pratica ||--o| contratto_storico : "importato da"
    contratto_storico ||--o{ contratto_storico_riga : contiene
    edizione ||--o{ planimetria_stand : "nell'edizione"
    stand ||--o{ planimetria_stand : "collocato in"
    padiglione ||--o{ planimetria_stand : ospita
    espositore_riservato {
        text id_espositore PK
        text partita_iva
        text referente
        text email_referente
    }
    planimetria_stand {
        smallint anno PK
        text codice_stand PK
        text padiglione FK
        numeric superficie_mq
        text posizione
    }
    contratto_storico {
        text id_contratto_origine PK
        uuid id_pratica FK
        numeric imponibile_listino_eur
        numeric imponibile_netto_eur
        date data_firma
        boolean rinnovo
    }
    contratto_storico_riga {
        text id_contratto_origine PK
        integer numero_riga PK
        text descrizione
        numeric importo_eur
        boolean presente_nel_listino
    }
    espositore { text id_espositore PK }
    pratica { uuid id_pratica PK }
    stand { text codice PK }
    padiglione { text codice PK }
    edizione { smallint anno PK }
```

### Dalla V015 alla V023: ruoli di esecuzione, registro accessi e proiezioni per BAD

La `V015` è il passo che rende vere le regole di visibilità: crea i ruoli con cui gira l'applicazione, `arcade_api`, `arcade_pubblico`, `arcade_scrittura_pubblica`, `arcade_registrazione`, `arcade_dispositivo` e `arcade_bad`, toglie al ruolo di sola lettura le tabelle dei visitatori e stringe la regola dei contatti: un espositore vede un contatto solo se è suo, se c'è il consenso a condividerlo, se è utilizzabile per il marketing, se la fascia d'età è adulta e, dal 2026, se c'è un lead magnet. Aggiunge anche `auth_login_rate_limit`, che conta i tentativi di accesso falliti, e `audit_event`, il registro degli accessi ai dati personali.

Dalla `V016` alla `V023` arrivano le proiezioni per BAD, che non espongono tabelle riservate, l'archivio dei documenti commerciali dentro il database e l'isolamento dei contratti storici per espositore.

### La V024 e la V025: turni del personale e accesso con Google o Microsoft

La `V024` aggiunge i turni del personale, che servono alla schermata Operatività evento, e allinea due cose lasciate aperte dalle migrazioni precedenti: il pacchetto `NON_DICHIARATO`, che faceva fallire la firma di una pratica importata, e i permessi mancanti sui token della `V011`. La `V026` completa i permessi di lettura sull'edizione.

La `V025` permette di entrare in tre modi, con un solo account: email e password, Google oppure Microsoft. Del fornitore esterno si conserva l'identificativo stabile e non l'email, perché l'email di una persona cambia mentre quell'identificativo no.

```mermaid
erDiagram
    espositore ||--o{ account_espositore : accede
    espositore ||--o{ invito_espositore : invitato
    account_espositore ||--o{ recupero_password : "reimposta con"
    account_espositore ||--o{ identita_esterna : "riconosciuto da"
    fornitore_identita ||--o{ identita_esterna : rilascia
    membro_staff ||--o| membro_staff_riservato : "nome in"
    membro_staff ||--o{ assegnazione_turno : "assegnato a"
    turno ||--o{ assegnazione_turno : "coperto da"
    edizione ||--o{ turno : "nell'edizione"
    varco |o--o{ turno : "presidiato in"
    padiglione |o--o{ turno : "presidiato in"
    account_espositore {
        uuid id_account PK
        text email
        text password_hash
        boolean email_verificata
    }
    recupero_password {
        text token_hash PK
        uuid id_account FK
        timestamptz scade_il
        timestamptz usato_il
    }
    fornitore_identita {
        text codice PK
        text nome
        boolean attivo
    }
    identita_esterna {
        text fornitore PK
        text subject PK
        uuid id_account FK
        text email_fornitore
    }
    membro_staff {
        uuid id_membro PK
        text codice
        text ruolo
    }
    membro_staff_riservato {
        uuid id_membro PK
        text nome
        text email
    }
    turno {
        uuid id_turno PK
        smallint anno FK
        text varco FK
        text padiglione FK
        text mansione
        timestamptz inizio
        timestamptz fine
        smallint persone_previste
    }
    assegnazione_turno {
        uuid id_turno PK
        uuid id_membro PK
        boolean confermata
    }
    espositore { text id_espositore PK }
    invito_espositore { text token_hash PK }
    edizione { smallint anno PK }
    varco { text codice PK }
    padiglione { text codice PK }
```

| Regola | Dove è garantita |
| --- | --- |
| Lo stato della pratica va solo avanti: BOZZA, INVIATA, FIRMATA, ACCONTO_RICEVUTO | Trigger `pratica_controlla` |
| Dopo la bozza la pratica ha uno stand | Vincolo di controllo su `pratica` |
| Lo sconto sopra la soglia richiede approvazione | Trigger `pratica_controlla`, colonna `approvazione_richiesta` |
| Alla firma lo stand viene assegnato e il pacchetto registrato, nella stessa transazione | Trigger `pratica_alla_firma` |
| Il prezzo applicato resta quello dell'offerta anche se il listino cambia | `voce_pratica.prezzo_unitario_eur` |
| Un'edizione senza date non può essere dichiarata attiva o conclusa | Vincolo `edizione_date_complete_se_confermata` |
| Un turno sta a un varco oppure in un padiglione, mai in entrambi e mai in nessuno | Vincolo `turno_un_solo_luogo` |
| La stessa persona non può stare su due turni sovrapposti | Vincolo di esclusione su `assegnazione_turno` |
| Se il turno viene spostato, gli orari delle assegnazioni lo seguono | Chiave esterna con `ON UPDATE CASCADE` |
| La stessa identità Google o Microsoft non può valere per due account | Chiave primaria di `identita_esterna` |
| Ogni colonna del database ha una descrizione nel dizionario | Controllo in fondo a ogni migrazione |

## 5. Dati personali e visibilità

- **Dati personali separati.** Email e nome non stanno mai nelle tabelle usate per i calcoli: `contatto_riservato` e `registrazione_riservata` sono tabelle a parte. `registrazione_riservata` è leggibile solo dal ruolo `arcade_dati_personali`.
- **Lo staff e i suoi turni non si vedono dal lato espositore.** `membro_staff`, `turno` e `assegnazione_turno` sono leggibili solo dai ruoli interni, i nomi solo da `arcade_dati_personali`.
- **Lo staff e i suoi turni non si vedono dal lato espositore.** `membro_staff`, `turno` e `assegnazione_turno` sono leggibili solo dai ruoli interni, i nomi solo da `arcade_dati_personali`. Lo stesso vale per i token di accesso e per l'anagrafica in `espositore_riservato`.
- **Account e listino restano fuori dalla lettura.** `account_espositore` e `invito_espositore` sono leggibili solo dal ruolo `arcade_autenticazione`, `richiesta_riservata` solo da `arcade_dati_personali`. Il listino, le richieste e i KPI non sono visibili agli espositori. `scansione_stand.operatore_id` e `ticket_ref` non sono leggibili dall'espositore.
- **Un espositore vede solo il proprio.** Con la row-level security, l'espositore legge il proprio pacchetto, i sensori AI del proprio stand e i lead magnet di ARCADE Milano e i propri. Non vede mai le registrazioni dei visitatori, le pedane o le viste aggregate della direzione.
- **La stima dal peso è solo PREMIUM.** La policy su `rilevazione_peso` lascia passare le righe solo se l'espositore ha il pacchetto PREMIUM per quell'edizione. Un espositore BASE non le vede nemmeno interrogando il database direttamente.
- **Nessuna profilazione dei minori.** Il modulo di registrazione offre solo fasce d'età da 18 anni in su, e `profilabile` è vero solo con il consenso marketing e una fascia adulta dichiarata.

## 6. Punti da conoscere

- `accesso.codice_biglietto` non ha una chiave esterna verso `biglietto`, perché 70 codici letti ai tornelli non esistono in biglietteria.
- Pedane, sensori AI e rilevazioni di peso hanno la colonna `fonte`, con valore `SIMULATA` o `SENSORE`, perché nella demo i dati sono simulati.
- Le viste dei KPI (per esempio `v_presenze_padiglione`, `v_picco_presenza_giorno`, `v_mql_stand`) leggono queste tabelle e non memorizzano dati. Sono definite nelle migrazioni dalla `V003` alla `V026`.
- Il diagramma più vecchio in [dati storici](dati-storici.md) descrive solo lo schema per le edizioni 2024 e 2025. Per il quadro completo vale questo documento.
