-- V001: schema base. Tabelle di riferimento, biglietteria, tornelli, stand, contatti, qualità e stima dal peso.
-- Convenzioni: nomi in italiano, orari in timestamptz (i file sono in ora italiana, Europe/Rome),
-- ogni riga importata conserva id_evento, la chiave del registro unico, per ripetere il caricamento senza duplicati.

CREATE SCHEMA IF NOT EXISTS arcade;
SET search_path TO arcade;

-- Tabelle di riferimento

CREATE TABLE edizione (
    anno            smallint PRIMARY KEY,
    inizio_vendite  date,
    inizio_fiera    date NOT NULL,
    fine_fiera      date NOT NULL,
    CHECK (fine_fiera >= inizio_fiera)
);

CREATE TABLE categoria_biglietto (
    codice           text PRIMARY KEY,
    descrizione      text NOT NULL,
    persone_incluse  smallint NOT NULL DEFAULT 1 CHECK (persone_incluse > 0)
);

CREATE TABLE canale_vendita (
    codice       text PRIMARY KEY,
    descrizione  text NOT NULL
);

CREATE TABLE padiglione (
    codice text PRIMARY KEY
);

CREATE TABLE varco (
    codice      text PRIMARY KEY,
    padiglione  text NOT NULL REFERENCES padiglione (codice)
);

CREATE TABLE stand (
    codice         text PRIMARY KEY,
    padiglione     text NOT NULL REFERENCES padiglione (codice),
    superficie_mq  numeric(8,2) CHECK (superficie_mq > 0)  -- non presente nei dati ricevuti
);

CREATE TABLE espositore (
    id_espositore    text PRIMARY KEY,
    ragione_sociale  text                                   -- non presente nei dati ricevuti
);

CREATE TABLE assegnazione_stand (
    anno           smallint NOT NULL REFERENCES edizione (anno),
    codice_stand   text NOT NULL REFERENCES stand (codice),
    id_espositore  text NOT NULL REFERENCES espositore (id_espositore),
    PRIMARY KEY (anno, codice_stand),
    UNIQUE (anno, id_espositore)
);

-- Biglietteria

CREATE TABLE ordine (
    id_ordine  text PRIMARY KEY,
    anno       smallint NOT NULL REFERENCES edizione (anno),
    canale     text NOT NULL REFERENCES canale_vendita (codice)
);

CREATE TABLE biglietto (
    codice         text PRIMARY KEY,
    id_evento      text NOT NULL UNIQUE,
    id_ordine      text NOT NULL REFERENCES ordine (id_ordine),
    anno           smallint NOT NULL REFERENCES edizione (anno),
    categoria      text NOT NULL REFERENCES categoria_biglietto (codice),
    giorno_valido  date,                                    -- NULL significa valido tutti i giorni
    registrato_il  timestamptz NOT NULL,                    -- può seguire il primo ingresso, vedi ACQUISTO_REGISTRATO_DOPO_INGRESSO
    fascia_eta     text NOT NULL DEFAULT 'NON_DICHIARATO'
        CHECK (fascia_eta IN ('0-7','8-13','14-17','18-24','25-34','35-44','45+','FAMIGLIA','NON_DICHIARATO')),
    minore         text NOT NULL DEFAULT 'NON_DICHIARATO'
        CHECK (minore IN ('SI','NO','NON_DICHIARATO')),
    provincia      text NOT NULL DEFAULT 'NON_DICHIARATO',
    codice_sconto  text NOT NULL DEFAULT 'NESSUNO'
        CHECK (codice_sconto IN ('NESSUNO','SCUOLA','EARLY10','STUDENTI')),
    quantita       smallint NOT NULL CHECK (quantita > 0),  -- persone coperte dal biglietto
    importo_eur    numeric(8,2) NOT NULL CHECK (importo_eur >= 0),
    flag_qualita   text[] NOT NULL DEFAULT '{}'
);
CREATE INDEX biglietto_ordine_idx ON biglietto (id_ordine);
CREATE INDEX biglietto_anno_categoria_idx ON biglietto (anno, categoria);

-- Tornelli

CREATE TABLE accesso (
    id_evento         text PRIMARY KEY,
    anno              smallint NOT NULL REFERENCES edizione (anno),
    varco             text NOT NULL REFERENCES varco (codice),
    letto_il          timestamptz NOT NULL,
    codice_biglietto  text NOT NULL,                        -- senza vincolo: 70 codici non esistono in biglietteria
    esito             text NOT NULL CHECK (esito IN ('INGRESSO','INGRESSO_RIFIUTATO')),
    persone           smallint NOT NULL CHECK (persone >= 0), -- 0 per i rifiuti, 4 per un Family
    flag_qualita      text[] NOT NULL DEFAULT '{}'
);
CREATE INDEX accesso_anno_ora_idx ON accesso (anno, letto_il);
CREATE INDEX accesso_biglietto_idx ON accesso (codice_biglietto);

-- Stand, solo edizione 2025

CREATE TABLE visita_stand_ora (
    id_riferimento  text PRIMARY KEY,
    id_evento       text NOT NULL UNIQUE,
    anno            smallint NOT NULL REFERENCES edizione (anno),
    codice_stand    text NOT NULL REFERENCES stand (codice),
    ora_inizio      timestamptz NOT NULL,
    scansioni       integer NOT NULL CHECK (scansioni >= 0),
    flag_qualita    text[] NOT NULL DEFAULT '{}',
    UNIQUE (codice_stand, ora_inizio)
);

CREATE TABLE fascia_stand_mancante (
    codice_stand  text NOT NULL REFERENCES stand (codice),
    ora_inizio    timestamptz NOT NULL,
    PRIMARY KEY (codice_stand, ora_inizio)
);

CREATE TABLE contatto_stand (
    id_contatto             text PRIMARY KEY,
    id_evento               text NOT NULL UNIQUE,
    anno                    smallint NOT NULL REFERENCES edizione (anno),
    codice_stand            text NOT NULL REFERENCES stand (codice),
    id_espositore           text NOT NULL REFERENCES espositore (id_espositore),
    raccolto_il             timestamptz NOT NULL,
    fascia_eta              text NOT NULL DEFAULT 'NON_DICHIARATO',
    provincia               text NOT NULL DEFAULT 'NON_DICHIARATO',
    interesse               text NOT NULL
        CHECK (interesse IN ('BETA_TEST','NEWSLETTER','EVENTO','PRODOTTO','LAVORO_STAGE')),
    consenso_marketing      text NOT NULL CHECK (consenso_marketing IN ('SI','NO','NON_DICHIARATO')),
    utilizzabile_marketing  boolean NOT NULL,
    motivo_esclusione       text NOT NULL DEFAULT 'NESSUNO'
        CHECK (motivo_esclusione IN ('NESSUNO','MINORE_14_17','CONSENSO_MANCANTE')),
    email_su_piu_stand      boolean NOT NULL DEFAULT false,
    flag_qualita            text[] NOT NULL DEFAULT '{}'
);
CREATE INDEX contatto_stand_idx ON contatto_stand (id_espositore, codice_stand);

-- Dato personale: tabella separata, accesso limitato (vedi V004)
CREATE TABLE contatto_riservato (
    id_contatto  text PRIMARY KEY REFERENCES contatto_stand (id_contatto) ON DELETE CASCADE,
    email        text NOT NULL
);

-- Qualità e importazione

CREATE TABLE importazione (
    id_importazione  bigserial PRIMARY KEY,
    file             text NOT NULL,
    iniziata_il      timestamptz NOT NULL DEFAULT now(),
    terminata_il     timestamptz,
    righe_lette      integer,
    righe_caricate   integer,
    righe_scartate   integer
);

CREATE TABLE scarto_importazione (
    id               bigserial PRIMARY KEY,
    id_importazione  bigint REFERENCES importazione (id_importazione),
    fonte            text NOT NULL,
    motivo           text NOT NULL,
    riga_originale   text NOT NULL,
    UNIQUE (fonte, motivo, riga_originale)
);

-- Anomalie trovate in fase di pulizia, come consegnate col dataset
CREATE TABLE catalogo_anomalia (
    fonte            text NOT NULL,
    codice           text NOT NULL,
    descrizione      text NOT NULL,
    righe_coinvolte  integer,
    gestione         text,
    PRIMARY KEY (fonte, codice, descrizione)
);

-- Stima delle presenze

CREATE TABLE parametri_stima (
    anno              smallint PRIMARY KEY REFERENCES edizione (anno),
    ore_permanenza    numeric(4,2) NOT NULL DEFAULT 4,      -- presenze = ingressi delle ultime N ore
    peso_medio_kg     numeric(5,2) NOT NULL DEFAULT 70,
    soglia_rumore_kg  numeric(5,2) NOT NULL DEFAULT 20,
    persone_per_mq    numeric(4,2) NOT NULL DEFAULT 1
);

CREATE TABLE rilevazione_peso (
    id             bigserial PRIMARY KEY,
    anno           smallint NOT NULL REFERENCES edizione (anno),
    codice_stand   text NOT NULL REFERENCES stand (codice),
    rilevato_il    timestamptz NOT NULL,
    peso_lordo_kg  numeric(8,2) NOT NULL CHECK (peso_lordo_kg >= 0),
    tara_kg        numeric(8,2) NOT NULL DEFAULT 0 CHECK (tara_kg >= 0),
    fonte          text NOT NULL DEFAULT 'SIMULATA' CHECK (fonte IN ('SIMULATA','SENSORE'))
);
CREATE INDEX rilevazione_peso_idx ON rilevazione_peso (codice_stand, rilevato_il);
