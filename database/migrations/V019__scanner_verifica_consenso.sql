SET search_path TO arcade;
BEGIN;

-- The scanner's email-write policy checks every condition directly on the new contact row.
GRANT SELECT (fascia_eta) ON contatto_stand TO arcade_dispositivo;

COMMIT;
