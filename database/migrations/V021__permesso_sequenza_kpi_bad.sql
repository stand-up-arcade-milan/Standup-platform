SET search_path TO arcade;
BEGIN;

GRANT USAGE, SELECT ON SEQUENCE kpi_osservazione_id_osservazione_seq TO arcade_bad;

COMMIT;
