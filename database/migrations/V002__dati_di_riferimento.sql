-- V002: dati di riferimento fissi, ricavati dai file delle due edizioni.
SET search_path TO arcade;

INSERT INTO edizione (anno, inizio_vendite, inizio_fiera, fine_fiera) VALUES
    (2024, '2024-07-03', '2024-12-20', '2024-12-22'),
    (2025, '2025-07-02', '2025-12-19', '2025-12-21');

INSERT INTO categoria_biglietto (codice, descrizione, persone_incluse) VALUES
    ('INTERO',          'Intero',                    1),
    ('RIDOTTO',         'Ridotto',                   1),
    ('FAMILY',          'Family',                    4),
    ('BUSINESS',        'Business',                  1),
    ('VIP',             'VIP',                       1),
    ('STAMPA',          'Stampa',                    1),
    ('ABBONAMENTO_3GG', 'Abbonamento 3 giorni',      1),
    ('GRATUITO_U8',     'Gratuito sotto gli 8 anni', 1);

INSERT INTO canale_vendita (codice, descrizione) VALUES
    ('ONLINE',              'Vendita online'),
    ('CASSA',               'Cassa in fiera'),
    ('RIVENDITORE_PARTNER', 'Rivenditore partner');

INSERT INTO padiglione (codice) VALUES ('P1'), ('P2'), ('P3');

INSERT INTO varco (codice, padiglione) VALUES
    ('P1-NORD',  'P1'),
    ('P1-SUD',   'P1'),
    ('P2-OVEST', 'P2'),
    ('P3-EST',   'P3');

INSERT INTO parametri_stima (anno) VALUES (2024), (2025);
