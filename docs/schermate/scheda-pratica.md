# Scheda pratica commerciale

**Utenti:** Commerciale · **Client:** Power Apps · **Priorità:** requisito MVP RF-11–RF-14 e RF-17.

## Contenuto

- Organizzazione, edizione e responsabile commerciale.
- Stato della pratica: Bozza → Inviata → Firmata → Acconto ricevuto.
- Stand, superficie, prezzo da listino, sconto, totale e pacchetto BASE/PREMIUM.
- Documenti: offerta generata e contratto firmato archiviato su SharePoint.
- Acconti registrati, date e scadenze; azione rinnovo dall'edizione precedente quando applicabile.

## Azioni e API

- Consultare/creare: `GET /pratiche/{id}`, `POST /pratiche`.
- Cambiare stato: `PATCH /pratiche/{id}/stato` con transizioni consentite.
- Offerta e documenti: `POST /pratiche/{id}/offerta`, `GET /pratiche/{id}/documenti`.
- Registrare acconto: `POST /pratiche/{id}/acconti`; proposta di rinnovo: `POST /pratiche/{id}/rinnovo`.
- Creare lead magnet associato quando previsto: `POST /lead-magnet`.

## Regole e stati

- Non permettere transizioni non valide; visualizzare l'errore `409` per stand già assegnato o conflitto di stato.
- Sconto oltre il 10% richiede approvazione; sotto o uguale alla soglia segue il flusso ordinario.
- Prezzo e acconto sono importi registrati, non incassi online. Non dichiarare firmato finché la firma/documento non è verificato.
- La generazione Word, approvazione e SharePoint dipendono dall'integrazione Power Automate descritta nei requisiti.
