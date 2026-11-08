SET search_path TO arcade;
BEGIN;

GRANT USAGE, SELECT ON SEQUENCE rilevazione_peso_id_seq TO arcade_dispositivo;

COMMIT;
