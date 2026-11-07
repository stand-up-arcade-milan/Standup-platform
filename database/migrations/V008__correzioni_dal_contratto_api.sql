-- V008: correzioni emerse dal confronto tra il contratto OpenAPI e lo schema.
-- Peso senza doppioni, scansioni 2026 con operatore, colonne mancanti (sede, stato, nome, disponibilità, motivo di rifiuto),
-- token di revoca dei consensi, costi dell'edizione e viste per i KPI che mancavano (persone uniche, costo per MQL).
SET search_path TO arcade;

-- Edizione: sede e stato, usati dal contratto (PIANIFICATA, ATTIVA, CONCLUSA)

ALTER TABLE edizione
    ADD COLUMN sede  text,
    ADD COLUMN stato text NOT NULL DEFAULT 'PIANIFICATA' CHECK (stato IN ('PIANIFICATA','ATTIVA','CONCLUSA'));
UPDATE edizione SET stato = 'CONCLUSA' WHERE anno < 2026;

-- Padiglione: nome leggibile. Stand: può essere tolto dalla vendita senza essere assegnato

ALTER TABLE padiglione ADD COLUMN nome text;
ALTER TABLE stand      ADD COLUMN disponibile boolean NOT NULL DEFAULT true;

-- Accesso: motivo del rifiuto, vuoto per gli ingressi e per i rifiuti storici senza motivo

ALTER TABLE accesso
    ADD COLUMN motivo_rifiuto text CHECK (motivo_rifiuto IN ('BIGLIETTO_NON_VALIDO','GIA_USATO','GIORNO_NON_VALIDO')),
    ADD CONSTRAINT accesso_motivo_solo_se_rifiutato CHECK (motivo_rifiuto IS NULL OR esito = 'INGRESSO_RIFIUTATO');

-- Costi dell'edizione, parametro del costo per MQL

ALTER TABLE parametri_stima ADD COLUMN costi_edizione_eur numeric(12,2) CHECK (costi_edizione_eur >= 0);

-- Revoca dei consensi: si conserva solo l'impronta del token, nella tabella riservata

ALTER TABLE registrazione_riservata ADD COLUMN token_revoca_hash text UNIQUE;

-- Peso: una lettura ripetuta dallo stesso sensore nello stesso istante non crea una riga doppia

ALTER TABLE rilevazione_peso
    ADD CONSTRAINT rilevazione_peso_lettura_unica UNIQUE (codice_stand, rilevato_il, fonte);

-- Scansioni 2026: una riga per scansione, con operatore e identificativo pseudonimizzato del biglietto.
-- Una scansione ripetuta dello stesso biglietto nello stesso stand è registrata come duplicata e non conteggiata.

CREATE TABLE scansione_stand (
    id_evento     text PRIMARY KEY,
    anno          smallint NOT NULL REFERENCES edizione (anno),
    codice_stand  text NOT NULL REFERENCES stand (codice),
    operatore_id  text NOT NULL,
    rilevata_il   timestamptz NOT NULL,
    ticket_ref    text,
    id_contatto   text REFERENCES contatto_stand (id_contatto),
    duplicata     boolean NOT NULL DEFAULT false,
    registrata_il timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX scansione_stand_stand_ora_idx ON scansione_stand (codice_stand, rilevata_il);
CREATE UNIQUE INDEX scansione_stand_biglietto_unico ON scansione_stand (anno, codice_stand, ticket_ref)
    WHERE ticket_ref IS NOT NULL AND NOT duplicata;

-- Viste

-- Stato dello stand per edizione: assegnato, libero oppure non disponibile
CREATE VIEW v_stand_stato AS
SELECT e.anno,
       s.codice AS codice_stand,
       s.padiglione,
       CASE WHEN a.id_espositore IS NOT NULL THEN 'ASSEGNATO'
            WHEN NOT s.disponibile THEN 'NON_DISPONIBILE'
            ELSE 'LIBERO' END AS stato
FROM edizione e
CROSS JOIN stand s
LEFT JOIN assegnazione_stand a ON a.anno = e.anno AND a.codice_stand = s.codice;

-- Visitatori: ingressi (persone), biglietti venduti (persone, un Family vale 4) e persone uniche (biglietti con almeno un ingresso)
CREATE VIEW v_visitatori_riepilogo AS
SELECT e.anno,
       coalesce(a.ingressi_persone, 0)       AS ingressi_persone,
       coalesce(b.biglietti_venduti_persone, 0) AS biglietti_venduti_persone,
       coalesce(a.persone_uniche, 0)         AS persone_uniche
FROM edizione e
LEFT JOIN (SELECT anno,
                  sum(persone) AS ingressi_persone,
                  count(DISTINCT codice_biglietto) AS persone_uniche
             FROM accesso
            WHERE esito = 'INGRESSO'
            GROUP BY anno) a ON a.anno = e.anno
LEFT JOIN (SELECT anno, sum(quantita) AS biglietti_venduti_persone
             FROM biglietto
            GROUP BY anno) b ON b.anno = e.anno;

-- Costo per MQL: costi dell'edizione divisi per gli MQL
CREATE VIEW v_costo_per_mql AS
SELECT p.anno,
       p.costi_edizione_eur,
       m.mql,
       round(p.costi_edizione_eur / nullif(m.mql, 0), 2) AS costo_per_mql
FROM parametri_stima p
LEFT JOIN (SELECT anno, sum(mql) AS mql FROM v_mql_stand GROUP BY anno) m ON m.anno = p.anno;

-- Visite orarie dalle scansioni 2026, senza duplicati. security_invoker: l'espositore vede solo il proprio stand
CREATE VIEW v_visite_stand_scansioni WITH (security_invoker = true) AS
SELECT anno,
       codice_stand,
       date_trunc('hour', rilevata_il) AS ora_inizio,
       count(*) AS scansioni
FROM scansione_stand
WHERE NOT duplicata
GROUP BY anno, codice_stand, date_trunc('hour', rilevata_il);

-- Riepilogo per stand: le visite 2024 e 2025 vengono dal conteggio orario, quelle 2026 dalle scansioni
CREATE OR REPLACE VIEW v_stand_riepilogo AS
WITH visite AS (
    SELECT anno,
           codice_stand,
           sum(scansioni) FILTER (WHERE NOT 'FUORI_ORARIO_VALORE_ANOMALO' = ANY (flag_qualita))::bigint AS scansioni
    FROM visita_stand_ora
    GROUP BY anno, codice_stand
    UNION ALL
    SELECT anno, codice_stand, count(*)::bigint
    FROM scansione_stand
    WHERE NOT duplicata
    GROUP BY anno, codice_stand
)
SELECT v.anno,
       v.codice_stand,
       sum(v.scansioni)::bigint AS scansioni,
       (SELECT count(*) FROM contatto_stand c WHERE c.codice_stand = v.codice_stand AND c.anno = v.anno) AS contatti,
       (SELECT count(*) FROM contatto_stand c WHERE c.codice_stand = v.codice_stand AND c.anno = v.anno
                                                  AND c.utilizzabile_marketing) AS contatti_utilizzabili
FROM visite v
GROUP BY v.anno, v.codice_stand;

-- Permessi. Le email e i token restano nelle tabelle riservate.

GRANT SELECT ON scansione_stand, v_stand_stato, v_visitatori_riepilogo, v_costo_per_mql, v_visite_stand_scansioni
    TO arcade_lettura;

ALTER TABLE scansione_stand ENABLE ROW LEVEL SECURITY;
CREATE POLICY lettura_completa ON scansione_stand FOR SELECT TO arcade_lettura USING (true);

-- L'espositore vede le scansioni del proprio stand, senza operatore e senza identificativo del biglietto
CREATE POLICY solo_proprio_stand ON scansione_stand FOR SELECT TO arcade_espositore
    USING (EXISTS (SELECT 1 FROM assegnazione_stand a
                    WHERE a.anno = scansione_stand.anno
                      AND a.codice_stand = scansione_stand.codice_stand
                      AND a.id_espositore = current_setting('arcade.id_espositore', true)));
GRANT SELECT (id_evento, anno, codice_stand, rilevata_il, duplicata) ON scansione_stand TO arcade_espositore;
GRANT SELECT ON v_visite_stand_scansioni TO arcade_espositore;
-- Lo stato degli stand è un'informazione pubblica: nessuna identità dell'espositore
GRANT SELECT ON v_stand_stato TO arcade_espositore;

-- Dizionario dati delle colonne nuove

INSERT INTO dizionario_dati (tabella, colonna, tipo, descrizione, sensibilita, titolare)
SELECT d.tabella, d.colonna, format_type(a.atttypid, a.atttypmod), d.descrizione, d.sensibilita, d.titolare
FROM (VALUES
    ('edizione', 'sede', 'Sede della fiera', 'PUBBLICO', 'Organizzazione'),
    ('edizione', 'stato', 'PIANIFICATA, ATTIVA oppure CONCLUSA', 'INTERNO', 'Organizzazione'),
    ('padiglione', 'nome', 'Nome leggibile del padiglione', 'PUBBLICO', 'Organizzazione'),
    ('stand', 'disponibile', 'Falso se lo stand è tolto dalla vendita, per esempio per un vincolo di allestimento', 'INTERNO', 'Organizzazione'),
    ('accesso', 'motivo_rifiuto', 'Perché l''ingresso è stato rifiutato, vuoto per gli ingressi e per i rifiuti storici', 'INTERNO', 'Controllo accessi'),
    ('parametri_stima', 'costi_edizione_eur', 'Costi dell''edizione, parametro del costo per MQL, simulato finché il cliente non lo fornisce', 'INTERNO', 'Organizzazione'),
    ('registrazione_riservata', 'token_revoca_hash', 'Impronta del token con cui il visitatore modifica i consensi, il token in chiaro non si conserva', 'RISERVATO', 'Marketing'),
    ('scansione_stand', 'id_evento', 'Chiave del registro unico, per ripetere un invio senza duplicati', 'INTERNO', 'Controllo accessi'),
    ('scansione_stand', 'anno', 'Edizione', 'INTERNO', 'Controllo accessi'),
    ('scansione_stand', 'codice_stand', 'Stand dove è avvenuta la scansione', 'INTERNO', 'Controllo accessi'),
    ('scansione_stand', 'operatore_id', 'Identificativo di chi ha scansionato, solo interno', 'RISERVATO', 'Controllo accessi'),
    ('scansione_stand', 'rilevata_il', 'Orario della scansione', 'INTERNO', 'Controllo accessi'),
    ('scansione_stand', 'ticket_ref', 'Identificativo pseudonimizzato del biglietto, non contiene nome o email', 'RISERVATO', 'Controllo accessi'),
    ('scansione_stand', 'id_contatto', 'Contatto creato dalla scansione, vuoto se il visitatore non lo ha lasciato', 'INTERNO', 'Marketing'),
    ('scansione_stand', 'duplicata', 'Vero se lo stesso biglietto era già stato scansionato nello stand, non viene conteggiata', 'INTERNO', 'Controllo accessi'),
    ('scansione_stand', 'registrata_il', 'Orario in cui il sistema ha registrato la scansione', 'INTERNO', 'Controllo accessi')
) AS d (tabella, colonna, descrizione, sensibilita, titolare)
JOIN pg_attribute a ON a.attrelid = ('arcade.' || d.tabella)::regclass AND a.attname = d.colonna;

-- Controllo: ogni colonna delle tabelle deve avere una riga nel dizionario
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
