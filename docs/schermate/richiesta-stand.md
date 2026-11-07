# Richiesta di stand

**Utenti:** potenziali espositori · **Client:** React · **Priorità:** requisito facoltativo RF-15.

## Contenuto

- Azienda, referente, email, categoria, superficie desiderata e consenso/informativa.
- Edizione per cui si chiede lo stand; scelta preimpostata sull'edizione attiva.
- Messaggio che spiega che l'invio è una richiesta e non una prenotazione o un'assegnazione.

## Azioni e API

- Validare i campi e inviare con `POST /richieste/espositore`.
- L'API crea una richiesta e una pratica in stato Bozza; mostrare il riferimento restituito e la conferma.

## Stati e permessi

- Gestire caricamento, errori di validazione, conflitto `409` e indisponibilità del servizio.
- Non mostrare listino riservato o dati di altri espositori.
- Il commerciale vede e prende in carico la richiesta nel back office; il visitatore non può modificarne lo stato.
