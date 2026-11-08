-- V019: Fix permessi su arcade.edizione
SET search_path TO arcade;
GRANT SELECT ON edizione TO arcade_autenticazione, arcade_dati_personali, arcade_lettura, arcade_backend;
