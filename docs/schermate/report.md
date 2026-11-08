# Report

**Utenti:** direzione e ruoli autorizzati. **Client:** Power BI o il client report concordato. **Proprietà dei calcoli:** BAD.

La struttura funzionale, le sorgenti, i filtri e le regole di riconciliazione sono descritte in [struttura-report.md](../struttura-report.md). I report consumano i KPI restituiti da `/kpi/*` e i fatti BID esposti da `/bi/dati/*`; non replicano le formule BAD.

Ogni visualizzazione mostra edizione, periodo, filtri, fonte, versione formula, aggiornamento, qualità e flag disponibili. Il report separa affluenza, espositori/stand, lead magnet, qualità e confronto tra edizioni. Non mostra email, QR, identificativi individuali o altri dati personali.

I filtri KPI disponibili includono edizione, intervallo temporale, fonte e le dimensioni consentite dalla specifica rotta. I fatti BID si estraggono per edizione e paginazione e possono essere filtrati localmente per periodo/stand. Valori nulli indicano dato non disponibile; non vanno convertiti in zero. Le edizioni sono confrontate solo quando copertura e definizioni sono compatibili.