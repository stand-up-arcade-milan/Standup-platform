-- V027: un account per la direzione.
-- La direzione di ARCADE entra con email e password, in una tabella separata dagli
-- espositori: il ruolo è diverso e i poteri non si mescolano.
SET search_path TO arcade;

CREATE TABLE IF NOT EXISTS account_direzione (
    id_account UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    email TEXT NOT NULL UNIQUE,
    password_hash TEXT,
    cognome TEXT NOT NULL,
    nome TEXT NOT NULL,
    attivo BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    ultimo_accesso TIMESTAMPTZ,
    email_verificata BOOLEAN NOT NULL DEFAULT false
);

COMMENT ON TABLE account_direzione IS 'Account per la direzione di ARCADE Milano (organizzatori della fiera)';
COMMENT ON COLUMN account_direzione.id_account IS 'Identificatore univoco dell''account';
COMMENT ON COLUMN account_direzione.email IS 'Email dell''utente, univoca';
COMMENT ON COLUMN account_direzione.password_hash IS 'Hash PBKDF2 della password';
COMMENT ON COLUMN account_direzione.cognome IS 'Cognome dell''utente';
COMMENT ON COLUMN account_direzione.nome IS 'Nome dell''utente';
COMMENT ON COLUMN account_direzione.attivo IS 'Se l''account è attivo';
COMMENT ON COLUMN account_direzione.ultimo_accesso IS 'Timestamp dell''ultimo accesso';
COMMENT ON COLUMN account_direzione.email_verificata IS 'Se l''email è stata verificata';

CREATE INDEX IF NOT EXISTS idx_account_direzione_email ON account_direzione(email);
CREATE INDEX IF NOT EXISTS idx_account_direzione_attivo ON account_direzione(attivo);

-- Permessi
GRANT SELECT, INSERT, UPDATE ON account_direzione TO arcade_autenticazione;

-- Dizionario dati
INSERT INTO dizionario_dati (tabella, colonna, tipo, descrizione, sensibilita, titolare)
SELECT d.tabella, d.colonna, format_type(a.atttypid, a.atttypmod), d.descrizione, d.sensibilita, d.titolare
FROM (VALUES
    ('account_direzione', 'id_account', 'Identificativo dell''account', 'INTERNO', 'Sicurezza'),
    ('account_direzione', 'email', 'Email di accesso', 'PERSONALE', 'Sicurezza'),
    ('account_direzione', 'password_hash', 'Impronta della password, mai la password', 'RISERVATO', 'Sicurezza'),
    ('account_direzione', 'cognome', 'Cognome della persona', 'PERSONALE', 'Sicurezza'),
    ('account_direzione', 'nome', 'Nome della persona', 'PERSONALE', 'Sicurezza'),
    ('account_direzione', 'attivo', 'Falso se l''account è disattivato', 'INTERNO', 'Sicurezza'),
    ('account_direzione', 'created_at', 'Orario di creazione', 'INTERNO', 'Sicurezza'),
    ('account_direzione', 'updated_at', 'Orario dell''ultima modifica', 'INTERNO', 'Sicurezza'),
    ('account_direzione', 'ultimo_accesso', 'Orario dell''ultimo accesso', 'INTERNO', 'Sicurezza'),
    ('account_direzione', 'email_verificata', 'Vero se email verificata', 'INTERNO', 'Sicurezza')
) AS d (tabella, colonna, descrizione, sensibilita, titolare)
JOIN pg_attribute a ON a.attrelid = ('arcade.' || d.tabella)::regclass AND a.attname = d.colonna;

-- Controllo dizionario
DO $$
DECLARE mancanti text;
BEGIN
    SELECT string_agg(c.table_name || '.' || c.column_name, ', ') INTO mancanti
    FROM information_schema.columns c
    JOIN information_schema.tables t USING (table_schema, table_name)
    WHERE c.table_schema = 'arcade' AND t.table_type = 'BASE TABLE' AND c.table_name <> 'dizionario_dati'
      AND NOT EXISTS (SELECT 1 FROM dizionario_dati d WHERE d.tabella = c.table_name AND d.colonna = c.column_name);
    IF mancanti IS NOT NULL THEN RAISE EXCEPTION 'Colonne senza descrizione: %', mancanti; END IF;
END $$;
