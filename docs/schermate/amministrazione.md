# Configurazione e avvisi

**Utenti:** Amministratore · **Client:** interfaccia da definire · **Priorità:** funzioni amministrative MVP.

## Contenuto

- Gestione edizioni: anno, date, sede e stato.
- Parametri per edizione: peso medio, soglia rumore, persone per m² e soglia avviso. La tara non è inclusa nello schema `ParametriEdizione` attuale e va concordata.
- Creazione, modifica e disattivazione degli avvisi di servizio, scegliendo pubblico `VISITATORI`, `ESPOSITORI` o `STAFF`.
- Riepilogo delle modifiche amministrative e collegamento al registro di audit.

## Azioni e API

- Edizione: `PUT /admin/edizioni/{anno}`.
- Parametri: `PATCH /admin/edizioni/{anno}/parametri`.
- Avvisi: `POST /avvisi`, `PATCH /avvisi/{id}`; elenco tramite `GET /avvisi?pubblico=`.

## Sicurezza e stati

- Accesso solo Amministratore con autenticazione interna; ogni modifica deve essere tracciata.
- Richiedere conferma prima di salvare parametri e pubblicare avvisi; mostrare autore/ora secondo i dati restituiti.
- Gestire errore di validazione, conflitto, edizione inesistente e accesso negato.
- Il contratto non definisce ancora endpoint per gestire utenti/ruoli o leggere il registro audit: non aggiungere queste azioni alla UI finché non sono specificate.
