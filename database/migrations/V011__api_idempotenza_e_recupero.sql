SET search_path TO arcade;

-- Event IDs in the API make simulator writes safely retryable.
CREATE TABLE acquisizione_evento (
    event_id text PRIMARY KEY,
    tipo text NOT NULL CHECK (tipo IN ('PEDANA','SENSORE_AI','PESO')),
    richiesta_hash text NOT NULL,
    ricevuto_il timestamptz NOT NULL DEFAULT now()
);

-- Recovery tokens are stored hashed and can be consumed once.
CREATE TABLE recupero_password (
    token_hash text PRIMARY KEY,
    id_account uuid NOT NULL REFERENCES account_espositore (id_account) ON DELETE CASCADE,
    scade_il timestamptz NOT NULL,
    usato_il timestamptz
);

CREATE TABLE revoca_registrazione_visitatore (
    token_hash text PRIMARY KEY,
    id_registrazione bigint NOT NULL REFERENCES registrazione_visitatore (id_registrazione) ON DELETE CASCADE,
    usato_il timestamptz
);

INSERT INTO dizionario_dati (tabella, colonna, tipo, descrizione, sensibilita, titolare)
SELECT d.tabella, d.colonna, format_type(a.atttypid, a.atttypmod), d.descrizione, d.sensibilita, d.titolare
FROM (VALUES
  ('acquisizione_evento','event_id','Identificativo idempotente dell’evento API','INTERNO','Operazioni'),
  ('acquisizione_evento','tipo','Tipo di rilevazione acquisita','INTERNO','Operazioni'),
  ('acquisizione_evento','richiesta_hash','Impronta SHA-256 della richiesta per confrontare i retry senza conservare il payload','RISERVATO','Operazioni'),
  ('acquisizione_evento','ricevuto_il','Data di ricezione dell’evento','INTERNO','Operazioni'),
  ('recupero_password','token_hash','Hash del token monouso di recupero','RISERVATO','Identità'),
  ('recupero_password','id_account','Account espositore che richiede il recupero','PERSONALE','Identità'),
  ('recupero_password','scade_il','Scadenza del token monouso','RISERVATO','Identità'),
  ('recupero_password','usato_il','Data di consumo del token','RISERVATO','Identità'),
  ('revoca_registrazione_visitatore','token_hash','Hash del token per aggiornare i consensi','RISERVATO','Privacy'),
  ('revoca_registrazione_visitatore','id_registrazione','Registrazione visitatore associata al token','PERSONALE','Privacy'),
  ('revoca_registrazione_visitatore','usato_il','Data di consumo del token','RISERVATO','Privacy')
) AS d(tabella,colonna,descrizione,sensibilita,titolare)
JOIN pg_attribute a ON a.attrelid = ('arcade.' || d.tabella)::regclass AND a.attname = d.colonna;
