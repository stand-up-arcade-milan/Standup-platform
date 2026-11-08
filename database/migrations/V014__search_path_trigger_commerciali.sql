-- Le funzioni trigger non devono dipendere dal search_path della connessione chiamante.
ALTER FUNCTION arcade.pratica_controlla()
    SET search_path TO arcade, pg_temp;

ALTER FUNCTION arcade.pratica_alla_firma()
    SET search_path TO arcade, pg_temp;
