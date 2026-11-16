-- V030: capienza provvisoria dei padiglioni, decisa dal team Stand up.
--
-- Dati reali di planimetria e capienza non esistono ancora (vedi
-- docs/dati-storici.md, docs/report-qualita-dati.md: "Capienze: DA COMPILARE").
-- Stima basata sul brief del cliente: oltre 50.000 presenze su 3 giorni di fiera,
-- con una crescita prevista di circa il 20% annuo.
--
-- Calcolo:
--   50.000 x 1,20 / 3 giorni        = 20.000 visitatori/giorno
--   20.000 x (permanenza media 4h / apertura 10h) = 8.000 presenti medi contemporanei
--   8.000 x 2 (fattore di picco)    = 16.000 presenti al picco
--   16.000 / 3 padiglioni           = 5.600 presenti di picco per padiglione
--   5.600 / 0,90 (capienza = 90% del picco) = 6.000 capienza per padiglione
--
-- Totale fiera: 6.000 x 3 padiglioni = 18.000.
-- Provvisoria: da sostituire con la capienza autorizzata della sede quando disponibile
-- (vedi docs/decisioni-da-confermare.md).

SET search_path TO arcade;

UPDATE padiglione
SET capienza = 6000
WHERE capienza IS NULL;

UPDATE dizionario_dati
SET descrizione = 'Persone ammesse contemporaneamente nel padiglione. Provvisoria: 6.000 stimata dal team sulla domanda 2026, da sostituire con la capienza autorizzata della sede'
WHERE tabella = 'padiglione' AND colonna = 'capienza';
