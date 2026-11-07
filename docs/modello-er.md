# Modello ER

Il diagramma descrive lo schema `arcade` di PostgreSQL così come lo costruiscono le [migrazioni](../database/migrations) da `V001` a `V007`. Se diagramma e SQL non coincidono, vale l'SQL. Il significato di ogni colonna è nel [dizionario dati](dizionario-dati.md).

## 1. Modello completo

Sono mostrate le chiavi e gli attributi principali. `PK` indica la chiave primaria e `FK` la chiave esterna. Per leggere meglio il disegno, i legami con `edizione` sono tracciati solo per `ordine` e `assegnazione_stand`, ma ogni tabella con la colonna `anno` ha una chiave esterna verso `edizione.anno`. Le tabelle di servizio dell'importazione sono elencate nel paragrafo 2.

```mermaid
erDiagram
    EDIZIONE ||--o| PARAMETRI_STIMA : "ha"
    EDIZIONE ||--o{ ORDINE : "contiene"
    EDIZIONE ||--o{ ASSEGNAZIONE_STAND : "assegna"

    CANALE_VENDITA ||--o{ ORDINE : "vende"
    ORDINE ||--|{ BIGLIETTO : "comprende"
    CATEGORIA_BIGLIETTO ||--o{ BIGLIETTO : "classifica"

    PADIGLIONE ||--o{ VARCO : "ospita"
    PADIGLIONE ||--o{ STAND : "ospita"
    PADIGLIONE ||--o{ PASSAGGIO_PEDANA : "conta"
    VARCO ||--o{ ACCESSO : "rileva"

    STAND ||--o{ ASSEGNAZIONE_STAND : "viene assegnato"
    ESPOSITORE ||--o{ ASSEGNAZIONE_STAND : "riceve"
    ESPOSITORE ||--o{ PACCHETTO_ESPOSITORE : "sceglie"
    ESPOSITORE |o--o{ LEAD_MAGNET : "offre"

    STAND ||--o{ VISITA_STAND_ORA : "misura"
    STAND ||--o{ CONTATTO_STAND : "raccoglie"
    ESPOSITORE ||--o{ CONTATTO_STAND : "riceve"
    LEAD_MAGNET |o--o{ CONTATTO_STAND : "genera"
    CONTATTO_STAND ||--o| CONTATTO_RISERVATO : "ha email in"

    STAND ||--o{ RILEVAZIONE_PESO : "pesa"
    STAND ||--o{ CONTEGGIO_SENSORE_STAND : "osserva"

    REGISTRAZIONE_VISITATORE ||--o| REGISTRAZIONE_RISERVATA : "ha nome ed email in"
    REGISTRAZIONE_VISITATORE ||--o{ INTERESSE_VISITATORE : "indica"

    EDIZIONE {
        smallint anno PK
        date inizio_vendite
        date inizio_fiera
        date fine_fiera
    }
    PARAMETRI_STIMA {
        smallint anno PK, FK
        numeric peso_medio_kg
        numeric soglia_rumore_kg
        numeric persone_per_mq
        numeric soglia_avviso
    }
    CANALE_VENDITA {
        text codice PK
        text descrizione
    }
    CATEGORIA_BIGLIETTO {
        text codice PK
        text descrizione
        smallint persone_incluse
    }
    ORDINE {
        text id_ordine PK
        smallint anno FK
        text canale FK
    }
    BIGLIETTO {
        text codice PK
        text id_ordine FK
        smallint anno FK
        text categoria FK
        date giorno_valido
        smallint quantita
        numeric importo_eur
    }
    PADIGLIONE {
        text codice PK
        numeric superficie_mq
        integer capienza
    }
    VARCO {
        text codice PK
        text padiglione FK
    }
    ACCESSO {
        text id_evento PK
        smallint anno FK
        text varco FK
        timestamptz letto_il
        text codice_biglietto
        text esito
        smallint persone
    }
    STAND {
        text codice PK
        text padiglione FK
        numeric superficie_mq
        smallint fila
        smallint colonna
    }
    ESPOSITORE {
        text id_espositore PK
        text ragione_sociale
    }
    ASSEGNAZIONE_STAND {
        smallint anno PK, FK
        text codice_stand PK, FK
        text id_espositore FK
    }
    PACCHETTO_ESPOSITORE {
        smallint anno PK, FK
        text id_espositore PK, FK
        text livello
    }
    VISITA_STAND_ORA {
        text id_riferimento PK
        smallint anno FK
        text codice_stand FK
        timestamptz ora_inizio
        integer scansioni
    }
    CONTATTO_STAND {
        text id_contatto PK
        smallint anno FK
        text codice_stand FK
        text id_espositore FK
        bigint id_lead_magnet FK
        text interesse
        boolean utilizzabile_marketing
    }
    CONTATTO_RISERVATO {
        text id_contatto PK, FK
        text email
    }
    LEAD_MAGNET {
        bigint id_lead_magnet PK
        smallint anno FK
        text id_espositore FK
        text tipo
        text titolo
        text interesse
        boolean attivo
    }
    RILEVAZIONE_PESO {
        bigint id PK
        smallint anno FK
        text codice_stand FK
        timestamptz rilevato_il
        numeric peso_lordo_kg
        numeric tara_kg
        text fonte
    }
    PASSAGGIO_PEDANA {
        text padiglione PK, FK
        timestamptz minuto PK
        smallint anno FK
        integer entrati
        integer usciti
        text fonte
    }
    CONTEGGIO_SENSORE_STAND {
        text codice_stand PK, FK
        timestamptz minuto PK
        smallint anno FK
        integer nuove_persone_ferme
        text fonte
    }
    REGISTRAZIONE_VISITATORE {
        bigint id_registrazione PK
        smallint anno FK
        text provincia
        text fascia_eta
        boolean consenso_marketing
        boolean consenso_espositori
        boolean profilabile
    }
    REGISTRAZIONE_RISERVATA {
        bigint id_registrazione PK, FK
        text nome
        text email
    }
    INTERESSE_VISITATORE {
        bigint id_registrazione PK, FK
        text interesse PK
    }
```

## 2. Come leggerlo

| Area | Tabelle | A cosa servono |
| --- | --- | --- |
| Riferimento | `edizione`, `padiglione`, `varco`, `stand`, `espositore`, `assegnazione_stand`, `categoria_biglietto`, `canale_vendita` | Anagrafiche comuni a tutte le edizioni. Un espositore occupa uno stand per edizione. |
| Biglietteria | `ordine`, `biglietto` | Ordini e biglietti, senza dati personali. Un biglietto può coprire più persone (`quantita`). |
| Accessi | `accesso` | Una riga per lettura al varco, con esito e numero di persone. |
| Stand e contatti | `visita_stand_ora`, `contatto_stand`, `contatto_riservato` | Scansioni per ora e contatti raccolti. L'email sta in una tabella separata. |
| Pacchetti e lead magnet | `pacchetto_espositore`, `lead_magnet` | BASE o PREMIUM per edizione, e ciò che il visitatore riceve in cambio del contatto. |
| Presenze | `passaggio_pedana`, `conteggio_sensore_stand`, `rilevazione_peso`, `parametri_stima` | Pedane nei padiglioni, sensori AI agli stand, stima dal peso e parametri di calcolo. |
| Visitatori registrati | `registrazione_visitatore`, `registrazione_riservata`, `interesse_visitatore` | Consensi separati e interessi. Nome ed email stanno in una tabella riservata. |
| Servizio | `importazione`, `scarto_importazione`, `catalogo_anomalia`, `fascia_stand_mancante`, `dizionario_dati` | Tracciano i caricamenti, le righe scartate e le anomalie, e descrivono ogni colonna. |

## 3. Novità del SAL 1

La migrazione `V007` aggiunge pedane, sensori AI, pacchetti, registrazione del visitatore e lead magnet. Questo schema più piccolo mostra solo quelle tabelle e i loro legami.

```mermaid
erDiagram
    PADIGLIONE ||--o{ PASSAGGIO_PEDANA : "conta"
    STAND ||--o{ CONTEGGIO_SENSORE_STAND : "osserva"
    STAND ||--o{ RILEVAZIONE_PESO : "pesa"
    ESPOSITORE ||--o{ PACCHETTO_ESPOSITORE : "sceglie"
    ESPOSITORE |o--o{ LEAD_MAGNET : "offre"
    LEAD_MAGNET |o--o{ CONTATTO_STAND : "genera"
    REGISTRAZIONE_VISITATORE ||--o| REGISTRAZIONE_RISERVATA : "ha nome ed email in"
    REGISTRAZIONE_VISITATORE ||--o{ INTERESSE_VISITATORE : "indica"

    PASSAGGIO_PEDANA {
        text padiglione PK, FK
        timestamptz minuto PK
        integer entrati
        integer usciti
        text fonte
    }
    CONTEGGIO_SENSORE_STAND {
        text codice_stand PK, FK
        timestamptz minuto PK
        integer nuove_persone_ferme
        text fonte
    }
    RILEVAZIONE_PESO {
        text codice_stand FK
        numeric peso_lordo_kg
        numeric tara_kg
    }
    PACCHETTO_ESPOSITORE {
        smallint anno PK, FK
        text id_espositore PK, FK
        text livello
    }
    LEAD_MAGNET {
        bigint id_lead_magnet PK
        text tipo
        text titolo
        text interesse
    }
    CONTATTO_STAND {
        text id_contatto PK
        bigint id_lead_magnet FK
        boolean utilizzabile_marketing
    }
    REGISTRAZIONE_VISITATORE {
        bigint id_registrazione PK
        boolean consenso_marketing
        boolean consenso_espositori
        boolean profilabile
    }
    REGISTRAZIONE_RISERVATA {
        bigint id_registrazione PK, FK
        text nome
        text email
    }
    INTERESSE_VISITATORE {
        bigint id_registrazione PK, FK
        text interesse PK
    }
```

| Novità | Tabelle | Indicatori che alimentano |
| --- | --- | --- |
| Pedane conta-persone | `passaggio_pedana` | Persone presenti, picco di presenza, saturazione e visitatori per m² |
| Sensori AI agli stand | `conteggio_sensore_stand` | Persone ferme allo stand e resa dello stand |
| Pacchetto dell'espositore | `pacchetto_espositore` | Accesso alla stima dal peso, riservato al PREMIUM |
| Lead magnet | `lead_magnet`, `contatto_stand.id_lead_magnet` | Contatti qualificati (MQL), quota MQL e resa dei lead magnet |
| Registrazione del visitatore | `registrazione_visitatore`, `registrazione_riservata`, `interesse_visitatore` | Interessi del pubblico, solo come totali e solo per chi è profilabile |

## 4. Dati personali e visibilità

- **Dati personali separati.** Email e nome non stanno mai nelle tabelle usate per i calcoli: `contatto_riservato` e `registrazione_riservata` sono tabelle a parte. `registrazione_riservata` è leggibile solo dal ruolo `arcade_dati_personali`.
- **Un espositore vede solo il proprio.** Con la row-level security, l'espositore legge il proprio pacchetto, i sensori AI del proprio stand e i lead magnet di ARCADE Milano e i propri. Non vede mai le registrazioni dei visitatori, le pedane o le viste aggregate della direzione.
- **La stima dal peso è solo PREMIUM.** La policy su `rilevazione_peso` lascia passare le righe solo se l'espositore ha il pacchetto PREMIUM per quell'edizione. Un espositore BASE non le vede nemmeno interrogando il database direttamente.
- **Nessuna profilazione dei minori.** Il modulo di registrazione offre solo fasce d'età da 18 anni in su, e `profilabile` è vero solo con il consenso marketing e una fascia adulta dichiarata.

## 5. Punti da conoscere

- `accesso.codice_biglietto` non ha una chiave esterna verso `biglietto`, perché 70 codici letti ai tornelli non esistono in biglietteria.
- Pedane, sensori AI e rilevazioni di peso hanno la colonna `fonte`, con valore `SIMULATA` o `SENSORE`, perché nella demo i dati sono simulati.
- Le viste dei KPI (per esempio `v_presenze_padiglione`, `v_picco_presenza_giorno`, `v_mql_stand`) leggono queste tabelle e non memorizzano dati. Sono definite nelle migrazioni `V003` e `V007`.
- Il diagramma più vecchio in [dati storici](dati-storici.md) descrive solo lo schema per le edizioni 2024 e 2025. Per il quadro completo vale questo documento.
