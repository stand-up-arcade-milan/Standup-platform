# Stato progetto e handoff

Aggiornato il 08/11/2026. Punto di partenza per BID, BAD e per chi continua il lavoro sul repository. Aggiornare questo file quando cambiano architettura, responsabilita, servizi disponibili o procedure di verifica.

## Sintesi

- BID gestisce il backend Java/Spring Boot, PostgreSQL, gli endpoint condivisi e i client React assegnati al gruppo.
- BAD calcola i KPI e li invia a BID. BID conserva e serve i KPI tramite API; i client non ricalcolano le formule.
- Stack deciso: Java 21 e Spring Boot; PostgreSQL; React e TypeScript con Bun, Vite e TanStack Router; Docker Compose per l'avvio locale.
- Le schermate 4, 5 e 6 sono implementate in React: `/commerciale`, `/espositore`, `/scansione`. Le schermate 7, 8 e 9 hanno specifiche funzionali senza implementazione; le schermate 1, 2 e 3 sono assegnate a un altro membro.
- `docs/openapi.yaml` e il contratto condiviso: attualmente descrive 50 percorsi e 54 operazioni, implementate in `backend/src/main/java/standup/api/PlatformApiController.java`.

## Lavoro completato

### Dati locali

- Gli export ricevuti sono stati normalizzati e importati nel volume PostgreSQL del progetto Compose locale `standup-import`.
- Conteggi riconciliati: 78.275 biglietti, 100.741 letture ai varchi, 2.451 righe di visite stand, 1.707 contatti, 135 espositori, 130 stand, 19 voci di listino complete, 168 contratti collegati e 806 righe contratto.
- Il [report di qualita dati](report-qualita-dati.md) documenta le riconciliazioni, le anomalie e le esclusioni. I dati cliente grezzi e normalizzati sono personali e restano in `dati-storici/`, esclusa da Git.
- La pulizia non attribuisce per supposizione i 30 contratti senza espositore univoco e le loro 144 righe; esclude la singola voce listino incompleta; conserva gli ingressi senza ticket corrispondente come rifiuti e tiene le anomalie con flag. I dettagli sono nel report.

### API Java

- Il backend implementa accesso pubblico, espositori, pratiche commerciali, biglietteria e accessi, scansioni e simulatori, KPI, avvisi, amministrazione e integrazione BID-BAD.
- Migrazioni database da V001 a V014. V014 imposta un `search_path` stabile per i trigger commerciali.
- Le risposte d'errore usano una struttura comune. I ruoli e i bearer token sono verificati dal backend.
- Gli export BID pseudonimizzano i riferimenti di ticket e ordine; i record esportati non devono contenere email, anagrafiche commerciali o QR in chiaro.
- Gli array PostgreSQL restituiti dalle query vengono convertiti in array JSON; il ricevitore KPI salva correttamente anche gli array `flagQualita` con tipo `text[]`.

### Frontend

- `/commerciale`: richieste, pratiche, listino, assegnazioni e planimetria; le API pubbliche degli espositori continuano a essere mostrate anche quando manca il token per le API interne.
- `/espositore`: login, accettazione/recupero account, contratto, contatti, indicatori condivisi e stato dei documenti.
- `/scansione`: lettura QR da fotocamera o inserimento manuale, scelta stand, consenso e lead magnet. Il token non viene salvato oltre la scheda corrente.
- La palette e le schede funzionali sono in `docs/identita-visiva.md` e `docs/schermate/`.

## Decisioni che impattano gli altri gruppi

- Usare `docs/openapi.yaml` come fonte dei nomi, tipi, stati, ruoli, errori e formati di richiesta/risposta. Non introdurre campi o rotte in un client senza riallinearli con il contratto.
- BAD legge i fatti BID da `GET /api/v1/bi/dati/vendite`, `/accessi`, `/stand`, `/commerciale` e `/qualita`; invia un lotto con `PUT /api/v1/integrazioni/bad/kpi/{batchId}`. Il `batchId` stabile rende ripetibile l'invio.
- Non inviare dati personali nei lotti KPI. Le dimensioni concordate possono contenere codici di area/stand, mai email o nominativi.
- Regole e livelli di accesso vanno applicati lato server. Nascondere un controllo nella UI non autorizza una richiesta API.
- Il listino incompleto e i contratti non riconciliabili non sono dati attivi. L'edizione 2026 resta pianificata senza date finche la fonte non le conferma.
- L'autenticazione aziendale OIDC/JWKS, la consegna email e l'archivio/download documenti sono dipendenze ancora da definire. Il JWT HS256 predefinito serve solo allo sviluppo locale e non sostituisce l'integrazione aziendale.

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

La CI esegue anche Compose smoke test: `docker compose config --quiet`, build delle immagini e richieste a `/api/v1/health` e `/actuator/health` passando dal frontend.

Esiti di verifica registrati per questa implementazione: `bun run build`, `mvn -B -ntp verify` e lint OpenAPI sono passati. Maven esegue ora 10 test automatici Java (JWT e ruoli, formato errori, health pubblico, export pseudonimizzato, array PostgreSQL e idempotenza KPI); tutti passano e la CI li lancia nel job backend con `mvn verify`. Newman ha eseguito gli 8 casi della collection con 25 asserzioni superate. I cinque export sono stati inoltre richiesti con dati importati: JSON valido, campi personali assenti, fingerprint HMAC di 64 caratteri e `flagQualita` come array. La UI delle route implementate e' stata verificata con browser headless.

### Collection Postman BID-BAD

- Importare `postman/standup-platform-bid-bad.postman_collection.json` e `postman/standup-platform-local.postman_environment.json` in Postman.
- Selezionare l'ambiente locale e impostare `apiBaseUrl` e `badToken`. Il token deve appartenere a un'identita BAD autorizzata dall'ambiente in prova; non salvare token reali nella collection o nel repository.
- La cartella `BID -> BAD` verifica tutti e cinque gli export e un 401 senza token. Gli script controllano forma JSON, paginazione, pseudonimizzazione e assenza di campi personali.
- La cartella `BAD -> BID` invia un KPI sintetico con `simulato: true` e ripete lo stesso `batchId` per controllare l'idempotenza. Il PUT salva un lotto: eseguirlo solo su un database locale/di test e usare un `batchId` dedicato.
- Per eseguire con Newman dalla radice del repository, impostare nella sessione un bearer JWT BAD valido per l'ambiente locale e lanciare `npx --yes newman run postman/standup-platform-bid-bad.postman_collection.json -e postman/standup-platform-local.postman_environment.json --env-var "badToken=<token>"`. Il token vuoto predefinito e' intenzionale; non usare la chiave JWT di sviluppo fuori dal locale.

## Dipendenze e prossimi passi

1. Concordare con BAD le dimensioni KPI, le fonti e le versioni formula definitive.
2. Confermare issuer, audience, JWKS e ruoli/client per Entra ID, BAD e dispositivi; poi sostituire il verificatore HS256 locale con l'integrazione autorizzata.
3. Configurare il provider email per inviti e recupero password.
4. Scegliere archivio, generazione e download dei documenti commerciali.
5. Allineare con gli altri membri l'integrazione dei rispettivi client; non implementare qui le schermate 1–3 gia assegnate.

## Procedura Git per il gruppo

- Prima di ogni push a `main`, verificare l'account GitHub `giosuetedeschi-spec`, fare `fetch/pull` e integrare i commit recenti del gruppo.
- Preparare commit atomici per dati/documentazione, backend/API e frontend; verificare che `git status` non includa `dati-storici/`, `.env`, `.venv/` o `.vscode/`.
- Non forzare aggiornamenti su `main`; se la protezione lo richiede, usare il flusso PR e attendere i controlli CI.
