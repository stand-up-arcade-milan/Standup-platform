# Requisiti e perimetro dell'MVP

Documento di lavoro del team **Stand up** per ARCADE Milano 2026. Chiude l'issue #1: fissa utenti, ruoli, flussi, dati e criteri di accettazione dell'MVP. Dove serviva una scelta, la scelta è già fatta e si cambia con un parametro.

Torna al [README](../README.md) · [Blueprint digitale](blueprint-digitale.md) · [Dati storici](dati-storici.md) · [Portale web](frontend-portale.md) · [Contratto API](openapi.yaml)

## 1. Obiettivo dell'MVP

Una piattaforma che, con un solo modello dati, permette di:

1. **vendere lo stand**, dalla pratica al contratto con acconto;
2. **seguire l'affluenza** in fiera, per ora, varco, padiglione e stand;
3. **confrontare le edizioni** 2024, 2025 e 2026 con KPI spiegabili.

Criterio del cliente: il prodotto deve funzionare, essere implementato bene e il team deve saperlo spiegare. Ogni requisito qui sotto ha quindi un criterio di accettazione verificabile durante la demo.

## 2. Scadenze

| Data | Momento | Che cosa si mostra |
| --- | --- | --- |
| 6/11/2026 | SAL 1 | Requisiti, schema dati, contratto API, mockup, KPI approvati |
| 4/12/2026 | SAL 2 | Due edizioni nel database, API base, flusso commerciale, primo report |
| 17/12/2026 | Presentazione finale | Le tre fasi della fiera dall'inizio alla fine, con i permessi per ruolo |

## 3. Utenti e ruoli

| Ruolo | Accesso | Che cosa fa nell'MVP | Che cosa vede |
| --- | --- | --- | --- |
| Direzione | Account aziendale | Consulta KPI e confronto edizioni | Dati aggregati di tutte le edizioni |
| Commerciale | Account aziendale | Gestisce pratiche, offerte, contratti e acconti | Le pratiche assegnate |
| Staff | Account aziendale | Consulta affluenza e avvisi, registra scansioni allo stand | Dati operativi, nessun dato commerciale |
| Espositore | Email e password, su invito dopo la firma | Consulta stand, contratto, contatti e riepilogo post-fiera | Solo la propria organizzazione |
| Visitatore | Nessun account | Consulta il portale e l'elenco espositori | Solo informazioni pubbliche |
| Amministratore | Account aziendale | Gestisce utenti, ruoli, edizioni e parametri | Tutto, con ogni operazione registrata |

Per la demo l'account aziendale è simulato con utenti di prova per ruolo, se Entra ID non è disponibile.

## 4. Requisiti funzionali

Priorità: **M** indispensabile per l'MVP, **S** se il tempo lo consente.

### 4.1 Dati e storico

| ID | Requisito | P | Criterio di accettazione | Issue |
| --- | --- | --- | --- | --- |
| RF-01 | Normalizzare e caricare le edizioni 2024 e 2025 dalle fonti originali | M | Una pipeline locale ripetibile importa i dati validi; un report confronta righe sorgente, importate e scartate per file, tabella ed edizione | #15, #16 |
| RF-02 | Pulire i dati storici in modo motivato e tracciabile | M | Si correggono solo formati o valori ricavabili senza ambiguità; i dati mancanti restano mancanti e i record non affidabili sono scartati con motivazione. Anomalie e scarti sono conteggiati per file, tabella ed edizione, senza esporre dati personali nel repository | #16 |
| RF-03 | Ripetere il caricamento senza duplicati | M | Un secondo caricamento dello stesso file non aggiunge righe | #15 |
| RF-04 | Gestire l'edizione 2026 come edizione attiva | M | Date, sede e stato arrivano dalla tabella Edizione, mai scritti nelle pagine | #17 |
| RF-05 | Simulatori di pedane, sensori AI e peso che inviano lo stesso messaggio di un dispositivo vero | M | Lo stesso script genera una giornata di fiera ripetibile, ogni riga dichiara la fonte SIMULATA | #25, #28 |

### 4.2 Commerciale, prima della fiera

| ID | Requisito | P | Criterio di accettazione | Issue |
| --- | --- | --- | --- | --- |
| RF-10 | Listino e planimetria con stand liberi e venduti | M | Il commerciale vede per ogni stand codice, padiglione, m², prezzo e stato | #18 |
| RF-11 | Pratica unica con quattro stati: Bozza, Inviata, Firmata, Acconto ricevuto | M | Una pratica passa da Bozza ad Acconto ricevuto senza uscire dalla scheda | #19 |
| RF-12 | Prezzo dal listino e approvazione solo per sconti oltre il 10% | M | Uno sconto del 15% chiede l'approvazione, uno del 5% no | #19 |
| RF-13 | Offerta generata da modello Word e contratto firmato archiviato su SharePoint | M | Il documento compare nella cartella della pratica | #19 |
| RF-14 | Stand assegnato alla firma, mai a due espositori nella stessa edizione | M | Il database rifiuta una seconda assegnazione dello stesso stand | #20 |
| RF-15 | Richiesta stand dalla home del portale, che crea una pratica in Bozza | S | La richiesta compare nel back office del commerciale | #32 |
| RF-16 | Proposta di rinnovo generata dal contratto dell'edizione precedente | S | Per un espositore 2025 si crea una pratica 2026 con stand e servizi precompilati | #33 |
| RF-17 | Pacchetto dell'espositore, BASE o PREMIUM, scelto nella pratica | M | Il PREMIUM sblocca la stima delle presenze dal peso nell'area espositore, il BASE no | #19 |

### 4.3 Operatività, durante la fiera

| ID | Requisito | P | Criterio di accettazione | Issue |
| --- | --- | --- | --- | --- |
| RF-20 | Registrare gli accessi ai varchi con esito e orario | M | Una lettura simulata compare nel cruscotto staff entro un minuto | #25 |
| RF-21 | Rifiutare biglietti non validi, già usati o fuori giorno | M | I tre casi restituiscono un esito di rifiuto con il motivo | #25 |
| RF-22 | Scansione allo stand con esito e conteggio, senza dati del visitatore | M | Una seconda scansione dello stesso codice nello stesso stand non conta due volte | #26 |
| RF-23 | Cruscotto staff con affluenza per ora, varco e padiglione | M | I numeri coincidono con le viste del database | #27 |
| RF-24 | Stima delle presenze nello stand dal peso, con dati simulati, solo per gli espositori PREMIUM | M | La stima resta entro il 15% dai conteggi di prova, il margine è dichiarato a schermo, un espositore BASE non la vede né dall'interfaccia né dal database | #28 |
| RF-26 | Persone presenti in ogni padiglione dalle pedane conta-persone, minuto per minuto | M | Presenti = entrati meno usciti dall'inizio della giornata, ogni pedana invia una riga al minuto anche quando il conteggio è zero | #25, #27 |
| RF-27 | Avviso allo staff quando un padiglione supera l'80% della capienza | M | Con il padiglione all'83% compare l'avviso nel cruscotto staff, la soglia è un parametro | #27 |
| RF-28 | Sensori AI agli stand che contano le persone ferme analizzando la sagoma, senza riconoscere nessuno | S | Il dispositivo elabora l'immagine e la cancella subito: nel database arriva solo un numero al minuto per stand, nessuna immagine né identificativo | #26 |
| RF-29 | Mappa interattiva: ricerca di un espositore, percorso fino allo stand, aree affollate | S | Cercando un espositore si vede il suo stand evidenziato e il varco più vicino, i colori della mappa seguono le visite reali | #32 |
| RF-25 | Avvisi di servizio per pubblico: visitatori, espositori, staff | S | Un avviso per lo staff non compare agli espositori | #27 |

### 4.4 Risultati, dopo la fiera

| ID | Requisito | P | Criterio di accettazione | Issue |
| --- | --- | --- | --- | --- |
| RF-30 | Report direzione con i KPI approvati e il confronto tra edizioni | M | Ogni KPI mostra definizione, fonte e data di aggiornamento | #22, #29 |
| RF-31 | Area espositore con stand, contratto, contatti e riepilogo post-fiera | M | L'espositore A non vede nessun dato dell'espositore B, né dall'interfaccia né chiamando l'API | #32 |
| RF-32 | Stessi numeri in tutte le viste | M | Il totale ingressi coincide tra database, API, Power BI e portale | #34 |
| RF-33 | Elenco espositori pubblico con ricerca e filtri per categoria | S | I conteggi accanto ai filtri coincidono con i risultati | #32 |
| RF-34 | Mappa di calore per la direzione, con le visite per stand e le persone per padiglione | S | I colori della mappa coincidono con i totali del report | #29 |
| RF-35 | Resa dello stand: contatti ogni 100 visite e contatti su persone ferme | M | Nell'area espositore compaiono i due rapporti e la media anonima della fiera | #32 |
| RF-36 | Contatti consegnati agli espositori come MQL | M | Un contatto è MQL solo se è adulto, ha dato il consenso, ha un interesse dichiarato e ha richiesto un lead magnet. Gli altri restano esclusi dal file consegnato | #32 |
| RF-37 | Lead magnet di ARCADE Milano e degli espositori: accesso beta, codice sconto, contenuto esclusivo, torneo, estrazione, demo privata | M | Allo stand e nel portale il visitatore sceglie un lead magnet, il contatto registra quale lo ha generato, l'espositore vede solo i propri | #26, #32 |
| RF-38 | Resa dei lead magnet | S | Per ogni lead magnet il report mostra quanti MQL ha portato | #29 |

### 4.5 Profilazione commerciale, facoltativa

| ID | Requisito | P | Criterio di accettazione | Issue |
| --- | --- | --- | --- | --- |
| RF-40 | Modulo del visitatore: nome, email, provincia, fascia d'età, interessi, due consensi separati | S | Il biglietto si ottiene anche senza consensi, nessuna casella è già spuntata | #32 |
| RF-41 | Nessuna profilazione dei minori | M | Chi non dichiara una fascia d'età adulta non entra mai nei profili, anche con il consenso | #30 |
| RF-42 | Consensi revocabili in un clic | S | Dopo la revoca la persona esce dai profili e dai contatti degli espositori | #30 |
| RF-43 | Interesse del pubblico per categoria, solo come totale | S | Il report mostra conteggi per interesse, mai le singole persone | #29 |

## 5. Requisiti non funzionali

| ID | Requisito | Criterio di accettazione |
| --- | --- | --- |
| RNF-01 | Permessi applicati sul server | Ogni endpoint rifiuta un ruolo non autorizzato con 403, anche se il pulsante è nascosto |
| RNF-02 | Isolamento degli espositori nel database | Le policy RLS restituiscono zero righe di altri espositori |
| RNF-03 | Minimizzazione dei dati personali | Le email stanno solo nella tabella riservata, i minori non sono mai utilizzabili per il marketing |
| RNF-04 | Tracciabilità | Accessi ai dati personali e operazioni amministrative finiscono in un registro |
| RNF-05 | Contratto API documentato | Ogni endpoint è descritto in OpenAPI e provabile da Swagger UI |
| RNF-06 | Portale utilizzabile da telefono | Nessuno scorrimento orizzontale a 360 px, contrasto dei testi almeno 4,5 a 1 |
| RNF-07 | Nessun segreto nel repository | Password, token e chiavi solo in variabili d'ambiente |
| RNF-08 | Demo ripetibile | Un solo script prepara database, dati simulati e utenti di prova |
| RNF-09 | Dispositivi senza dati personali | Pedane, sensori AI e peso producono solo conteggi, sensori AI e profilazione richiedono la DPIA prima dell'uso reale |

## 6. Dati gestiti

| Area | Entità | Fonte |
| --- | --- | --- |
| Riferimento | Edizione, padiglione con superficie e capienza, varco, stand con posizione sulla mappa, categoria biglietto, canale | Dati storici e parametri |
| Commerciale | Espositore, pratica, offerta, contratto, acconto, listino, assegnazione stand, pacchetto BASE o PREMIUM | Back office Power Apps |
| Biglietteria e accessi | Ordine, biglietto, accesso | Storico e simulatore dei varchi |
| Padiglioni | Passaggio alle pedane, con entrati e usciti al minuto | Simulatore delle pedane |
| Stand | Visita per ora, scansione, contatto con il lead magnet che lo ha generato, contatto riservato, rilevazione di peso, persone ferme dal sensore AI | Storico, app di scansione e simulatori |
| Marketing | Lead magnet di ARCADE Milano e degli espositori | Back office e area espositore |
| Visitatori | Registrazione con consensi, dati riservati, interessi | Modulo del portale |
| Qualità | Importazione, scarto, catalogo anomalie, dizionario dati | Script di caricamento |
| Portale | Categoria, avviso, richiesta espositore, utente, ruolo | Portale e amministrazione |

Pedane, sensori AI, pacchetti, posizione degli stand, registrazione del visitatore e lead magnet sono già nella migrazione V007. Le tabelle commerciali (pratica, contratto, acconto, listino) e quelle del portale si aggiungono con nuove migrazioni, senza modificare quelle già applicate.

## 7. Scelte fatte per i dati che mancano

| Mancanza | Scelta | Dichiarata dove |
| --- | --- | --- |
| Uscite dai varchi | Per il 2026 presenze misurate dalle pedane, per il 2024 e il 2025 stimate come ingressi delle ultime 4 ore | Report e cruscotto staff |
| Capienza e superficie dei padiglioni | Valori simulati, P1 3.000, P2 2.000, P3 1.500 persone, finché il cliente non li fornisce | Cruscotto staff |
| Prezzi e superfici degli stand | Listino e superfici simulati, finché il cliente non li fornisce | Report direzione |
| Costi per il costo per contatto | Costi come parametro per edizione, valori simulati | Report direzione |
| Lead magnet nei dati 2025 | I contatti 2025 utilizzabili valgono come MQL, perché il lead magnet non esisteva ancora | Report e area espositore |
| Sensori di peso, pedane e sensori AI | Letture simulate con un profilo di giornata realistico, l'installazione va concordata con il cliente per il 2026 | Cruscotto staff e riepilogo espositore |
| Tornelli e biglietteria reali | Simulatore che invia lo stesso messaggio di un dispositivo vero | Documentazione API |
| Account aziendali | Utenti di prova per ruolo, se Entra ID non è disponibile | README |

## 8. Fuori dal perimetro

- Pagamenti online e firma digitale con valore legale: l'acconto si registra, non si incassa.
- Vendita dei biglietti: resta alla biglietteria esterna.
- Installazione di tornelli, pedane, sensori AI e sensori di peso: solo simulatori, con una prova facoltativa su pedana.
- Uso reale dei sensori AI e della profilazione prima della DPIA con il responsabile privacy del cliente.
- Navigazione al metro dentro i padiglioni: la mappa mostra lo stand, il varco più vicino e le aree affollate.
- Matchmaking, agenda personale e account per i visitatori.
- Blog, area stampa e accrediti.
- App native per iOS e Android: il portale è web e responsive.

## 9. Divisione tra i client

| Flusso | Strumento |
| --- | --- |
| Area espositore, portale pubblico, mappa interattiva, modulo del visitatore, cruscotto staff | React |
| Back office commerciale | Power Apps |
| Scansione allo stand | Web mobile in React, Power Apps solo se la prova su licenze e uso offline va bene |
| Automazioni del flusso commerciale | Power Automate |
| Report direzione e mappa di calore | Power BI |

Nessuna schermata esiste in due client.

## 10. Definizione di fatto

Un requisito è fatto quando:

1. il criterio di accettazione è verificato e scritto nella issue;
2. il codice è in una pull request rivista da un'altra persona del team;
3. l'endpoint, se c'è, è nel contratto OpenAPI;
4. la funzione rientra nel test end-to-end delle tre fasi della fiera (#36).

Per dichiarare completa questa sessione di sviluppo, RF-01 e RF-02 devono essere verificati sui file originali già ricevuti: dati puliti e importati nel database locale, decisioni di correzione/scarto documentate, report di qualità aggiornato e sorgenti o dettagli personali mantenuti fuori da Git. La sola presenza dello script o dei file sorgente non soddisfa il criterio.
