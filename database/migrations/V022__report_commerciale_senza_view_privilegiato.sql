SET search_path TO arcade;
BEGIN;

-- The BAD projection must not depend on the exhibitor-facing security_invoker view
-- v_pratica: BAD can read this narrow projection, but must not receive base-table grants.
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
       coalesce(h.imponibile_netto_eur,
                round(coalesce(r.imponibile_listino_eur, 0) * (1 - p.sconto_percentuale / 100), 2)) AS imponibile_eur,
       CASE
           WHEN a.importo_eur IS NOT NULL THEN a.importo_eur
           WHEN h.acconto_pagato_il IS NOT NULL THEN NULL
           ELSE 0::numeric
       END AS acconto_pagato_eur,
       NULL::numeric AS saldo_pagato_eur,
       p.stato,
       coalesce(p.firmata_il::date, h.data_firma) AS data_firma,
       array_remove(ARRAY[
           CASE WHEN h.acconto_pagato_il IS NOT NULL AND a.importo_eur IS NULL THEN 'IMPORTO_ACCONTO_STORICO_NON_DICHIARATO' END,
           'SALDO_NON_TRACCIATO'
       ], NULL)::text[] || coalesce(h.flag_qualita, '{}'::text[]) AS flag_qualita,
       CASE WHEN h.id_pratica IS NOT NULL THEN 'CONTRATTO_STORICO' ELSE 'PRATICA_CORRENTE' END AS fonte
  FROM pratica p
  LEFT JOIN contratto_storico h USING (id_pratica)
  LEFT JOIN righe r USING (id_pratica)
  LEFT JOIN acconti a USING (id_pratica)
  LEFT JOIN stand s ON s.codice = p.codice_stand
  LEFT JOIN planimetria_stand ps ON ps.anno = p.anno AND ps.codice_stand = p.codice_stand;

GRANT SELECT ON v_bi_commerciale TO arcade_bad;
COMMENT ON VIEW v_bi_commerciale IS 'Fatti commerciali minimizzati per BAD; i dati non dichiarati restano NULL e non espongono tabelle riservate.';

COMMIT;
