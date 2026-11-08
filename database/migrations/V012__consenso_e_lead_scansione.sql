SET search_path TO arcade;

-- These fields capture consents from new scanner events; history stays unknown/false.
ALTER TABLE contatto_stand ADD COLUMN consenso_espositori boolean NOT NULL DEFAULT false;
ALTER TABLE scansione_stand ADD COLUMN id_lead_magnet bigint REFERENCES lead_magnet (id_lead_magnet);

INSERT INTO dizionario_dati (tabella, colonna, tipo, descrizione, sensibilita, titolare)
SELECT d.tabella, d.colonna, format_type(a.atttypid, a.atttypmod), d.descrizione, d.sensibilita, d.titolare
FROM (VALUES
  ('contatto_stand','consenso_espositori','Consenso esplicito a condividere il contatto con l’espositore','PERSONALE','Privacy'),
  ('scansione_stand','id_lead_magnet','Lead magnet associato alla scansione','INTERNO','Commerciale')
) AS d(tabella,colonna,descrizione,sensibilita,titolare)
JOIN pg_attribute a ON a.attrelid = ('arcade.' || d.tabella)::regclass AND a.attname = d.colonna;
