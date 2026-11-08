SET search_path TO arcade;
BEGIN;

-- Registration needs only the active edition key; it cannot read commercial or event records.
GRANT SELECT (anno, stato) ON edizione TO arcade_registrazione;

COMMIT;
