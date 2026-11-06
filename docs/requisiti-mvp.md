# Requisiti e perimetro dell'MVP

Documento di lavoro del team **Stand up** per ARCADE Milano 2026. Chiude l'issue #1: fissa utenti, ruoli, flussi, dati e criteri di accettazione dell'MVP. Dove serviva una scelta, la scelta è già fatta e si cambia con un parametro.

Torna al [README](../README.md) · [Blueprint digitale](blueprint-digitale.md) · [Dati storici](dati-storici.md) · [Portale web](frontend-portale.md)

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
| RF-01 | Caricare le edizioni 2024 e 2025 dal registro unico | M | Le righe nel database coincidono con quelle dei file, il report di qualità è generato in automatico | #15, #16 |
| RF-02 | Segnalare le anomalie senza correggere le righe | M | Ogni anomalia ha un codice nel catalogo e un conteggio per tabella ed edizione | #16 |
| RF-03 | Ripetere il caricamento senza duplicati | M | Un secondo caricamento dello stesso file non aggiunge righe | #15 |
| RF-04 | Gestire l'edizione 2026 come edizione attiva | M | Date, sede e stato arrivano dalla tabella Edizione, mai scritti nelle pagine | #17 |

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

### 4.3 Operatività, durante la fiera

| ID | Requisito | P | Criterio di accettazione | Issue |
| --- | --- | --- | --- | --- |
| RF-20 | Registrare gli accessi ai varchi con esito e orario | M | Una lettura simulata compare nel cruscotto staff entro un minuto | #25 |
| RF-21 | Rifiutare biglietti non validi, già usati o fuori giorno | M | I tre casi restituiscono un esito di rifiuto con il motivo | #25 |
| RF-22 | Scansione allo stand con esito e conteggio, senza dati del visitatore | M | Una seconda scansione dello stesso codice nello stesso stand non conta due volte | #26 |
| RF-23 | Cruscotto staff con affluenza per ora, varco e padiglione | M | I numeri coincidono con le viste del database | #27 |
| RF-24 | Stima delle presenze nello stand dal peso, con dati simulati | M | La stima resta entro il 15% dai conteggi di prova e il margine è dichiarato a schermo | #28 |
| RF-25 | Avvisi di servizio per pubblico: visitatori, espositori, staff | S | Un avviso per lo staff non compare agli espositori | #27 |

### 4.4 Risultati, dopo la fiera

| ID | Requisito | P | Criterio di accettazione | Issue |
| --- | --- | --- | --- | --- |
| RF-30 | Report direzione con i KPI approvati e il confronto tra edizioni | M | Ogni KPI mostra definizione, fonte e data di aggiornamento | #22, #29 |
| RF-31 | Area espositore con stand, contratto, contatti e riepilogo post-fiera | M | L'espositore A non vede nessun dato dell'espositore B, né dall'interfaccia né chiamando l'API | #32 |
| RF-32 | Stessi numeri in tutte le viste | M | Il totale ingressi coincide tra database, API, Power BI e portale | #34 |
| RF-33 | Elenco espositori pubblico con ricerca e filtri per categoria | S | I conteggi accanto ai filtri coincidono con i risultati | #32 |

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

## 6. Dati gestiti

| Area | Entità | Fonte |
| --- | --- | --- |
| Riferimento | Edizione, padiglione, varco, stand, categoria biglietto, canale | Dati storici e parametri |
| Commerciale | Espositore, pratica, offerta, contratto, acconto, listino, assegnazione stand | Back office Power Apps |
| Biglietteria e accessi | Ordine, biglietto, accesso | Storico e simulatore dei varchi |
| Stand | Visita per ora, scansione, contatto, contatto riservato, rilevazione di peso | Storico, app di scansione e simulatore |
| Qualità | Importazione, scarto, catalogo anomalie, dizionario dati | Script di caricamento |
| Portale | Categoria, avviso, richiesta espositore, utente, ruolo | Portale e amministrazione |

Le tabelle commerciali (pratica, contratto, acconto, listino) e quelle del portale si aggiungono allo schema esistente con nuove migrazioni, senza modificare quelle già applicate.

## 7. Scelte fatte per i dati che mancano

| Mancanza | Scelta | Dichiarata dove |
| --- | --- | --- |
| Uscite dai varchi | Presenze stimate come ingressi delle ultime 4 ore, parametro modificabile | Report e cruscotto staff |
| Prezzi e superfici degli stand | Listino e superfici simulati, finché il cliente non li fornisce | Report direzione |
| Costi per il costo per contatto | Costi come parametro per edizione, valori simulati | Report direzione |
| Sensori di peso | Letture simulate con un profilo di giornata realistico | Cruscotto staff e riepilogo espositore |
| Tornelli e biglietteria reali | Simulatore che invia lo stesso messaggio di un dispositivo vero | Documentazione API |
| Account aziendali | Utenti di prova per ruolo, se Entra ID non è disponibile | README |

## 8. Fuori dal perimetro

- Pagamenti online e firma digitale con valore legale: l'acconto si registra, non si incassa.
- Vendita dei biglietti: resta alla biglietteria esterna.
- Integrazione con tornelli e sensori fisici: solo simulatori, con una prova facoltativa su pedana.
- Matchmaking, agenda personale e account per i visitatori.
- Blog, area stampa e accrediti.
- App native per iOS e Android: il portale è web e responsive.

## 9. Divisione tra i client

| Flusso | Strumento |
| --- | --- |
| Area espositore, portale pubblico, cruscotto staff | React |
| Back office commerciale | Power Apps |
| Scansione allo stand | Web mobile in React, Power Apps solo se la prova su licenze e uso offline va bene |
| Automazioni del flusso commerciale | Power Automate |
| Report direzione | Power BI |

Nessuna schermata esiste in due client.

## 10. Definizione di fatto

Un requisito è fatto quando:

1. il criterio di accettazione è verificato e scritto nella issue;
2. il codice è in una pull request rivista da un'altra persona del team;
3. l'endpoint, se c'è, è nel contratto OpenAPI;
4. la funzione rientra nel test end-to-end delle tre fasi della fiera (#36).
