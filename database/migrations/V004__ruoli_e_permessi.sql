-- V004: separazione dei dati personali. Le email stanno solo in contatto_riservato.
DO $$
BEGIN
    IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'arcade_lettura') THEN
        CREATE ROLE arcade_lettura NOLOGIN;
    END IF;
    IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'arcade_dati_personali') THEN
        CREATE ROLE arcade_dati_personali NOLOGIN;
    END IF;
END $$;

GRANT USAGE ON SCHEMA arcade TO arcade_lettura, arcade_dati_personali;
GRANT SELECT ON ALL TABLES IN SCHEMA arcade TO arcade_lettura;
REVOKE ALL ON arcade.contatto_riservato FROM arcade_lettura;

-- Chi gestisce i consensi legge anche le email
GRANT arcade_lettura TO arcade_dati_personali;
GRANT SELECT ON arcade.contatto_riservato TO arcade_dati_personali;
