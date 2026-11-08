<div align="center">

![Stand up presenta ARCADE Milano 2026](docs/assets/arcade-banner.svg)

Piattaforma integrata per coordinare espositori, vendite, operatività e risultati tra le edizioni dell’evento.

**Team Stand up** · ARCADE Milano · 2026

[Panoramica](#panoramica) · [Architettura](#architettura) · [Utenti](#ruoli-e-visibilita) · [KPI](#indicatori) · [Roadmap](#roadmap) · [Gruppo](#gruppo) · [Metodo GitHub](#metodo) · [Identità visiva](#identita-visiva) · [Blueprint digitale](docs/blueprint-digitale.md) · [Frontend](docs/frontend-portale.md) · [Schede schermate](docs/schermate/README.md) · [CI/CD](docs/ci-cd.md) · [Requisiti MVP](docs/requisiti-mvp.md) · [Modello ER](docs/modello-er.md)

</div>

---

<a id="panoramica"></a>
## Il progetto in breve

ARCADE Milano è un festival di tre giorni dedicato al gaming e alla cultura pop. La piattaforma aiuta il team a preparare l’edizione, gestire espositori e sponsor, seguire le attività durante l’evento e misurare i risultati dopo la chiusura.

È pensato per fare bene tre cose:

1. **Vendere lo stand**, dal preventivo al contratto, con acconti e previsioni sotto controllo.
2. **Seguire l’affluenza**, cioè quante persone entrano, quando e dove, in diretta se i tornelli lo consentono.
3. **Confrontare le edizioni**, con un riepilogo dei numeri, il confronto con gli anni scorsi e la proposta di rinnovo agli espositori.

Le tre cose usano gli stessi dati, così direzione, commerciale ed espositori vedono numeri coerenti.

| Prima dell’evento | Durante l’evento | Dopo l’evento |
| --- | --- | --- |
| Dati storici, offerte, stand e contratti | Accessi, presenze e scansioni agli stand | Risultati, confronto tra edizioni e rinnovi |

<a id="architettura"></a>
## Architettura della piattaforma

```mermaid
flowchart LR
    subgraph persone["PERSONE E RUOLI"]
        D["Direzione"]
        C["Commerciale"]
        S["Staff"]
        E["Espositore"]
        V["Visitatore"]
    end

    subgraph interfacce["INTERFACCE"]
        WEB["Portale web responsive<br/>React"]
        PA["Back office<br/>Power Apps"]
        SCAN["App scansione stand<br/>Power Apps o web mobile"]
        BI["Cruscotti<br/>Power BI"]
        DOC["Documenti<br/>SharePoint"]
    end

    subgraph servizi["SERVIZI CONDIVISI"]
        API["API REST<br/>Java · Spring Boot<br/>contratto OpenAPI"]
        FLOW["Automazioni e integrazioni<br/>Power Automate"]
        DB[("Modello operativo condiviso<br/>PostgreSQL")]
    end

    TICKET["Biglietteria esterna"]
    TURN["Tornelli e lettori"]
    SENS["Sensori di peso agli stand<br/>simulati nella demo"]
    PED["Pedane conta-persone nei padiglioni<br/>simulate nella demo"]
    AI["Sensori AI agli stand<br/>simulati nella demo"]
    HIST["Dati storici 2024 e 2025"]

    D --> BI
    C --> PA
    C --> WEB
    S --> WEB
    S --> SCAN
    E --> WEB
    V --> WEB
    WEB --> API
    PA --> API
    SCAN --> API
    API --> DB
    FLOW <--> API
    DB --> BI
    DOC -. "materiali e documenti" .-> WEB
    TICKET <--> API
    TURN --> API
    HIST --> API
    SENS --> API
    PED --> API
    AI --> API

    classDef people fill:#3f826d,color:#f7f7ff,stroke:#cbff8c,stroke-width:2px
    classDef ui fill:#171219,color:#f7f7ff,stroke:#3f826d,stroke-width:2px
    classDef platform fill:#c03221,color:#f7f7ff,stroke:#f7f7ff,stroke-width:2px
    classDef store fill:#cbff8c,color:#171219,stroke:#3f826d,stroke-width:2px
    class D,C,S,E,V people
    class WEB,PA,SCAN,BI,DOC ui
    class API,FLOW,TICKET,TURN,HIST,SENS,PED,AI platform
    class DB store
```

### Perché questa architettura

Il database PostgreSQL conserva i dati condivisi e mantiene relazioni coerenti tra edizioni, espositori, stand, contratti, biglietti, accessi e scansioni.

L’API Java con Spring Boot centralizza le regole applicative e i controlli di autorizzazione. React e Power Apps offrono interfacce adatte ai diversi processi, senza collegarsi direttamente alle tabelle.

**Database scelto: PostgreSQL, non MongoDB.** Espositori, stand, edizioni, pratiche, contratti, pagamenti, biglietti, accessi e contatti hanno relazioni e vincoli d’integrità che devono restare coerenti; servono inoltre policy per isolare i dati degli espositori. PostgreSQL offre chiavi esterne, vincoli unici e row-level security, e il repository contiene già migrazioni SQL per questi casi. MongoDB supporta relazioni e transazioni, ma il suo modello documentale flessibile non porta un vantaggio sufficiente a giustificare un secondo modello dati. Riferimenti: [vincoli PostgreSQL](https://www.postgresql.org/docs/current/ddl-constraints.html), [row-level security PostgreSQL](https://www.postgresql.org/docs/current/ddl-rowsecurity.html), [modellazione MongoDB](https://www.mongodb.com/docs/manual/data-modeling/).

SharePoint è adatto a documenti e collaborazione, mentre le transazioni e le relazioni principali restano in PostgreSQL. Power Automate gestisce preventivi, approvazioni, contratti, notifiche e rinnovi. Power BI presenta gli indicatori per ruolo e ambito.

<a id="flusso-operativo"></a>
## Flusso operativo

In ogni flusso la regola è la stessa: le schermate non parlano mai direttamente con il database. Passano dall’API, che verifica identità, ruolo e ambito, e Power BI legge solo viste autorizzate. Ecco tre esempi concreti.

### 1. Dal preventivo al contratto

Il processo che vende lo stand, ridotto a una sola pratica e a quattro passaggi: scelta, offerta, firma con acconto, chiusura automatica. Il back office è in Power Apps, i documenti stanno su SharePoint. L'approvazione scatta solo per le eccezioni, cioè per uno sconto oltre la soglia (proposta: 10%).

```mermaid
sequenceDiagram
    autonumber
    actor Com as Commerciale
    actor Esp as Espositore
    participant PA as Back office Power Apps
    participant API as API Spring Boot
    participant DB as PostgreSQL
    participant FLOW as Power Automate
    participant SP as SharePoint
    participant BI as Power BI

    Com->>PA: Sceglie espositore e stand, il prezzo arriva dal listino
    PA->>API: Crea la pratica in stato Bozza
    API->>DB: Salva la pratica
    Com->>PA: Genera l'offerta con un clic
    PA->>FLOW: Crea il documento dal modello Word
    opt Sconto oltre la soglia
        FLOW->>Com: Chiede l'approvazione, solo per le eccezioni
    end
    FLOW->>Esp: Invia l'offerta
    Esp-->>Com: Accetta e firma
    Com->>PA: Registra firma e acconto nella stessa schermata
    PA->>API: Pratica Firmata, acconto ricevuto
    API->>DB: Assegna lo stand e salva contratto e acconto
    FLOW->>SP: Archivia il contratto firmato
    FLOW->>Com: Avvisa che la pratica è chiusa
    DB-->>BI: Vendite, acconti e previsioni aggiornati
```

La pratica ha quattro stati: **Bozza, Inviata, Firmata, Acconto ricevuto**. Prelazione e rinnovo restano fuori dal flusso principale: il rinnovo è una proposta generata in automatico dal contratto dell'edizione precedente.

### 2. Ingresso del visitatore

Il flusso che conta le persone. Dipende da biglietteria e tornelli, quindi va confermato con i fornitori (decisioni aperte 1 e 2).

```mermaid
sequenceDiagram
    autonumber
    actor Vis as Visitatore
    participant TURN as Tornello e lettore
    participant API as API Spring Boot
    participant TICKET as Biglietteria esterna
    participant DB as PostgreSQL
    participant BI as Power BI

    Vis->>TURN: Mostra il QR del biglietto
    TURN->>API: Invia la lettura con varco e orario
    API->>TICKET: Verifica che il biglietto sia valido
    TICKET-->>API: Conferma validità e tipologia
    API->>DB: Registra l'accesso con esito e orario
    API-->>TURN: Esito del varco
    DB-->>BI: Affluenza, picchi e saturazione
```

### 3. Scansione allo stand

Il flusso che misura i contatti. I dati del visitatore compaiono solo se servono e sono autorizzati.

```mermaid
sequenceDiagram
    autonumber
    actor Staff
    participant SCAN as App scansione stand
    participant API as API Spring Boot
    participant DB as PostgreSQL
    participant BI as Power BI
    actor Esp as Espositore

    Staff->>SCAN: Scansiona il QR del visitatore
    SCAN->>API: Invia codice, stand e operatore
    API->>API: Verifica ruolo, stand e consenso
    API->>DB: Salva la scansione se valida e non duplicata
    DB-->>API: Conferma
    API-->>SCAN: Esito e conteggio, senza dati inutili
    DB-->>BI: Contatti raccolti per stand
    BI-->>Esp: Solo i contatti del proprio stand
```

<a id="stack"></a>
## Stack tecnologico

Avvia lo stack completo con `docker compose up --build`: PostgreSQL, API Spring Boot e frontend React partono insieme. Le credenziali predefinite sono condivise solo per lo sviluppo locale; un file `.env` facoltativo può sovrascriverle. Il container PostgreSQL carica `database/migrations/` solo quando inizializza un volume vuoto.

Per avviare solo il database e controllare che lo schema sia stato creato, con le credenziali predefinite:

```bash
docker compose up -d db
docker compose exec db psql -U arcade_admin -d arcade -c '\dt arcade.*'
```

Per ripartire da zero, cancellando i dati locali, si usa `docker compose down -v`.

| Servizio | Indirizzo dal browser/host | Indirizzo tra container |
| --- | --- | --- |
| Frontend Vite | `http://localhost:5173` | `frontend:5173` |
| API Spring Boot | `http://localhost:8080` | `backend:8080` |
| PostgreSQL | `localhost:5432` | `db:5432` |

Il frontend inoltra `/api` e `/actuator` a `backend:8080` tramite il proxy Vite. L'endpoint `GET /api/v1/health` è un controllo di avvio; `/actuator/health` mostra anche lo stato della connessione PostgreSQL in questo setup locale.

| Componente | Tecnologia | Responsabilità |
| --- | --- | --- |
| Database | PostgreSQL | Fonte condivisa per contratti, espositori, biglietti, accessi, scansioni e personale |
| Backend | Java e Spring Boot | API REST, regole di business, validazione e autorizzazioni |
| Descrizione API | OpenAPI e Swagger UI | Contratto leggibile e documentazione degli endpoint, consultabili e provabili |
| Interfaccia web | React e TypeScript | Portale responsive per espositori, visitatori e operatività evento |
| Routing frontend | TanStack Router | Navigazione tra schermate, route annidate e parametri tipizzati |
| Pacchetti e script frontend | Bun | Installazione delle dipendenze e avvio degli script |
| Server di sviluppo e build frontend | Vite | Server di sviluppo con aggiornamento rapido e generazione degli asset statici |
| App operative | Power Apps | Back office commerciale e, se la prova tecnica lo conferma, scansione allo stand |
| Automazioni | Power Automate | Generazione dell’offerta, approvazione delle sole eccezioni, archivio, notifiche e rinnovi |
| Documenti | SharePoint | File, planimetrie, contratti firmati e materiali |
| Analisi | Power BI | Indicatori direzionali e viste per ruolo |
| Identità | Microsoft Entra ID, da valutare | Accesso con account e gruppi, se disponibile per il contesto |

Le integrazioni con tornelli e scanner dipendono da hardware, protocolli, rete sul posto e API dei fornitori.

<a id="react-o-power-apps"></a>
## React o Power Apps: chi usa cosa

Power Apps e React non devono duplicare le stesse schermate. Per ogni flusso si sceglie il client più adatto, dopo una prova su autenticazione, uso da telefono o da computer, connettori e licenze.

| Flusso | Chi lo usa | Strumento | Perché |
| --- | --- | --- | --- |
| Area espositore | Espositore | React | Con il marchio, veloce, adatta al telefono |
| Biglietto e accesso | Visitatore | React | Semplice e leggibile da telefono |
| Operatività evento | Staff | React | Una sola navigazione, per ruolo |
| Back office commerciale | Commerciale | Power Apps | Si collega a Outlook e Word per i preventivi |
| Scansione allo stand | Staff | Da provare | Power Apps o web mobile, dopo la prova |
| Report direzionali | Direzione | Power BI | Indicatori e viste per ruolo |

**Regola.** Ciò che vede l’espositore o il visitatore va in React. Ciò che il commerciale usa dentro l’azienda per creare contratti va in Power Apps.

<a id="ruoli-e-visibilita"></a>
## Ruoli e visibilità

| Profilo | Che cosa deve poter fare | Limite di visibilità |
| --- | --- | --- |
| Direzione | Consultare KPI, vendite, affluenza e confronto tra edizioni | Dati aggregati, dettagli secondo incarico |
| Commerciale | Gestire contatti, offerte, contratti, acconti e rinnovi | Organizzazioni e pratiche assegnate |
| Staff | Consultare turno, area e stato operativo, registrare attività autorizzate | Dati necessari al servizio, senza accesso generalizzato ai dati commerciali |
| Espositore | Consultare la propria organizzazione, lo stand, il contratto e i servizi | Solo i propri dati e, se previsto, i lead del proprio stand |
| Visitatore | Consultare il proprio biglietto e le informazioni di accesso | Solo il proprio account e il proprio titolo d’ingresso |
| Amministratore | Configurare utenti, ruoli, edizioni e parametri | Accesso amministrativo tracciato e ristretto |

I controlli vengono applicati dall’API e anche nei dataset Power BI. Nascondere una schermata nell’interfaccia non è sufficiente per proteggere un dato: ogni richiesta deve essere verificata anche lato server. Per gli espositori serve un filtro per organizzazione che impedisca la consultazione dei dati dei concorrenti.

<a id="schermate"></a>
## Schermate da progettare

Il primo mockup usa un’unica navigazione, con pagine e azioni visibili in base al ruolo.

| Schermata | Utente principale | Contenuto |
| --- | --- | --- |
| Accesso | Tutti | Accesso, gestione sessione e messaggi di autorizzazione |
| Cruscotto direzionale | Direzione | Visitatori, picchi, saturazione, ricavi per m², costo per contatto e confronto edizioni |
| Operatività evento | Staff | Stato dei varchi, affluenza, avvisi, turni e riepilogo per area |
| Back office commerciale | Commerciale | Scheda pratica unica per offerta, contratto e acconto, più espositori, listino, planimetria e rinnovi |
| Area espositore | Espositore | Dati della propria azienda, stand, documenti, servizi e riepilogo autorizzato |
| Scansione allo stand | Staff o espositore autorizzato | Lettura QR, esito, orario e conteggio, con dati del visitatore solo se necessari e autorizzati |
| Biglietteria e accessi | Staff autorizzato | Verifica del biglietto, esito del varco, orario e gestione delle eccezioni |
| Mappa interattiva | Visitatori e staff | Ricerca di un espositore, percorso fino allo stand, aree affollate, e per la direzione la mappa di calore |
| Report | Direzione e ruoli autorizzati | Filtri per edizione, giornata, area e fonte, con le definizioni dei KPI |

<a id="modello-dati"></a>
## Modello dati iniziale

Le entità sono la base dello schema `arcade` di PostgreSQL. Il [modello ER](docs/modello-er.md) mostra tabelle, chiavi e relazioni come sono nelle migrazioni da `V001` a `V007`.

- **Edizione**: anno, date, sede e stato.
- **Organizzazione / Espositore**: anagrafica, referente e stato.
- **Stand**: codice, area, superficie, disponibilità e assegnazione per edizione.
- **Offerta / Contratto / Pagamento**: importi, stato, date, acconti e rinnovi.
- **Biglietto**: codice, tipologia, validità ed edizione, evitando dati personali non necessari.
- **Accesso**: varco, esito, orario e riferimento al biglietto.
- **Scansione stand / Lead**: stand, orario, operatore e identificativo consentito.
- **Persona staff / Turno / Badge**: ruolo, area, orario e stato del badge.
- **Rilevazione di peso / Parametri di stima**: stand, orario, peso lordo, tara e fonte, più peso medio, soglia di rumore e capienza per m².
- **Passaggio alle pedane**: padiglione, minuto, entrati, usciti e fonte, per le persone presenti in ogni padiglione.
- **Conteggio del sensore AI**: stand, minuto e nuove persone ferme, senza immagini.
- **Pacchetto dell'espositore**: BASE o PREMIUM per edizione, il PREMIUM sblocca la stima dal peso.
- **Lead magnet**: accesso beta, codice sconto, contenuto esclusivo, torneo, estrazione o demo privata, offerti da ARCADE Milano o da un espositore. Ogni contatto 2026 registra il lead magnet che lo ha generato.
- **Registrazione del visitatore**: provincia, fascia d'età adulta, interessi e due consensi separati, con nome ed email in una tabella riservata.
- **Fonte importata / Esito importazione**: origine, data, righe elaborate e anomalie.

<a id="indicatori"></a>
## Indicatori

Il team ha definito gli indicatori e il committente li ha approvati il 6 novembre 2026. Ogni indicatore dipende dalla disponibilità e dalla qualità dei dati, e dove un dato manca la scelta adottata è dichiarata nei report.

| KPI | Formula | Fonte | Note |
| --- | --- | --- | --- |
| Visitatori | Somma delle persone negli accessi con esito INGRESSO | `accesso` | Misura principale. Accanto: biglietti venduti (somma di `quantita`, un Family vale 4) e persone uniche (biglietti con almeno un ingresso) |
| Picco di presenza | Massimo, nella giornata, delle persone presenti in tutta la fiera nello stesso minuto | `v_picco_presenza_giorno` | Presenti = entrati meno usciti dalle pedane dall'inizio della giornata. Per il 2024 e il 2025 è stimato come ingressi delle ultime 4 ore (`v_presenze_stimate_ora`) |
| Saturazione spazi | Persone presenti nel padiglione ÷ capienza del padiglione × 100 | `v_presenze_padiglione` | Avviso allo staff oltre l'80% (`soglia_avviso`) |
| Visitatori per m² | Media delle persone presenti nel quarto d'ora ÷ superficie utile del padiglione | `v_densita_padiglione_15min` | Calcolato ogni 15 minuti |
| Presenze nello stand, dal peso | (peso lordo − tara) ÷ peso medio, al minuto | `v_presenze_stand_peso` | Solo per gli espositori PREMIUM. Peso medio 70 kg, variazioni sotto i 20 kg ignorate |
| Persone ferme allo stand | Somma delle nuove persone ferme contate dal sensore AI | `conteggio_sensore_stand` | Il sensore analizza la sagoma, non riconosce nessuno e non salva immagini. Uso reale solo dopo la DPIA |
| Resa dello stand | Contatti ÷ visite × 100, e contatti ÷ persone ferme × 100 | `v_stand_conversione` | L'espositore vede la propria e la media anonima della fiera |
| Ricavo per m² | Somma dei contratti firmati dell'area, al netto di IVA e sconti ÷ m² venduti dell'area | Contratti, `stand.superficie_mq` | Prezzi e superfici simulati finché il cliente non li fornisce |
| Contatti qualificati (MQL) | Contatti adulti, con consenso e interesse dichiarato, che hanno richiesto un lead magnet, una sola volta per persona e stand | `v_mql_stand` | È ciò che consegniamo agli espositori. Per il 2025, senza lead magnet, valgono i contatti utilizzabili |
| Quota MQL | MQL ÷ contatti raccolti × 100 | `v_mql_stand` | Misura la qualità dei contatti dello stand |
| Resa dei lead magnet | MQL generati da ogni lead magnet | `v_lead_magnet_resa` | Indica quali lead magnet funzionano meglio |
| Costo per MQL | Costi dell'edizione ÷ MQL | Parametro costi, `v_mql_stand` | Costi come parametro per edizione, simulati e dichiarati |

Oltre a questi, la prima proposta comprende espositori per edizione e stato del contratto, offerte per valore e stato, stand venduti e disponibilità residua, il confronto tra le edizioni 2024, 2025 e 2026 e un riepilogo per espositore con accesso limitato alla propria organizzazione.

Per ogni indicatore saranno documentati proprietario, definizione, fonte, formula, frequenza di aggiornamento, filtri e controlli di riconciliazione, così il numero non cambia significato tra direzione, commerciale ed espositori.

<a id="stima-peso"></a>
### Stima delle presenze dal peso

Per valutare l’affluenza in uno spazio circoscritto come lo stand si può usare il peso rilevato in quel momento. È un indicatore in più, riservato agli espositori con il pacchetto **PREMIUM**: il filtro è nel database, quindi un espositore BASE non lo vede nemmeno chiamando l'API. Le scelte sotto sono già fatte e sono tutte modificabili da parametro.

| Tema | Soluzione proposta | Perché |
| --- | --- | --- |
| Sensori | Letture **simulate** da un generatore di dati con un profilo di giornata realistico, e picchi a metà mattina e nel pomeriggio. Facoltativa una prova fisica con una cella di carico e una scheda ESP32 | La demo è ripetibile e non servono sensori in fiera. L'API accetta lo stesso messaggio da un sensore vero o simulato |
| Formula | Persone stimate = (peso lordo meno tara) diviso peso medio | Una riga di calcolo, spiegabile a chiunque |
| Peso medio | 70 kg a persona, parametro per edizione | Valore prudente, regolabile dopo una prova |
| Tara | Stand azzerato a vuoto all'apertura e dopo ogni cambio di allestimento | Elimina il peso di arredi ed espositori |
| Rumore | Media mobile su 30 secondi, variazioni sotto i 20 kg ignorate, valori oltre la capienza scartati | Evita picchi falsi, per esempio per una borsa appoggiata |
| Frequenza | Una lettura ogni 10 secondi, aggregata al minuto e a 5 minuti per il cruscotto | Abbastanza fluida da sembrare in diretta |
| Capienza | Superficie dello stand per 1 persona al m², parametro modificabile | Dà una saturazione semplice da leggere |
| Validazione | Confronto con le scansioni QR allo stand e con conteggi manuali di 10 minuti, obiettivo di scostamento medio entro il 15% | Dimostra quanto è affidabile la stima |
| Privacy | Nessun dato personale: il peso non identifica nessuno | Un vantaggio da dichiarare |
| Limiti | Bambini, borse e oggetti spostati falsano la stima. È una stima, non un conteggio, e gli ingressi totali restano ai tornelli | Meglio dichiararlo noi che farlo scoprire al cliente |

Per il 2024 e il 2025 non esistono misure di peso: il confronto tra edizioni su questo indicatore si fa su scenari simulati, e va dichiarato nei report.

<a id="sicurezza-e-uso-dei-dati"></a>
## Privacy e sicurezza

- Non inserire password, token, chiavi API o credenziali nel repository.
- Documentare fonti e trasformazioni dei dati importati.

### Privacy by design

La piattaforma nasce con la protezione dei dati nel progetto, come chiede il GDPR (articolo 25): raccoglie il minimo e mostra a ciascuno solo ciò che gli serve.

| Principio | Come si applica |
| --- | --- |
| Minimizzazione | Biglietto senza dati personali non necessari, verifica di codice fiscale, età e curriculum dello staff |
| Impostazioni sicure per default | Ogni profilo vede solo il proprio ambito, e nei report i dati dei visitatori sono aggregati |
| Dati anonimi dove basta | La scansione allo stand mostra un esito, la stima dal peso non identifica nessuno |
| Controllo sul server | Permessi nell'API e nei report Power BI, non solo pulsanti nascosti |
| Tutela dei minori | Aggregazione o pseudonimizzazione dei dati della biglietteria |
| Tracciabilità | Registro degli accessi ai dati sensibili e delle operazioni amministrative |
| Conservazione limitata | Tempi di cancellazione e gestione delle richieste, come da tabella |

**Tabella dei dati personali (proposta da validare con il responsabile privacy).**

| Dato | Finalità | Chi lo vede | Conservazione proposta |
| --- | --- | --- | --- |
| Email e nome dell'account | Accesso alla piattaforma | L'utente e l'amministratore | Finché l'account è attivo |
| Codice del biglietto | Verifica dell'ingresso | Staff autorizzato | Fino alla chiusura dell'edizione, poi solo dati aggregati |
| Accesso al varco | Affluenza e picchi | Direzione, in forma aggregata | Dati aggregati dopo la chiusura dell'edizione |
| Scansione allo stand (lead) | Contatti per l'espositore, con consenso | Solo l'espositore di quello stand | Fino alla consegna del riepilogo post-fiera |
| Staff: nome, ruolo e turno | Organizzazione del servizio | Responsabili dello staff | Fino alla chiusura dell'edizione |
| Codice fiscale, età, curriculum dello staff | Da verificare | Nessuno finché non è confermato che servano | Non raccolti per ora |
| Peso rilevato nello stand | Stima delle presenze | Staff, direzione ed espositori PREMIUM del proprio stand | Nessun dato personale |
| Conteggi di pedane e sensori AI | Presenze e persone ferme | Staff, direzione, espositore per il proprio stand | Nessun dato personale, nessuna immagine |
| Registrazione del visitatore: nome ed email | Invio del biglietto e, con consenso, offerte | Solo il responsabile dei dati | Fino alla revoca del consenso o alla fine dell'edizione |
| Fascia d'età, provincia e interessi | Profilazione, solo adulti con consenso | Direzione, solo come totali | Fino alla revoca del consenso |

<a id="decisioni-aperte"></a>
## Decisioni aperte

Servono le risposte prima di scrivere codice.

1. Chi è il fornitore della biglietteria e che cosa identifica ogni biglietto?
2. I tornelli inviano eventi in tempo reale? Espongono ingressi e uscite o solo scansioni?
3. Lo scanner identifica una persona, un biglietto o un consenso alla condivisione del contatto?
4. Quali utenti sono visitatori registrati e quali usano un biglietto senza account?
5. Power Apps è adatto all’uso mobile offline e alla scansione sul posto? Quali licenze e connettori sono disponibili?
6. Come si definiscono capienza, saturazione, ricavo per m² e costo per contatto?
7. Quali acconti e previsioni entrano nei report e quali sono esclusi?
8. Quali dati storici 2024 e 2025 sono disponibili?
9. Quanto vale il peso medio per persona e quanta gente ci sta in uno stand? Proposta: 70 kg e 1 persona per m², entrambi parametri modificabili.
10. Da quale sconto serve l'approvazione del responsabile? Proposta: oltre il 10%, tutto il resto procede senza approvazione.
11. Sensori di peso reali o simulati? Proposta: dati simulati, con una prova fisica facoltativa su una pedana.

<a id="roadmap"></a>
## Piano di consegna

Dal kickoff del 16 ottobre alla presentazione finale del 17 dicembre 2026, in cinque fasi.

```mermaid
gantt
    title Stand up · ARCADE Milano, piano di progetto 2026
    dateFormat YYYY-MM-DD
    axisFormat %d %b

    section Fase 0 · Avvio
    Kickoff e intervista requisiti        :done, a1, 2026-10-16, 1d
    Ruoli, Git e convenzioni              :done, a2, 2026-10-17, 2026-10-21
    Esplorazione dati e anomalie          :a3, 2026-10-19, 2026-10-27
    Definizione KPI                       :done, a4, 2026-10-19, 2026-10-29

    section Fase 1 · Analisi e progettazione
    Requisiti e perimetro MVP             :done, b0, 2026-10-25, 2026-11-06
    Processo commerciale                  :b1, 2026-10-19, 2026-10-28
    Schema dati su PostgreSQL             :crit, b2, 2026-10-21, 2026-10-29
    Contratto API OpenAPI                 :crit, b3, 2026-10-22, 2026-10-29
    Privacy by design e sicurezza         :b4, 2026-10-23, 2026-10-29
    Mockup back office e portale          :b5, 2026-10-23, 2026-10-29
    Preparazione SAL 1                    :done, b6, 2026-11-05, 2026-11-06
    SAL 1                                 :done, milestone, m1, 2026-11-06, 0d

    section Fase 2 · Fondamenta
    Database e edizione 2024              :crit, c1, 2026-11-09, 2026-11-13
    API base                              :c3, 2026-11-09, 2026-11-20
    Back office Power Apps                :c4, 2026-11-09, 2026-11-18
    Flusso commerciale semplificato       :crit, c5, 2026-11-10, 2026-11-20
    Edizione 2025 e anomalie              :crit, c2, 2026-11-16, 2026-11-20
    Dati commerciali nel modello          :c7, 2026-11-16, 2026-11-24
    Primo report Power BI                 :c6, 2026-11-18, 2026-11-27
    Prova integrata della demo            :c8, 2026-12-01, 2026-12-03
    SAL 2 demo con due edizioni           :milestone, m3, 2026-12-04, 0d

    section Fase 3 · Moduli in autonomia e integrazioni
    Tornelli e scanner in tempo reale     :d1, 2026-11-23, 2026-12-02
    Sicurezza RLS e dati dei minori       :d5, 2026-11-23, 2026-12-01
    Stima presenze dal peso simulata      :d9, 2026-11-25, 2026-12-02
    App di scansione allo stand           :d2, 2026-11-30, 2026-12-09
    Cruscotto staff                       :d3, 2026-12-01, 2026-12-10
    Report direzione                      :d4, 2026-12-01, 2026-12-10
    Portale espositori                    :d6, 2026-12-02, 2026-12-11
    Rinnovo dal contratto precedente      :d7, 2026-12-07, 2026-12-11
    Riconciliazione dei numeri            :crit, d8, 2026-12-09, 2026-12-14

    section Fase 4 · Chiusura e consegna
    Test end-to-end delle tre fasi        :e1, 2026-12-11, 2026-12-15
    README, API e repository              :e2, 2026-12-11, 2026-12-16
    Prove della demo dal vivo             :e3, 2026-12-14, 2026-12-16
    Presentazione finale e consegna       :milestone, m4, 2026-12-17, 0d
```

Ogni attività ha una issue nel [GitHub Project](https://github.com/orgs/stand-up-arcade-milan/projects/1), con data di inizio e di fine, fase come milestone e filone (BID, BAD, Comune, Gestione). La vista Roadmap del Project è la versione operativa di questo grafico.

### Percorso critico

- **Tabelle commerciali e caricamento degli storici** entro il 20 novembre: senza dati e senza pratiche la demo del SAL 2 non regge.
- **Flusso commerciale, dalla pratica al contratto,** entro il 20 novembre: è la fase "prima" da mostrare al SAL 2.
- **Tornelli, sicurezza RLS e stima dal peso** avviati prima del SAL 2: dopo il 4 dicembre restano solo nove giorni lavorativi.
- **Riconciliazione dei numeri** tra Power BI, cruscotto e portale entro il 14 dicembre, prima dei test finali.

<a id="gruppo"></a>
## Gruppo Stand up

Il team è organizzato nelle aree BID e BAD, più alcune responsabilità trasversali. La ripartizione descrive i filoni di lavoro, non assegna ancora i singoli membri: le attività verranno concordate e aggiornate nel GitHub Project. Una persona può coprire più ruoli, ma le responsabilità restano esplicite anche quando sono accorpate.

### Membri del gruppo

1. Girelle Beni Benj
2. Giuseppe Sparviero
3. Giosuè Tedeschi
4. Mihai Blendea
5. Luca Cerrone
6. Vinicius Dematos
7. Marguerite Deido El Mbimbey

### BID · Dati e codice

- **Data Architect / DBA PostgreSQL**: modello dati condiviso, relazioni, vincoli, migrazioni e decisioni documentate.
- **Data Engineer**: importazione dei dati 2024 e 2025 da biglietteria, tornelli e scanner, con profilazione della qualità e registro delle anomalie.
- **Backend Developer**: contratto REST, endpoint, validazione e controlli di accesso con Java e Spring Boot.
- **Frontend Developer**: portale web responsive e cruscotto operativo in React.

### BAD · Power Platform

- **Power Apps Developer**: back office per listino, planimetria, contratti, acconti e previsioni, più una prova dell’app di scansione allo stand.
- **Power Automate / Integration Developer**: flusso commerciale semplificato, dalla pratica al contratto, notifiche, rinnovi e passaggio dei dati commerciali nel modello condiviso.
- **Power BI / BI Analyst**: formule dei KPI concordate con il committente, report direzionali e coerenza tra le diverse viste.

### Responsabilità trasversali

- **Project Manager / Team Lead**: contatto con il committente, aggiornamento settimanale scritto, Gantt, rischi e decisioni.
- **Sicurezza e privacy**: privacy by design, controlli su API e Power BI, separazione dei dati degli espositori, protezione dei dati personali.
- **Git, documentazione e QA**: repository e README, contratto API, criteri di revisione, test tra i client e preparazione della demo.

<a id="milestone"></a>
## Milestone

| Data | Risultato atteso |
| --- | --- |
| 6 novembre 2026 · SAL 1 | Requisiti e KPI approvati dal cliente |
| 4 dicembre 2026 · SAL 2 | Edizioni 2024 e 2025 caricate, API base e un contratto 2026 dalla pratica alla firma |
| 17 dicembre 2026 · Presentazione finale | Demo dal vivo delle tre fasi, repository unico e documentazione |

Il team manda al cliente un aggiornamento scritto il 20 e il 27 novembre e l'11 dicembre.

<a id="metodo"></a>
## Metodo di lavoro su GitHub

- Le **issue** descrivono funzionalità, attività, difetti e decisioni da validare.
- Le **sub-issue** suddividono il lavoro in attività più piccole e assegnabili.
- Il **GitHub Project** mostra stato, gruppo responsabile, priorità e scadenze.
- Le **pull request** descrivono le modifiche e consentono la revisione prima dell’integrazione.
- Ogni membro usa il proprio account GitHub.

Branch di lavoro:

- `main` per la versione integrata.
- `feature/nome-funzione` per una funzionalità.
- `fix/nome-correzione` per una correzione.
- `docs/nome-documento` per la documentazione.

<a id="struttura-del-repository"></a>
## Struttura del repository

```text
.
├── backend/ # API Java e Spring Boot
├── database/ # Migrazioni PostgreSQL, da V001 a V007
├── docs/ # Blueprint, requisiti, modello ER, dati storici, API e identità visiva
├── frontend/ # Applicazione React con Vite, Bun e TanStack Router
├── scripts/ # Importazione dei dati storici e del Gantt
├── power-platform/ # Specifiche Power Apps, Power Automate e Power BI, da creare
├── compose.yaml # Database, API e frontend in locale con Docker
├── Dockerfile # Immagine del database con le migrazioni
└── README.md
```

<a id="documentazione"></a>
## Documentazione

- [Blueprint digitale](docs/blueprint-digitale.md): traduzione digitale della bozza cartacea, con architettura, processi, schermate, KPI, privacy e decisioni aperte. È la base di discussione con il gruppo e con il committente.
- [Requisiti e perimetro dell'MVP](docs/requisiti-mvp.md): utenti, ruoli, requisiti con criteri di accettazione, dati gestiti e confini dell'MVP.
- [Modello ER](docs/modello-er.md): diagramma completo dello schema `arcade`, con le novità del SAL 1, i dati personali separati e le regole di visibilità.
- [Requisiti del frontend](docs/frontend-portale.md): home, accesso per ruolo, area espositore, elenco con filtri, avvisi e dati da aggiungere, con le idee tratte da due portali fieristici.
- [Schede delle schermate](docs/schermate/README.md): contenuti, azioni, ruoli, stati e API previsti per ciascuna schermata React, Power Apps e Power BI.
- [CI/CD GitHub Actions](docs/ci-cd.md): controlli automatici su push/PR, smoke check Docker Compose e pubblicazione versionata delle immagini su GHCR.
- [Stato progetto e handoff](docs/stato-progetto.md): stato aggiornato, decisioni condivise, servizi locali, procedure di verifica e prossimi passi.
- [Collection Postman BID-BAD](postman/standup-platform-bid-bad.postman_collection.json): test degli export BID, dell'autorizzazione e dell'invio idempotente dei KPI.
- [Dati storici](docs/dati-storici.md): i dati delle edizioni 2024 e 2025, che cosa permettono di calcolare, le anomalie e l'importazione con `scripts/dati/importa_storici.py`.
- [Governance dei dati](docs/governance-dati.md): mappa delle fonti, pulizia, classificazione e sicurezza, con il [dizionario dati](docs/dizionario-dati.md) e il [report di qualità](docs/report-qualita-dati.md).
- [Migrazioni del database](database/migrations): schema PostgreSQL, viste dei KPI, ruoli, filtro per espositore, area commerciale e KPI BAD (V007–V009); storico commerciale, planimetria, idempotenza e recupero password (V010–V011); consenso alla scansione, metadati documentali senza archivio configurato e `search_path` stabile per i trigger (V012–V014).
- [Contratto API OpenAPI](docs/openapi.yaml): richieste, risposte, schemi, sicurezza e scambio dati tra BID e BAD; bozza da allineare con entrambi i gruppi.
- [Brief del laboratorio](docs/fonti/Progetto_Laboratorio_Integrato_BAD-BID_compilato.docx) e [Gantt](docs/fonti/Gantt-Stand-UP.pdf): consegna, responsabilità e milestone del progetto.

<a id="identita-visiva"></a>
## Identità visiva

La palette ufficiale di Stand up combina un fondo scuro con accenti luminosi e un colore secondario ispirato al palco e alla cultura arcade.

Codici ed esportazioni: [palette colori](docs/palette-colori.md).

| Colore | Codice | Uso nel progetto |
| --- | --- | --- |
| Coffee Bean | #171219 | Fondo principale e testi su superfici chiare |
| Lime Cream | #cbff8c | Accenti, evidenze e stati attivi |
| Brick Ember | #c03221 | Azioni, dettagli di richiamo e contrasto |
| Ghost White | #f7f7ff | Testi su fondi scuri e superfici chiare |
| Jungle Teal | #3f826d | Elementi secondari, collegamenti e area dati |

<a id="stato-del-progetto"></a>
## Stato del progetto

SAL 1 risulta chiuso. I dati storici sono stati importati e riconciliati nel database Docker locale; le fonti cliente e il volume non sono inclusi in Git. Il backend contiene handler per le 54 operazioni dichiarate in OpenAPI e la UI React implementa le schermate 4, 5 e 6 (`/commerciale`, `/espositore`, `/scansione`). Le build e i controlli HTTP/headless registrati sono documentati in [stato progetto](docs/stato-progetto.md).

La consegna complessiva non è ancora chiusa: l’issue #10 mantiene aperta la revisione BID–BAD del contratto, le schermate 7–9 sono solo specifiche, le schermate 1–3 sono assegnate a un altro membro e restano le soluzioni Power Apps, Power Automate e Power BI del gruppo BAD. GitHub mostra 13 issue chiuse e 25 aperte al 08/11/2026. La CI esegue 10 test automatici Java, ma non una suite E2E delle tre fasi.
