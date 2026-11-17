-- V028: lettura dei turni del personale per la schermata Operatività evento.
-- La vista di copertura e le tabelle dei turni nascono in V024 con i soli permessi
-- di arcade_lettura; l'API gira con SET LOCAL ROLE arcade_api e qui riceve la SELECT.
SET search_path TO arcade;

GRANT SELECT ON membro_staff, turno, assegnazione_turno, v_turno_copertura, v_turno_scoperto TO arcade_api;
