-- Solo database usa-e-getta per la suite API integrata. Tutte le righe sono sintetiche.
SET search_path TO arcade;
BEGIN;

INSERT INTO edizione (anno, sede, stato, inizio_fiera, fine_fiera)
VALUES (2026, 'Fixture CI', 'ATTIVA', '2026-12-18', '2026-12-20')
ON CONFLICT (anno) DO UPDATE SET sede=EXCLUDED.sede, stato=EXCLUDED.stato,
    inizio_fiera=EXCLUDED.inizio_fiera, fine_fiera=EXCLUDED.fine_fiera;
INSERT INTO edizione (anno, sede, stato, inizio_fiera, fine_fiera)
VALUES (2027, 'Fixture CI', 'PIANIFICATA', NULL, NULL)
ON CONFLICT (anno) DO UPDATE SET sede=EXCLUDED.sede, stato=EXCLUDED.stato,
    inizio_fiera=EXCLUDED.inizio_fiera, fine_fiera=EXCLUDED.fine_fiera;
INSERT INTO parametri_stima (anno) VALUES (2026), (2027) ON CONFLICT (anno) DO NOTHING;

INSERT INTO stand (codice, padiglione, superficie_mq, disponibile)
VALUES ('CI-STAND-01', 'P1', 18, true), ('CI-STAND-02', 'P1', 12, true)
ON CONFLICT (codice) DO UPDATE SET superficie_mq=EXCLUDED.superficie_mq, disponibile=true;
INSERT INTO planimetria_stand (anno, codice_stand, padiglione, nome_padiglione, superficie_mq, posizione)
VALUES (2026, 'CI-STAND-01', 'P1', 'Padiglione 1', 18, 'Fixture A-01'),
       (2026, 'CI-STAND-02', 'P1', 'Padiglione 1', 12, 'Fixture A-02'),
       (2027, 'CI-STAND-01', 'P1', 'Padiglione 1', 18, 'Fixture A-01')
ON CONFLICT (anno, codice_stand) DO UPDATE SET superficie_mq=EXCLUDED.superficie_mq, posizione=EXCLUDED.posizione;

INSERT INTO espositore (id_espositore, ragione_sociale)
VALUES ('CI-EXHIBITOR-01', 'Arcade Test Uno S.r.l.'), ('CI-EXHIBITOR-02', 'Arcade Test Due S.r.l.')
ON CONFLICT (id_espositore) DO UPDATE SET ragione_sociale=EXCLUDED.ragione_sociale;
INSERT INTO espositore_riservato (id_espositore, partita_iva, settore, citta, referente, email_referente)
VALUES ('CI-EXHIBITOR-01', 'IT00000000001', 'Videogiochi', 'Milano', 'Ada Test', 'ada@example.invalid'),
       ('CI-EXHIBITOR-02', 'IT00000000002', 'Accessori', 'Torino', 'Luca Test', 'luca@example.invalid')
ON CONFLICT (id_espositore) DO UPDATE SET partita_iva=EXCLUDED.partita_iva, settore=EXCLUDED.settore,
    citta=EXCLUDED.citta, referente=EXCLUDED.referente, email_referente=EXCLUDED.email_referente;
INSERT INTO profilo_espositore (id_espositore, nome_pubblico, descrizione, in_evidenza)
VALUES ('CI-EXHIBITOR-01', 'Arcade Test Uno', 'Profilo sintetico usato dalla CI.', false),
       ('CI-EXHIBITOR-02', 'Arcade Test Due', 'Profilo sintetico usato dalla CI.', false)
ON CONFLICT (id_espositore) DO UPDATE SET nome_pubblico=EXCLUDED.nome_pubblico, descrizione=EXCLUDED.descrizione;

INSERT INTO listino_voce (anno, codice_voce, descrizione, tipo, unita, prezzo_eur)
VALUES (2026, 'SPAZIO-CI', 'Spazio espositivo di prova', 'STAND', 'MQ', 80.00),
       (2027, 'SPAZIO-CI', 'Spazio espositivo di prova', 'STAND', 'MQ', 80.00)
ON CONFLICT (anno, codice_voce) DO UPDATE SET descrizione=EXCLUDED.descrizione, prezzo_eur=EXCLUDED.prezzo_eur;

INSERT INTO lead_magnet (id_lead_magnet, anno, id_espositore, tipo, titolo, interesse, attivo)
VALUES (990001, 2026, 'CI-EXHIBITOR-01', 'CONTENUTO_ESCLUSIVO', 'Materiale sintetico CI', 'NEWSLETTER', true)
ON CONFLICT (id_lead_magnet) DO UPDATE SET anno=EXCLUDED.anno, id_espositore=EXCLUDED.id_espositore,
    tipo=EXCLUDED.tipo, titolo=EXCLUDED.titolo, interesse=EXCLUDED.interesse, attivo=true;

INSERT INTO ordine (id_ordine, anno, canale) VALUES ('CI-ORDER-01', 2026, 'ONLINE')
ON CONFLICT (id_ordine) DO NOTHING;
INSERT INTO biglietto (codice, id_evento, id_ordine, anno, categoria, giorno_valido, registrato_il, quantita, importo_eur)
VALUES ('CI-TICKET-01', 'CI-TICKET-EVENT-01', 'CI-ORDER-01', 2026, 'INTERO', NULL, now(), 1, 0)
ON CONFLICT (codice) DO UPDATE SET anno=EXCLUDED.anno, id_ordine=EXCLUDED.id_ordine;

-- Record legacy sovrapposto: il report deve preferire il conteggio scanner, senza sommare 99 + scansioni.
INSERT INTO visita_stand_ora (id_riferimento, id_evento, anno, codice_stand, ora_inizio, scansioni, flag_qualita)
VALUES ('CI-LEGACY-01', 'CI-LEGACY-EVENT-01', 2026, 'CI-STAND-01', date_trunc('hour', now()), 99, '{}')
ON CONFLICT (id_riferimento) DO UPDATE SET ora_inizio=EXCLUDED.ora_inizio, scansioni=EXCLUDED.scansioni;

COMMIT;
