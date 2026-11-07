# Verifica biglietti e accessi

**Utenti:** staff autorizzato; lettori/simulatori ai varchi · **Client:** dispositivo o interfaccia operativa da definire · **Priorità:** RF-20/RF-21.

## Contenuto e azioni

- Identificazione del varco/dispositivo e campo di lettura QR.
- Esito immediato: ingresso consentito o rifiutato, motivo, orario e numero di persone.
- Registrare ciascuna lettura con `POST /accessi`; il sistema deve rifiutare biglietti non validi, già usati o fuori giorno.

## Stati e limiti del contratto

- Gestire ingresso valido, non valido, già usato, fuori giorno, rete non disponibile e dispositivo non autenticato.
- Un evento rifiutato resta registrato come esito, non va confuso con un errore tecnico.
- **Gap da risolvere:** OpenAPI autorizza `POST /accessi` con credenziale dispositivo, ma non definisce un endpoint o una UI staff per verificare/ricercare un biglietto, né specifica i motivi puntuali nel modello di risposta. Non implementare una ricerca o bypass client senza aggiornare il contratto.
- L'emissione e vendita del biglietto restano alla biglietteria esterna; questo flusso verifica l'accesso.
