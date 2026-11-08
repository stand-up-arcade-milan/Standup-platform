# Punti da chiudere

Promemoria per la revisione complessiva del lavoro. Sono decisioni o integrazioni esterne ancora necessarie, non dati da indovinare.

## Import storico

- L'importazione e la riconciliazione sono completate nel volume Docker locale del progetto Compose `standup-import`; il report aggregato è in `report-qualita-dati.md`.
- Stack attualmente esposto solo su localhost: PostgreSQL `55432`, API `18080`, frontend `15173`. Per riprodurlo, avviare Compose con `POSTGRES_PORT=55432`, `API_PORT=18080`, `WEB_PORT=15173`, `POSTGRES_USER=arcade_admin` e `POSTGRES_PASSWORD=arcade_dev_only`, poi eseguire `python scripts/dati/importa_dataset.py` con `DATABASE_URL=postgresql://arcade_admin:arcade_dev_only@localhost:55432/arcade`.
- Il database e i file cliente sono locali e non versionati. Un clone non contiene tali dati; per importarli servono le fonti ricevute separatamente.
## Identità e notifiche

- Confermare issuer, audience, URI JWKS e mapping dei ruoli per Entra ID, BAD e dispositivi. I ruoli aziendali possono autenticarsi con OIDC/JWKS RS256 se configurato. Gli account espositore usano token HS256 emessi dopo verifica password; i token interni HS256 richiedono l’opzione esplicita di sviluppo locale.
- Configurare l’invio email per inviti e recupero password. Gli endpoint conservano token monouso con scadenza; senza un provider non possono consegnare il link all’utente.

## Documenti commerciali

- La generazione PDF delle offerte, l’archiviazione in PostgreSQL con hash SHA-256 e i download autorizzati sono implementati e verificati. Alla transizione di stato `FIRMATA` viene archiviato un riepilogo informativo, non l’originale firmato.
- Concordare il modello legale e il template del documento contrattuale ufficiale, il processo per ricevere/verificare la firma e i campi fiscali richiesti. I PDF applicativi non costituiscono una firma elettronica o un sostituto del documento ufficiale.

## Dati e integrazione

- Confermare con BAD le dimensioni JSON ufficiali dei KPI (codice stand/espositore) e la lista dei ruoli effettivi per client, dispositivi e Power Apps.
- La fonte commerciale non fornisce date di fiera 2026: l’edizione resta pianificata senza date finché non vengono comunicate.


## Verifiche aggiunte al 08/11/2026

- **KPI e API BID–BAD:** chiudere in [issue #10](https://github.com/stand-up-arcade-milan/Standup-platform/issues/10) il nome `costo_per_mql` rispetto a `costo_per_contatto` e definire quota MQL, persone ferme e visitatori unici. Le proiezioni ora restituiscono contatti, contatti con consenso, persone ferme e fatti commerciali minimizzati; la suite verifica queste letture con dati sintetici. BAD deve confermare se i dati BID disponibili bastano per le formule approvate (in particolare costi per edizione, capienza e aggregati lead magnet/interesse) e formalizzare fonti, formule e dimensioni prima di chiudere il contratto.
- **Scansioni e consensi:** la suite prova consensi, fascia adulta, lead magnet valido, duplicati e mancata acquisizione in assenza di consenso. Resta da confermare con BAD la definizione organizzativa di MQL e l'allineamento fra interesse dichiarato e criteri KPI.
- **Schema pubblico:** separare lo schema pubblico `Stand` da quello interno: il contratto riusa `Stand` con `prezzoListinoEur` su risposte pubbliche (`/mappa`, profilo espositore), anche se il controller attuale restituisce il prezzo nullo.
- **RLS e audit:** V015–V023 attivano ruoli runtime non proprietari, `SET LOCAL ROLE`, isolamento tenant per espositore, policy per contratti storici e registro audit. La suite prova accesso ai documenti del proprio tenant e rifiuto per un tenant diverso. L’implementazione tecnica è presente; restano accettazione dell’issue [#30](https://github.com/stand-up-arcade-milan/Standup-platform/issues/30), requisiti aggiuntivi di audit e le decisioni del titolare su conservazione/rettifica/cancellazione.
- **Esplorazione API:** OpenAPI esiste e Redocly lo valida, ma il backend non include Swagger UI; aggiungere o decidere come soddisfare RNF-05.
- **Demo riproducibile:** esiste un fixture SQL sintetico per il test delle rotte e dei flussi; non sostituisce ancora una demo didattica completa con giornata simulata e utenti gestibili da RNF-08. I dati importati restano locali e non versionati; non distribuire gli export originali.
- **Calendario:** brief, Gantt e issue hanno date diverse per SAL 2 e presentazione finale. Il brief riporta demo SAL 2 13/11 e finale 4/12; Gantt e milestone Fase 4 riportano finale 17/12; issue #24 e #40 hanno periodi diversi dalle scadenze dei milestone. Stabilire un unico calendario.
- **Flussi da integrare:** chiarire se `/richieste/visitatore` e `/visitatori/registrazioni` restano entrambe, e se anagrafiche, stand, padiglioni e listino vengono gestiti da Power Apps o da un altro servizio.
- **Dipendenze operative:** prima dell’uso fuori dal locale, configurare issuer/audience/JWKS OIDC, invio email e ambiente demo/deploy con segreti esterni al repository; concordare modello e procedura di firma del contratto ufficiale.

La suite locale `scripts/test/run-integration.ps1` e la CI esercitano 56/56 operationId in 70 richieste, i tre percorsi applicativi, la riconciliazione scanner/commerciale/portale, 15 test Java e 8 richieste Newman con 25 asserzioni. Non simulano il browser fisico, Power Platform o provider reali. Per modalità e limiti, vedere [ci-cd.md](ci-cd.md).

Le differenze elencate nel commento del 7 novembre all’issue #10 su tabelle, campi e idempotenza vanno confrontate con lo schema corrente e le migrazioni V001–V023: parte del commento precede modifiche già presenti nel repository e non va riportata come difetto attuale senza una nuova verifica.
