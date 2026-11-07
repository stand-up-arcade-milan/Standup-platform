# Recupero password

**Utenti:** espositori · **Client:** React.

## Contenuto e azioni

- Campo email, azione per chiedere il link e ritorno al login.
- Inviare la richiesta a `POST /auth/password/recupero`.
- Mostrare sempre lo stesso esito generico: se l'account esiste, arriverà un link.

## Stati e sicurezza

- Convalidare sintassi email senza confermare se l'indirizzo è registrato.
- Gestire invio in corso, richiesta presa in carico (`202`) e indisponibilità del servizio.
- Il contratto attuale definisce la richiesta di recupero, non la pagina/API di reimpostazione tramite link: completare questa parte del flusso prima di considerare la funzione pronta.
