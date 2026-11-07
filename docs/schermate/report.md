# Report

**Utenti:** Direzione e ruoli autorizzati · **Client:** Power BI · **Priorità:** KPI/report MVP.

## Viste

- **Accessi e affluenza:** ingressi validi, andamento per ora/varco, picco di presenza, presenti e saturazione per padiglione.
- **Espositori e stand:** contratti/stati, stand venduti e disponibilità residua, ricavo per m², visite/contatti e conversione per stand.
- **Lead magnet:** MQL per lead magnet e resa (`GET /kpi/lead-magnet`).
- **Qualità e fonti:** aggiornamento, qualità, simulazioni/stime e anomalie rilevanti per interpretare i numeri.
- **Confronto edizioni:** 2024, 2025 e 2026 solo con periodi e definizioni confrontabili.

## Filtri, API e definizioni

- Filtri richiesti: edizione, giornata, area e fonte; ogni filtro selezionato deve essere visibile nell'intestazione del report.
- API attuali: `GET /kpi/affluenza`, `GET /kpi/stand/{codice}`, `GET /kpi/lead-magnet`, `GET /kpi/direzione`. Per la vista complessiva non duplicare in Power BI le formule BAD.
- Ogni KPI mostra definizione, formula, fonte e data aggiornamento. Definizioni e limiti sono nel [catalogo KPI](../requisiti-mvp.md#indicatori).

## Accesso e lacune

- Direzione consulta dati aggregati; commerciale/staff solo i report autorizzati al proprio ruolo.
- La bozza OpenAPI non definisce endpoint distinti per tutti i report commerciali/qualità né parametri uniformi per area e fonte: accordare il modello con BAD prima di fissare i visual.
- Non mostrare dettagli personali dei visitatori nei report aggregati.
