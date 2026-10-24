-- ARCADE Milano, bozza dello schema PostgreSQL per i dati storici 2024 e 2025
-- Team Stand up. Bozza da discutere con BID e BAD prima dell'implementazione.
-- Descrizione dei dati: docs/dati-storici.md
--
-- Scelte principali
--  * Ogni orario è un timestamptz: data e ora dei file sono in ora italiana (Europe/Rome).
--  * L'id_evento del registro unico è la chiave di origine, così il caricamento si ripete senza duplicati.
--  * Le righe con anomalia non si correggono: il flag di controllo_qualita si conserva in flag_qualita.
--  * Le email dei contatti stanno in una tabella riservata, con accesso limitato.

CREATE SCHEMA IF NOT EXISTS arcade;
SET search_path TO arcade;

-- ---------------------------------------------------------------
-- Tabelle di riferimento
-- ---------------------------------------------------------------

CREATE TABLE edizione (
    anno                 smallint PRIMARY KEY,
    inizio_vendite       date,
    inizio_fiera         date NOT NULL,
    fine_fiera           date NOT NULL,
    CHECK (fine_fiera >= inizio_fiera)
);

INSERT INTO edizione (anno, inizio_vendite, inizio_fiera, fine_fiera) VALUES
    (2024, '2024-07-03', '2024-12-20', '2024-12-22'),
    (2025, '2025-07-02', '2025-12-19', '2025-12-21');

CREATE TABLE categoria_biglietto (
    codice               text PRIMARY KEY,
    descrizione          text NOT NULL,
    persone_incluse      smallint NOT NULL DEFAULT 1
);

INSERT INTO categoria_biglietto (codice, descrizione, persone_incluse) VALUES
    ('INTERO',          'Intero',                  1),
    ('RIDOTTO',         'Ridotto',                 1),
    ('FAMILY',          'Family',                  4),
    ('BUSINESS',        'Business',                1),
    ('VIP',             'VIP',                     1),
    ('STAMPA',          'Stampa',                  1),
    ('ABBONAMENTO_3GG', 'Abbonamento 3 giorni',    1),
    ('GRATUITO_U8',     'Gratuito sotto gli 8 anni', 1);

CREATE TABLE canale_vendita (
    codice               text PRIMARY KEY,
    descrizione          text NOT NULL
);

INSERT INTO canale_vendita (codice, descrizione) VALUES
    ('ONLINE',              'Vendita online'),
    ('CASSA',               'Cassa in fiera'),
    ('RIVENDITORE_PARTNER', 'Rivenditore partner');

CREATE TABLE padiglione (
    codice               text PRIMARY KEY
);

INSERT INTO padiglione (codice) VALUES ('P1'), ('P2'), ('P3');

CREATE TABLE varco (
    codice               text PRIMARY KEY,
    padiglione           text NOT NULL REFERENCES padiglione (codice)
);

INSERT INTO varco (codice, padiglione) VALUES
    ('P1-NORD',  'P1'),
    ('P1-SUD',   'P1'),
    ('P2-OVEST', 'P2'),
    ('P3-EST',   'P3');

CREATE TABLE stand (
    codice               text PRIMARY KEY,
    padiglione           text NOT NULL REFERENCES padiglione (codice),
    superficie_mq        numeric(8,2) CHECK (superficie_mq > 0)   -- da ricevere dal cliente
);

CREATE TABLE espositore (
    id_espositore        text PRIMARY KEY,
    ragione_sociale      text                                      -- non presente nei dati ricevuti
);

CREATE TABLE assegnazione_stand (
    anno                 smallint NOT NULL REFERENCES edizione (anno),
    codice_stand         text     NOT NULL REFERENCES stand (codice),
    id_espositore        text     NOT NULL REFERENCES espositore (id_espositore),
    PRIMARY KEY (anno, codice_stand),
    UNIQUE (anno, id_espositore)
);

-- ---------------------------------------------------------------
-- Biglietteria
-- ---------------------------------------------------------------

CREATE TABLE ordine (
    id_ordine            text PRIMARY KEY,
    anno                 smallint NOT NULL REFERENCES edizione (anno),
    canale               text     NOT NULL REFERENCES canale_vendita (codice)
);

CREATE TABLE biglietto (
    codice               text PRIMARY KEY,
    id_evento            text NOT NULL UNIQUE,
    id_ordine            text NOT NULL REFERENCES ordine (id_ordine),
    anno                 smallint NOT NULL REFERENCES edizione (anno),
    categoria            text     NOT NULL REFERENCES categoria_biglietto (codice),
    giorno_valido        date,                                     -- NULL significa valido tutti i giorni
    registrato_il        timestamptz NOT NULL,                     -- orario di registrazione, vedi ACQUISTO_DOPO_INGRESSO
    fascia_eta           text NOT NULL DEFAULT 'NON_DICHIARATO'
        CHECK (fascia_eta IN ('0-7','8-13','14-17','18-24','25-34','35-44','45+','FAMIGLIA','NON_DICHIARATO')),
    minore               text NOT NULL DEFAULT 'NON_DICHIARATO'
        CHECK (minore IN ('SI','NO','NON_DICHIARATO')),
    provincia            text NOT NULL DEFAULT 'NON_DICHIARATO',
    codice_sconto        text NOT NULL DEFAULT 'NESSUNO',
    quantita             smallint NOT NULL CHECK (quantita > 0),
    importo_eur          numeric(8,2) NOT NULL CHECK (importo_eur >= 0),
    flag_qualita         text[] NOT NULL DEFAULT '{}'
);

CREATE INDEX biglietto_ordine_idx ON biglietto (id_ordine);
CREATE INDEX biglietto_anno_categoria_idx ON biglietto (anno, categoria);

-- ---------------------------------------------------------------
-- Tornelli
-- ---------------------------------------------------------------

CREATE TABLE accesso (
    id_evento            text PRIMARY KEY,
    anno                 smallint NOT NULL REFERENCES edizione (anno),
    varco                text     NOT NULL REFERENCES varco (codice),
    letto_il             timestamptz NOT NULL,
    codice_biglietto     text NOT NULL,                            -- senza vincolo: 70 codici non esistono in biglietteria
    esito                text NOT NULL CHECK (esito IN ('INGRESSO','INGRESSO_RIFIUTATO')),
    flag_qualita         text[] NOT NULL DEFAULT '{}'
);

CREATE INDEX accesso_anno_ora_idx ON accesso (anno, letto_il);
CREATE INDEX accesso_biglietto_idx ON accesso (codice_biglietto);

-- ---------------------------------------------------------------
-- Stand (solo 2025)
-- ---------------------------------------------------------------

CREATE TABLE visita_stand_ora (
    id_riferimento       text PRIMARY KEY,
    id_evento            text NOT NULL UNIQUE,
    anno                 smallint NOT NULL REFERENCES edizione (anno),
    codice_stand         text     NOT NULL REFERENCES stand (codice),
    ora_inizio           timestamptz NOT NULL,
    scansioni            integer  NOT NULL CHECK (scansioni >= 0),
    flag_qualita         text[] NOT NULL DEFAULT '{}',
    UNIQUE (codice_stand, ora_inizio)
);

CREATE TABLE fascia_stand_mancante (
    codice_stand         text NOT NULL REFERENCES stand (codice),
    ora_inizio           timestamptz NOT NULL,
    PRIMARY KEY (codice_stand, ora_inizio)
);

CREATE TABLE contatto_stand (
    id_contatto          text PRIMARY KEY,
    id_evento            text NOT NULL UNIQUE,
    anno                 smallint NOT NULL REFERENCES edizione (anno),
    codice_stand         text     NOT NULL REFERENCES stand (codice),
    id_espositore        text     NOT NULL REFERENCES espositore (id_espositore),
    raccolto_il          timestamptz NOT NULL,
    fascia_eta           text NOT NULL DEFAULT 'NON_DICHIARATO',
    provincia            text NOT NULL DEFAULT 'NON_DICHIARATO',
    interesse            text,
    consenso_marketing   text NOT NULL CHECK (consenso_marketing IN ('SI','NO','NON_DICHIARATO')),
    utilizzabile_marketing boolean NOT NULL,
    motivo_esclusione    text NOT NULL DEFAULT 'NESSUNO',
    flag_qualita         text[] NOT NULL DEFAULT '{}'
);

CREATE INDEX contatto_stand_idx ON contatto_stand (id_espositore, codice_stand);

-- Dati personali: accesso limitato al ruolo di amministrazione dei dati, mai nei report degli espositori
CREATE TABLE contatto_riservato (
    id_contatto          text PRIMARY KEY REFERENCES contatto_stand (id_contatto) ON DELETE CASCADE,
    email                text NOT NULL
);

-- ---------------------------------------------------------------
-- Qualità e importazione
-- ---------------------------------------------------------------

CREATE TABLE importazione (
    id_importazione      bigserial PRIMARY KEY,
    fonte                text NOT NULL,
    file                 text NOT NULL,
    iniziata_il          timestamptz NOT NULL DEFAULT now(),
    righe_lette          integer,
    righe_caricate       integer,
    righe_scartate       integer
);

CREATE TABLE scarto_importazione (
    id                   bigserial PRIMARY KEY,
    id_importazione      bigint REFERENCES importazione (id_importazione),
    fonte                text NOT NULL,
    motivo               text NOT NULL,
    riga_originale       text NOT NULL
);

CREATE TABLE catalogo_anomalia (
    fonte                text NOT NULL,
    codice               text NOT NULL,
    descrizione          text NOT NULL,
    righe_coinvolte      integer,
    gestione             text,
    PRIMARY KEY (fonte, codice, descrizione)
);

-- ---------------------------------------------------------------
-- Stima delle presenze dal peso (dati simulati nella demo)
-- ---------------------------------------------------------------

CREATE TABLE parametri_stima (
    anno                 smallint PRIMARY KEY REFERENCES edizione (anno),
    peso_medio_kg        numeric(5,2) NOT NULL DEFAULT 70,
    soglia_rumore_kg     numeric(5,2) NOT NULL DEFAULT 20,
    persone_per_mq       numeric(4,2) NOT NULL DEFAULT 1,
    ore_permanenza       numeric(4,2) NOT NULL DEFAULT 4           -- per stimare le presenze dagli ingressi
);

CREATE TABLE rilevazione_peso (
    id                   bigserial PRIMARY KEY,
    anno                 smallint NOT NULL REFERENCES edizione (anno),
    codice_stand         text     NOT NULL REFERENCES stand (codice),
    rilevato_il          timestamptz NOT NULL,
    peso_lordo_kg        numeric(8,2) NOT NULL CHECK (peso_lordo_kg >= 0),
    tara_kg              numeric(8,2) NOT NULL DEFAULT 0,
    fonte                text NOT NULL DEFAULT 'SIMULATA' CHECK (fonte IN ('SIMULATA','SENSORE'))
);

CREATE INDEX rilevazione_peso_idx ON rilevazione_peso (codice_stand, rilevato_il);

-- ---------------------------------------------------------------
-- Viste d'esempio per i KPI calcolabili
-- ---------------------------------------------------------------

-- Ingressi per ora e varco, esclusi i rifiutati
CREATE VIEW v_ingressi_per_ora AS
SELECT anno,
       varco,
       date_trunc('hour', letto_il AT TIME ZONE 'Europe/Rome') AS ora_locale,
       count(*) AS ingressi
FROM accesso
WHERE esito = 'INGRESSO'
GROUP BY anno, varco, date_trunc('hour', letto_il AT TIME ZONE 'Europe/Rome');

-- Persone e incassi dei biglietti per edizione e categoria
CREATE VIEW v_vendite_per_categoria AS
SELECT anno,
       categoria,
       sum(quantita)    AS persone,
       sum(importo_eur) AS incasso_eur
FROM biglietto
GROUP BY anno, categoria;

-- Visite e contatti per stand, senza dati personali
CREATE VIEW v_stand_riepilogo AS
SELECT s.codice AS codice_stand,
       v.anno,
       sum(v.scansioni)  AS scansioni,
       (SELECT count(*) FROM contatto_stand c
         WHERE c.codice_stand = s.codice AND c.anno = v.anno) AS contatti
FROM stand s
JOIN visita_stand_ora v ON v.codice_stand = s.codice
WHERE NOT ('FUORI_ORARIO_VALORE_ANOMALO' = ANY (v.flag_qualita))
GROUP BY s.codice, v.anno;
