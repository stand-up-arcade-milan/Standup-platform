# CI/CD su GitHub Actions

## Controlli continui

`.github/workflows/ci.yml` parte su ogni push, sulle pull request verso `main` e manualmente da GitHub Actions. Usa solo permessi `contents: read`.

- **Frontend:** installazione riproducibile con Bun e build Vite, che include il controllo TypeScript.
- **Backend:** `mvn verify` con Java 21; esegue i test Maven presenti e prepara il package.
- **OpenAPI:** lint del contratto con Redocly.
- **Compose smoke check:** valida la configurazione, costruisce anche il target frontend di produzione, crea i container, attende PostgreSQL/API e verifica la home frontend e il proxy frontend→API. I log sono raccolti in caso di errore.

Il repository al momento non contiene una suite di test applicativi; il job Maven controlla compilazione/package e lo smoke check copre la comunicazione tra i servizi. Aggiungere test mirati quando i moduli applicativi vengono implementati.

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
