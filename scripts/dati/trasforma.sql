-- Trasformazione da staging a schema arcade. Ogni istruzione è ripetibile: ON CONFLICT DO NOTHING sulle chiavi.
-- Gli orari del file sono in ora italiana: si convertono in timestamptz con Europe/Rome.
SET search_path TO arcade;

-- 1. Anagrafiche ricavate dai dati
INSERT INTO stand (codice, padiglione)
SELECT DISTINCT luogo, padiglione FROM staging.eventi WHERE fonte IN ('SCANNER_STAND','CONTATTI_STAND')
ON CONFLICT DO NOTHING;

INSERT INTO espositore (id_espositore)
SELECT DISTINCT id_espositore FROM staging.eventi WHERE fonte IN ('SCANNER_STAND','CONTATTI_STAND')
ON CONFLICT DO NOTHING;

INSERT INTO assegnazione_stand (anno, codice_stand, id_espositore)
SELECT DISTINCT edizione::smallint, luogo, id_espositore FROM staging.eventi WHERE fonte IN ('SCANNER_STAND','CONTATTI_STAND')
ON CONFLICT DO NOTHING;

-- 2. Biglietteria
INSERT INTO ordine (id_ordine, anno, canale)
SELECT DISTINCT id_ordine, edizione::smallint, luogo FROM staging.eventi WHERE fonte = 'BIGLIETTERIA'
ON CONFLICT DO NOTHING;

INSERT INTO biglietto (codice, id_evento, id_ordine, anno, categoria, giorno_valido, registrato_il, fascia_eta, minore,
                       provincia, codice_sconto, quantita, importo_eur, flag_qualita)
SELECT id_riferimento, id_evento, id_ordine, edizione::smallint, categoria_biglietto,
       CASE WHEN giorno_valido = 'TUTTI' THEN NULL ELSE giorno_valido::date END,
       (data || ' ' || ora)::timestamp AT TIME ZONE 'Europe/Rome',
       fascia_eta, minore, provincia, codice_sconto, quantita::smallint, importo_eur::numeric,
       CASE WHEN controllo_qualita = 'OK' THEN '{}' ELSE string_to_array(controllo_qualita, '|') END
FROM staging.eventi WHERE fonte = 'BIGLIETTERIA'
ON CONFLICT DO NOTHING;

-- 3. Tornelli
INSERT INTO accesso (id_evento, anno, varco, letto_il, codice_biglietto, esito, persone, flag_qualita)
SELECT id_evento, edizione::smallint, luogo, (data || ' ' || ora)::timestamp AT TIME ZONE 'Europe/Rome',
       id_riferimento, evento, quantita::smallint,
       CASE WHEN controllo_qualita = 'OK' THEN '{}' ELSE string_to_array(controllo_qualita, '|') END
FROM staging.eventi WHERE fonte = 'TORNELLI'
ON CONFLICT DO NOTHING;

-- 4. Stand
INSERT INTO visita_stand_ora (id_riferimento, id_evento, anno, codice_stand, ora_inizio, scansioni, flag_qualita)
SELECT id_riferimento, id_evento, edizione::smallint, luogo, (data || ' ' || ora)::timestamp AT TIME ZONE 'Europe/Rome',
       quantita::integer,
       CASE WHEN controllo_qualita = 'OK' THEN '{}' ELSE string_to_array(controllo_qualita, '|') END
FROM staging.eventi WHERE fonte = 'SCANNER_STAND'
ON CONFLICT DO NOTHING;

INSERT INTO fascia_stand_mancante (codice_stand, ora_inizio)
SELECT codice_stand, (data || ' ' || ora)::timestamp AT TIME ZONE 'Europe/Rome' FROM staging.fasce_mancanti
ON CONFLICT DO NOTHING;

INSERT INTO contatto_stand (id_contatto, id_evento, anno, codice_stand, id_espositore, raccolto_il, fascia_eta, provincia,
                            interesse, consenso_marketing, utilizzabile_marketing, motivo_esclusione, email_su_piu_stand, flag_qualita)
SELECT e.id_riferimento, e.id_evento, e.edizione::smallint, e.luogo, e.id_espositore,
       (e.data || ' ' || e.ora)::timestamp AT TIME ZONE 'Europe/Rome',
       e.fascia_eta, e.provincia, e.interesse, c.consenso_marketing,
       c.utilizzabile_marketing = 'SI', c.motivo_esclusione, c.email_su_piu_stand = 'SI',
       CASE WHEN e.controllo_qualita = 'OK' THEN '{}' ELSE string_to_array(e.controllo_qualita, '|') END
FROM staging.eventi e
JOIN staging.contatti c ON c.id_contatto = e.id_riferimento
WHERE e.fonte = 'CONTATTI_STAND'
ON CONFLICT DO NOTHING;

INSERT INTO contatto_riservato (id_contatto, email)
SELECT id_contatto, email FROM staging.contatti WHERE id_contatto IN (SELECT id_contatto FROM contatto_stand)
ON CONFLICT DO NOTHING;

-- 5. Registro delle anomalie e righe scartate
INSERT INTO catalogo_anomalia (fonte, codice, descrizione, righe_coinvolte, gestione)
SELECT fonte, codice, descrizione, NULLIF(righe_coinvolte, '')::integer, gestione FROM staging.anomalie
ON CONFLICT DO NOTHING;

INSERT INTO scarto_importazione (fonte, motivo, riga_originale)
SELECT fonte, motivo, riga_originale FROM staging.scarti
ON CONFLICT DO NOTHING;
