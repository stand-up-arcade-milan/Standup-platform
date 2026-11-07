# Operatività evento

**Utenti:** staff autenticato · **Client:** React · **Priorità:** requisiti MVP RF-23 e RF-27.

## Contenuto

- Edizione/giornata attiva e ora dell'ultimo aggiornamento.
- Affluenza per ora, varco e padiglione; presenti e saturazione rispetto alla capienza.
- Avvisi operativi, in particolare padiglioni oltre la soglia configurata dell'80%.
- Turno, area assegnata e riepilogo delle attività autorizzate, se i dati vengono resi disponibili.

## Azioni e API

- Caricare serie aggregate da `GET /kpi/affluenza?edizione=&padiglione=&dal=&al=`.
- Caricare avvisi con `GET /avvisi?pubblico=STAFF`.
- Da questa pagina si può aprire la scansione allo stand o la verifica accessi secondo le autorizzazioni.

## Stati, visibilità e lacune

- Mostrare caricamento, dato in ritardo, assenza di letture e errore distinguendo zero da dato mancante.
- L'API limita i dati operativi al ruolo; niente dettagli commerciali o contatti personali.
- Il contratto OpenAPI non definisce ancora endpoint per turni/assegnazioni né per consultare lo stato dei varchi/eventi di accesso; servono per completare la pagina.
- Ogni avviso di saturazione deve mostrare padiglione, ora e soglia applicata, senza ricalcolare il KPI nel frontend.
