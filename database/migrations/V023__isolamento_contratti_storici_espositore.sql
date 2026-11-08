SET search_path TO arcade;
BEGIN;

-- Preserve the legacy read role and the internal API while making exhibitor
-- access to the invoker-security contract view tenant-scoped.
ALTER TABLE contratto_storico ENABLE ROW LEVEL SECURITY;
ALTER TABLE contratto_storico FORCE ROW LEVEL SECURITY;
GRANT SELECT (id_pratica, imponibile_listino_eur, imponibile_netto_eur, acconto_pagato_il)
    ON contratto_storico TO arcade_espositore;

CREATE POLICY contratto_storico_api_full ON contratto_storico
    FOR ALL TO arcade_api USING (true) WITH CHECK (true);
CREATE POLICY contratto_storico_legacy_read ON contratto_storico
    FOR SELECT TO arcade_lettura USING (true);
CREATE POLICY contratto_storico_espositore_proprio ON contratto_storico
    FOR SELECT TO arcade_espositore
    USING (EXISTS (
        SELECT 1 FROM pratica p
         WHERE p.id_pratica = contratto_storico.id_pratica
           AND p.id_espositore = current_setting('arcade.id_espositore', true)
    ));

COMMIT;
