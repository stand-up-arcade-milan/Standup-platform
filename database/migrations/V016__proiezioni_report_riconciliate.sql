SET search_path TO arcade;
BEGIN;

-- BAD receives one row per stand/hour. If legacy aggregates and scanner events overlap,
-- scanner events are preferred and the overlap is made explicit instead of being summed.
DROP VIEW v_bi_stand;
CREATE VIEW v_bi_stand AS
WITH storico AS (
    SELECT anno,
           codice_stand,
           date_trunc('hour', ora_inizio AT TIME ZONE 'Europe/Rome') AT TIME ZONE 'Europe/Rome' AS intervallo_dal,
           sum(scansioni) FILTER (WHERE NOT 'FUORI_ORARIO_VALORE_ANOMALO' = ANY (flag_qualita))::bigint AS visite,
           CASE WHEN bool_or('FUORI_ORARIO_VALORE_ANOMALO' = ANY (flag_qualita))
                THEN ARRAY['FUORI_ORARIO_VALORE_ANOMALO']::text[]
                ELSE '{}'::text[] END AS flag_qualita
      FROM visita_stand_ora
     GROUP BY anno, codice_stand,
              date_trunc('hour', ora_inizio AT TIME ZONE 'Europe/Rome') AT TIME ZONE 'Europe/Rome'
), scanner AS (
    SELECT anno,
           codice_stand,
           date_trunc('hour', rilevata_il AT TIME ZONE 'Europe/Rome') AT TIME ZONE 'Europe/Rome' AS intervallo_dal,
           count(*) FILTER (WHERE NOT duplicata)::bigint AS visite
      FROM scansione_stand
     GROUP BY anno, codice_stand,
              date_trunc('hour', rilevata_il AT TIME ZONE 'Europe/Rome') AT TIME ZONE 'Europe/Rome'
), contatti AS (
    SELECT anno,
           codice_stand,
           date_trunc('hour', raccolto_il AT TIME ZONE 'Europe/Rome') AT TIME ZONE 'Europe/Rome' AS intervallo_dal,
           count(*)::integer AS contatti,
           count(*) FILTER (WHERE consenso_espositori
                              AND consenso_marketing = 'SI'
                              AND utilizzabile_marketing
                              AND fascia_eta IN ('18-24','25-34','35-44','45+')
                              AND motivo_esclusione = 'NESSUNO'
                              AND (anno < 2026 OR id_lead_magnet IS NOT NULL))::integer AS contatti_con_consenso
      FROM contatto_stand
     GROUP BY anno, codice_stand,
              date_trunc('hour', raccolto_il AT TIME ZONE 'Europe/Rome') AT TIME ZONE 'Europe/Rome'
), persone_fermate AS (
    SELECT anno,
           codice_stand,
           date_trunc('hour', minuto AT TIME ZONE 'Europe/Rome') AT TIME ZONE 'Europe/Rome' AS intervallo_dal,
           sum(nuove_persone_ferme)::bigint AS persone_fermate,
           array_agg(DISTINCT fonte) AS fonti
      FROM conteggio_sensore_stand
     GROUP BY anno, codice_stand,
              date_trunc('hour', minuto AT TIME ZONE 'Europe/Rome') AT TIME ZONE 'Europe/Rome'
), intervalli AS (
    SELECT anno, codice_stand, intervallo_dal FROM storico
    UNION
    SELECT anno, codice_stand, intervallo_dal FROM scanner
    UNION
    SELECT anno, codice_stand, intervallo_dal FROM contatti
    UNION
    SELECT anno, codice_stand, intervallo_dal FROM persone_fermate
)
SELECT i.anno AS edizione,
       i.codice_stand,
       i.intervallo_dal,
       coalesce(live.visite, legacy.visite)::bigint AS visite,
       coalesce(c.contatti, 0)::integer AS contatti,
       coalesce(c.contatti_con_consenso, 0)::integer AS contatti_con_consenso,
       stopped.persone_fermate,
       array_remove(coalesce(legacy.flag_qualita, '{}'::text[]) || ARRAY[
           CASE WHEN live.intervallo_dal IS NOT NULL AND legacy.intervallo_dal IS NOT NULL THEN 'SCANNER_PREFERITO_FONTE_SOVRAPPOSTA' END,
           CASE WHEN live.intervallo_dal IS NULL AND legacy.intervallo_dal IS NULL THEN 'VISITE_NON_RILEVATE_NELL_INTERVALLO' END
       ], NULL)::text[] AS flag_qualita,
       array_remove(ARRAY[
           CASE WHEN live.intervallo_dal IS NOT NULL THEN 'SCANSIONE_STAND' END,
           CASE WHEN legacy.intervallo_dal IS NOT NULL THEN 'VISITA_STAND_ORA' END,
           CASE WHEN c.contatti IS NOT NULL THEN 'CONTATTO_STAND' END,
           CASE WHEN 'SENSORE' = ANY(coalesce(stopped.fonti, '{}'::text[])) THEN 'SENSORE_AI:SENSORE' END,
           CASE WHEN 'SIMULATA' = ANY(coalesce(stopped.fonti, '{}'::text[])) THEN 'SENSORE_AI:SIMULATA' END
       ], NULL)::text[] AS fonti
  FROM intervalli i
  LEFT JOIN storico legacy USING (anno, codice_stand, intervallo_dal)
  LEFT JOIN scanner live USING (anno, codice_stand, intervallo_dal)
  LEFT JOIN contatti c USING (anno, codice_stand, intervallo_dal)
  LEFT JOIN persone_fermate stopped USING (anno, codice_stand, intervallo_dal);

-- Historical signed totals remain authoritative. New practices use their saved line prices;
-- unknown historical deposit amounts stay NULL and balance payments are not inferred.
DROP VIEW v_bi_commerciale;
CREATE VIEW v_bi_commerciale AS
WITH righe AS (
    SELECT id_pratica,
           sum(quantita * prezzo_unitario_eur)::numeric(12,2) AS imponibile_listino_eur
      FROM voce_pratica
     GROUP BY id_pratica
), acconti AS (
    SELECT id_pratica, sum(importo_eur)::numeric(12,2) AS importo_eur
      FROM acconto
     GROUP BY id_pratica
)
SELECT p.anno AS edizione,
       p.id_espositore AS espositore_ref,
       p.codice_stand,
       p.pacchetto,
       coalesce(ps.superficie_mq, s.superficie_mq) AS superficie_mq,
       coalesce(h.imponibile_listino_eur, r.imponibile_listino_eur) AS imponibile_listino_eur,
       coalesce(h.sconto_dichiarato_pct, p.sconto_percentuale) AS sconto_percentuale,
       coalesce(h.imponibile_netto_eur, vp.totale_eur) AS imponibile_eur,
       CASE
           WHEN a.importo_eur IS NOT NULL THEN a.importo_eur
           WHEN h.acconto_pagato_il IS NOT NULL THEN NULL
           ELSE 0::numeric
       END AS acconto_pagato_eur,
       NULL::numeric AS saldo_pagato_eur,
       p.stato,
       h.data_firma AS data_firma,
       array_remove(ARRAY[
           CASE WHEN h.acconto_pagato_il IS NOT NULL AND a.importo_eur IS NULL THEN 'IMPORTO_ACCONTO_STORICO_NON_DICHIARATO' END,
           'SALDO_NON_TRACCIATO'
       ], NULL)::text[] || coalesce(h.flag_qualita, '{}'::text[]) AS flag_qualita,
       CASE WHEN h.id_pratica IS NOT NULL THEN 'CONTRATTO_STORICO' ELSE 'PRATICA_CORRENTE' END AS fonte
  FROM pratica p
  LEFT JOIN v_pratica vp ON vp.id_pratica = p.id_pratica
  LEFT JOIN contratto_storico h ON h.id_pratica = p.id_pratica
  LEFT JOIN righe r ON r.id_pratica = p.id_pratica
  LEFT JOIN acconti a ON a.id_pratica = p.id_pratica
  LEFT JOIN stand s ON s.codice = p.codice_stand
  LEFT JOIN planimetria_stand ps ON ps.anno = p.anno AND ps.codice_stand = p.codice_stand;

GRANT SELECT ON v_bi_stand, v_bi_commerciale TO arcade_bad;

COMMENT ON VIEW v_bi_stand IS 'Fatti aggregati orari per BAD; non somma fonti sovrapposte e non espone dati personali.';
COMMENT ON VIEW v_bi_commerciale IS 'Fatti commerciali per BAD; conserva NULL quando un importo storico non e dichiarato.';
COMMIT;
