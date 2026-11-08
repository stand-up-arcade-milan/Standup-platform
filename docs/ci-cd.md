# CI/CD su GitHub Actions

## Controlli continui

`.github/workflows/ci.yml` parte su ogni push, sulle pull request verso `main` e manualmente da GitHub Actions. Usa solo permessi `contents: read`.

- **Frontend:** installazione riproducibile con Bun e build Vite, che include il controllo TypeScript.
- **Backend:** `mvn verify` con Java 21; esegue i test Maven e prepara il package.
- **OpenAPI:** lint del contratto con Redocly.
- **Compose smoke check:** valida la configurazione, costruisce anche il target frontend di produzione, crea i container, attende PostgreSQL/API e verifica la home frontend e il proxy frontend→API. I log sono raccolti in caso di errore.

Al 08/11/2026 la suite Java contiene 10 test automatici su token e ruoli, formato degli errori, health pubblico, pseudonimizzazione degli export, array PostgreSQL e idempotenza dei KPI. La pipeline li esegue con `mvn verify`.

Questi test non sostituiscono una verifica integrata di tutte le 54 operazioni contro PostgreSQL e i client BID/BAD. Lo smoke test Compose verifica l'avvio dei servizi e il proxy HTTP frontend→API; non importa i dati, non prova Power Apps/Power BI e non copre i flussi completi prima, durante e dopo la fiera. La verifica browser headless registrata in `docs/stato-progetto.md` è manuale e non è ancora una suite E2E ripetibile in CI.

Il lint Redocly controlla la sintassi del contratto OpenAPI, non la corrispondenza automatica tra ogni schema/risposta documentata e l'implementazione Java. L'issue [#10](https://github.com/stand-up-arcade-milan/Standup-platform/issues/10) resta aperta per la revisione congiunta BID–BAD. Non è configurata una Swagger UI nell'applicazione.

## Consegna immagini

`.github/workflows/release-images.yml` pubblica immagini versionate su GitHub Container Registry quando viene inviato un tag `v*`, per esempio `v0.1.0`. Usa il `GITHUB_TOKEN` con `packages: write`; non richiede una password Docker o un token personale.

- `ghcr.io/stand-up-arcade-milan/standup-platform-backend:v0.1.0`
- `ghcr.io/stand-up-arcade-milan/standup-platform-frontend:v0.1.0`

Il frontend di rilascio serve gli asset statici con Nginx e inoltra `/api/` e `/actuator/` a un servizio Compose chiamato `backend`. Il Dockerfile mantiene il server Vite come target predefinito per lo sviluppo locale.

Questa pipeline consegna immagini eseguibili; non effettua il deploy su un server. Il progetto non ha ancora un ambiente di destinazione, dominio o configurazione di segreti di deploy da automatizzare.

## Pubblicare una versione

Dopo aver unito in `main` una versione verificata:

```powershell
git tag v0.1.0
git push origin v0.1.0
```

La pubblicazione parte solo dal tag; push ordinari e pull request non pubblicano immagini.
