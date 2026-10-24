-- V003: viste di base per i KPI calcolabili dai dati storici. Nessuna contiene dati personali.
SET search_path TO arcade;

CREATE VIEW v_ingressi_per_ora AS
SELECT anno,
       varco,
       date_trunc('hour', letto_il AT TIME ZONE 'Europe/Rome') AS ora_locale,
       sum(persone) AS persone
FROM accesso
WHERE esito = 'INGRESSO'
GROUP BY anno, varco, date_trunc('hour', letto_il AT TIME ZONE 'Europe/Rome');

-- Presenze stimate: persone entrate nelle ultime N ore (parametri_stima.ore_permanenza), il file non ha le uscite
CREATE VIEW v_presenze_stimate_ora AS
WITH ore AS (
    SELECT anno, ora_locale, sum(persone) AS persone
    FROM v_ingressi_per_ora
    GROUP BY anno, ora_locale
)
SELECT o.anno,
       o.ora_locale,
       (SELECT sum(x.persone)
          FROM ore x
         WHERE x.anno = o.anno
           AND x.ora_locale >  o.ora_locale - (p.ore_permanenza * interval '1 hour')
           AND x.ora_locale <= o.ora_locale) AS presenze_stimate
FROM ore o
JOIN parametri_stima p USING (anno);

CREATE VIEW v_vendite_per_categoria AS
SELECT anno, categoria, sum(quantita) AS persone, count(*) AS biglietti, sum(importo_eur) AS incasso_eur
FROM biglietto
GROUP BY anno, categoria;

CREATE VIEW v_vendite_per_canale AS
SELECT b.anno, o.canale, count(*) AS biglietti, sum(b.quantita) AS persone, sum(b.importo_eur) AS incasso_eur
FROM biglietto b
JOIN ordine o USING (id_ordine)
GROUP BY b.anno, o.canale;

-- Biglietti venduti e mai passati ai varchi
CREATE VIEW v_biglietti_non_utilizzati AS
SELECT b.anno, b.categoria, count(*) AS biglietti, sum(b.quantita) AS persone
FROM biglietto b
WHERE NOT EXISTS (SELECT 1 FROM accesso a WHERE a.codice_biglietto = b.codice AND a.esito = 'INGRESSO')
GROUP BY b.anno, b.categoria;

-- Visite per stand: le fasce con picco fuori orario sono escluse finché il cliente non le chiarisce
CREATE VIEW v_stand_riepilogo AS
SELECT v.anno,
       v.codice_stand,
       sum(v.scansioni) FILTER (WHERE NOT 'FUORI_ORARIO_VALORE_ANOMALO' = ANY (v.flag_qualita)) AS scansioni,
       (SELECT count(*) FROM contatto_stand c WHERE c.codice_stand = v.codice_stand AND c.anno = v.anno) AS contatti,
       (SELECT count(*) FROM contatto_stand c WHERE c.codice_stand = v.codice_stand AND c.anno = v.anno
                                                  AND c.utilizzabile_marketing) AS contatti_utilizzabili
FROM visita_stand_ora v
GROUP BY v.anno, v.codice_stand;

-- Registro delle anomalie, calcolato in tempo reale dai flag delle righe
CREATE VIEW v_registro_anomalie AS
SELECT 'biglietto' AS tabella, anno, flag, count(*) AS righe FROM biglietto, unnest(flag_qualita) AS flag GROUP BY anno, flag
UNION ALL
SELECT 'accesso',  anno, flag, count(*) FROM accesso, unnest(flag_qualita) AS flag GROUP BY anno, flag
UNION ALL
SELECT 'visita_stand_ora', anno, flag, count(*) FROM visita_stand_ora, unnest(flag_qualita) AS flag GROUP BY anno, flag
UNION ALL
SELECT 'contatto_stand', anno, flag, count(*) FROM contatto_stand, unnest(flag_qualita) AS flag GROUP BY anno, flag;
