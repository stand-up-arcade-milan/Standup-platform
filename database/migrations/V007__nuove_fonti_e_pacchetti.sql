-- V007: novità presentate al SAL 1 del 6 novembre 2026.
-- Pedane conta-persone nei padiglioni, sensori AI agli stand, posizione degli stand per la mappa,
-- pacchetti degli espositori (la stima dal peso è riservata al PREMIUM), registrazione del visitatore con consensi separati
-- e lead magnet, così i contatti consegnati agli espositori sono MQL (Marketing Qualified Lead).
-- Pedane e sensori sono simulati nella demo: ogni riga dichiara la fonte.
SET search_path TO arcade;

-- Padiglioni e parametri: superficie e capienza per presenze, saturazione e visitatori per m²

ALTER TABLE padiglione
    ADD COLUMN superficie_mq  numeric(9,2) CHECK (superficie_mq > 0),
    ADD COLUMN capienza       integer      CHECK (capienza > 0);

ALTER TABLE parametri_stima
    ADD COLUMN soglia_avviso  numeric(3,2) NOT NULL DEFAULT 0.80 CHECK (soglia_avviso > 0 AND soglia_avviso <= 1);

-- Mappa interattiva: posizione dello stand nella griglia del padiglione

ALTER TABLE stand
    ADD COLUMN fila     smallint CHECK (fila > 0),
    ADD COLUMN colonna  smallint CHECK (colonna > 0),
    ADD CONSTRAINT stand_posizione_unica UNIQUE (padiglione, fila, colonna);

-- Pedane conta-persone: un conteggio al minuto per padiglione, nessun dato personale

CREATE TABLE passaggio_pedana (
    anno        smallint    NOT NULL REFERENCES edizione (anno),
    padiglione  text        NOT NULL REFERENCES padiglione (codice),
    minuto      timestamptz NOT NULL CHECK (extract(second FROM minuto) = 0),
    entrati     integer     NOT NULL CHECK (entrati >= 0),
    usciti      integer     NOT NULL CHECK (usciti >= 0),
    fonte       text        NOT NULL DEFAULT 'SIMULATA' CHECK (fonte IN ('SIMULATA','SENSORE')),
    PRIMARY KEY (padiglione, minuto)
);
CREATE INDEX passaggio_pedana_anno_idx ON passaggio_pedana (anno, minuto);

-- Sensori AI agli stand: nuove persone ferme davanti allo stand in quel minuto, l'immagine non lascia il dispositivo

CREATE TABLE conteggio_sensore_stand (
    anno                 smallint    NOT NULL REFERENCES edizione (anno),
    codice_stand         text        NOT NULL REFERENCES stand (codice),
    minuto               timestamptz NOT NULL CHECK (extract(second FROM minuto) = 0),
    nuove_persone_ferme  integer     NOT NULL CHECK (nuove_persone_ferme >= 0),
    fonte                text        NOT NULL DEFAULT 'SIMULATA' CHECK (fonte IN ('SIMULATA','SENSORE')),
    PRIMARY KEY (codice_stand, minuto)
);

-- Pacchetti degli espositori: il PREMIUM aggiunge la stima delle presenze dal peso

CREATE TABLE pacchetto_espositore (
    anno           smallint NOT NULL REFERENCES edizione (anno),
    id_espositore  text     NOT NULL REFERENCES espositore (id_espositore),
    livello        text     NOT NULL DEFAULT 'BASE' CHECK (livello IN ('BASE','PREMIUM')),
    PRIMARY KEY (anno, id_espositore)
);

-- Registrazione del visitatore: biglietto anche senza consensi, consensi separati e revocabili,
-- nessuna profilazione senza una fascia d'età adulta dichiarata (il modulo offre solo fasce da 18 anni in su)

CREATE TABLE registrazione_visitatore (
    id_registrazione        bigserial   PRIMARY KEY,
    anno                    smallint    NOT NULL REFERENCES edizione (anno),
    registrato_il           timestamptz NOT NULL DEFAULT now(),
    provincia               text        NOT NULL DEFAULT 'NON_DICHIARATO',
    fascia_eta              text        NOT NULL DEFAULT 'NON_DICHIARATO'
        CHECK (fascia_eta IN ('18-24','25-34','35-44','45+','NON_DICHIARATO')),
    consenso_marketing      boolean     NOT NULL DEFAULT false,
    consenso_espositori     boolean     NOT NULL DEFAULT false,
    consensi_aggiornati_il  timestamptz NOT NULL DEFAULT now(),
    profilabile             boolean     GENERATED ALWAYS AS (consenso_marketing AND fascia_eta <> 'NON_DICHIARATO') STORED
);

CREATE TABLE registrazione_riservata (
    id_registrazione  bigint PRIMARY KEY REFERENCES registrazione_visitatore (id_registrazione) ON DELETE CASCADE,
    nome              text,
    email             text   NOT NULL
);

CREATE TABLE interesse_visitatore (
    id_registrazione  bigint NOT NULL REFERENCES registrazione_visitatore (id_registrazione) ON DELETE CASCADE,
    interesse         text   NOT NULL CHECK (interesse IN ('BETA_TEST','NEWSLETTER','EVENTO','PRODOTTO','LAVORO_STAGE')),
    PRIMARY KEY (id_registrazione, interesse)
);

-- Lead magnet: ciò che il visitatore riceve in cambio del contatto, da ARCADE Milano (id_espositore vuoto) o da un espositore

CREATE TABLE lead_magnet (
    id_lead_magnet  bigserial PRIMARY KEY,
    anno            smallint NOT NULL REFERENCES edizione (anno),
    id_espositore   text     REFERENCES espositore (id_espositore),
    tipo            text     NOT NULL
        CHECK (tipo IN ('ACCESSO_BETA','CODICE_SCONTO','CONTENUTO_ESCLUSIVO','TORNEO','ESTRAZIONE','DEMO_PRIVATA')),
    titolo          text     NOT NULL,
    interesse       text     NOT NULL CHECK (interesse IN ('BETA_TEST','NEWSLETTER','EVENTO','PRODOTTO','LAVORO_STAGE')),
    attivo          boolean  NOT NULL DEFAULT true
);

-- Il contatto 2026 registra il lead magnet che lo ha generato, vuoto per i dati storici
ALTER TABLE contatto_stand
    ADD COLUMN id_lead_magnet bigint REFERENCES lead_magnet (id_lead_magnet);

-- Viste dei KPI

-- Persone presenti in ogni padiglione, minuto per minuto, dalla somma di entrati meno usciti dall'inizio della giornata
CREATE VIEW v_presenze_padiglione AS
SELECT p.anno,
       p.padiglione,
       p.minuto,
       sum(p.entrati) OVER w                                AS entrati_da_inizio_giornata,
       sum(p.usciti)  OVER w                                AS usciti_da_inizio_giornata,
       greatest(sum(p.entrati - p.usciti) OVER w, 0)        AS presenti,
       pd.capienza,
       pd.superficie_mq,
       round(100.0 * greatest(sum(p.entrati - p.usciti) OVER w, 0) / pd.capienza, 1) AS saturazione_pct,
       greatest(sum(p.entrati - p.usciti) OVER w, 0) >= ps.soglia_avviso * pd.capienza AS avviso
FROM passaggio_pedana p
JOIN padiglione pd      ON pd.codice = p.padiglione
JOIN parametri_stima ps ON ps.anno = p.anno
WINDOW w AS (PARTITION BY p.padiglione, (p.minuto AT TIME ZONE 'Europe/Rome')::date ORDER BY p.minuto);

-- Picco di presenza misurato: massimo delle persone presenti in tutta la fiera nello stesso minuto, per giorno
CREATE VIEW v_picco_presenza_giorno AS
WITH fiera AS (
    SELECT anno, minuto, sum(presenti) AS presenti
    FROM v_presenze_padiglione
    GROUP BY anno, minuto
)
SELECT DISTINCT ON (anno, (minuto AT TIME ZONE 'Europe/Rome')::date)
       anno,
       (minuto AT TIME ZONE 'Europe/Rome')::date AS giorno,
       minuto  AS ora_picco,
       presenti AS picco
FROM fiera
ORDER BY anno, (minuto AT TIME ZONE 'Europe/Rome')::date, presenti DESC, minuto;

-- Visitatori per m² ogni 15 minuti: media delle persone presenti nel quarto d'ora divisa per la superficie del padiglione
CREATE VIEW v_densita_padiglione_15min AS
SELECT anno,
       padiglione,
       date_bin('15 minutes', minuto, TIMESTAMPTZ '2000-01-01 00:00:00+00') AS quarto_ora,
       round(avg(presenti), 1)                                 AS presenti_medi,
       round(avg(presenti) / max(superficie_mq), 3)            AS visitatori_per_mq
FROM v_presenze_padiglione
GROUP BY anno, padiglione, date_bin('15 minutes', minuto, TIMESTAMPTZ '2000-01-01 00:00:00+00');

-- Stima delle presenze nello stand dal peso, al minuto. security_invoker: chi la legge è soggetto alle regole RLS
CREATE VIEW v_presenze_stand_peso WITH (security_invoker = true) AS
SELECT r.anno,
       r.codice_stand,
       date_trunc('minute', r.rilevato_il)                                     AS minuto,
       round(greatest(avg(r.peso_lordo_kg - r.tara_kg), 0) / p.peso_medio_kg)  AS presenze_stimate,
       count(*)                                                                AS letture
FROM rilevazione_peso r
JOIN parametri_stima p USING (anno)
GROUP BY r.anno, r.codice_stand, date_trunc('minute', r.rilevato_il), p.peso_medio_kg;

-- Resa dello stand: visite, persone ferme, contatti e conversioni
CREATE VIEW v_stand_conversione AS
SELECT s.anno,
       s.codice_stand,
       s.scansioni                                                       AS visite,
       f.persone_ferme,
       s.contatti,
       round(100.0 * s.contatti / nullif(s.scansioni, 0), 1)             AS contatti_ogni_100_visite,
       round(100.0 * s.contatti / nullif(f.persone_ferme, 0), 1)         AS contatti_su_persone_ferme_pct
FROM v_stand_riepilogo s
LEFT JOIN (SELECT anno, codice_stand, sum(nuove_persone_ferme) AS persone_ferme
             FROM conteggio_sensore_stand
            GROUP BY anno, codice_stand) f USING (anno, codice_stand);

-- MQL per stand: contatto adulto, con consenso valido, con un interesse dichiarato.
-- Dal 2026 serve anche il lead magnet richiesto, che conferma l'interesse con un'azione concreta.
CREATE VIEW v_mql_stand AS
SELECT c.anno,
       c.codice_stand,
       c.id_espositore,
       count(*) FILTER (WHERE c.utilizzabile_marketing
                          AND (c.anno < 2026 OR c.id_lead_magnet IS NOT NULL))  AS mql,
       count(*)                                                                AS contatti_raccolti,
       round(100.0 * count(*) FILTER (WHERE c.utilizzabile_marketing
                                        AND (c.anno < 2026 OR c.id_lead_magnet IS NOT NULL))
             / nullif(count(*), 0), 1)                                          AS quota_mql_pct
FROM contatto_stand c
GROUP BY c.anno, c.codice_stand, c.id_espositore;

-- Resa dei lead magnet: quanti MQL porta ognuno
CREATE VIEW v_lead_magnet_resa AS
SELECT m.anno, m.id_lead_magnet, m.id_espositore, m.tipo, m.titolo,
       count(c.id_contatto) FILTER (WHERE c.utilizzabile_marketing) AS mql
FROM lead_magnet m
LEFT JOIN contatto_stand c ON c.id_lead_magnet = m.id_lead_magnet
GROUP BY m.anno, m.id_lead_magnet, m.id_espositore, m.tipo, m.titolo;

-- Interesse del pubblico per categoria, solo da chi è profilabile e solo come totale
CREATE VIEW v_interessi_pubblico AS
SELECT r.anno, i.interesse, count(*) AS persone
FROM interesse_visitatore i
JOIN registrazione_visitatore r USING (id_registrazione)
WHERE r.profilabile
GROUP BY r.anno, i.interesse;

-- Permessi

GRANT SELECT ON passaggio_pedana, conteggio_sensore_stand, pacchetto_espositore,
                registrazione_visitatore, interesse_visitatore,
                v_presenze_padiglione, v_picco_presenza_giorno, v_densita_padiglione_15min,
                v_presenze_stand_peso, v_stand_conversione, v_interessi_pubblico,
                lead_magnet, v_mql_stand, v_lead_magnet_resa
    TO arcade_lettura;
GRANT SELECT ON registrazione_riservata TO arcade_dati_personali;

-- Un espositore vede il proprio pacchetto, i sensori AI del proprio stand e, solo se PREMIUM, la stima dal peso

ALTER TABLE pacchetto_espositore     ENABLE ROW LEVEL SECURITY;
ALTER TABLE conteggio_sensore_stand  ENABLE ROW LEVEL SECURITY;
ALTER TABLE rilevazione_peso         ENABLE ROW LEVEL SECURITY;
ALTER TABLE lead_magnet              ENABLE ROW LEVEL SECURITY;

CREATE POLICY lettura_completa ON pacchetto_espositore    FOR SELECT TO arcade_lettura USING (true);
CREATE POLICY lettura_completa ON conteggio_sensore_stand FOR SELECT TO arcade_lettura USING (true);
CREATE POLICY lettura_completa ON rilevazione_peso        FOR SELECT TO arcade_lettura USING (true);
CREATE POLICY lettura_completa ON lead_magnet             FOR SELECT TO arcade_lettura USING (true);

-- L'espositore vede i lead magnet di ARCADE Milano e i propri, mai quelli dei concorrenti
CREATE POLICY propri_e_di_arcade ON lead_magnet FOR SELECT TO arcade_espositore
    USING (id_espositore IS NULL OR id_espositore = current_setting('arcade.id_espositore', true));

CREATE POLICY solo_proprio_pacchetto ON pacchetto_espositore FOR SELECT TO arcade_espositore
    USING (id_espositore = current_setting('arcade.id_espositore', true));

CREATE POLICY solo_proprio_stand ON conteggio_sensore_stand FOR SELECT TO arcade_espositore
    USING (EXISTS (SELECT 1 FROM assegnazione_stand a
                    WHERE a.anno = conteggio_sensore_stand.anno
                      AND a.codice_stand = conteggio_sensore_stand.codice_stand
                      AND a.id_espositore = current_setting('arcade.id_espositore', true)));

CREATE POLICY solo_proprio_stand_premium ON rilevazione_peso FOR SELECT TO arcade_espositore
    USING (EXISTS (SELECT 1 FROM assegnazione_stand a
                     JOIN pacchetto_espositore k ON k.anno = a.anno AND k.id_espositore = a.id_espositore
                    WHERE a.anno = rilevazione_peso.anno
                      AND a.codice_stand = rilevazione_peso.codice_stand
                      AND a.id_espositore = current_setting('arcade.id_espositore', true)
                      AND k.livello = 'PREMIUM'));

GRANT SELECT ON pacchetto_espositore, conteggio_sensore_stand, rilevazione_peso, parametri_stima,
                lead_magnet, v_presenze_stand_peso
    TO arcade_espositore;
-- L'espositore non vede mai: registrazioni dei visitatori, pedane, viste aggregate della direzione.

-- Dizionario dati delle colonne nuove

INSERT INTO dizionario_dati (tabella, colonna, tipo, descrizione, sensibilita, titolare)
SELECT d.tabella, d.colonna, format_type(a.atttypid, a.atttypmod), d.descrizione, d.sensibilita, d.titolare
FROM (VALUES
    ('padiglione', 'superficie_mq', 'Superficie utile del padiglione in metri quadri', 'INTERNO', 'Organizzazione'),
    ('padiglione', 'capienza', 'Persone ammesse contemporaneamente nel padiglione', 'INTERNO', 'Organizzazione'),
    ('parametri_stima', 'soglia_avviso', 'Quota della capienza oltre cui lo staff riceve un avviso, 0,80 di partenza', 'INTERNO', 'Data Engineering'),
    ('stand', 'fila', 'Fila dello stand nella griglia della mappa', 'PUBBLICO', 'Organizzazione'),
    ('stand', 'colonna', 'Colonna dello stand nella griglia della mappa', 'PUBBLICO', 'Organizzazione'),
    ('passaggio_pedana', 'anno', 'Edizione', 'INTERNO', 'Controllo accessi'),
    ('passaggio_pedana', 'padiglione', 'Padiglione della pedana', 'INTERNO', 'Controllo accessi'),
    ('passaggio_pedana', 'minuto', 'Minuto del conteggio', 'INTERNO', 'Controllo accessi'),
    ('passaggio_pedana', 'entrati', 'Persone entrate nel padiglione in quel minuto', 'INTERNO', 'Controllo accessi'),
    ('passaggio_pedana', 'usciti', 'Persone uscite dal padiglione in quel minuto', 'INTERNO', 'Controllo accessi'),
    ('passaggio_pedana', 'fonte', 'SIMULATA o SENSORE', 'INTERNO', 'Controllo accessi'),
    ('conteggio_sensore_stand', 'anno', 'Edizione', 'INTERNO', 'Controllo accessi'),
    ('conteggio_sensore_stand', 'codice_stand', 'Stand del sensore', 'INTERNO', 'Controllo accessi'),
    ('conteggio_sensore_stand', 'minuto', 'Minuto del conteggio', 'INTERNO', 'Controllo accessi'),
    ('conteggio_sensore_stand', 'nuove_persone_ferme', 'Persone che si sono fermate davanti allo stand in quel minuto, senza immagini', 'INTERNO', 'Controllo accessi'),
    ('conteggio_sensore_stand', 'fonte', 'SIMULATA o SENSORE', 'INTERNO', 'Controllo accessi'),
    ('pacchetto_espositore', 'anno', 'Edizione', 'INTERNO', 'Commerciale'),
    ('pacchetto_espositore', 'id_espositore', 'Espositore', 'INTERNO', 'Commerciale'),
    ('pacchetto_espositore', 'livello', 'BASE oppure PREMIUM, il PREMIUM include la stima dal peso', 'INTERNO', 'Commerciale'),
    ('registrazione_visitatore', 'id_registrazione', 'Numero progressivo', 'INTERNO', 'Marketing'),
    ('registrazione_visitatore', 'anno', 'Edizione', 'INTERNO', 'Marketing'),
    ('registrazione_visitatore', 'registrato_il', 'Orario della registrazione', 'INTERNO', 'Marketing'),
    ('registrazione_visitatore', 'provincia', 'Provincia dichiarata, quasi-identificatore', 'RISERVATO', 'Marketing'),
    ('registrazione_visitatore', 'fascia_eta', 'Fascia d''età dichiarata, solo adulti, quasi-identificatore', 'RISERVATO', 'Marketing'),
    ('registrazione_visitatore', 'consenso_marketing', 'Consenso a offerte e novità di ARCADE Milano', 'RISERVATO', 'Marketing'),
    ('registrazione_visitatore', 'consenso_espositori', 'Consenso a essere contattato dagli espositori visitati', 'RISERVATO', 'Marketing'),
    ('registrazione_visitatore', 'consensi_aggiornati_il', 'Ultima modifica o revoca dei consensi', 'RISERVATO', 'Marketing'),
    ('registrazione_visitatore', 'profilabile', 'Vero solo con consenso marketing e fascia d''età adulta dichiarata', 'RISERVATO', 'Marketing'),
    ('registrazione_riservata', 'id_registrazione', 'Registrazione di appartenenza', 'PERSONALE', 'Marketing'),
    ('registrazione_riservata', 'nome', 'Nome del visitatore', 'PERSONALE', 'Marketing'),
    ('registrazione_riservata', 'email', 'Email del visitatore', 'PERSONALE', 'Marketing'),
    ('interesse_visitatore', 'id_registrazione', 'Registrazione di appartenenza', 'RISERVATO', 'Marketing'),
    ('interesse_visitatore', 'interesse', 'Interesse scelto nel modulo', 'RISERVATO', 'Marketing'),
    ('lead_magnet', 'id_lead_magnet', 'Numero progressivo', 'INTERNO', 'Marketing'),
    ('lead_magnet', 'anno', 'Edizione', 'INTERNO', 'Marketing'),
    ('lead_magnet', 'id_espositore', 'Espositore che lo offre, vuoto se lo offre ARCADE Milano', 'INTERNO', 'Marketing'),
    ('lead_magnet', 'tipo', 'Accesso beta, codice sconto, contenuto esclusivo, torneo, estrazione o demo privata', 'PUBBLICO', 'Marketing'),
    ('lead_magnet', 'titolo', 'Nome mostrato al visitatore', 'PUBBLICO', 'Marketing'),
    ('lead_magnet', 'interesse', 'Interesse che il lead magnet conferma', 'PUBBLICO', 'Marketing'),
    ('lead_magnet', 'attivo', 'Visibile nel portale e allo stand', 'INTERNO', 'Marketing'),
    ('contatto_stand', 'id_lead_magnet', 'Lead magnet che ha generato il contatto, vuoto per i dati storici', 'INTERNO', 'Marketing')
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
