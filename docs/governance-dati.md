# Governance dei dati

Come il team **Stand up** gestisce i dati, in quattro fasi. Ogni fase indica che cosa è stato fatto e dove si trova.

## 1. Audit e mappa

Ogni fonte è stata inventariata, con i suoi formati e le sue incoerenze.

| Fonte | Edizioni | Formato | Incoerenze trovate |
|---|---|---|---|
| Biglietteria | 2024, 2025 | Nomi dei tipi diversi, provincia scritta in 3 modi | Tipi uniformati in 8 categorie, province in sigla |
| Tornelli | 2024, 2025 | 2024 con `;`, data italiana, esito 1/0. 2025 con `,`, data ISO, esito OK/KO, orari in UTC | Formato e fuso uniformati, 2.075 doppie letture rimosse, 70 codici inesistenti |
| Scanner stand | 2025 | Una riga per stand e ora | 70 fasce senza dato, 1 picco fuori orario |
| Contatti stand | 2025 | Una riga per contatto, con email | 14 minori, 9 senza consenso, 38 email incoerenti |

Il dettaglio è in [`dati-storici.md`](dati-storici.md). Il silo principale è l'assenza di un legame tra le fonti: i tornelli leggono un codice, la biglietteria lo vende, gli stand non sanno chi è entrato. Lo schema li collega con `codice_biglietto`, `id_ordine` e `anno`.

## 2. Pulizia e standardizzazione

Una pipeline ripetibile, [`importa_storici.py`](../scripts/dati/importa_storici.py): staging, controlli, trasformazione, riconciliazione. Gestisce i valori mancanti con `NON_DICHIARATO`, non inventa i dati assenti e non cancella le anomalie: le segnala con un flag sulla riga. Dopo ogni caricamento produce il [report di qualità](report-qualita-dati.md), con il confronto tra righe del file e righe del database e 15 controlli di integrità.

## 3. Classificazione e metadati

Il [dizionario dati](dizionario-dati.md) descrive ogni colonna: significato, tipo, titolare e livello di sensibilità. Vive anche nel database, nella tabella `arcade.dizionario_dati`, ed è generato da [`genera_dizionario.py`](../scripts/dati/genera_dizionario.py). La migrazione V005 fallisce se una colonna non ha descrizione, così il dizionario non resta indietro.

| Livello | Esempio | Regola |
|---|---|---|
| PUBBLICO | Padiglioni | Può comparire sul portale |
| INTERNO | Ordini, accessi | Solo organizzazione e team |
| RISERVATO | Fascia d'età, provincia, contatti dello stand | Solo aggregato, oppure solo il proprietario |
| PERSONALE | Email | Solo il responsabile dei dati |

## 4. Governo e sicurezza

Privacy by design nel database, non solo nell'applicazione.

| Ruolo | Che cosa vede |
|---|---|
| `arcade_espositore` | Solo pratiche, documenti, pagamenti, stand e contatti ammessi del tenant corrente; le email sono leggibili solo nei contatti che superano le regole di condivisione |
| `arcade_lettura` | Tabelle operative e storiche esplicitamente concesse; escluse email, registrazioni e richieste riservate |
| `arcade_dati_personali` | Dati personali solo per le operazioni applicative autorizzate e tracciate |

- **Minimizzazione.** Il registro dei biglietti non contiene nome né contatto del titolare. Le email stanno in `contatto_riservato`, separate dal resto.
- **Filtro per espositore.** Compose usa il login DB non proprietario `arcade_app` con `NOINHERIT`. Il controller imposta un ruolo tecnico con `SET LOCAL ROLE` dentro la transazione e valorizza `arcade.id_espositore`; le policy RLS limitano le query al tenant. V015–V023 applicano le policy runtime e isolano anche i contratti storici. La suite integrata prova lettura del tenant corretto e rifiuto della pratica per il tenant diverso (issue [#30](https://github.com/stand-up-arcade-milan/Standup-platform/issues/30)).
- **Audit.** Letture autorizzate di dati personali e operazioni amministrative registrano azione, ruolo, risorsa e riferimento pseudonimizzato. Non vengono registrati token, corpi richiesta, email o IP.
- **Minori.** I contatti di ragazzi di 14-17 anni non sono mai utilizzabili per il marketing, con un controllo automatico a ogni importazione.
- **Staging.** Si elimina a fine caricamento, perché contiene le email.
- **Repository.** I file CSV non si versionano. Il report di qualità contiene solo conteggi.

La verifica RLS è stata eseguita su un database di test sintetico. Il database storico `standup-import` e gli export personali restano separati. Prima dell'uso reale vanno definiti il periodo di conservazione e le procedure di rettifica/cancellazione con il titolare del trattamento.

## Decisioni

| Decisione | Motivo |
|---|---|
| Nessun vincolo tra `accesso.codice_biglietto` e `biglietto` | 70 codici letti ai varchi non esistono in biglietteria e vanno conservati come rifiuti |
| Orari in `timestamptz` con fuso Europe/Rome | I due anni di tornelli avevano fusi diversi |
| `giorno_valido` vuoto per i biglietti validi tutti i giorni | Evita il valore testuale «TUTTI» in una colonna data |
| Presenze stimate dagli ingressi delle ultime N ore, `ore_permanenza` in `parametri_stima` | Il file non ha le uscite, il parametro si cambia senza toccare il codice |
| Le fasce stand mancanti non si inventano | Sono dato reale: scanner spento o dato perso |
| Migrazioni numerate `V001__nome.sql` | Il nome è compatibile con Flyway, usato da Spring Boot |

## Da chiarire con il cliente

- Orario di registrazione dei biglietti: 10.846 risultano registrati dopo il primo ingresso.
- Regola dello sconto EARLY10 durante la fiera e a che cosa servono SCUOLA e STUDENTI.
- Il picco di 912 scansioni di P1-A02 il 19/12 alle 08:00.
- Superficie degli stand, costi e contratti: non presenti nei dati.
