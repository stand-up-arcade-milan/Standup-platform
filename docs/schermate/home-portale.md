# Home del portale

**Utenti:** visitatori e potenziali espositori · **Client:** React · **Priorità:** ingresso pubblico dell'MVP.

## Contenuto

- Nome, logo, edizione attiva, date e sede, letti dai dati dell'edizione.
- Due azioni di pari rilievo: **Registrati come visitatore** e **Richiedi uno stand**.
- Numeri chiave della precedente edizione disponibili e approvati alla pubblicazione: visitatori, espositori e stand.
- Accesso all'elenco espositori, alla mappa e agli avvisi per il pubblico.
- Accesso espositore ben visibile.

## Azioni e dati

- Aprire la registrazione visitatore o il modulo di richiesta stand.
- Cambiare edizione e consultare informazioni pubbliche.
- Leggere gli avvisi con pubblico `VISITATORI`.
- API previste: `GET /edizioni`, `GET /avvisi?pubblico=VISITATORI`. I numeri storici devono provenire da dati pubblici approvati; il contratto non definisce ancora un endpoint dedicato per questi tre contatori.

## Stati e regole

- Se non esistono statistiche pubblicabili, nascondere il blocco o dichiarare chiaramente che i dati non sono disponibili; niente numeri inventati.
- Mostrare edizione, date e sede coerenti anche quando si cambia pagina.
- Non vendere né emettere biglietti: il pulsante relativo rimanda alla biglietteria esterna.
- Banner cookie solo se necessario; se sono usati solo cookie tecnici, informare nella documentazione privacy.
