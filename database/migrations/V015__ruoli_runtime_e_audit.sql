SET search_path TO arcade;

DO $$
BEGIN
    IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'arcade_api') THEN CREATE ROLE arcade_api NOLOGIN; END IF;
    IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'arcade_pubblico') THEN CREATE ROLE arcade_pubblico NOLOGIN; END IF;
    IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'arcade_scrittura_pubblica') THEN CREATE ROLE arcade_scrittura_pubblica NOLOGIN; END IF;
    IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'arcade_registrazione') THEN CREATE ROLE arcade_registrazione NOLOGIN; END IF;
    IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'arcade_dispositivo') THEN CREATE ROLE arcade_dispositivo NOLOGIN; END IF;
    IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'arcade_bad') THEN CREATE ROLE arcade_bad NOLOGIN; END IF;
    IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'arcade_audit_writer') THEN CREATE ROLE arcade_audit_writer NOLOGIN; END IF;
    IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'arcade_audit_reader') THEN CREATE ROLE arcade_audit_reader NOLOGIN; END IF;
    IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'arcade_app') THEN
        RAISE EXCEPTION 'Create the arcade_app LOGIN role before applying V015';
    END IF;
END $$;

GRANT USAGE ON SCHEMA arcade TO arcade_api, arcade_pubblico, arcade_scrittura_pubblica,
    arcade_registrazione, arcade_dispositivo, arcade_bad, arcade_audit_writer, arcade_audit_reader;
GRANT arcade_api, arcade_pubblico, arcade_scrittura_pubblica, arcade_registrazione,
    arcade_dispositivo, arcade_bad, arcade_audit_writer, arcade_audit_reader,
    arcade_espositore, arcade_dati_personali, arcade_autenticazione TO arcade_app;
ALTER ROLE arcade_app NOINHERIT NOSUPERUSER NOCREATEDB NOCREATEROLE NOREPLICATION;

-- Internal API operations use a non-owner, non-superuser role. Personal data stays in dedicated roles.
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA arcade TO arcade_api;
GRANT USAGE, SELECT, UPDATE ON ALL SEQUENCES IN SCHEMA arcade TO arcade_api;
REVOKE ALL ON contatto_stand, contatto_riservato, registrazione_visitatore, registrazione_riservata,
    interesse_visitatore, richiesta_riservata, espositore_riservato, account_espositore,
    invito_espositore, recupero_password, revoca_registrazione_visitatore FROM arcade_api;

-- Do not expose quasi-identifying visitor rows through the generic reader role.
REVOKE SELECT ON registrazione_visitatore, interesse_visitatore FROM arcade_lettura;

-- Internal API reads/writes are explicit and still subject to RLS on tenant-scoped tables.
DO $$
DECLARE relation record;
BEGIN
    FOR relation IN
        SELECT c.relname
          FROM pg_class c
          JOIN pg_namespace n ON n.oid = c.relnamespace
         WHERE n.nspname = 'arcade' AND c.relkind = 'r' AND c.relrowsecurity
           AND c.relname NOT IN ('contatto_stand', 'contatto_riservato', 'registrazione_visitatore',
                'registrazione_riservata', 'interesse_visitatore', 'richiesta_riservata',
                'espositore_riservato', 'revoca_registrazione_visitatore')
    LOOP
        EXECUTE format('DROP POLICY IF EXISTS arcade_api_full ON arcade.%I', relation.relname);
        EXECUTE format('CREATE POLICY arcade_api_full ON arcade.%I FOR ALL TO arcade_api USING (true) WITH CHECK (true)', relation.relname);
        EXECUTE format('ALTER TABLE arcade.%I FORCE ROW LEVEL SECURITY', relation.relname);
    END LOOP;
END $$;

-- Only public columns/data needed by the public site and map.
GRANT SELECT ON edizione, padiglione, varco, stand, assegnazione_stand, planimetria_stand,
    profilo_espositore, categoria_espositore, espositore_categoria, lead_magnet, avviso TO arcade_pubblico;
CREATE POLICY arcade_public_assignments ON assegnazione_stand
    FOR SELECT TO arcade_pubblico USING (true);

-- Public routes need explicit policies where earlier migrations enabled RLS.
CREATE POLICY arcade_public_plan ON planimetria_stand FOR SELECT TO arcade_pubblico USING (true);
CREATE POLICY arcade_public_lead_magnets ON lead_magnet FOR SELECT TO arcade_pubblico
    USING (id_espositore IS NULL AND attivo);
CREATE POLICY arcade_public_notices ON avviso FOR SELECT TO arcade_pubblico
    USING (attivo AND pubblico = 'VISITATORI');

CREATE VIEW v_lead_magnet_pubblici AS
SELECT l.id_lead_magnet, l.anno, NULL::text AS codice_stand, l.tipo, l.titolo, l.interesse
  FROM lead_magnet l
 WHERE l.id_espositore IS NULL AND l.attivo
UNION ALL
SELECT l.id_lead_magnet, l.anno, a.codice_stand, l.tipo, l.titolo, l.interesse
  FROM lead_magnet l
  JOIN assegnazione_stand a ON a.anno = l.anno AND a.id_espositore = l.id_espositore
 WHERE l.id_espositore IS NOT NULL AND l.attivo;
GRANT SELECT ON v_lead_magnet_pubblici TO arcade_pubblico;

CREATE VIEW v_mappa_affollamento AS
SELECT k.codice, k.valore, k.unita, l.anno AS edizione, k.periodo_dal, k.periodo_al,
       k.dimensioni, k.fonte, k.qualita, k.flag_qualita, k.stimato, k.simulato, k.nota,
       l.calcolato_il, l.formula_versione
  FROM lotto_kpi l JOIN kpi_osservazione k USING (batch_id)
 WHERE k.codice = 'saturazione_pct';
GRANT SELECT ON v_mappa_affollamento TO arcade_pubblico;
GRANT SELECT ON v_mappa_affollamento TO arcade_api;

-- Public stand requests may add a request and its restricted contact details, but cannot read them back.
GRANT INSERT ON richiesta TO arcade_scrittura_pubblica;
GRANT SELECT (id_richiesta) ON richiesta TO arcade_scrittura_pubblica;
GRANT INSERT ON richiesta_riservata TO arcade_scrittura_pubblica;
ALTER TABLE richiesta_riservata ENABLE ROW LEVEL SECURITY;
ALTER TABLE richiesta_riservata FORCE ROW LEVEL SECURITY;
CREATE POLICY richiesta_public_insert ON richiesta_riservata
    FOR INSERT TO arcade_scrittura_pubblica WITH CHECK (true);
CREATE POLICY richiesta_personal_read ON richiesta_riservata
    FOR SELECT TO arcade_dati_personali USING (true);

-- Visitor registration accepts inserts and token-authorized consent updates only.
GRANT INSERT (anno, provincia, fascia_eta, consenso_marketing, consenso_espositori)
    ON registrazione_visitatore TO arcade_registrazione;
GRANT SELECT (id_registrazione, consenso_marketing, consenso_espositori,
    consensi_aggiornati_il, profilabile) ON registrazione_visitatore TO arcade_registrazione;
GRANT UPDATE (consenso_marketing, consenso_espositori, consensi_aggiornati_il)
    ON registrazione_visitatore TO arcade_registrazione;
GRANT INSERT ON registrazione_riservata, interesse_visitatore TO arcade_registrazione;
GRANT INSERT ON revoca_registrazione_visitatore TO arcade_registrazione;
GRANT SELECT (token_hash, id_registrazione, usato_il) ON revoca_registrazione_visitatore TO arcade_registrazione;
GRANT UPDATE (usato_il) ON revoca_registrazione_visitatore TO arcade_registrazione;
GRANT USAGE, SELECT ON SEQUENCE registrazione_visitatore_id_registrazione_seq TO arcade_registrazione;

ALTER TABLE registrazione_visitatore ENABLE ROW LEVEL SECURITY;
ALTER TABLE registrazione_visitatore FORCE ROW LEVEL SECURITY;
CREATE POLICY registrazione_public_insert ON registrazione_visitatore
    FOR INSERT TO arcade_registrazione WITH CHECK (true);
CREATE POLICY registrazione_token_update ON registrazione_visitatore
    FOR UPDATE TO arcade_registrazione USING (true) WITH CHECK (true);
CREATE POLICY registrazione_limited_return ON registrazione_visitatore
    FOR SELECT TO arcade_registrazione USING (true);

ALTER TABLE registrazione_riservata ENABLE ROW LEVEL SECURITY;
ALTER TABLE registrazione_riservata FORCE ROW LEVEL SECURITY;
CREATE POLICY registrazione_personal_insert ON registrazione_riservata
    FOR INSERT TO arcade_registrazione WITH CHECK (true);
CREATE POLICY registrazione_personal_read ON registrazione_riservata
    FOR SELECT TO arcade_dati_personali USING (true);

ALTER TABLE interesse_visitatore ENABLE ROW LEVEL SECURITY;
ALTER TABLE interesse_visitatore FORCE ROW LEVEL SECURITY;
CREATE POLICY interesse_registration_insert ON interesse_visitatore
    FOR INSERT TO arcade_registrazione WITH CHECK (true);

ALTER TABLE revoca_registrazione_visitatore ENABLE ROW LEVEL SECURITY;
ALTER TABLE revoca_registrazione_visitatore FORCE ROW LEVEL SECURITY;
CREATE POLICY token_revoca_access ON revoca_registrazione_visitatore
    FOR ALL TO arcade_registrazione USING (true) WITH CHECK (true);

-- Exhibitors can see only MQLs that are usable for marketing and explicitly shared with that exhibitor.
DROP POLICY IF EXISTS solo_propri_contatti_utilizzabili ON contatto_stand;
CREATE POLICY solo_propri_contatti_mql_condivisi ON contatto_stand
    FOR SELECT TO arcade_espositore
    USING (id_espositore = current_setting('arcade.id_espositore', true)
       AND consenso_espositori
       AND consenso_marketing = 'SI'
       AND utilizzabile_marketing
       AND fascia_eta IN ('18-24','25-34','35-44','45+')
       AND motivo_esclusione = 'NESSUNO'
       AND (anno < 2026 OR id_lead_magnet IS NOT NULL));
ALTER TABLE contatto_stand FORCE ROW LEVEL SECURITY;

ALTER TABLE contatto_riservato ENABLE ROW LEVEL SECURITY;
ALTER TABLE contatto_riservato FORCE ROW LEVEL SECURITY;
GRANT SELECT ON contatto_riservato TO arcade_espositore;
CREATE POLICY email_personal_data_read ON contatto_riservato
    FOR SELECT TO arcade_dati_personali USING (true);
CREATE POLICY email_exhibitor_mql_read ON contatto_riservato
    FOR SELECT TO arcade_espositore
    USING (EXISTS (
        SELECT 1 FROM contatto_stand c
         WHERE c.id_contatto = contatto_riservato.id_contatto
           AND c.id_espositore = current_setting('arcade.id_espositore', true)
           AND c.consenso_espositori AND c.consenso_marketing = 'SI'
           AND c.utilizzabile_marketing AND c.fascia_eta IN ('18-24','25-34','35-44','45+')
           AND c.motivo_esclusione = 'NESSUNO'
           AND (c.anno < 2026 OR c.id_lead_magnet IS NOT NULL)));

-- The exhibitor portal needs only its own legal company name and public stand geometry.
GRANT SELECT (id_espositore, ragione_sociale) ON espositore TO arcade_espositore;
GRANT SELECT ON stand, planimetria_stand TO arcade_espositore;
ALTER TABLE espositore ENABLE ROW LEVEL SECURITY;
ALTER TABLE espositore FORCE ROW LEVEL SECURITY;
CREATE POLICY arcade_api_company_access ON espositore
    FOR ALL TO arcade_api USING (true) WITH CHECK (true);
CREATE POLICY exhibitor_own_company ON espositore
    FOR SELECT TO arcade_espositore
    USING (id_espositore = current_setting('arcade.id_espositore', true));

-- Scanner/database service can insert only an explicitly shared lead without marketing permission.
GRANT SELECT (codice, id_evento, anno, categoria, giorno_valido, quantita, registrato_il)
    ON biglietto TO arcade_dispositivo;
GRANT SELECT ON accesso, assegnazione_stand, lead_magnet, acquisizione_evento, scansione_stand TO arcade_dispositivo;
CREATE POLICY dispositivo_assignment_read ON assegnazione_stand
    FOR SELECT TO arcade_dispositivo USING (true);
GRANT INSERT ON accesso, passaggio_pedana, conteggio_sensore_stand, rilevazione_peso,
    acquisizione_evento, scansione_stand, contatto_stand, contatto_riservato TO arcade_dispositivo;
GRANT SELECT (id_contatto, anno, id_espositore, consenso_marketing, consenso_espositori,
    utilizzabile_marketing, motivo_esclusione, id_lead_magnet) ON contatto_stand TO arcade_dispositivo;
CREATE POLICY dispositivo_scan_full ON scansione_stand
    FOR ALL TO arcade_dispositivo USING (true) WITH CHECK (true);
CREATE POLICY dispositivo_contact_read ON contatto_stand
    FOR SELECT TO arcade_dispositivo
    USING (consenso_espositori AND consenso_marketing = 'SI' AND utilizzabile_marketing
       AND fascia_eta IN ('18-24','25-34','35-44','45+')
       AND id_lead_magnet IS NOT NULL AND motivo_esclusione = 'NESSUNO');
CREATE POLICY dispositivo_contact_insert ON contatto_stand
    FOR INSERT TO arcade_dispositivo
    WITH CHECK (consenso_espositori AND consenso_marketing = 'SI'
        AND utilizzabile_marketing AND fascia_eta IN ('18-24','25-34','35-44','45+')
        AND id_lead_magnet IS NOT NULL AND motivo_esclusione = 'NESSUNO');
CREATE POLICY dispositivo_email_insert ON contatto_riservato
    FOR INSERT TO arcade_dispositivo
    WITH CHECK (EXISTS (
        SELECT 1 FROM contatto_stand c
         WHERE c.id_contatto = contatto_riservato.id_contatto
           AND c.consenso_espositori AND c.consenso_marketing = 'SI'
           AND c.utilizzabile_marketing AND c.fascia_eta IN ('18-24','25-34','35-44','45+')
           AND c.id_lead_magnet IS NOT NULL AND c.motivo_esclusione = 'NESSUNO'));
CREATE POLICY dispositivo_active_lead_magnet ON lead_magnet FOR SELECT TO arcade_dispositivo
    USING (attivo);

-- Sensor, scanner, and access routes write only through the dedicated role.
DO $$
DECLARE relation record;
BEGIN
    FOR relation IN
        SELECT c.relname
          FROM pg_class c
          JOIN pg_namespace n ON n.oid = c.relnamespace
         WHERE n.nspname = 'arcade' AND c.relkind = 'r' AND c.relrowsecurity
           AND c.relname IN ('passaggio_pedana','conteggio_sensore_stand','rilevazione_peso')
    LOOP
        EXECUTE format('CREATE POLICY dispositivo_insert ON arcade.%I FOR INSERT TO arcade_dispositivo WITH CHECK (true)', relation.relname);
        EXECUTE format('ALTER TABLE arcade.%I FORCE ROW LEVEL SECURITY', relation.relname);
    END LOOP;
END $$;

-- BAD receives purpose-built projections; raw registration/contact tables are not granted.
CREATE VIEW v_bi_vendite AS
SELECT b.id_evento AS ticket_ref, o.id_ordine AS ordine_ref, b.anno AS edizione, b.categoria,
       o.canale, b.giorno_valido, b.quantita, b.importo_eur, b.registrato_il, b.flag_qualita
  FROM biglietto b JOIN ordine o USING (id_ordine);
CREATE VIEW v_bi_accessi AS
SELECT a.id_evento, a.codice_biglietto AS raw_ticket_ref,
       ticket.id_evento AS matched_ticket_ref, a.anno AS edizione, a.varco,
       a.letto_il, a.esito, a.persone, a.flag_qualita
  FROM accesso a
  LEFT JOIN LATERAL (
      SELECT b.id_evento FROM biglietto b
       WHERE b.id_evento = a.codice_biglietto OR b.codice = a.codice_biglietto
       ORDER BY CASE WHEN b.id_evento = a.codice_biglietto THEN 0 ELSE 1 END LIMIT 1
  ) ticket ON true;
CREATE VIEW v_bi_stand AS
SELECT anno AS edizione, codice_stand, ora_inizio AS intervallo_dal, scansioni AS visite,
       NULL::integer AS contatti, NULL::integer AS contatti_con_consenso,
       NULL::integer AS persone_fermate, flag_qualita
  FROM visita_stand_ora;
CREATE VIEW v_bi_commerciale AS
SELECT p.anno AS edizione, p.id_espositore AS espositore_ref, p.codice_stand, p.pacchetto,
       coalesce(ps.superficie_mq, s.superficie_mq) AS superficie_mq,
       h.imponibile_listino_eur, h.sconto_dichiarato_pct AS sconto_percentuale,
       h.imponibile_netto_eur AS imponibile_eur, NULL::numeric AS acconto_pagato_eur,
       NULL::numeric AS saldo_pagato_eur
  FROM pratica p JOIN contratto_storico h USING (id_pratica)
  LEFT JOIN stand s ON s.codice = p.codice_stand
  LEFT JOIN planimetria_stand ps ON ps.anno = p.anno AND ps.codice_stand = p.codice_stand;
GRANT SELECT ON v_bi_vendite, v_bi_accessi, v_bi_stand, v_bi_commerciale,
    v_registro_anomalie TO arcade_bad;
GRANT SELECT, INSERT ON lotto_kpi, kpi_osservazione TO arcade_bad;
REVOKE UPDATE, DELETE ON lotto_kpi, kpi_osservazione FROM arcade_bad;

-- Password and account operations remain in their dedicated database role.
GRANT SELECT, INSERT, UPDATE ON recupero_password TO arcade_autenticazione;

CREATE TABLE auth_login_rate_limit (
    rate_key       text PRIMARY KEY CHECK (rate_key ~ '^[0-9a-f]{64}$'),
    window_started timestamptz NOT NULL,
    attempt_count  integer NOT NULL CHECK (attempt_count >= 0),
    last_attempt   timestamptz NOT NULL,
    blocked_until  timestamptz
);
CREATE INDEX auth_login_rate_limit_last_attempt_idx ON auth_login_rate_limit(last_attempt);
ALTER TABLE auth_login_rate_limit ENABLE ROW LEVEL SECURITY;
ALTER TABLE auth_login_rate_limit FORCE ROW LEVEL SECURITY;
CREATE POLICY auth_login_rate_limit_access ON auth_login_rate_limit
    FOR ALL TO arcade_autenticazione USING (true) WITH CHECK (true);
GRANT SELECT, INSERT, UPDATE, DELETE ON auth_login_rate_limit TO arcade_autenticazione;

CREATE TABLE audit_event (
    event_id   bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    occurred_at timestamptz NOT NULL DEFAULT clock_timestamp(),
    actor_ref  text CHECK (actor_ref IS NULL OR actor_ref ~ '^[0-9a-f]{64}$'),
    actor_role text NOT NULL CHECK (actor_role IN ('PUBBLICO','ESPOSITORE','COMMERCIALE','STAFF','AMMINISTRATORE','DIREZIONE','DEVICE','BAD')),
    action     text NOT NULL CHECK (action IN ('GET','POST','PATCH','PUT')),
    resource   text NOT NULL CHECK (length(resource) <= 200)
);
COMMENT ON TABLE audit_event IS 'Successful access to personal data and administrative operations; no tokens, request bodies, emails or IP addresses.';
ALTER TABLE audit_event ENABLE ROW LEVEL SECURITY;
ALTER TABLE audit_event FORCE ROW LEVEL SECURITY;
CREATE POLICY audit_write_only ON audit_event
    FOR INSERT TO arcade_audit_writer WITH CHECK (true);
CREATE POLICY audit_admin_read ON audit_event
    FOR SELECT TO arcade_audit_reader USING (true);
GRANT INSERT ON audit_event TO arcade_audit_writer;
GRANT USAGE, SELECT ON SEQUENCE audit_event_event_id_seq TO arcade_audit_writer;
GRANT SELECT ON audit_event TO arcade_audit_reader;
