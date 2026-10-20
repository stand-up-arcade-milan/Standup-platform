<div align="center">

![Stand up presenta ARCADE Milano 2026](docs/assets/arcade-banner.svg)

Piattaforma integrata per coordinare espositori, vendite, operatività e risultati tra le edizioni dell’evento.

**Team Stand up** · ARCADE Milano · 2026

[Panoramica](#panoramica) · [Architettura](#architettura) · [Stack](#stack) · [Roadmap](#roadmap) · [Gruppo](#gruppo) · [Metodo GitHub](#metodo) · [Identità visiva](#identita-visiva)

</div>

---

## Indice

- [Il progetto in breve](#panoramica)
- [Architettura della piattaforma](#architettura)
- [Flusso operativo](#flusso-operativo)
- [Ruoli e visibilità](#ruoli-e-visibilita)
- [Stack tecnologico](#stack)
- [Indicatori da validare](#indicatori-da-validare)
- [Piano di consegna](#roadmap)
- [Gruppo Stand up](#gruppo)
- [Milestone](#milestone)
- [Metodo di lavoro su GitHub](#metodo)
- [Struttura prevista](#struttura-prevista)
- [Sicurezza e uso dei dati](#sicurezza-e-uso-dei-dati)
- [Stato del progetto](#stato-del-progetto)

---

<a id="panoramica"></a>
## Il progetto in breve

ARCADE Milano è un festival di tre giorni dedicato al gaming e alla cultura pop. La piattaforma aiuta il team a preparare l’edizione, gestire espositori e sponsor, seguire le attività durante l’evento e misurare i risultati dopo la chiusura.

La piattaforma è progettata per valorizzare i dati storici delle edizioni 2024 e 2025, supportare la pianificazione di ARCADE Milano 2026 e collegare il lavoro commerciale alla reportistica.

| Prima dell’evento | Durante l’evento | Dopo l’evento |
| --- | --- | --- |
| Dati storici, offerte, stand e contratti | Presenze e visite agli stand | Risultati, confronto tra edizioni e rinnovi |

<a id="architettura"></a>
## Architettura della piattaforma

```mermaid
flowchart LR
    subgraph persone["PERSONE"]
        direction TB
        DIR["Direzione"]
        COM["Team commerciale"]
        STA["Staff operativo"]
        ESP["Espositori"]
    end

    subgraph accesso["ESPERIENZA E ACCESSO"]
        direction TB
        SP["SharePoint<br/>Portale e documenti"]
        WEB["React<br/>Portale web"]
        PA["Power Apps<br/>Flussi operativi BAD"]
    end

    subgraph servizi["SERVIZI APPLICATIVI"]
        API["Java · Spring Boot<br/>API REST<br/>Regole e autorizzazioni"]
        AUTO["Power Automate<br/>Notifiche e approvazioni"]
    end

    subgraph dati["DATI E ANALISI"]
        DB[("PostgreSQL<br/>Fonte transazionale")]
        BI["Power BI<br/>Indicatori e report"]
    end

    DIR --> SP
    COM --> WEB
    STA --> PA
    ESP --> WEB
    SP -. "documenti e collegamenti" .-> WEB
    SP -. "accesso ai flussi" .-> PA
    WEB --> API
    PA --> API
    API --> DB
    DB --> BI
    API -. "eventi di processo" .-> AUTO
    AUTO -. "notifiche e approvazioni" .-> API

    classDef people fill:#3f826d,color:#f7f7ff,stroke:#cbff8c,stroke-width:2px
    classDef experience fill:#171219,color:#f7f7ff,stroke:#3f826d,stroke-width:2px
    classDef service fill:#c03221,color:#f7f7ff,stroke:#f7f7ff,stroke-width:2px
    classDef data fill:#cbff8c,color:#171219,stroke:#3f826d,stroke-width:2px

    class DIR,COM,STA,ESP people
    class SP,WEB,PA experience
    class API,AUTO service
    class DB,BI data
```

### Perché questa architettura

Il database PostgreSQL conserva i dati condivisi e mantiene relazioni coerenti tra edizioni, espositori, stand, contratti e presenze.

L’API Java con Spring Boot centralizza le regole applicative e i controlli di autorizzazione. React e Power Apps offrono interfacce adatte ai diversi processi, senza collegarsi direttamente alle tabelle.

SharePoint fornisce un punto d’accesso ai documenti e agli strumenti Microsoft 365. Power Automate gestisce notifiche e approvazioni; Power BI presenta gli indicatori per ruolo e ambito.

Questa separazione potrebbe rendere più semplice controllare gli accessi, evitare duplicazioni e modificare un componente senza riscrivere l’intero sistema.

## Flusso operativo

```mermaid
sequenceDiagram
    autonumber
    actor Operatore
    participant UI as React o Power Apps
    participant API as API Spring Boot
    participant DB as PostgreSQL
    participant BI as Power BI

    Operatore->>UI: Accede con il proprio account
    UI->>API: Richiede dati o registra un'attività
    API->>API: Verifica identità, ruolo e ambito
    API->>DB: Legge o aggiorna i dati autorizzati
    DB-->>API: Restituisce il risultato
    API-->>UI: Risposta filtrata per l'utente
    DB-->>BI: Viste di lettura per gli indicatori
    BI-->>Operatore: Report coerente con il ruolo
```

## Ruoli e visibilità

| Ruolo | Accesso previsto |
| --- | --- |
| Direzione | Indicatori aggregati, vendite e confronto tra edizioni |
| Commerciale | Espositori, sponsor, offerte, contratti e rinnovi |
| Staff operativo | Presenze e visite, secondo le autorizzazioni assegnate |
| Espositore | Dati e riepilogo della propria organizzazione |
| Amministratore | Configurazione, utenti e permessi |

I controlli vengono applicati dall’API. Nascondere una schermata nell’interfaccia non è sufficiente per proteggere un dato: ogni richiesta deve essere verificata anche lato server.

<a id="stack"></a>
## Stack tecnologico

| Componente | Tecnologia | Responsabilità |
| --- | --- | --- |
| Database | PostgreSQL | Persistenza relazionale e integrità dei dati |
| Backend | Java e Spring Boot | API REST, regole di business e autorizzazioni |
| Interfaccia web | React | Portale per operatori e area espositore |
| Portale documentale | SharePoint | Documenti, collegamenti e punto di accesso |
| App operative | Power Apps | Raccolta e gestione di processi BAD |
| Automazioni | Power Automate | Notifiche e approvazioni |
| Analisi | Power BI | Indicatori, riepiloghi e confronti |

<a id="identita-visiva"></a>
## Identità visiva

La palette ufficiale di Stand up combina un fondo scuro con accenti luminosi e un colore secondario ispirato al palco e alla cultura arcade.

| Colore | Codice | Uso nel progetto |
| --- | --- | --- |
| Coffee Bean | #171219 | Fondo principale e testi su superfici chiare |
| Lime Cream | #cbff8c | Accenti, evidenze e stati attivi |
| Brick Ember | #c03221 | Azioni, dettagli di richiamo e contrasto |
| Ghost White | #f7f7ff | Testi su fondi scuri e superfici chiare |
| Jungle Teal | #3f826d | Elementi secondari, collegamenti e area dati |

I valori HEX sono i riferimenti ufficiali. Le tonalità derivate per gli stati intermedi possono essere usate nell’interfaccia, mantenendo leggibili testi e controlli.

## Indicatori da validare

Gli indicatori dipendono dalla disponibilità e dalla qualità dei dati. La prima proposta comprende:

- Espositori per edizione, categoria e stato del contratto.
- Offerte commerciali per valore e stato.
- Stand venduti e disponibilità residua.
- Presenze per giornata e fascia oraria.
- Visite agli stand, se raccolte con criteri verificabili.
- Confronto tra le edizioni 2024, 2025 e 2026.
- Riepilogo per espositore con accesso limitato alla propria organizzazione.

Per ogni indicatore saranno documentati definizione, fonte, formula, frequenza di aggiornamento e responsabile della validazione.

<a id="roadmap"></a>
## Piano di consegna

```mermaid
gantt
    title ARCADE Milano · Roadmap 2026
    dateFormat YYYY-MM-DD
    axisFormat %d %b

    section Fondazioni
    Requisiti e modello dati       :crit, req, 2026-10-16, 2026-10-30
    Modello dati e API definiti :milestone, sal1, 2026-10-30, 0d

    section Dimostrazione prodotto
    Importazione dati 2024 e 2025  :hist, 2026-10-20, 2026-11-06
    Flusso contratto 2026         :contract, 2026-10-26, 2026-11-13
    Demo integrata          :milestone, sal2, 2026-11-13, 0d

    section Integrazione e consegna
    Interfacce e processi          :apps, 2026-11-02, 2026-11-27
    Report e confronto edizioni    :reports, 2026-11-09, 2026-11-27
    Validazione e documentazione   :docs, 2026-11-23, 2026-12-04
    Consegna finale                :milestone, final, 2026-12-04, 0d
```

Le date rappresentano il piano di consegna condiviso. Il GitHub Project sarà la vista operativa per aggiornare stato, priorità, responsabile e scadenze.

<a id="gruppo"></a>
## Gruppo Stand up

Il team è organizzato nelle aree BID e BAD. La suddivisione delle attività verrà concordata e aggiornata nel GitHub Project.

### Membri del gruppo

1. Girelle Beni Benj
2. Giuseppe Sparviero
3. Giosuè Tedeschi
4. Mihai Blendea
5. Luca Cerrone
6. Vinicius Dematos
7. Marguerite Deido El Mbimbey

### BID · Backend, database e integrazione

- Modello dati e migrazioni PostgreSQL.
- API Java con Spring Boot.
- Controllo di identità, ruoli e visibilità.
- Integrazione tra backend, frontend e strumenti Microsoft.

### BAD · Dati, processi e Business Intelligence

- Raccolta e validazione dei dati storici.
- Flussi Power Apps e Power Automate.
- Definizione degli indicatori.
- Report Power BI e confronto tra edizioni.

## Milestone

| Data | Risultato atteso |
| --- | --- |
| 30 ottobre 2026 | Modello dati e contratti API definiti |
| 13 novembre 2026 | Dati 2024 e 2025 disponibili e un flusso di contratto 2026 dimostrato |
| 4 dicembre 2026 · Consegna | MVP integrato, documentazione e demo del prodotto |

<a id="metodo"></a>
## Metodo di lavoro su GitHub

- Le **issue** descrivono funzionalità, attività, difetti e decisioni da validare.
- Le **sub-issue** suddividono il lavoro in attività più piccole e assegnabili.
- Il **GitHub Project** mostra stato, gruppo responsabile, priorità e scadenze.
- Le **pull request** descrivono le modifiche e consentono la revisione prima dell’integrazione.
- Ogni membro usa il proprio account GitHub.

Branch di lavoro:

- `main` per la versione integrata.
- `feature/nome-funzione` per una funzionalità.
- `fix/nome-correzione` per una correzione.
- `docs/nome-documento` per la documentazione.

## Struttura prevista

```text
.
├── backend/              # API Java e Spring Boot
├── database/             # Migrazioni PostgreSQL e dati dimostrativi
├── docs/                  # Architettura, modello dati, sicurezza e roadmap
├── frontend/              # Applicazione React
├── power-platform/        # Specifiche Power Apps, Power Automate e Power BI
└── README.md
```

## Sicurezza e uso dei dati

- Non inserire password, token, chiavi API o credenziali nel repository.
- Limitare i dati in base al ruolo e all’organizzazione dell’utente.
- Documentare fonti e trasformazioni dei dati importati.
- Raccogliere solo i dati personali necessari al perimetro dimostrativo.

## Stato del progetto

Repository inizializzato. Modello dati, API, indicatori, backlog e componenti applicativi saranno sviluppati per fasi...
