# Punti da chiudere

Promemoria per la revisione complessiva del lavoro. Sono decisioni o integrazioni esterne ancora necessarie, non dati da indovinare.

## Import storico

- L'importazione e la riconciliazione sono completate nel volume Docker locale del progetto Compose `standup-import`; il report aggregato è in `report-qualita-dati.md`.
- Stack attualmente esposto solo su localhost: PostgreSQL `55432`, API `18080`, frontend `15173`. Per riprodurlo, avviare Compose con `POSTGRES_PORT=55432`, `API_PORT=18080`, `WEB_PORT=15173`, `POSTGRES_USER=arcade_admin` e `POSTGRES_PASSWORD=arcade_dev_only`, poi eseguire `python scripts/dati/importa_dataset.py` con `DATABASE_URL=postgresql://arcade_admin:arcade_dev_only@localhost:55432/arcade`.
- Il database e i file cliente sono locali e non versionati. Un clone non contiene tali dati; per importarli servono le fonti ricevute separatamente.
## Identità e notifiche

- Confermare issuer, audience e chiavi JWKS per token Entra ID, BAD e dispositivi. Il backend implementato firma token HS256 per gli account espositori e verifica token HS256 locali; questo non sostituisce la validazione OIDC/JWKS aziendale prevista dal contratto.
- Configurare l’invio email per inviti e recupero password. Gli endpoint conservano token monouso con scadenza; senza un provider non possono consegnare il link all’utente.

## Documenti commerciali

- Definire generazione, archivio e download delle offerte/contratti. Al momento la rotta crea metadati, ma il progetto non ha storage o una rotta di download per il file effettivo.
- Finché non è configurato l’archivio documentale, le offerte registrano i metadati con `url: null`; la UI non propone un collegamento inesistente.

## Dati e integrazione

- Confermare con BAD le dimensioni JSON ufficiali dei KPI (codice stand/espositore) e la lista dei ruoli effettivi per client, dispositivi e Power Apps.
- La fonte commerciale non fornisce date di fiera 2026: l’edizione resta pianificata senza date finché non vengono comunicate.
