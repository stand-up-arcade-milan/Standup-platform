-- V015: turni del personale per la schermata Operatività evento,
-- più due allineamenti alle migrazioni dalla V010 alla V014.
SET search_path TO arcade;

CREATE EXTENSION IF NOT EXISTS btree_gist;

-- Allineamenti
ALTER TABLE pacchetto_espositore DROP CONSTRAINT pacchetto_espositore_livello_check;
ALTER TABLE pacchetto_espositore ADD CONSTRAINT pacchetto_espositore_livello_check
  CHECK (livello IN ('BASE','PREMIUM','NON_DICHIARATO'));

GRANT SELECT, INSERT, UPDATE ON recupero_password TO arcade_autenticazione;
GRANT SELECT, INSERT, UPDATE ON revoca_registrazione_visitatore TO arcade_dati_personali;

-- Personale in fiera
CREATE TABLE membro_staff (
  id_membro uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  codice text UNIQUE,
  ruolo text NOT NULL CHECK (ruolo IN ('ACCOGLIENZA','CONTROLLO_ACCESSI','INFO_POINT','SICUREZZA','TECNICO','CAPO_TURNO')),
  attivo boolean NOT NULL DEFAULT true
);

CREATE TABLE membro_staff_riservato (
  id_membro uuid PRIMARY KEY REFERENCES membro_staff (id_membro) ON DELETE CASCADE,
  nome text NOT NULL,
  email text,
  telefono text
);

-- Turni
CREATE TABLE turno (
  id_turno uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  anno smallint NOT NULL REFERENCES edizione (anno),
  varco text REFERENCES varco (codice),
  padiglione text REFERENCES padiglione (codice),
  mansione text NOT NULL CHECK (mansione IN ('ACCOGLIENZA','CONTROLLO_ACCESSI','INFO_POINT','SICUREZZA','TECNICO')),
  inizio timestamptz NOT NULL,
  fine timestamptz NOT NULL,
  persone_previste smallint NOT NULL DEFAULT 1 CHECK (persone_previste > 0),
  note text,
  CONSTRAINT turno_fine_dopo_inizio CHECK (fine > inizio),
  CONSTRAINT turno_un_solo_luogo CHECK (num_nonnulls(varco, padiglione) = 1),
  UNIQUE (id_turno, inizio, fine)
);
CREATE INDEX turno_anno_inizio_idx ON turno (anno, inizio);

-- Assegnazione turni
CREATE TABLE assegnazione_turno (
  id_turno uuid NOT NULL,
  id_membro uuid NOT NULL REFERENCES membro_staff (id_membro),
  inizio timestamptz NOT NULL,
  fine timestamptz NOT NULL,
  confermata boolean NOT NULL DEFAULT false,
  PRIMARY KEY (id_turno, id_membro),
  FOREIGN KEY (id_turno, inizio, fine) REFERENCES turno (id_turno, inizio, fine)
    ON UPDATE CASCADE ON DELETE CASCADE,
  CONSTRAINT assegnazione_turno_niente_sovrapposizioni
    EXCLUDE USING gist (id_membro WITH =, tstzrange(inizio, fine) WITH &&)
);

-- Trigger per sincronizzare orari
CREATE FUNCTION assegnazione_turno_orari() RETURNS trigger LANGUAGE plpgsql
SET search_path TO arcade, pg_temp AS $$
BEGIN
  SELECT t.inizio, t.fine INTO NEW.inizio, NEW.fine FROM turno t WHERE t.id_turno = NEW.id_turno;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Il turno % non esiste', NEW.id_turno USING ERRCODE = '23503';
  END IF;
  RETURN NEW;
END $$;

CREATE TRIGGER assegnazione_turno_orari BEFORE INSERT OR UPDATE OF id_turno ON assegnazione_turno
  FOR EACH ROW EXECUTE FUNCTION assegnazione_turno_orari();

-- Viste
CREATE VIEW v_turno_copertura AS
SELECT t.id_turno, t.anno, coalesce(t.varco, t.padiglione) AS luogo,
       CASE WHEN t.varco IS NOT NULL THEN 'VARCO' ELSE 'PADIGLIONE' END AS tipo_luogo,
       t.mansione, t.inizio, t.fine, t.persone_previste,
       count(a.id_membro) AS persone_assegnate,
       greatest(t.persone_previste - count(a.id_membro), 0) AS persone_mancanti
FROM turno t
LEFT JOIN assegnazione_turno a ON a.id_turno = t.id_turno
GROUP BY t.id_turno, t.anno, t.varco, t.padiglione, t.mansione, t.inizio, t.fine, t.persone_previste;

CREATE VIEW v_turno_scoperto AS
SELECT * FROM v_turno_copertura WHERE persone_mancanti > 0;

-- Permessi
GRANT SELECT ON membro_staff, turno, assegnazione_turno, v_turno_copertura, v_turno_scoperto TO arcade_lettura;
GRANT SELECT ON membro_staff_riservato TO arcade_dati_personali;

-- Dizionario dati
INSERT INTO dizionario_dati (tabella, colonna, tipo, descrizione, sensibilita, titolare)
SELECT d.tabella, d.colonna, format_type(a.atttypid, a.atttypmod), d.descrizione, d.sensibilita, d.titolare
FROM (VALUES
  ('membro_staff', 'id_membro', 'Identificativo della persona dello staff', 'INTERNO', 'Organizzazione'),
  ('membro_staff', 'codice', 'Sigla interna della persona, usata nei turni stampati', 'INTERNO', 'Organizzazione'),
  ('membro_staff', 'ruolo', 'Mansione prevalente: accoglienza, controllo accessi, info point, sicurezza, tecnico o capo turno', 'INTERNO', 'Organizzazione'),
  ('membro_staff', 'attivo', 'Falso se la persona non è più in servizio', 'INTERNO', 'Organizzazione'),
  ('membro_staff_riservato', 'id_membro', 'Persona dello staff', 'PERSONALE', 'Organizzazione'),
  ('membro_staff_riservato', 'nome', 'Nome e cognome della persona dello staff', 'PERSONALE', 'Organizzazione'),
  ('membro_staff_riservato', 'email', 'Email della persona dello staff', 'PERSONALE', 'Organizzazione'),
  ('membro_staff_riservato', 'telefono', 'Telefono della persona dello staff', 'PERSONALE', 'Organizzazione'),
  ('turno', 'id_turno', 'Identificativo del turno', 'INTERNO', 'Organizzazione'),
  ('turno', 'anno', 'Edizione', 'INTERNO', 'Organizzazione'),
  ('turno', 'varco', 'Varco presidiato, vuoto se il turno è di padiglione', 'INTERNO', 'Organizzazione'),
  ('turno', 'padiglione', 'Padiglione presidiato, vuoto se il turno è di varco', 'INTERNO', 'Organizzazione'),
  ('turno', 'mansione', 'Cosa si fa in questo turno', 'INTERNO', 'Organizzazione'),
  ('turno', 'inizio', 'Inizio del turno', 'INTERNO', 'Organizzazione'),
  ('turno', 'fine', 'Fine del turno', 'INTERNO', 'Organizzazione'),
  ('turno', 'persone_previste', 'Quante persone servono in questo turno', 'INTERNO', 'Organizzazione'),
  ('turno', 'note', 'Note libere del turno', 'INTERNO', 'Organizzazione'),
  ('assegnazione_turno', 'id_turno', 'Turno assegnato', 'INTERNO', 'Organizzazione'),
  ('assegnazione_turno', 'id_membro', 'Persona assegnata', 'INTERNO', 'Organizzazione'),
  ('assegnazione_turno', 'inizio', 'Inizio del turno, copiato dal turno e tenuto allineato dal database', 'INTERNO', 'Organizzazione'),
  ('assegnazione_turno', 'fine', 'Fine del turno, copiata dal turno e tenuta allineata dal database', 'INTERNO', 'Organizzazione'),
  ('assegnazione_turno', 'confermata', 'Vero se la persona ha confermato la disponibilità', 'INTERNO', 'Organizzazione')
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
