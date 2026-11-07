# Elenco espositori

**Utenti:** visitatori e staff · **Client:** React · **Priorità:** ricerca e filtri sono requisito facoltativo RF-33.

## Contenuto

- Ricerca per nome, filtro per categoria con conteggio e risultati paginati.
- Elementi in evidenza, se il servizio è previsto per l'edizione e il relativo dato è disponibile.
- Filtri di interesse e preferiti locali nel browser, se confermati: non richiedono un account visitatore.

## Azioni e API

- Cercare e filtrare con `GET /espositori?q=&categoria=&edizione=`.
- Caricare categorie e conteggi con `GET /espositori/categorie?edizione=`.
- Aprire la scheda pubblica dell'espositore.

## Stati e privacy

- Mostrare risultati, nessun risultato, caricamento, errore e paginazione.
- Esporre solo informazioni marcate pubbliche; i contatti dipendono dalla scelta di visibilità dell'espositore.
- Il contratto attuale espone un filtro categoria singolo; filtri multipli e ordinamento per interesse richiedono conferma/aggiornamento del contratto.
