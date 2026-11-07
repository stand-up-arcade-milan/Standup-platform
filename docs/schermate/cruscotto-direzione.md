# Cruscotto direzionale

**Utenti:** Direzione · **Client:** Power BI · **Priorità:** requisito MVP RF-30.

## Filtri e contenuti

- Filtri per edizione (2024/2025/2026), giornata e, quando applicabile, area/fonte.
- KPI principali: visitatori, biglietti venduti e persone uniche; picco di presenza; saturazione; visitatori per m²; ricavo per m²; costo per MQL.
- Andamento accessi per giorno/fascia, confronto tra edizioni, stato vendite/stand e qualità/fonte dei dati.
- Avvisi da verificare, timestamp ultimo aggiornamento e indicazione di dati stimati o simulati.

## Fonte e definizioni

- La bozza API espone `GET /kpi/direzione?edizione=&dal=&al=`; i risultati devono includere formula, fonte, aggiornamento e qualità.
- Il calcolo appartiene a BAD; BID conserva/serve i risultati concordati. Power BI non deve inventare formule diverse.
- Usare la definizione in [Requisiti MVP, KPI](../requisiti-mvp.md#indicatori); distinguere visitatori, biglietti venduti e persone uniche.
- I numeri del wireframe nel blueprint sono segnaposto e non vanno mostrati come risultati.

## Sicurezza e stati

- Solo Direzione e ruoli autorizzati; applicare sicurezza anche nel dataset Power BI.
- Mostrare “non disponibile” o “dato stimato” quando la fonte non consente una misura reale; non equiparare zero a dato assente.
- Evidenziare copertura incompleta, ritardo di aggiornamento e confronto non omogeneo tra edizioni.
