# Recupero password

**Utenti:** espositori · **Client:** React.

## Contenuto e azioni

- Campo email, azione per chiedere il link e ritorno al login.
- Inviare la richiesta a `POST /auth/password/recupero`.
- Mostrare sempre lo stesso esito generico: se l'account esiste, arriverà un link.
- Dal link, inviare il token monouso e la nuova password a `POST /auth/password/reimposta`; dopo il `204`, tornare al login.

## Stati e sicurezza

- Convalidare sintassi email senza confermare se l'indirizzo è registrato.
- Gestire invio in corso, richiesta presa in carico (`202`) e indisponibilità del servizio.
- La schermata consente di inserire il token ricevuto; la consegna email resta subordinata alla configurazione del provider e non va simulata dal client.
- Token scaduto o già usato: mostrare un errore non rivelatore e permettere di richiedere un nuovo link.
