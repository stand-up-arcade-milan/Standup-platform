# Login espositore

**Utenti:** espositori invitati e già attivati · **Client:** React.

## Contenuto e azioni

- Campi email e password, azione di accesso, collegamento al recupero password e informativa privacy.
- Invio a `POST /auth/login`; dopo l'autenticazione aprire l'area espositore e richiedere solo i dati dell'organizzazione associata all'account.
- Logout sempre disponibile nell'area riservata; cancellare la sessione lato client al logout o alla scadenza.

## Stati e sicurezza

- Usare messaggio generico per credenziali errate; gestire blocco temporaneo/limite `429` e sessione scaduta con ritorno al login.
- Account non ancora invitato: spiegare che gli account vengono creati dal flusso commerciale dopo la firma, non tramite registrazione libera.
- Nessun dato o token in URL, log o messaggi d'errore. La protezione dei dati resta applicata dal server, non solo dal router frontend.
- Commerciale, Direzione, Staff e Amministratore usano account interni/Entra ID se disponibile o utenti demo; il flusso di login interno non è specificato nel contratto OpenAPI attuale.
