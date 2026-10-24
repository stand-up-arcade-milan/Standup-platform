-- V006: privacy by design nel database. Un espositore vede solo i dati del suo stand, e solo i contatti utilizzabili.
-- L'applicazione imposta l'espositore a inizio richiesta: SELECT set_config('arcade.id_espositore', 'ESP060', true);
SET search_path TO arcade;

DO $$
BEGIN
    IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'arcade_espositore') THEN
        CREATE ROLE arcade_espositore NOLOGIN;
    END IF;
END $$;

ALTER TABLE visita_stand_ora   ENABLE ROW LEVEL SECURITY;
ALTER TABLE contatto_stand     ENABLE ROW LEVEL SECURITY;
ALTER TABLE assegnazione_stand ENABLE ROW LEVEL SECURITY;

-- Chi lavora sui dati vede tutto, tranne le email che restano nella tabella riservata
CREATE POLICY lettura_completa ON visita_stand_ora   FOR SELECT TO arcade_lettura USING (true);
CREATE POLICY lettura_completa ON contatto_stand     FOR SELECT TO arcade_lettura USING (true);
CREATE POLICY lettura_completa ON assegnazione_stand FOR SELECT TO arcade_lettura USING (true);

CREATE POLICY solo_proprio_stand ON assegnazione_stand FOR SELECT TO arcade_espositore
    USING (id_espositore = current_setting('arcade.id_espositore', true));

CREATE POLICY solo_proprio_stand ON visita_stand_ora FOR SELECT TO arcade_espositore
    USING (EXISTS (SELECT 1 FROM assegnazione_stand a
                    WHERE a.anno = visita_stand_ora.anno
                      AND a.codice_stand = visita_stand_ora.codice_stand
                      AND a.id_espositore = current_setting('arcade.id_espositore', true)));

CREATE POLICY solo_propri_contatti_utilizzabili ON contatto_stand FOR SELECT TO arcade_espositore
    USING (id_espositore = current_setting('arcade.id_espositore', true) AND utilizzabile_marketing);

GRANT USAGE ON SCHEMA arcade TO arcade_espositore;
GRANT SELECT ON visita_stand_ora, contatto_stand, assegnazione_stand TO arcade_espositore;
-- L'espositore non vede mai: biglietti, accessi, email, importazioni, dizionario.
