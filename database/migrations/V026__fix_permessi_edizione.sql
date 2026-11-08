-- V026: permessi di lettura sull'edizione per i ruoli che ne hanno bisogno.
SET search_path TO arcade;

-- arcade_backend non è creato da nessuna migrazione precedente: lo crea questa, se manca,
-- così la catena non si interrompe su un'installazione pulita.
DO $$
BEGIN
    IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'arcade_backend') THEN
        CREATE ROLE arcade_backend NOLOGIN;
    END IF;
END $$;
GRANT USAGE ON SCHEMA arcade TO arcade_backend;

GRANT SELECT ON edizione TO arcade_autenticazione, arcade_dati_personali, arcade_lettura, arcade_backend;
