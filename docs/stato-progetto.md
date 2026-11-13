# Stato progetto e handoff

Aggiornato il 08/11/2026. Punto di partenza per BID, BAD e per chi continua il lavoro sul repository. Aggiornare questo file quando cambiano architettura, responsabilita, servizi disponibili o procedure di verifica.

## Sintesi

- BID gestisce il backend Java/Spring Boot, PostgreSQL, gli endpoint condivisi e i client React assegnati al gruppo.
- BAD calcola i KPI e li invia a BID. BID conserva e serve i KPI tramite API; i client non ricalcolano le formule.
- Stack deciso: Java 21 e Spring Boot; PostgreSQL; React e TypeScript con Bun, Vite e TanStack Router; Docker Compose per l'avvio locale.
- Le schermate 4, 5 e 6 sono implementate in React: `/commerciale`, `/espositore`, `/scansione`. La schermata 1 (`/accesso`) entra come ingresso unico con sessione e ruoli; la schermata 2 e la 3 sono in lavorazione su branch dedicati; le schermate 7, 8 e 9 hanno specifiche funzionali senza implementazione.
- La home pubblica (`/`) segue la struttura delle home di fiera (rif. `docs/fonti/ARCADE-Milano-Bozza-schermate.html` e il sito di riferimento del cliente): pagina in Coffee Bean con la palette ufficiale — banner ufficiale integro in cima a tutta larghezza, lime per le azioni, teal per gli accenti, chip con date e sede, grandi CTA «Visita»/«Esponi», blocco «in breve» (dove/quando/biglietti), avvisi in griglia tipo news, sezione «perché visitare», FAQ e accesso al portale, senza numeri inventati.
- `docs/openapi.yaml` è il contratto condiviso: descrive 54 percorsi e 58 operazioni. La suite di integrazione invoca tutte le operationId e fallisce se il contratto aggiunge un’operazione senza test; restano da concordare congiuntamente i KPI nell’[issue #10](https://github.com/stand-up-arcade-milan/Standup-platform/issues/10).

## Lavoro completato

Per i dettagli pratici di collaborazione BID–BAD, credenziali, paginazione e ambiente demo LAN vedere [integrazione-bid-bad.md](integrazione-bid-bad.md). La pipeline locale, le esclusioni e la collocazione dei dati sono in [trattamento-dati-ricevuti.md](trattamento-dati-ricevuti.md). La cache Graphify vive in graphify-out/ ed è locale/ignorata da Git.

### Dati locali

- Gli export ricevuti sono stati normalizzati e importati nel volume PostgreSQL del progetto Compose locale `standup-import`.
- Conteggi riconciliati: 78.275 biglietti, 100.741 letture ai varchi, 2.451 righe di visite stand, 1.707 contatti, 135 espositori, 130 stand, 19 voci di listino complete, 168 contratti collegati e 806 righe contratto.
- Il [report di qualita dati](report-qualita-dati.md) documenta le riconciliazioni, le anomalie e le esclusioni. I dati cliente grezzi e normalizzati sono personali e restano in `dati-storici/`, esclusa da Git.
- La pulizia non attribuisce per supposizione i 30 contratti senza espositore univoco e le loro 144 righe; esclude la singola voce listino incompleta; conserva gli ingressi senza ticket corrispondente come rifiuti e tiene le anomalie con flag. I dettagli sono nel report.

### API Java

- Il backend implementa accesso pubblico, espositori, pratiche commerciali, biglietteria e accessi, scansioni e simulatori, KPI, avvisi, amministrazione e integrazione BID-BAD.
- Migrazioni database da V001 a V026. V015 introduce ruoli DB a privilegi minimi, RLS e audit; V016 riconcilia le proiezioni dei report; V017 archivia i PDF; V018–V023 correggono e provano i privilegi dei flussi reali e l’isolamento dei contratti storici; V024 aggiunge i turni del personale per l’operatività evento; V025 aggiunge l’accesso con Google e Microsoft; V026 corregge i permessi su `edizione`.
- Le migrazioni vengono applicate da zero a ogni push dal workflow [Database e documenti](../.github/workflows/database-docs.yml), che costruisce l’immagine del progetto e fallisce se una migrazione non si applica su un database vuoto. Lo stesso workflow rigenera `docs/dizionario-dati.md` e fallisce se il file nel repository non corrisponde al database.
- Compose collega Spring al login DB `arcade_app` (NOINHERIT); per ogni richiesta il controller imposta un ruolo DB dedicato nella transazione. L’identità espositore è passata in `arcade.id_espositore` e le policy RLS limitano pratiche, documenti, pagamenti, contratti storici e contatti al tenant autenticato.
- La schermata Accesso (`/accesso`) e l'ingresso unico: email e password, oppure un account Google o Microsoft. Con un fornitore esterno il client manda solo l'ID token; `SocialIdTokens` ne verifica firma, emittente, destinatario e scadenza contro le chiavi pubbliche del fornitore, e subject ed email si leggono dal token verificato, mai dal corpo della richiesta. Qui non si creano account: l'email deve gia appartenere a un account nato da un invito, e al primo accesso il fornitore viene collegato a quell'account in `identita_esterna`. Senza client id configurato il fornitore resta spento, il pulsante e disabilitato e l'endpoint risponde 503.
- Gli account espositore usano JWT HS256 emessi dopo la verifica password; anche i token interni HS256 sono disponibili solo con l’opzione di sviluppo locale. Per i ruoli aziendali è supportata la verifica OIDC/JWKS RS256 con issuer, audience e URI JWKS configurati. L’identity provider reale e il mapping dei ruoli devono ancora essere concordati e configurati.
- Il client decodifica il payload del token solo per scegliere la schermata di destinazione, il ruolo nella barra di navigazione e i messaggi di autorizzazione: la verifica e le regole di accesso restano sul server. La sessione vive in `sessionStorage`, viene ripristinata al ricaricamento della scheda, i token scaduti vengono rimossi e la scadenza mostra il messaggio di sessione scaduta. Le aree protette usano la guardia `RequireRole` con messaggi espliciti di accesso richiesto o non autorizzato, e il menu mostra solo le aree consentite al ruolo.
- Le risposte d'errore usano una struttura comune. Gli accessi a dati personali e le operazioni amministrative registrano azione, ruolo, risorsa e riferimento pseudonimizzato; non vengono registrati token, corpi o indirizzi email.
- Gli export BID pseudonimizzano i riferimenti di ticket e ordine; i record esportati non devono contenere email, anagrafiche commerciali o QR in chiaro.
- Gli array PostgreSQL restituiti dalle query vengono convertiti in array JSON; il ricevitore KPI salva correttamente anche gli array `flagQualita` con tipo `text[]`.

### Frontend

- `/commerciale`: richieste, pratiche, listino, assegnazioni e planimetria; genera offerte PDF, le archivia e permette il download autenticato. Le API pubbliche degli espositori restano mostrate anche senza token interno.
- Il passaggio applicativo a `FIRMATA` archivia anche un riepilogo informativo; acconti e rinnovi restano collegati alla pratica. Questo flusso non raccoglie o verifica la firma elettronica.
- `/espositore`: login, accettazione/recupero account, contratto, download dei propri documenti, contatti consentiti, indicatori condivisi e serie di presenze PREMIUM.
- `/scansione`: lettura QR da fotocamera o inserimento manuale, scelta stand, consenso e lead magnet. Il token non viene salvato oltre la scheda corrente.
- La palette e le schede funzionali sono in `docs/palette-colori.md` e `docs/schermate/`.

### Report e documenti commerciali

- `docs/struttura-report.md` definisce pagine, dati, fonti, null, filtri, qualità e regole di confronto. `v_bi_stand` preferisce scansioni granulari ai totali storici sovrapposti e segnala la scelta; `v_bi_commerciale` conserva gli importi storici firmati e non inventa acconti o saldi mancanti.
- La suite integrata confronta stand/report, stato e importi commerciali e il portale espositore. Il fixture include 99 visite storiche sovrapposte a due scansioni: l’export deve restituire due visite, un contatto con consenso e il flag di sovrapposizione.
- Le offerte sono PDF informativi, archiviati in PostgreSQL come documento immutabile con MIME, dimensione e SHA-256; download con controllo tenant, `no-store`, `nosniff` ed ETag. Il riepilogo creato quando una pratica passa a `FIRMATA` non è il contratto originale firmato e non attua una firma elettronica.

## Decisioni che impattano gli altri gruppi

- Usare `docs/openapi.yaml` come fonte dei nomi, tipi, stati, ruoli, errori e formati di richiesta/risposta. Non introdurre campi o rotte in un client senza riallinearli con il contratto.
- BAD legge i fatti BID da `GET /api/v1/bi/dati/vendite`, `/accessi`, `/stand`, `/commerciale` e `/qualita`; invia un lotto con `PUT /api/v1/integrazioni/bad/kpi/{batchId}`. Il `batchId` stabile rende ripetibile l'invio.
- Non inviare dati personali nei lotti KPI. Le dimensioni concordate possono contenere codici di area/stand, mai email o nominativi.
- Regole e livelli di accesso vanno applicati lato server. Nascondere un controllo nella UI non autorizza una richiesta API.
- Il listino incompleto e i contratti non riconciliabili non sono dati attivi. L'edizione 2026 resta pianificata senza date finche la fonte non le conferma.
- Configurare i valori dell’identity provider aziendale OIDC/JWKS e il provider email. Concordare il modello e la procedura legale per caricare/validare il documento contrattuale originale firmato; i PDF generati sono bozze/riepiloghi informativi, non sostituiscono quel documento.

## Avvio e verifica

### Stack standard

Da PowerShell nella radice del repository:

```powershell
docker compose up --build
```

Frontend: `http://localhost:5173`; API: `http://localhost:8080/api/v1`; PostgreSQL: `localhost:5432`. Compose usa valori predefiniti condivisi per il solo sviluppo locale, sovrascrivibili con variabili d'ambiente. Le migrazioni in `database/migrations/` vengono eseguite solo all'inizializzazione di un volume PostgreSQL vuoto.

### Database importato su questa macchina

Il database importato si trova nel progetto Compose separato `standup-import`, con PostgreSQL su 55432, API su 18080 e frontend su 15173. Per ricreare/avviare lo stack con queste porte, impostare prima le variabili in PowerShell:

```powershell
$env:POSTGRES_PORT = '55432'
$env:API_PORT = '18080'
$env:WEB_PORT = '15173'
$env:POSTGRES_USER = 'arcade_admin'
$env:POSTGRES_PASSWORD = 'arcade_dev_only'
docker compose --project-name standup-import up -d --build
```

Per importare nuovamente i file normalizzati disponibili localmente:

```powershell
python -m pip install -r scripts/dati/requirements.txt
python scripts/dati/importa_dataset.py --dsn postgresql://arcade_admin:arcade_dev_only@localhost:55432/arcade
```

Cambiare `POSTGRES_PASSWORD` in Compose non cambia la password gia inizializzata nel volume. Per una nuova installazione condivisa, il team deve impostare gli stessi valori locali prima del primo avvio. Non committare file cliente, token, password personali o `.env`.

### Controlli usati in questa sessione

```powershell
cd frontend
bun run build
cd ..\backend
mvn -B -ntp verify
cd ..
npx --yes @redocly/cli@2.64.1 lint --extends minimal docs/openapi.yaml
```

La CI e il test locale eseguono anche la suite completa su un progetto Compose isolato e fixture sintetici, senza accedere al volume `standup-import`. I container di test vengono fermati a fine esecuzione; il volume di test resta disponibile per diagnosi.

Esiti verificati in questa sessione: build Bun/TypeScript, `mvn -B -ntp verify` (15 test Java), lint Redocly e suite Compose passati. La suite esercita 58/58 `operationId` OpenAPI (70 richieste, incluse ripetizioni per idempotenza, ruoli e verifica audit), i flussi commerciale/documenti, accessi/scansione e post-fiera/report/portale, la riconciliazione tra viste e l’isolamento tenant. Newman ha eseguito 8 richieste e 25 asserzioni. Il workflow GitHub esegue questi stessi controlli su ogni push/PR; la verifica delle API esterne Power Apps/Power BI non è simulata.

### Collection Postman BID-BAD

- Importare `postman/standup-platform-bid-bad.postman_collection.json` e `postman/standup-platform-local.postman_environment.json` in Postman.
- Selezionare l'ambiente locale e impostare `apiBaseUrl` e `badToken`. Il token deve appartenere a un'identita BAD autorizzata dall'ambiente in prova; non salvare token reali nella collection o nel repository.
- La cartella `BID -> BAD` verifica tutti e cinque gli export e un 401 senza token. Gli script controllano forma JSON, paginazione, pseudonimizzazione e assenza di campi personali.
- La cartella `BAD -> BID` invia un KPI sintetico con `simulato: true` e ripete lo stesso `batchId` per controllare l'idempotenza. Il PUT salva un lotto: eseguirlo solo su un database locale/di test e usare un `batchId` dedicato.
- Per eseguire con Newman dalla radice del repository, impostare nella sessione un bearer JWT BAD valido per l'ambiente locale e lanciare `npx --yes newman run postman/standup-platform-bid-bad.postman_collection.json -e postman/standup-platform-local.postman_environment.json --env-var "badToken=<token>"`. Il token vuoto predefinito e' intenzionale; non usare la chiave JWT di sviluppo fuori dal locale.

## Dipendenze e prossimi passi

1. **Contratto BID–BAD (#10):** approvare i KPI e le dimensioni mancanti (costo per MQL, quota MQL, persone uniche e persone ferme), le formule/fonti e i nomi dei campi. Il file attuale ha 54 percorsi e 58 operazioni; il testo dell’issue è rimasto a 53 e va corretto. BAD deve confermare che gli export forniscano costi, capienza, interessi e lead magnet necessari.
2. **Schema pubblico:** separare lo schema `Stand` pubblico da quello interno. Il controller restituisce `prezzoListinoEur` nullo sulle route pubbliche, ma il campo è ancora nel contratto condiviso.
3. **Identità e comunicazioni:** configurare issuer, audience, JWKS e mapping dei ruoli dell’identity provider reale; configurare email per inviti e recupero password. Per l’accesso degli espositori servono inoltre le registrazioni delle applicazioni su Google Cloud e su Entra ID: finché i client id non sono in `ARCADE_GOOGLE_CLIENT_ID` e `ARCADE_MICROSOFT_CLIENT_ID`, i due pulsanti restano disabilitati e la demo passa da email e password.
4. **Privacy operativa (#30):** i controlli tecnici RLS, audit e minori sono implementati e testati con fixture sintetici. Il titolare deve ancora fissare conservazione, rettifica/cancellazione e requisiti di audit; il gruppo deve accettare formalmente l’issue.
5. **Contratto ufficiale:** concordare modello, campi fiscali e processo per ricevere/verificare il documento firmato. I PDF attuali sono offerte e riepiloghi informativi.
6. **Applicazioni BAD e modello condiviso (#18, #19, #20, #22, #26, #29, #33):** sviluppare e collegare Power Apps, Power Automate e Power BI; le API BID sono disponibili, ma le applicazioni BAD non sono nel repository.
7. **Fonti in tempo reale (#25, #28):** collegare tornelli e dispositivi reali e concordare/verificare la stima di affluenza dal peso. Le route e i simulatori sono testati, l’hardware reale non è simulato.
8. **Prova e riconciliazione di gruppo (#23, #24, #34, #36):** i tre percorsi sono verificati a livello API con dati sintetici; manca la prova end-to-end con i client BAD, i dispositivi e le viste Power BI reali. La schermata direzionale e l’operatività sono assegnate a un altro membro (#45–#47).
9. **Documentazione e consegna (#12, #37, #38, #40):** completare/approvare mockup, revisione README e pulizia finale, prova demo dal vivo, slide e consegna. Swagger UI non è ancora configurata.
10. **Date:** allineare brief, Gantt, milestone e issue per SAL 2 e consegna finale. I dati commerciali non indicano le date dell’edizione 2026.

## Stato issue GitHub al 08/11/2026

Il repository contiene 41 issue: 13 chiuse e 28 aperte. Il milestone Fase 1 è scaduto il 6 novembre; #10 e #12 restano aperte. Le issue #45–#47, relative alle schermate 1–3, sono assegnate a `MDL-CNAKE`; le altre issue aperte non hanno assegnatario. Il token disponibile non ha lo scope `read:project`, quindi questo riepilogo viene dalle issue e dai milestone del repository, non dalla vista Projects. Le issue aperte sono:

- **Fase 1:** [#10 contratto API](https://github.com/stand-up-arcade-milan/Standup-platform/issues/10), [#12 mockup](https://github.com/stand-up-arcade-milan/Standup-platform/issues/12).
- **Fase 2:** [#17 API base](https://github.com/stand-up-arcade-milan/Standup-platform/issues/17), [#18 back office Power Apps](https://github.com/stand-up-arcade-milan/Standup-platform/issues/18), [#19 flusso commerciale](https://github.com/stand-up-arcade-milan/Standup-platform/issues/19), [#20 dati commerciali condivisi](https://github.com/stand-up-arcade-milan/Standup-platform/issues/20), [#22 report Power BI](https://github.com/stand-up-arcade-milan/Standup-platform/issues/22), [#23 prova integrata SAL 2](https://github.com/stand-up-arcade-milan/Standup-platform/issues/23), [#24 SAL 2](https://github.com/stand-up-arcade-milan/Standup-platform/issues/24).
- **Fase 3:** [#25 tornelli e scanner](https://github.com/stand-up-arcade-milan/Standup-platform/issues/25), [#26 app scansione](https://github.com/stand-up-arcade-milan/Standup-platform/issues/26), [#27 cruscotto staff](https://github.com/stand-up-arcade-milan/Standup-platform/issues/27), [#28 stima dal peso](https://github.com/stand-up-arcade-milan/Standup-platform/issues/28), [#29 report direzione](https://github.com/stand-up-arcade-milan/Standup-platform/issues/29), [#30 RLS e minori](https://github.com/stand-up-arcade-milan/Standup-platform/issues/30), [#31 stato 20/11](https://github.com/stand-up-arcade-milan/Standup-platform/issues/31), [#32 portale espositori](https://github.com/stand-up-arcade-milan/Standup-platform/issues/32), [#33 rinnovi](https://github.com/stand-up-arcade-milan/Standup-platform/issues/33), [#34 riconciliazione](https://github.com/stand-up-arcade-milan/Standup-platform/issues/34), [#35 stato 27/11](https://github.com/stand-up-arcade-milan/Standup-platform/issues/35), [#45 accesso](https://github.com/stand-up-arcade-milan/Standup-platform/issues/45), [#46 cruscotto direzionale](https://github.com/stand-up-arcade-milan/Standup-platform/issues/46), [#47 operatività evento](https://github.com/stand-up-arcade-milan/Standup-platform/issues/47).
- **Fase 4:** [#36 test E2E](https://github.com/stand-up-arcade-milan/Standup-platform/issues/36), [#37 README/API/pulizia](https://github.com/stand-up-arcade-milan/Standup-platform/issues/37), [#38 slide e demo](https://github.com/stand-up-arcade-milan/Standup-platform/issues/38), [#39 stato 11/12](https://github.com/stand-up-arcade-milan/Standup-platform/issues/39), [#40 presentazione finale](https://github.com/stand-up-arcade-milan/Standup-platform/issues/40).

Il Gantt è uno snapshot precedente: riporta 11/38 issue completate, mentre GitHub ne mostra 13 chiuse. Il calendario vincolante è deciso: **SAL 2 il 4 dicembre 2026, presentazione finale il 17 dicembre 2026**. Il milestone GitHub Fase 2 scade il 4 dicembre e il milestone Fase 4 il 17 dicembre, quindi i milestone sono già allineati. Restano da correggere le fonti che riportano le date vecchie: l’issue #24 ha periodo 13 novembre, l’issue #40 ha periodo 4 dicembre, l’issue #39 è intitolata “11/12” ma ha periodo 3 dicembre, e il Gantt va riallineato alle due date decise.

L’issue #10 è aperta: il suo testo conta 53 operazioni, mentre il contratto corrente ne descrive 58 su 54 percorsi. Restano l’approvazione BID–BAD di KPI e dimensioni e la separazione dello schema pubblico `Stand`; il campo prezzo viene restituito nullo, ma resta nel contratto. L’issue elenca inoltre discrepanze ormai superate: controllarle contro V001–V026 prima di trattarle come difetti attuali.

Le issue #17, #30 e parte delle #32/#34 hanno già implementazioni e test nel repository; #36 è coperta solo per i flussi API sintetici. Le issue restano aperte finché i responsabili non verificano i deliverable e aggiornano lo stato su GitHub.

## Procedura Git per il gruppo

- Prima di ogni push a `main`, verificare l'account GitHub `giosuetedeschi-spec`, fare `fetch/pull` e integrare i commit recenti del gruppo.
- Preparare commit atomici per dati/documentazione, backend/API e frontend; verificare che `git status` non includa `dati-storici/`, `.env`, `.venv/` o `.vscode/`.
- Non forzare aggiornamenti su `main`; se la protezione lo richiede, usare il flusso PR e attendere i controlli CI.
