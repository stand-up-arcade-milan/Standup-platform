# Contatti e lead dell'espositore

**Utenti:** espositore autenticato · **Client:** React · **Priorità:** consegna MQL RF-36.

## Contenuto

- Elenco paginato dei soli contatti autorizzati raccolti presso gli stand dell'organizzazione.
- Quando disponibile, lead magnet d'origine e informazioni utili a distinguere i contatti qualificati.
- Riepilogo del periodo/edizione e definizione di MQL; non mostrare minori o contatti senza i consensi richiesti.

## Azioni e API

- Caricare con `GET /espositori/me/contatti?edizione=&limit=&cursor=`.
- La ricerca, esportazione o download non sono definiti nei requisiti/API attuali: aggiungerli solo dopo una decisione privacy e contrattuale.

## Stati e privacy

- Distinguere lista vuota, caricamento, errore e pagina successiva.
- La risposta e la UI devono rispettare adultità, consenso, interesse e lead magnet previsti dalla definizione MQL.
- Mai esporre contatti appartenenti ad altri espositori. Il controllo è lato API/database; non basarsi su filtri client.
- La retention e la revoca del consenso devono essere definite prima di rendere disponibili dati identificativi.
