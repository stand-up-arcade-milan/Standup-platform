# Area espositore

**Utenti:** espositore autenticato · **Client:** React · **Priorità:** requisito MVP RF-31.

## Contenuto

- Saluto, nome pubblico/azienda, edizione e logout.
- Riquadro **Il mio stand**: codice, padiglione, superficie e link alla mappa.
- Riquadro **Il mio contratto**: pratica e stato (Bozza, Inviata, Firmata, Acconto ricevuto), documenti disponibili e servizi/pacchetto.
- Riquadro **Riepilogo**: KPI consentiti, con confronto all'edizione precedente solo se comparabile; stima peso solo per PREMIUM.
- Avvisi destinati agli espositori.

## Azioni e API

- Profilo: `GET /espositori/me`.
- Contratto/documenti: `GET /espositori/me/contratto?edizione=`.
- KPI dell'organizzazione/stand: `GET /kpi/espositori/{id}?edizione=` e `GET /kpi/stand/{codice}?edizione=`.
- Stima dal peso, solo PREMIUM: `GET /espositori/me/presenze-peso?edizione=&dal=&al=`.
- Avvisi: `GET /avvisi?pubblico=ESPOSITORI`.

## Stati e sicurezza

- Ogni riquadro gestisce caricamento, dati non ancora disponibili, errore e accesso negato.
- La pagina resta utile anche se non c'è uno stand o il post-fiera non è ancora disponibile: spiegare il passo successivo, senza valori segnaposto spacciati per reali.
- L'API limita tutte le richieste all'organizzazione autenticata. Nascondere KPI o pulsanti non sostituisce il controllo server.
- BASE non deve ricevere la stima dal peso né poterla ottenere chiamando direttamente l'API.
