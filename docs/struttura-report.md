# Struttura dei report

## Principi

Il report usa i KPI già calcolati e inviati da BAD. BID conserva e restituisce osservazioni, fonti e metadati; né Power BI né le schermate React devono ricalcolare formule o ricostruire valori mancanti. La decisione evita divergenze tra i numeri della direzione, l'area espositore e i report condivisi.

Ogni KPI deve mostrare valore e unità, edizione e intervallo, dimensioni applicate, fonte, versione formula, data di calcolo, qualità, flag, stima/simulazione e nota quando presente. Un valore assente resta distinto da zero.

## Pagine e contenuti

1. **Sintesi direzionale** — accessi effettivi, presenze/picco, saturazione, vendite e indicatori economici approvati da BAD. Mostrare l'ultimo aggiornamento e la qualità per ogni indicatore.
2. **Affluenza e operatività** — serie per ora, padiglione e fonte; confrontare gli ingressi effettivi con le stime solo se i metadati le qualificano come stimate. Le letture rifiutate non sono ingressi.
3. **Espositori e stand** — stati e superfici commerciali, visite registrate, contatti e contatti condivisibili. Separare le edizioni e mostrare le fonti sovrapposte o non rilevate.
4. **Lead magnet** — MQL, interesse e resa esclusivamente dai KPI BAD; non mostrare contatti o email individuali.
5. **Qualità e confronto edizioni** — conteggi delle anomalie per fonte, aggiornamento, dati simulati/stimati e differenze di copertura. Il confronto 2024/2025/2026 deve segnalare i periodi o le fonti non confrontabili.

## Fonti e riconciliazione

| Dato visualizzato | Fonte autorevole | Riconciliazione |
|---|---|---|
| KPI e serie approvate | `GET /kpi/direzione`, `/kpi/affluenza`, `/kpi/stand/{codice}`, `/kpi/espositori/{id}`, `/kpi/lead-magnet` | Leggere `KpiObservation` senza ricalcolare. Applicare edizione, intervallo e dimensioni restituite. |
| Vendite | `GET /bi/dati/vendite` | Quantità e importi derivano dai fatti biglietteria; riferimenti ticket e ordine sono pseudonimizzati. |
| Accessi | `GET /bi/dati/accessi` | Distinguere `INGRESSO` e `INGRESSO_RIFIUTATO`; un riferimento non abbinato resta identificabile come pseudonimo, non come ticket in chiaro. |
| Visite e contatti orari stand | `GET /bi/dati/stand` | `visite` è null se non c'è una fonte di visite. Se scanner e storico coprono lo stesso stand/ora, si usa il conteggio scanner e si espone `SCANNER_PREFERITO_FONTE_SOVRAPPOSTA`; non si sommano fonti potenzialmente duplicate. |
| Stato e importi commerciali | `GET /bi/dati/commerciale` | I totali firmati importati restano autorevoli; per le nuove pratiche valgono le righe salvate. Acconti non dichiarati e saldo non tracciato restano null, mai ricostruiti per differenza. |
| Anomalie | `GET /bi/dati/qualita` | Usare i conteggi per fonte e flag per spiegare esclusioni o copertura incompleta. |
| Lead individuali condivisibili | `GET /espositori/me/contatti` | Solo l'espositore autenticato riceve i propri lead ammessi; i report aggregati non devono contenere email, ticket, identificativi di contatto o nominativi. |

Per la riconciliazione dello scanner, il totale non duplicato per stand/ora nell'export deve corrispondere al conteggio registrato dal flusso di scansione. Il totale dei `contattiConConsenso` deve corrispondere ai lead che soddisfano entrambe le condizioni di consenso, fascia adulta, idoneità marketing e, dal 2026, lead magnet valido. I dati storici privi del consenso esplicito alla condivisione non diventano lead condivisibili.

Per la riconciliazione commerciale, confrontare stato e imponibile netto con il back office e il portale espositore. L'importo degli acconti è la somma dei soli pagamenti registrati; il saldo non è modellato né esportato come importo pagato. L'assenza di un importo storico resta un'anomalia documentata.

## Filtri e copertura

Le route KPI accettano `edizione`, `dal`, `al` e, dove applicabile, `padiglione`, `fonte` o l'identificativo di stand/espositore. Il filtro `fonte` corrisponde ai valori dichiarati da BAD nel campo `KpiObservation.fonte`. Le route `/bi/dati/*` accettano edizione e paginazione; Power BI può filtrare i fatti per intervallo e stand dopo l'estrazione.

Non presentare come zero un intervallo senza misurazioni. Non sommare le letture di diversi sensori come persone uniche. Le formule di permanenza, conversione, saturazione, costo per contatto/MQL e ricavo per metro quadro restano di BAD e devono riportare la versione formula concordata.

## Decisioni provvisorie

- La proiezione oraria preferisce i dati scanner granulari quando esistono fonti storiche sovrapposte, dichiarando la scelta nel flag.
- La tabella dei report commerciali espone gli importi firmati storici e i pagamenti effettivamente registrati, senza inferenze su importi mancanti.
- L'allineamento dei codici KPI e delle definizioni tra BID e BAD resta soggetto alla revisione del contratto API; il report non assegna nuove formule.