SET search_path TO arcade;
BEGIN;

ALTER TABLE pratica ADD COLUMN firmata_il timestamptz;
ALTER TABLE documento_pratica
    ADD COLUMN mime_type text,
    ADD COLUMN dimensione_byte bigint,
    ADD COLUMN sha256 text,
    ADD COLUMN contenuto_pdf bytea;

ALTER TABLE documento_pratica
    ADD CONSTRAINT documento_pratica_dimensione_check
        CHECK (dimensione_byte IS NULL OR dimensione_byte >= 0),
    ADD CONSTRAINT documento_pratica_sha256_check
        CHECK (sha256 IS NULL OR sha256 ~ '^[0-9a-f]{64}$'),
    ADD CONSTRAINT documento_pratica_archivio_check
        CHECK (contenuto_pdf IS NULL OR (mime_type = 'application/pdf' AND dimensione_byte > 0 AND sha256 IS NOT NULL));

-- Generated documents are append-only. Legacy SharePoint links remain available as metadata.
ALTER TABLE documento_pratica ENABLE ROW LEVEL SECURITY;
ALTER TABLE documento_pratica FORCE ROW LEVEL SECURITY;
CREATE POLICY documento_api_access ON documento_pratica
    FOR ALL TO arcade_api USING (true) WITH CHECK (true);
CREATE POLICY documento_espositore_proprio ON documento_pratica
    FOR SELECT TO arcade_espositore USING (
        EXISTS (
            SELECT 1 FROM pratica p
             WHERE p.id_pratica = documento_pratica.id_pratica
               AND p.id_espositore = current_setting('arcade.id_espositore', true)
        )
    );
GRANT SELECT, INSERT ON documento_pratica TO arcade_api;
GRANT SELECT ON documento_pratica TO arcade_espositore;
REVOKE UPDATE, DELETE ON documento_pratica FROM arcade_api;

-- The saved signature timestamp supports reporting; historic dates remain authoritative.
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
       coalesce(p.firmata_il::date, h.data_firma) AS data_firma,
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
GRANT SELECT ON v_bi_commerciale TO arcade_bad;
COMMENT ON VIEW v_bi_commerciale IS 'Fatti commerciali per BAD; conserva NULL quando un importo storico non e dichiarato.';

INSERT INTO dizionario_dati (tabella, colonna, tipo, descrizione, sensibilita, titolare)
SELECT d.tabella, d.colonna, format_type(a.atttypid, a.atttypmod), d.descrizione, d.sensibilita, d.titolare
  FROM (VALUES
      ('pratica','firmata_il','Istante registrato dal flusso quando lo stato diventa FIRMATA','INTERNO','Commerciale'),
      ('documento_pratica','mime_type','Tipo MIME del file archiviato','INTERNO','Commerciale'),
      ('documento_pratica','dimensione_byte','Dimensione del file archiviato in byte','INTERNO','Commerciale'),
      ('documento_pratica','sha256','Impronta SHA-256 per verificare l''integrita del file','INTERNO','Commerciale'),
      ('documento_pratica','contenuto_pdf','Documento PDF generato e archiviato nel database','RISERVATO','Commerciale')
  ) AS d(tabella,colonna,descrizione,sensibilita,titolare)
  JOIN pg_attribute a ON a.attrelid = ('arcade.' || d.tabella)::regclass AND a.attname = d.colonna;

COMMIT;
