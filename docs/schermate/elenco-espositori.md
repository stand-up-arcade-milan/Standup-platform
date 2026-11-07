# Elenco espositori

**Utenti:** visitatori e staff · **Client:** React · **Priorità:** ricerca e filtri sono requisito facoltativo RF-33.

## Contenuto

- Ricerca per nome, filtro per categoria con conteggio e risultati paginati.
- Elementi in evidenza, se il servizio è previsto per l'edizione e il relativo dato è disponibile.
- Filtri di interesse e preferiti locali nel browser, se confermati: non richiedono un account visitatore.

## Azioni e API

- Cercare e filtrare con `GET /espositori?q=&categorie=&edizione=`; ripetere `categorie` per selezioni multiple.
- Caricare categorie e conteggi con `GET /espositori/categorie?edizione=`.
- Aprire la scheda pubblica dell'espositore.

## Stati e privacy

- Mostrare risultati, nessun risultato, caricamento, errore e paginazione.
- Esporre solo informazioni marcate pubbliche; i contatti dipendono dalla scelta di visibilità dell'espositore.
- Le categorie di interesse restano nel browser. L'API filtra per le categorie selezionate; l'ordinamento per interesse può essere applicato ai risultati senza inviare preferenze personali.
