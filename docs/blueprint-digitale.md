
# ARCADE Milano · Trasposizione digitale della bozza cartacea

> Descrive il perimetro proposto: architettura, processi, KPI e soprattutto responsabilità vanno confermati con il gruppo (o con il committente prima dello sviluppo).

## A cosa serve

Questo documento traduce gli appunti cartacei e le note operative in una base comune per progettare interfacce, dati, API e report. La proposta mantiene distinti:

- **BID · Dati e codice**: modello dati, caricamento e qualità, API e interfacce web.
- **BAD · Power Platform**: back office, automazioni e app operative, con collaborazione sulla Business Intelligence.
- **Responsabilità trasversali**: coordinamento, sicurezza, documentazione e qualità.

La ripartizione descrive i filoni, non assegna ancora i singoli membri.

## 1. Quadro della soluzione

~~~mermaid
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
    HIST["Dati storici 2024–2025"]

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

    classDef people fill:#3f826d,color:#f7f7ff,stroke:#cbff8c,stroke-width:2px
    classDef ui fill:#171219,color:#f7f7ff,stroke:#3f826d,stroke-width:2px
    classDef platform fill:#c03221,color:#f7f7ff,stroke:#f7f7ff,stroke-width:2px
    classDef store fill:#cbff8c,color:#171219,stroke:#3f826d,stroke-width:2px
    class D,C,S,E,V people
    class WEB,PA,SCAN,BI,DOC ui
    class API,FLOW,TICKET,TURN,HIST,SENS platform
    class DB store
~~~

**Come leggere il diagramma:** le persone usano l’interfaccia adatta al proprio compito; i client passano dall’API, che applica le autorizzazioni e legge o aggiorna il modello condiviso. I sistemi esterni e i dati storici entrano attraverso integrazioni controllate. Power BI consuma viste autorizzate. SharePoint è il punto per documenti e materiali.

## 2. Scelta architetturale da validare

La proposta coerente con il repository è:

| Livello | Tecnologia proposta | Responsabilità |
| --- | --- | --- |
| Portale web | React | Cruscotto operativo, consultazione e portale espositore |
| App operative | Power Apps | Back office commerciale e scansione allo stand, se la prova tecnica ne conferma l’idoneità |
| API | Java, Spring Boot, REST | Regole, validazione, integrazione e autorizzazioni |
| Descrizione API | OpenAPI e Swagger UI | Contratto leggibile e documentazione degli endpoint |
| Dati operativi | PostgreSQL | Fonte condivisa per contratti, espositori, ticket, accessi, scansioni e personale |
| Automazioni | Power Automate | Preventivo, approvazione, contratto, notifiche e rinnovi |
| Documenti | SharePoint | File, planimetrie, contratti firmati e materiali |
| Report | Power BI | Indicatori direzionali e viste per ruolo |
| Identità | Microsoft Entra ID da valutare | Accesso con account e gruppi, se disponibile per il contesto |

### Precisazioni importanti

- **Swagger**: OpenAPI descrive le richieste e le risposte; Swagger UI permette di consultare e provare il contratto.
- **SharePoint**: è adatto a documenti e collaborazione. Le transazioni e le relazioni principali restano nel modello PostgreSQL proposto.
- **Power Apps e React non devono duplicare le stesse schermate**: dobbiamo scegliere per ogni flusso il client più adatto dopo una prova su autenticazione, uso mobile o desktop, connettori e licenze.
- Le integrazioni con tornelli e scanner dipendono da hardware, protocolli, rete sul posto e API del fornitore.

## 3. Filoni e responsabilità

### BID · Dati e codice

| Ruolo | Risultato atteso |
| --- | --- |
| Data Architect / DBA PostgreSQL | Modello dati condiviso, relazioni, vincoli e decisioni documentate. Proposta di congelamento per il SAL 1 del 30 ottobre, da confermare. |
| Data Engineer | Importa dati 2024 e 2025 da biglietteria, tornelli e scanner; profila la qualità, registra anomalie. |
| Backend Developer · Java/Spring Boot | Definisce e implementa il contratto REST, gli endpoint, la validazione e i controlli di accesso. Il contratto API è una dipendenza del frontend e delle app. |
| Frontend Developer · React (e i suoi framework) | Realizza il portale web responsive e il cruscotto operativo, inclusa la consultazione dell’affluenza quando la fonte dati lo consente. |

### BAD · Power Platform

| Ruolo | Risultato atteso |
| --- | --- |
| Power Apps Developer | Progetta il back office per listino, planimetria, contratti, acconti e previsioni; realizza una prova dell’app di scansione allo stand. |
| Power Automate / Integration Developer | Modella il flusso commerciale semplificato in quattro passaggi (scelta, offerta, firma con acconto, chiusura automatica), con approvazione solo per gli sconti oltre soglia; notifiche e rinnovi; passaggio dei dati commerciali nel modello condiviso. |
| Power BI / BI Analyst | Definisce con il committente le formule dei KPI, prepara i report direzionali e verifica che le diverse viste restituiscano numeri abbastanza coerenti. |

### Responsabilità trasversali

- **Project Manager / Team Lead**: interlocuzione con il committente, aggiornamento settimanale scritto, gestione del Gantt, rischi e decisioni.
- **Sicurezza e privacy**: controlli API e Power BI, segregazione dei dati degli espositori, minimizzazione e protezione dei dati personali, con attenzione ai minori.
- **Git, documentazione e QA**: repository e README, contratto API, criteri di revisione, test end-to-end fra i client e preparazione della demo.

Una persona può coprire più ruoli; le responsabilità restano esplicite anche quando sono accorpate.

## 4. Utenti, permessi e dati visibili

| Profilo | Cosa deve poter fare | Limite di visibilità |
| --- | --- | --- |
| Direzione | Consultare KPI, vendite, affluenza e confronto tra edizioni | Dati aggregati; accesso ai dettagli secondo incarico |
| Commerciale | Gestire contatti, offerte, contratti, acconti e rinnovi | Organizzazioni e pratiche assegnate |
| Staff | Consultare turno, area/stand e stato operativo; registrare attività autorizzate | Dati necessari al servizio, senza accesso generalizzato a dati commerciali |
| Espositore | Consultare la propria organizzazione, stand, contratto e servizi | Solo i propri dati e, se previsto, i lead raccolti dal proprio stand |
| Visitatore | Consultare il proprio biglietto e le informazioni di accesso | Solo i dati del proprio account e titolo d’ingresso |
| Amministratore | Configurare utenti, ruoli, edizioni e parametri | Accesso amministrativo tracciato e ristretto |

I permessi vanno applicati **sul server/API** e anche nei dataset Power BI, non solo nascondendo pulsanti o pagine. Per gli espositori serve un filtro per organizzazione che impedisca la consultazione dei dati dei concorrenti.

## 5. Moduli funzionali e schermate da progettare

Il primo mockup frontend dovrebbe usare un’unica navigazione coerente, con pagine e azioni visibili in base al ruolo.

| Schermata | Utente principale | Contenuto del mockup |
| --- | --- | --- |
| Accesso | Tutti | Accesso, recupero o gestione sessione e messaggi di autorizzazione |
| Cruscotto direzionale | Direzione | Visitatori, picchi, saturazione, ricavi per m², costo per contatto e confronto edizioni |
| Operatività evento | Staff | Stato dei varchi, affluenza, avvisi, turni e riepilogo per area |
| Back office commerciale | Commerciale | Espositori, listino, planimetria, offerte, contratti, acconti e rinnovi |
| Area espositore | Espositore | Dati della propria azienda, stand, documenti, servizi e riepilogo autorizzato |
| Scansione allo stand | Staff o espositore autorizzato | Lettura QR, esito, timestamp e conteggio; i dati del visitatore sono mostrati solo se necessari e autorizzati |
| Biglietteria e accessi | Staff autorizzato | Ricerca o verifica ticket, esito del varco, timestamp e gestione delle eccezioni |
| Report | Direzione e ruoli autorizzati | Filtri per edizione, giornata, area e fonte, con definizioni dei KPI accessibili |

### Wireframe iniziale del cruscotto direzionale

~~~text
┌────────────────────────────────────────────────────────────────────┐
│ ARCADE Milano 2026     Edizione ▾     Aggiornato alle 10:42   Utente│
├──────────────┬─────────────────────────────────────────────────────┤
│ Panoramica   │ Visitatori       Picco giornaliero   Saturazione    │
│ Vendite      │ [ 12.480 ]       [ 3.210 ]           [ 78% ]        │
│ Accessi      ├─────────────────────────────────────────────────────┤
│ Espositori   │ Andamento accessi per fascia oraria                 │
│ Staff        │ [ grafico per giorno e fascia ]                     │
│ Report       ├───────────────────────────┬─────────────────────────┤
│ Impostazioni │ Ricavo per m²             │ Costo per contatto      │
│              │ [ valore + confronto ]    │ [ valore + confronto ] │
│              ├───────────────────────────┴─────────────────────────┤
│              │ Avvisi da verificare · fonti · ultima sincronizzazione│
└──────────────┴─────────────────────────────────────────────────────┘
~~~

Il wireframe usa valori segnaposto solo per mostrare la gerarchia visiva: non sono dati reali né KPI già validati.

## 6. Modello dati iniziale

Le entità seguenti sono una base per la discussione con BID e BAD. Le relazioni e i campi vanno definiti nel modello ER prima di implementare.

- **Edizione**: anno, date, sede e stato.
- **Organizzazione / Espositore**: anagrafica, referente e stato.
- **Stand**: codice, area, superficie, disponibilità e assegnazione per edizione.
- **Offerta / Contratto / Pagamento**: importi, stato, date, acconti e rinnovi.
- **Biglietto**: codice, tipologia, validità ed edizione, evitando dati personali non necessari.
- **Accesso**: varco, esito, timestamp e riferimento al biglietto.
- **Scansione stand / Lead**: stand, timestamp, operatore e identificativo consentito.
- **Persona staff / Turno / Badge**: ruolo, area, orario e stato del badge.
- **Rilevazione di peso / Parametri di stima**: stand, orario, peso lordo, tara e fonte, più peso medio, soglia di rumore e capienza per m².
- **Fonte importata / Esito importazione**: origine, data, righe elaborate ed anomalie.

Per ogni campo personale o economico documentare finalità, proprietario, profilo autorizzato, retention e regole di correzione.

## 7. KPI da definire con formula e fonte

| KPI candidato | Definizione da concordare | Dati necessari |
| --- | --- | --- |
| Visitatori | Biglietti venduti, ingressi effettivi o persone uniche: non sono la stessa misura | Biglietteria e letture varchi |
| Picco di presenza | Massimo di persone presenti nello stesso intervallo, calcolato da ingressi e uscite affidabili | Timestamp e direzione dei passaggi |
| Saturazione spazi | Metrica di occupazione: definire denominatore, area e soglia | Planimetria, superficie e presenze |
| Presenze nello stand (stima dal peso) | Persone stimate dal peso netto diviso il peso medio, con margine d’errore dichiarato | Sensori di peso, tara e parametri di stima |
| Visitatori per m² | Persone nell’area divise per superficie utile e intervallo | Presenze per area e m² |
| Ricavo per m² | Ricavo attribuito all’area diviso per superficie; chiarire lordo/netto e periodo | Contratti, incassi e planimetria |
| Contatti / lead | Scansioni valide e non duplicate, secondo consenso e regole concordate | Scanner, stand, timestamp |
| Costo per contatto | Costi inclusi divisi per lead validi; definire costi e deduplicazione | Costi, campagne e lead |

Ogni KPI deve avere proprietario, formula, fonte, frequenza, filtri e controlli di riconciliazione. I report devono spiegare definizioni e aggiornamento, così i numeri non cambiano significato tra direzione, commerciale ed espositori.

### Stima delle presenze dal peso

Per valutare l’affluenza in uno spazio circoscritto come lo stand si può usare il peso rilevato in quel momento. Scelte già fatte e modificabili da parametro:

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

## 8. Privacy e sicurezza da includere nel progetto

Gli appunti citano codice fiscale, età e curriculum per lo staff. Prima del mockup va verificato se questi dati siano davvero indispensabili al processo. In particolare:

- raccogliere solo i campi necessari e definire chi li può vedere;
- stabilire tempi di conservazione, cancellazione e gestione delle richieste;
- proteggere maggiormente i dati di eventuali minorenni e limitare l’accesso per ruolo;
- non mostrare dati personali dei visitatori durante la scansione se basta un esito o un conteggio;
- registrare gli accessi ai dati sensibili e le operazioni amministrative;
- documentare fonti e trasformazioni dei dati importati.

Questi punti sono requisiti da validare con il responsabile privacy.

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
| Peso rilevato nello stand | Stima delle presenze | Staff e direzione | Nessun dato personale |

## 9. Decisioni aperte prima del codice

1. Qual è il fornitore della biglietteria e che cosa identifica?
2. I tornelli inviano eventi in tempo reale? Espongono ingressi e uscite o solo scansioni?
3. Lo scanner identifica una persona, un ticket e/o un consenso alla condivisione del contatto?
4. Quali utenti sono visitatori registrati e quali usano un biglietto senza account?
5. Power Apps è adatto all’uso mobile offline e alla scansione richiesta sul posto? Che licenze/connettori sono disponibili?
6. Come si definiscono capienza, saturazione, ricavo per m² e costo per contatto?
7. Quali acconti e previsioni devono entrare nei report e quali sono esclusi?
8. Quali dati storici 2024/2025 sono disponibili?
9. Quanto vale il peso medio per persona e quanta gente ci sta in uno stand? Proposta: 70 kg e 1 persona per m², entrambi parametri modificabili.
10. Da quale sconto serve l'approvazione del responsabile? Proposta: oltre il 10%, tutto il resto procede senza approvazione.
11. Sensori di peso reali o simulati? Proposta: dati simulati, con una prova fisica facoltativa su una pedana.

## 10. Sequenza di lavoro

1. **Confermare processi e utenti** con cliente e gruppo.
2. **Definire glossario, dati e permessi**, compresi i KPI e le regole privacy.
3. **Congelare il modello dati e il contratto API** per il SAL 1, se le dipendenze sono disponibili.
4. **Disegnare i mockup** delle schermate per ruolo usando la palette ufficiale del brand.
5. **Provare le integrazioni** con dataset anonimizzati o dimostrativi e un singolo flusso end-to-end.
6. **Realizzare un vertical slice**: un espositore, uno stand, un contratto, un biglietto e un accesso tracciato fino al report.
7. **Ampliare i moduli**, validare qualità e permessi, poi preparare demo e documentazione.

## Riferimenti del repository

- [README e visione generale](../README.md)
- [Palette ufficiale e banner](assets/arcade-banner.svg)