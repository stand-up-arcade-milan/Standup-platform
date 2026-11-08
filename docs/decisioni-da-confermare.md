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


## Verifiche aggiunte al 08/11/2026

- **KPI e API BID–BAD:** chiudere in [issue #10](https://github.com/stand-up-arcade-milan/Standup-platform/issues/10) il nome `costo_per_mql` rispetto a `costo_per_contatto` e definire quota MQL, persone ferme e visitatori unici. L’export `/bi/dati/stand` restituisce ancora `contatti`, `persone_fermate` e `contatti_con_consenso` come `null`; non esporta i dati necessari per tutti i KPI (pedane/capienza, MQL e lead magnet, interessi aggregati e costi edizione). Decidere se calcola BID o BAD e documentare fonti, formule e dimensioni.
- **Scansioni e consensi:** definire la semantica di `consensoEspositori`, consenso marketing, interesse dichiarato e richiesta lead magnet, e verificare il criterio MQL (adulto, consenso, interesse e lead magnet) end-to-end.
- **Schema pubblico:** separare lo schema pubblico `Stand` da quello interno: il contratto riusa `Stand` con `prezzoListinoEur` su risposte pubbliche (`/mappa`, profilo espositore), anche se il controller attuale restituisce il prezzo nullo.
- **RLS e audit:** le policy RLS sono nelle migrazioni ma il backend Compose usa l’utente DB `arcade_admin`; non risultano attivati ruolo applicativo e `arcade.id_espositore` per richiesta. Va realizzato e provato l’accesso con privilegi minimi. Non risulta una tabella o un endpoint di registro audit per letture di dati personali e operazioni amministrative (RNF-04, issue [#30](https://github.com/stand-up-arcade-milan/Standup-platform/issues/30)).
- **Esplorazione API:** OpenAPI esiste e Redocly lo valida, ma il backend non include Swagger UI; aggiungere o decidere come soddisfare RNF-05.
- **Demo riproducibile:** i dati importati e il database sono locali e non versionati. Preparare seed non personali, utenti di prova e generazione ripetibile della giornata simulata richiesta da RNF-08; non distribuire gli export originali.
- **Calendario:** brief, Gantt e issue hanno date diverse per SAL 2 e presentazione finale. Il brief riporta demo SAL 2 13/11 e finale 4/12; Gantt e milestone Fase 4 riportano finale 17/12; issue #24 e #40 hanno periodi diversi dalle scadenze dei milestone. Stabilire un unico calendario.
- **Flussi da integrare:** chiarire se `/richieste/visitatore` e `/visitatori/registrazioni` restano entrambe, e se anagrafiche, stand, padiglioni e listino vengono gestiti da Power Apps o da un altro servizio.
- **Dipendenze operative:** prima dell’uso fuori dal locale, configurare OIDC/JWKS, invio email, generazione/archivio/download dei documenti e un ambiente di demo/deploy con segreti gestiti fuori dal repository.

Le differenze elencate nel commento del 7 novembre all’issue #10 su tabelle e campi vanno confrontate con le migrazioni V008–V014: parte di quel commento precede modifiche già presenti nel repository e non va riportata come difetto attuale senza una nuova verifica.
