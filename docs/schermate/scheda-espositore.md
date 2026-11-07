# Scheda pubblica espositore

**Utenti:** visitatori e staff · **Client:** React.

## Contenuto

- Nome pubblico, categorie, descrizione e marchi quando forniti e autorizzati alla pubblicazione.
- Stand e padiglione per l'edizione scelta; indicazione se l'assegnazione non è ancora disponibile.
- Sito, email o telefono soltanto se l'espositore li ha resi pubblici.
- Collegamento allo stand sulla mappa.

## Azioni e API

- Recuperare i dati con `GET /espositori/{id}?edizione=`.
- Aprire la mappa interattiva sul padiglione/stand.

## Stati e privacy

- Gestire caricamento, espositore non trovato (`404`), dato non pubblicato e indisponibilità del servizio.
- Non mostrare documenti contrattuali, dati di contatto riservati, contatti acquisiti o KPI non pubblici.
- Allineare la scheda ai campi effettivamente presenti nello schema `EspositorePubblico` prima dell'implementazione: logo, prodotti e marchi sono richiesti dal documento frontend ma non sono tutti esplicitati nell'attuale schema OpenAPI.
