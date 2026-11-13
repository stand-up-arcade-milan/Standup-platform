# CI/CD su GitHub Actions

## Verifiche su push e pull request

`.github/workflows/ci.yml` parte su ogni push, sulle pull request verso `main` e manualmente. Usa `contents: read`.

- **Frontend:** installazione riproducibile con Bun, build Vite e controllo TypeScript.
- **Backend:** `mvn verify` con Java 21; include i test Java automatici e il package.
- **OpenAPI:** lint di `docs/openapi.yaml` con Redocly.
- **Compose integrato:** build dei servizi, health check del database/API/frontend e proxy frontend→API; carica soltanto fixture sintetici, esercita tutti gli operationId, confronta i flussi integrati e infine lancia Newman.

La suite Java contiene 15 test automatici. La suite integrata invoca tutte le 56 operationId OpenAPI (70 chiamate includendo ripetizioni per idempotenza, controllo ruoli e audit), verifica che non restino route senza test e controlla tre percorsi applicativi:

1. **Flusso commerciale:** pratica, modifica, offerta PDF, archivio e download, invio/firma amministrativa, riepilogo informativo, acconto e rinnovo.
2. **Operatività in fiera:** accesso con biglietto, scansione con consenso, duplicato, assenza di consenso, pedana, sensore AI e rilevazione peso.
3. **Dati post-fiera:** KPI BAD, report e filtri, privacy/tenant del portale, download documenti e confronto dei valori tra report commerciale e area espositore.

Il fixture contiene due fonti sovrapposte di visite stand (storico 99 e scanner 2): la proiezione deve preferire le scansioni, esporre il flag della sovrapposizione e contare un solo lead con consenso. I valori inseriti sono marcati `simulato` e `CI_SINTETICA`.

La CI usa fixture sintetiche isolate; non legge i dati in dati-storici/ e non monta il volume locale standup-import_postgres_data. Le istruzioni per avviare la demo BID–BAD sulla LAN sono in [integrazione-bid-bad.md](integrazione-bid-bad.md).

La suite locale riproduce il job integrato da PowerShell:

```powershell
.\scripts\test\run-integration.ps1
```

Richiede Docker Desktop; le verifiche del frontend usano Bun, mentre Node.js e npm servono solo al primo download di Newman tramite `npx`. Avvia un progetto Compose casuale con credenziali e porte temporanee, carica il fixture sintetico, esegue i test e ferma i container. Il volume PostgreSQL di test viene conservato per diagnosi; lo stack e il volume importato `standup-import` non vengono usati né modificati. L'opzione `-SkipPostman` salta solo Newman.

Queste prove coprono backend, database e API HTTP insieme, non simulano l'integrazione reale con Power Apps/Power BI, il provider OIDC, l'invio email o il browser fisico dello scanner. La home del frontend e il proxy API passano uno smoke test e la build front-end passa separatamente; i test di processo non usano una sessione browser automatizzata.

Il lint Redocly verifica la forma del contratto, mentre la suite confronta tutti gli `operationId` con le chiamate effettive. La revisione BID–BAD dei nomi e delle formule KPI resta aperta nell'[issue #10](https://github.com/stand-up-arcade-milan/Standup-platform/issues/10). Swagger UI non è ancora configurata.

## Pubblicazione immagini

`.github/workflows/release-images.yml` pubblica immagini versionate su GitHub Container Registry quando viene inviato un tag `v*`, per esempio `v0.1.0`. Usa `GITHUB_TOKEN` con `packages: write`; non richiede un token personale.

- `ghcr.io/stand-up-arcade-milan/standup-platform-backend:v0.1.0`
- `ghcr.io/stand-up-arcade-milan/standup-platform-frontend:v0.1.0`

Il frontend di rilascio serve gli asset statici con Nginx e inoltra `/api/` e `/actuator/` al servizio Compose `backend`. Il Dockerfile mantiene il server Vite come target predefinito per lo sviluppo locale.

La pipeline pubblica immagini eseguibili ma non distribuisce l'applicazione. Restano da concordare ambiente, dominio e segreti di deploy.

## Pubblicare una versione

Dopo aver integrato su `main` una versione verificata:

```powershell
git tag v0.1.0
git push origin v0.1.0
```

La pubblicazione parte dal tag; push ordinari e pull request non pubblicano immagini.
