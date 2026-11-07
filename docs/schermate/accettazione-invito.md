# Accettazione invito espositore

**Utenti:** referente espositore invitato dopo la firma del contratto · **Client:** React.

## Contenuto e azioni

- Conferma dell'indirizzo destinatario senza esporre informazioni non necessarie.
- Campi per impostare e confermare la password; link all'informativa privacy.
- Inviare il token monouso e la password a `POST /auth/invito/accetta`; all'esito aprire l'area espositore.

## Stati e sicurezza

- Token valido: mostrare conferma dell'attivazione.
- Token scaduto, già usato o non valido: spiegare come chiedere un nuovo invito al referente commerciale; non riprovare automaticamente.
- Gestire `400`, `404` e `409` con messaggi comprensibili senza rivelare dati di altri account.
- La scadenza e l'uso singolo del link sono regole del flusso; il contratto API va mantenuto coerente con esse.
