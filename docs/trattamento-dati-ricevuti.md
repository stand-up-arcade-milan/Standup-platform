# Trattamento dei dati ricevuti

## Perimetro

Gli archivi consegnati per lo sviluppo contengono dati personali o identificativi (per esempio email, partita IVA e codici ticket). Anche quando il brief li qualifica come dataset di esercitazione, li trattiamo con le cautele previste dal modello dati e non li distribuiamo nel repository. Questo documento descrive la copia locale e la pipeline attuale, non una base legale per un trattamento in produzione.

## Dove si trovano

| Livello | Percorso/oggetto | Stato |
| --- | --- | --- |
| Sorgenti ricevute | dati-storici/originali/ARCADE_Milano_dati/ | Locale, escluso da Git; contiene CSV e ARCADE_Commerciale.xlsx |
| Dati uniformati | dati-storici/normalizzati/ | Locale, escluso da Git; CSV trasformati e commerciale_normalizzato.json |
| Righe escluse con motivazione | scarti_righe_rimosse.csv e le corrispondenti righe in arcade.scarto_importazione | Tracciate localmente, senza pubblicare le righe sorgente in Git |
| Database importato | database arcade nel volume Docker standup-import_postgres_data | Volume locale Docker Desktop, non è un file sotto la repository e non è condiviso automaticamente |
| Report di controllo | docs/report-qualita-dati.md | Versionato; contiene aggregati e conteggi, non email o righe cliente |

Il flusso produce il report di qualità del repository, ma non carica gli archivi o il volume Docker su GitHub. Il database locale resta disponibile dopo l'arresto dei container perché il volume è persistente. Docker Desktop lo gestisce nel proprio storage; il suo percorso fisico dipende dalla configurazione del PC. Il repository non documenta un backup remoto per quel volume.

## Pipeline ripetibile

1. Le sorgenti sono state inventariate e copiate dalla consegna nell'area locale ignorata da Git. File temporanei, metadati macOS e la copia ZIP annidata non sono stati usati come input.
2. scripts/dati/prepara_storici.py legge CSV/XLSX e produce i file uniformati in dati-storici/normalizzati/. Normalizza date, fusi, categorie, province, esiti e codici; genera anomalie, scarti, finestre senza misurazione e il JSON commerciale.
3. scripts/dati/importa_dataset.py carica i file in uno schema staging con nome casuale, valida chiavi e relazioni, applica scripts/dati/trasforma.sql e importa il dominio storico/commerciale in PostgreSQL.
4. L'importazione usa una transazione per staging e dominio: se i controlli falliscono, la transazione viene annullata; se termina, lo schema temporaneo viene eliminato.
5. Lo script confronta conteggi e controlli di integrità e aggiorna docs/report-qualita-dati.md con soli aggregati. I test CI e la suite Postman usano fixture sintetiche isolate e non leggono questo volume.

Per i dettagli di sorgenti, campi e anomalie consultare [dati storici](dati-storici.md), [report di qualità](report-qualita-dati.md), [governance](governance-dati.md) e il [dizionario dati](dizionario-dati.md).

## Criteri per mancanti e anomalie

La pulizia non ha cercato di rendere i dati artificialmente completi. Un campo non dichiarato resta NON_DICHIARATO o null; non si deduce un valore dal contesto. Per le misure, null significa che manca una fonte, mentre zero significa che la fonte ha misurato zero. Questa distinzione evita di gonfiare o abbassare KPI e copertura.

- Doppie letture tornelli: rimosse solo quando lo stesso ticket ricompare entro 10 secondi. Le 2.075 righe sono registrate negli scarti con la riga originale, così l'esclusione è verificabile e non silenziosa.
- Ticket senza corrispondenza: 70 letture il cui codice non esiste in biglietteria restano accessi rifiutati; non si inventa un biglietto e non sono conteggiate come visitatori.
- Riuso respinto: le letture successive a un ingresso valido restano con esito rifiutato e flag.
- Intervalli stand mancanti: le 70 combinazioni senza rilevazione vengono registrate come mancanti, non convertite in zero.
- Scansione anomala: la lettura da 912 visite alle 08:00 viene conservata e segnalata; la proiezione KPI la esclude dal conteggio utilizzabile.
- Acquisto dopo l'ingresso, sconto e categorie discordanti: gli eventi restano conservati e marcati. Non riscriviamo la cronologia né cambiamo la categoria sulla base di un'ipotesi.
- Contatti con consenso o profilo incerto: i record restano nello storico riservato, ma minori, consenso assente/non dichiarato ed email in conflitto sono esclusi dall'idoneità marketing. I contatti storici senza prova del consenso alla condivisione non diventano lead per gli espositori o per BAD.
- Contratti non riconciliabili: 30 contratti e 144 righe restano fuori dal dominio importato perché non è possibile collegarli con certezza a un espositore; il file sorgente resta locale e il report dà il conteggio aggregato.
- Listino incompleto: una voce senza unità o prezzo non entra nel listino attivo.
- Acconti e pacchetti mancanti: la data di un acconto non inventa l'importo; il pacchetto non dichiarato resta NON_DICHIARATO. Importi non presenti restano null.
- Dati 2026: l'edizione resta PIANIFICATA senza date finché la fonte non le dichiara.

Queste scelte conservano le righe utili e l'auditabilità, ma bloccano dall'uso operativo le correzioni non dimostrabili o incompatibili con privacy e consenso. Nei fatti esportati a BAD restano solo i campi contrattuali necessari; riferimenti di ticket/ordine sono pseudonimizzati e le anomalie sono aggregate o rese come flag. Le email e le anagrafiche commerciali non sono incluse.

## Limiti e manutenzione

Il report aggregato documenta l'esecuzione rilevata e può diventare obsoleto se gli script o i dati cambiano: va rigenerato dopo una nuova importazione. Non copre da solo richieste di accesso, rettifica, cancellazione o tempi di conservazione; tali regole devono essere stabilite dal titolare prima di un uso reale. Nessun dump del volume è incluso nella CI o nel repository.
