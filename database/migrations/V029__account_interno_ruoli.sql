-- V029: account interni con email e password per i ruoli operativi.
-- La schermata di accesso è l'unica porta d'ingresso: staff, commerciale e
-- amministrazione entrano come direzione ed espositori, con hash PBKDF2
-- nella stessa forma di account_direzione e account_espositore.
SET search_path TO arcade;

CREATE TABLE IF NOT EXISTS account_interno (
    id_account     uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    email          text NOT NULL UNIQUE,
    password_hash  text NOT NULL,
    ruolo          text NOT NULL CHECK (ruolo IN ('STAFF','COMMERCIALE','AMMINISTRATORE')),
    attivo         boolean NOT NULL DEFAULT true,
    creato_il      timestamptz NOT NULL DEFAULT now(),
    ultimo_accesso timestamptz
);

CREATE INDEX IF NOT EXISTS idx_account_interno_email ON account_interno(email);
CREATE INDEX IF NOT EXISTS idx_account_interno_attivo ON account_interno(attivo);

GRANT SELECT, INSERT, UPDATE ON account_interno TO arcade_autenticazione;

-- Dizionario dati
INSERT INTO dizionario_dati (tabella, colonna, tipo, descrizione, sensibilita, titolare)
SELECT d.tabella, d.colonna, format_type(a.atttypid, a.atttypmod), d.descrizione, d.sensibilita, d.titolare
FROM (VALUES
  ('account_interno', 'id_account', 'Identificativo dell''account interno', 'RISERVATO', 'Sicurezza'),
  ('account_interno', 'email', 'Email di accesso dell''account interno', 'PERSONALE', 'Sicurezza'),
  ('account_interno', 'password_hash', 'Impronta della password, mai la password', 'RISERVATO', 'Sicurezza'),
  ('account_interno', 'ruolo', 'Ruolo operativo: staff, commerciale o amministratore', 'INTERNO', 'Sicurezza'),
  ('account_interno', 'attivo', 'Se l''account è attivo', 'INTERNO', 'Sicurezza'),
  ('account_interno', 'creato_il', 'Creazione dell''account', 'INTERNO', 'Sicurezza'),
  ('account_interno', 'ultimo_accesso', 'Ultimo accesso riuscito', 'INTERNO', 'Sicurezza')
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
