-- V010: conserva i dati ricevuti senza inventare date, pagamenti, pacchetti o voci di listino.
SET search_path TO arcade;

-- L'edizione può essere pianificata prima che le date della fiera siano confermate.
ALTER TABLE edizione ALTER COLUMN inizio_fiera DROP NOT NULL;
ALTER TABLE edizione ALTER COLUMN fine_fiera DROP NOT NULL;
ALTER TABLE edizione
    ADD CONSTRAINT edizione_date_complete_se_confermata
    CHECK (stato = 'PIANIFICATA' OR (inizio_fiera IS NOT NULL AND fine_fiera IS NOT NULL));
INSERT INTO edizione (anno, stato) VALUES (2026, 'PIANIFICATA')
ON CONFLICT (anno) DO NOTHING;
INSERT INTO parametri_stima (anno) VALUES (2026) ON CONFLICT (anno) DO NOTHING;

-- Il file degli espositori contiene dati riservati, separati dal profilo pubblico.
CREATE TABLE espositore_riservato (
    id_espositore   text PRIMARY KEY REFERENCES espositore (id_espositore),
    partita_iva     text,
    settore         text,
    citta           text,
    referente       text,
    email_referente text
);
ALTER TABLE espositore_riservato ENABLE ROW LEVEL SECURITY;
CREATE POLICY accesso_dati_personali ON espositore_riservato
    FOR ALL TO arcade_dati_personali USING (true) WITH CHECK (true);
GRANT SELECT, INSERT, UPDATE ON espositore_riservato TO arcade_dati_personali;

-- La planimetria è versionata per edizione: non sovrascrive la posizione storica di uno stand.
CREATE TABLE planimetria_stand (
    anno            smallint NOT NULL REFERENCES edizione (anno),
    codice_stand    text NOT NULL REFERENCES stand (codice),
    padiglione      text NOT NULL REFERENCES padiglione (codice),
    nome_padiglione text,
    superficie_mq   numeric(8,2) CHECK (superficie_mq > 0),
    posizione       text NOT NULL,
    attivo_dal      smallint,
    PRIMARY KEY (anno, codice_stand)
);
CREATE INDEX planimetria_stand_padiglione_idx ON planimetria_stand (anno, padiglione);

-- Il listino ricevuto usa unità percentuali che il modello precedente non rappresentava.
ALTER TABLE listino_voce DROP CONSTRAINT listino_voce_unita_check;
ALTER TABLE listino_voce ADD CONSTRAINT listino_voce_unita_check
    CHECK (unita IN ('MQ','FORFAIT','PERCENTUALE','PERCENTUALE_MQ'));
ALTER TABLE listino_voce ADD COLUMN disponibilita_sorgente text;
ALTER TABLE listino_voce ADD COLUMN nota_sorgente text;

-- Uno storico può dichiarare la data dell'acconto senza riportarne l'importo.
-- Il livello non presente nella fonte viene dichiarato esplicitamente.
ALTER TABLE pratica DROP CONSTRAINT pratica_pacchetto_check;
ALTER TABLE pratica ADD CONSTRAINT pratica_pacchetto_check
    CHECK (pacchetto IN ('BASE','PREMIUM','NON_DICHIARATO'));

ALTER TABLE contatto_stand DROP CONSTRAINT contatto_stand_motivo_esclusione_check;
ALTER TABLE contatto_stand ADD CONSTRAINT contatto_stand_motivo_esclusione_check
    CHECK (motivo_esclusione IN ('NESSUNO','MINORE_14_17','CONSENSO_MANCANTE','EMAIL_CONFLITTO'));

CREATE TABLE contratto_storico (
    id_contratto_origine       text PRIMARY KEY,
    id_pratica                 uuid NOT NULL UNIQUE REFERENCES pratica (id_pratica),
    imponibile_listino_eur     numeric(12,2) NOT NULL CHECK (imponibile_listino_eur >= 0),
    sconto_dichiarato_pct      numeric(5,2) NOT NULL CHECK (sconto_dichiarato_pct BETWEEN 0 AND 100),
    imponibile_netto_eur       numeric(12,2) NOT NULL CHECK (imponibile_netto_eur >= 0),
    data_firma                 date,
    acconto_scadenza           date,
    acconto_pagato_il          date,
    saldo_scadenza             date,
    saldo_pagato_il            date,
    rinnovo                    boolean NOT NULL DEFAULT false,
    abbinato_per_nome          boolean NOT NULL DEFAULT false,
    flag_qualita               text[] NOT NULL DEFAULT '{}'
);

CREATE TABLE contratto_storico_riga (
    id_contratto_origine text NOT NULL REFERENCES contratto_storico (id_contratto_origine) ON DELETE CASCADE,
    numero_riga          integer NOT NULL,
    codice_voce_sorgente text NOT NULL,
    descrizione          text NOT NULL,
    quantita             numeric(10,3) NOT NULL CHECK (quantita > 0),
    prezzo_unitario_eur  numeric(10,2) NOT NULL CHECK (prezzo_unitario_eur >= 0),
    importo_eur          numeric(12,2) NOT NULL CHECK (importo_eur >= 0),
    presente_nel_listino boolean NOT NULL,
    PRIMARY KEY (id_contratto_origine, numero_riga)
);
GRANT SELECT ON planimetria_stand TO arcade_lettura, arcade_espositore;
GRANT SELECT ON contratto_storico, contratto_storico_riga TO arcade_lettura;

-- Per i contratti importati, i totali firmati dalla fonte sono autorevoli.
CREATE OR REPLACE VIEW v_pratica WITH (security_invoker = true) AS
SELECT p.id_pratica, p.anno, p.id_espositore, p.codice_stand, p.stato, p.pacchetto,
       p.sconto_percentuale, p.approvazione_richiesta, p.creata_il, p.aggiornata_il,
       round(coalesce(h.imponibile_listino_eur, v.imponibile_listino, 0), 2) AS imponibile_listino_eur,
       round(coalesce(h.imponibile_netto_eur,
                      coalesce(v.imponibile_listino, 0) * (1 - p.sconto_percentuale / 100)), 2) AS totale_eur,
       CASE WHEN h.acconto_pagato_il IS NOT NULL AND a.acconti IS NULL THEN NULL
            ELSE coalesce(a.acconti, 0) END AS acconti_eur
FROM pratica p
LEFT JOIN (SELECT id_pratica, sum(quantita * prezzo_unitario_eur) AS imponibile_listino
             FROM voce_pratica GROUP BY id_pratica) v ON v.id_pratica = p.id_pratica
LEFT JOIN (SELECT id_pratica, sum(importo_eur) AS acconti
             FROM acconto GROUP BY id_pratica) a ON a.id_pratica = p.id_pratica
LEFT JOIN contratto_storico h ON h.id_pratica = p.id_pratica;

-- Metadati delle colonne nuove e dei dati riservati.
INSERT INTO dizionario_dati (tabella, colonna, tipo, descrizione, sensibilita, titolare)
SELECT d.tabella, d.colonna, format_type(a.atttypid, a.atttypmod), d.descrizione, d.sensibilita, d.titolare
FROM (VALUES
    ('espositore_riservato', 'id_espositore', 'Identificativo dell’espositore', 'RISERVATO', 'Commerciale'),
    ('espositore_riservato', 'partita_iva', 'Partita IVA dell’espositore', 'PERSONALE', 'Commerciale'),
    ('espositore_riservato', 'settore', 'Settore dichiarato dall’espositore', 'INTERNO', 'Commerciale'),
    ('espositore_riservato', 'citta', 'Città dell’espositore', 'RISERVATO', 'Commerciale'),
    ('espositore_riservato', 'referente', 'Nome del referente commerciale', 'PERSONALE', 'Commerciale'),
    ('espositore_riservato', 'email_referente', 'Email del referente commerciale', 'PERSONALE', 'Commerciale'),
    ('planimetria_stand', 'anno', 'Edizione della planimetria', 'INTERNO', 'Organizzazione'),
    ('planimetria_stand', 'codice_stand', 'Codice dello stand', 'PUBBLICO', 'Organizzazione'),
    ('planimetria_stand', 'padiglione', 'Padiglione dello stand in questa edizione', 'PUBBLICO', 'Organizzazione'),
    ('planimetria_stand', 'nome_padiglione', 'Nome del padiglione', 'PUBBLICO', 'Organizzazione'),
    ('planimetria_stand', 'superficie_mq', 'Superficie dello stand in metri quadrati', 'PUBBLICO', 'Organizzazione'),
    ('planimetria_stand', 'posizione', 'Posizione dello stand nella planimetria', 'PUBBLICO', 'Organizzazione'),
    ('planimetria_stand', 'attivo_dal', 'Anno di attivazione dello stand come indicato nella fonte', 'INTERNO', 'Organizzazione'),
    ('listino_voce', 'disponibilita_sorgente', 'Disponibilità come indicata nel listino ricevuto', 'INTERNO', 'Commerciale'),
    ('listino_voce', 'nota_sorgente', 'Nota come indicata nel listino ricevuto', 'INTERNO', 'Commerciale'),
    ('contratto_storico', 'id_contratto_origine', 'Identificativo del contratto nella fonte', 'INTERNO', 'Commerciale'),
    ('contratto_storico', 'id_pratica', 'Pratica collegata al contratto storico', 'INTERNO', 'Commerciale'),
    ('contratto_storico', 'imponibile_listino_eur', 'Imponibile di listino riportato nel contratto', 'INTERNO', 'Commerciale'),
    ('contratto_storico', 'sconto_dichiarato_pct', 'Percentuale di sconto normalizzata dalla fonte', 'INTERNO', 'Commerciale'),
    ('contratto_storico', 'imponibile_netto_eur', 'Imponibile netto riportato nel contratto', 'INTERNO', 'Commerciale'),
    ('contratto_storico', 'data_firma', 'Data di firma riportata nel contratto', 'INTERNO', 'Commerciale'),
    ('contratto_storico', 'acconto_scadenza', 'Scadenza dell’acconto', 'INTERNO', 'Commerciale'),
    ('contratto_storico', 'acconto_pagato_il', 'Data di pagamento dell’acconto senza importo disponibile', 'INTERNO', 'Commerciale'),
    ('contratto_storico', 'saldo_scadenza', 'Scadenza del saldo', 'INTERNO', 'Commerciale'),
    ('contratto_storico', 'saldo_pagato_il', 'Data di pagamento del saldo senza importo disponibile', 'INTERNO', 'Commerciale'),
    ('contratto_storico', 'rinnovo', 'Indicazione di rinnovo nella fonte', 'INTERNO', 'Commerciale'),
    ('contratto_storico', 'abbinato_per_nome', 'Collegamento fatto per corrispondenza esatta del nome normalizzato', 'INTERNO', 'Qualità'),
    ('contratto_storico', 'flag_qualita', 'Anomalie del contratto storico', 'INTERNO', 'Qualità'),
    ('contratto_storico_riga', 'id_contratto_origine', 'Contratto di origine', 'INTERNO', 'Commerciale'),
    ('contratto_storico_riga', 'numero_riga', 'Numero della riga nel foglio sorgente', 'INTERNO', 'Commerciale'),
    ('contratto_storico_riga', 'codice_voce_sorgente', 'Codice della voce nel contratto', 'INTERNO', 'Commerciale'),
    ('contratto_storico_riga', 'descrizione', 'Descrizione della voce nel contratto', 'INTERNO', 'Commerciale'),
    ('contratto_storico_riga', 'quantita', 'Quantità riportata nel contratto', 'INTERNO', 'Commerciale'),
    ('contratto_storico_riga', 'prezzo_unitario_eur', 'Prezzo unitario riportato nel contratto', 'INTERNO', 'Commerciale'),
    ('contratto_storico_riga', 'importo_eur', 'Importo della riga riportato nel contratto', 'INTERNO', 'Commerciale'),
    ('contratto_storico_riga', 'presente_nel_listino', 'Indica se il codice compare nel listino 2026 ricevuto', 'INTERNO', 'Qualità')
) AS d (tabella, colonna, descrizione, sensibilita, titolare)
JOIN pg_attribute a ON a.attrelid = ('arcade.' || d.tabella)::regclass AND a.attname = d.colonna;

DO $$
DECLARE mancanti text;
BEGIN
    SELECT string_agg(c.table_name || '.' || c.column_name, ', ') INTO mancanti
    FROM information_schema.columns c
    JOIN information_schema.tables t USING (table_schema, table_name)
    WHERE c.table_schema = 'arcade' AND t.table_type = 'BASE TABLE' AND c.table_name <> 'dizionario_dati'
      AND NOT EXISTS (SELECT 1 FROM dizionario_dati d WHERE d.tabella = c.table_name AND d.colonna = c.column_name);
    IF mancanti IS NOT NULL THEN RAISE EXCEPTION 'Colonne senza descrizione nel dizionario: %', mancanti; END IF;
END $$;
