-- V016: tre modi di entrare, un solo account.
-- Email e password per chi non ha un fornitore aziendale, oppure Google, oppure Microsoft.
-- Del fornitore si conserva l'identificativo stabile, non l'email, perché l'email può cambiare.
SET search_path TO arcade;

CREATE TABLE fornitore_identita (
    codice text PRIMARY KEY CHECK (codice IN ('GOOGLE','MICROSOFT')),
    nome   text NOT NULL,
    attivo boolean NOT NULL DEFAULT true
);
INSERT INTO fornitore_identita (codice, nome) VALUES
    ('GOOGLE', 'Google'),
    ('MICROSOFT', 'Microsoft');

-- Un account collegato a Google o Microsoft non ha password
ALTER TABLE account_espositore ALTER COLUMN password_hash DROP NOT NULL;
ALTER TABLE account_espositore ADD COLUMN email_verificata boolean NOT NULL DEFAULT false;

CREATE TABLE identita_esterna (
    fornitore       text NOT NULL REFERENCES fornitore_identita (codice),
    subject         text NOT NULL,
    id_account      uuid NOT NULL REFERENCES account_espositore (id_account) ON DELETE CASCADE,
    email_fornitore text,
    collegata_il    timestamptz NOT NULL DEFAULT now(),
    ultimo_accesso  timestamptz,
    PRIMARY KEY (fornitore, subject),
    UNIQUE (id_account, fornitore)
);
CREATE INDEX identita_esterna_account_idx ON identita_esterna (id_account);

-- Viste
CREATE VIEW v_account_accesso AS
SELECT a.id_account, a.id_espositore, a.attivo,
       a.password_hash IS NOT NULL AS con_password,
       coalesce(bool_or(i.fornitore = 'GOOGLE'), false) AS con_google,
       coalesce(bool_or(i.fornitore = 'MICROSOFT'), false) AS con_microsoft
FROM account_espositore a
LEFT JOIN identita_esterna i ON i.id_account = a.id_account
GROUP BY a.id_account, a.id_espositore, a.attivo, a.password_hash;

CREATE VIEW v_account_senza_accesso AS
SELECT id_account, id_espositore
FROM v_account_accesso
WHERE NOT con_password AND NOT con_google AND NOT con_microsoft;

-- Permessi
GRANT SELECT ON fornitore_identita TO arcade_lettura, arcade_espositore;
GRANT SELECT, INSERT, UPDATE ON identita_esterna TO arcade_autenticazione;
GRANT SELECT ON v_account_accesso, v_account_senza_accesso TO arcade_autenticazione;

-- Dizionario dati
INSERT INTO dizionario_dati (tabella, colonna, tipo, descrizione, sensibilita, titolare)
SELECT d.tabella, d.colonna, format_type(a.atttypid, a.atttypmod), d.descrizione, d.sensibilita, d.titolare
FROM (VALUES
    ('fornitore_identita', 'codice', 'GOOGLE oppure MICROSOFT', 'PUBBLICO', 'Sicurezza'),
    ('fornitore_identita', 'nome', 'Nome mostrato sul pulsante di accesso', 'PUBBLICO', 'Sicurezza'),
    ('fornitore_identita', 'attivo', 'Falso per togliere il pulsante', 'INTERNO', 'Sicurezza'),
    ('account_espositore', 'email_verificata', 'Vero se email verificata', 'INTERNO', 'Sicurezza'),
    ('identita_esterna', 'fornitore', 'Fornitore OAuth', 'INTERNO', 'Sicurezza'),
    ('identita_esterna', 'subject', 'ID stabile dal fornitore', 'RISERVATO', 'Sicurezza'),
    ('identita_esterna', 'id_account', 'Account collegato', 'INTERNO', 'Sicurezza'),
    ('identita_esterna', 'email_fornitore', 'Email dal fornitore', 'PERSONALE', 'Sicurezza'),
    ('identita_esterna', 'collegata_il', 'Quando collegata', 'INTERNO', 'Sicurezza'),
    ('identita_esterna', 'ultimo_accesso', 'Ultimo accesso', 'INTERNO', 'Sicurezza')
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
