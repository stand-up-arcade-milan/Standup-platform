# Integrazione BID–BAD e ambienti

## Scopo e contratto

Il contratto verificabile è docs/openapi.yaml. La collezione Postman postman/standup-platform-bid-bad.postman_collection.json contiene chiamate di prova e asserzioni; postman/standup-platform-local.postman_environment.json fornisce l'ambiente locale. Per request e response complete, schemi, ruoli ed errori, fanno fede OpenAPI e il codice Java allineato.

La direzione dello scambio è questa:

| Direzione | Chi chiama | API BID | Contenuto |
| --- | --- | --- | --- |
| Fatti in ingresso a BAD | BAD → BID | GET /api/v1/bi/dati/vendite | Biglietti, importi e canali, con riferimenti pseudonimizzati |
| Fatti in ingresso a BAD | BAD → BID | GET /api/v1/bi/dati/accessi | Esiti e orari dei varchi, senza QR in chiaro |
| Fatti in ingresso a BAD | BAD → BID | GET /api/v1/bi/dati/stand | Conteggi orari di visite, contatti e fonti |
| Fatti in ingresso a BAD | BAD → BID | GET /api/v1/bi/dati/commerciale | Superfici, importi e stato commerciale senza anagrafica |
| Qualità dei fatti | BAD → BID | GET /api/v1/bi/dati/qualita | Conteggi aggregati delle anomalie |
| KPI calcolati | BAD → BID | PUT /api/v1/integrazioni/bad/kpi/{batchId} | Lotto validato e conservato da BID |
| Visualizzazione | Clienti BID → BID | GET /api/v1/kpi/... | KPI pubblicati da BAD, senza ricalcolare le formule |

Al momento non è definita né implementata una API esterna esposta da BAD che BID debba chiamare. Il flusso concordato è BAD che legge i fatti BID e poi invia a BID i risultati calcolati. React, Power Apps e i report leggono i KPI dalle route BID. Se BAD propone in futuro un servizio distinto, prima si aggiunge al contratto base URL, autenticazione, schema, errori, retry e responsabilità di hosting.

## Lettura dei fatti da BAD

BAD autentica ogni richiesta con Authorization: Bearer token JWT del servizio BAD. Il ruolo è limitato alle route di integrazione e non equivale a un token utente. In ambiente locale si usano solo token sintetici di test, mai credenziali reali nel repository o nelle collection.

Per ogni export paginato, BAD invia edizione. Può richiedere limit da 1 a 500, predefinito 100. Se la risposta include page.nextCursor valorizzato, lo copia senza modificarlo nel parametro cursor della richiesta successiva. Non deve calcolare offset propri. Le risposte includono l'edizione e l'istante di estrazione. L'export qualità è invece un conteggio aggregato e il contratto corrente espone solo il filtro edizione.

Le viste di export escludono email, ragione sociale, partita IVA e QR in chiaro. I riferimenti ticket e ordine sono pseudonimizzati per consentire join limitati tra fonti senza rivelare il codice sorgente. I record commerciali usano riferimenti interni e non includono l'anagrafica. BAD non deve tentare di reidentificare persone né inviare identificativi personali nei KPI.

Regole di lettura importanti:

- Un accesso con esito INGRESSO_RIFIUTATO non è un visitatore entrato.
- visite null indica che la fonte non ha una misura; 0 indica una misura pari a zero.
- Le fasce orarie mancanti non sono conteggi zero.
- La proiezione stand evita di sommare fonti sovrapposte; il flag di qualità indica quando una fonte è stata preferita.
- Flag e conteggi qualità vanno mantenuti come metadati del calcolo, non trasformati in correzioni silenziose.
- Gli importi mancanti restano null e non sono ricostruiti per differenza.

## Invio dei KPI da BAD

BAD invia un lotto JSON a PUT /api/v1/integrazioni/bad/kpi/{batchId}, dove batchId è un UUID creato dal produttore. Lo stesso UUID si riusa solo quando si ritenta lo stesso identico lotto; per un nuovo calcolo, anche sulla stessa edizione, si crea un nuovo UUID.

Il corpo contiene edizione, calcolatoIl, formulaVersione e items. Ogni osservazione dichiara codice KPI, valore numerico, unità, edizione, intervallo facoltativo, dimensioni, data di calcolo, versione formula, fonti, qualità, flag, stimato, simulato e nota facoltativa. Edizione, istante di calcolo e versione formula di ogni elemento devono corrispondere ai metadati del lotto. Sono ammessi i codici e gli enum descritti in OpenAPI. Dimensioni sono codici di filtro quali padiglione, stand, categoria o canale: mai email, nomi o altri dati personali.

La risposta è 201 per un nuovo lotto e 200 con stato GIA_RICEVUTO per un UUID già acquisito. La collection prova anche il retry idempotente. Il contratto prevede 409 per conflitti, ma l'implementazione attuale riconosce il batch già presente senza confrontare il nuovo corpo con il corpo archiviato. Perciò BAD deve riusare l'UUID solo con il payload identico; va concordata una verifica del payload prima di usare la route per aggiornamenti correttivi.

Dopo l'invio, BAD può verificare i numeri con GET /api/v1/kpi/direzione, /affluenza, /stand/{codice}, /espositori/{id} e /lead-magnet. I client BID leggono le stesse route. Non duplicare le formule nelle interfacce.

## Definizioni KPI da allineare

L'issue GitHub #10 resta il punto di revisione BID–BAD. Prima di considerare i numeri ufficiali concordare per ciascun codice: definizione e unità, popolazione inclusa, finestra temporale e fuso, dimensioni ammesse, fonti, esclusioni, regole null/zero, comportamento per dati simulati e versione formula. In particolare restano da rendere espliciti visitatori unici rispetto agli ingressi, persone fermate e conversione, costo per contatto rispetto a costo per MQL, interesse pubblico, saturazione e ricavo per metro quadro.

## Errori e retry

Gli errori seguono il modello Problem di OpenAPI: status, code, title, requestId e, quando serve, detail ed errors per campo.

| HTTP | Interpretazione | Comportamento del client |
| --- | --- | --- |
| 400 | Parametro o payload non valido | Correggere il dato; non ripetere invariato |
| 401 | Token assente, scaduto o non valido | Rinnovare la credenziale del servizio |
| 403 | Token valido ma ruolo/ambito non ammesso | Fermarsi e chiedere correzione autorizzativa |
| 404 | Risorsa o route non disponibile | Verificare route, edizione e ambito |
| 409 | Conflitto applicativo/idempotenza | Verificare lo stato prima di ritentare |
| 429 | Limite temporaneo | Rispettare Retry-After se presente e applicare backoff |
| 500 | Errore server | Ritentare con backoff limitato, conservando requestId per diagnosi |

Non inserire token o corpi contenenti dati sensibili nei log. Per una segnalazione tecnica condividere requestId, route, timestamp e codice errore.

## Sviluppo: ciascuno lavora sul proprio PC

Durante lo sviluppo non esiste un server sempre acceso né una LAN condivisa. Ogni membro avvia il proprio stack Docker Compose:

| Servizio | Porta host predefinita | Uso |
| --- | ---: | --- |
| React/Vite | 5173 | Browser locale su http://localhost:5173 |
| Spring Boot | 8080 | API locale su http://localhost:8080/api/v1 |
| PostgreSQL | 5432 | Solo loopback della macchina; non è accesso per i client |

Ogni PC ha il proprio database e le proprie fixture. localhost indica sempre il PC corrente: un client BAD sul portatile di un altro membro non raggiunge il tuo localhost. Per sviluppare in parallelo si usa il contratto OpenAPI, i dati sintetici e la collection Postman; non si dipende da un servizio condiviso.

Avvio normale:

    docker compose up --build

La Vite dev server inoltra /api e /actuator al backend attraverso la rete interna Compose. BAD che esegue Postman direttamente usa invece l'URL API locale del proprio PC e il token sintetico previsto dall'ambiente di test.

## Demo: un portatile host sulla stessa LAN

Per una demo in presenza scegliamo un portatile come host temporaneo. Il portatile deve restare acceso e collegato alla rete; se va in sospensione, gli altri perdono l'accesso. Verificare che il Wi-Fi consenta il traffico tra dispositivi: alcune reti scolastiche isolano i client. Il database rimane privato all'host e i membri accedono tramite browser o client API.

1. Copiare demo.env.example in .env.demo, ignorato da Git.
2. Impostare API_BIND_ADDRESS e WEB_BIND_ADDRESS all'IPv4 privato del portatile host, rilevabile con ipconfig. Lasciare PostgreSQL legato a 127.0.0.1.
3. Sostituire tutte le password e il segreto JWT con valori casuali di demo; non riutilizzare password personali. Lasciare attivi i token locali soltanto per dati e account fittizi.
4. Avviare Docker Desktop e i servizi:

       docker compose --project-name standup-demo --env-file .env.demo up --build -d

5. Gli altri membri aprono http://IP-LAN-HOST:5173. Un client Postman sulla stessa rete usa http://IP-LAN-HOST:8080/api/v1. Il browser parla al frontend e Vite inoltra le richieste al backend sulla rete Compose.
6. Consentire le porte 5173 e 8080 solo sul profilo Windows Firewall Privato e sulla rete della demo. Non pubblicare PostgreSQL, non configurare port forwarding sul router e usare dati sintetici.
7. A demo conclusa:

       docker compose --project-name standup-demo --env-file .env.demo down

Non aggiungere -v: il volume del database viene mantenuto.

L'host espone l'API a dispositivi della LAN. Il firewall deve limitare l'accesso alla rete di demo; il binding delle porte sono sull'IPv4 privato specifico e il DB resta su loopback. Non usare questo ambiente per dati reali o come servizio persistente.

## Power Apps e Power BI in cloud

La rete Wi-Fi condivisa permette ai laptop di raggiungere l'host, ma non instrada automaticamente il traffico dei servizi Microsoft cloud verso il suo indirizzo privato. I custom connector possono descrivere l'API tramite OpenAPI o Postman; per API private Microsoft documenta il gateway dati locale. Per Power BI Service il gateway può servire anche all'aggiornamento dei report che usano connettori custom.

Il tenant scolastico, le licenze, i permessi amministrativi, il gateway disponibile e l'autenticazione compatibile non sono verificati. Quindi la demo via Power Apps/Power Automate/Power BI cloud resta subordinata a una prova con l'amministratore del tenant. Se non è disponibile un gateway autorizzato, mostrare React e Postman sulla LAN e non rendere pubblica l'API per aggirare il vincolo.

Riferimenti Microsoft: [custom connector e API private](https://learn.microsoft.com/en-us/connectors/custom-connectors/), [gateway in Power BI Service per connettori custom](https://learn.microsoft.com/en-us/power-bi/connect-data/service-gateway-custom-connectors).
