# Back office commerciale

**Utenti:** Commerciale · **Client:** Power Apps · **Priorità:** flusso commerciale MVP.

## Vista iniziale

- Richieste nuove da lavorare e pratiche assegnate, con ricerca e filtro per edizione/stato.
- Indicatori operativi solo se derivabili dai dati disponibili: conteggio pratiche per stato e stand liberi; non introdurre previsioni o KPI non definiti.
- Accessi alle aree **Pratiche**, **Stand e listino**, **Espositori** e **Rinnovi**.

## Azioni e API

- Caricare richieste da `GET /richieste?stato=&limit=&cursor=` e pratiche da `GET /pratiche?edizione=&stato=&limit=&cursor=`.
- Aprire la scheda di una pratica o la disponibilità stand.
- Chiamare l'API BID con identità interna; l'interfaccia Power Apps non diventa fonte alternativa dei dati.

## Stati e permessi

- Gestire liste vuote, paginazione, errore e accesso negato; mostrare edizione e stato sempre espliciti.
- Il commerciale vede solo organizzazioni e pratiche assegnate secondo il requisito di ruolo.
- I pagamenti online e la firma digitale non fanno parte del perimetro: qui si registra l'acconto e si consulta il documento archiviato.
- Autenticazione Power Apps/Entra e configurazione connettore devono essere concordate; la specifica OpenAPI prevede `internalBearer`.
