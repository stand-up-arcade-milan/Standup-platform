# Registrazione visitatore

**Utenti:** visitatori · **Client:** React · **Priorità:** raccolta contatto prevista; profilazione estesa facoltativa.

## Contenuto

- Modulo breve: email e consenso richiesto per la finalità dichiarata; nome facoltativo.
- Link all'informativa privacy e spiegazione che registrarsi non acquista un biglietto.
- Se il flusso esteso viene approvato: provincia, fascia d'età, interessi e consensi separati; nessuna data di nascita.
- Collegamento alla biglietteria esterna per acquistare o recuperare il titolo d'ingresso.

## Azioni e API

- Inviare i dati minimi con `POST /richieste/visitatore`; usare `POST /visitatori/registrazioni` solo per il flusso di profilazione approvato.
- Mostrare conferma d'invio e link alla biglietteria esterna.

## Stati e privacy

- Campi non validi: indicare il campo e conservare quanto già inserito.
- Errore di rete: consentire un nuovo invio evitando di promettere che la richiesta sia stata registrata.
- Nessuna casella di consenso preselezionata; ottenere i consensi separatamente quando il flusso esteso è attivo.
- Non includere minori nei profili marketing. Il contratto attuale non definisce una vista autenticata per leggere o modificare la registrazione; il collegamento ai dati personali e la revoca vanno concordati prima di attivare questo flusso.
