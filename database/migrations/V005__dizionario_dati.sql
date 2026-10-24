-- V005: dizionario dati. Ogni colonna ha descrizione, livello di sensibilità e titolare.
-- Livelli: PUBBLICO, INTERNO, RISERVATO (quasi-identificatori, solo aggregati o solo il proprietario), PERSONALE (identifica la persona).
-- Generato da scripts/dati/genera_dizionario.py: non modificare a mano.
SET search_path TO arcade;

CREATE TABLE dizionario_dati (
    tabella       text NOT NULL,
    colonna       text NOT NULL,
    tipo          text NOT NULL,
    descrizione   text NOT NULL,
    sensibilita   text NOT NULL CHECK (sensibilita IN ('PUBBLICO','INTERNO','RISERVATO','PERSONALE')),
    titolare      text NOT NULL,
    PRIMARY KEY (tabella, colonna)
);

INSERT INTO dizionario_dati (tabella, colonna, tipo, descrizione, sensibilita, titolare)
SELECT d.tabella, d.colonna, format_type(a.atttypid, a.atttypmod), d.descrizione, d.sensibilita, d.titolare
FROM (VALUES
    ('edizione', 'anno', 'Anno dell''edizione, chiave', 'INTERNO', 'Organizzazione'),
    ('edizione', 'inizio_vendite', 'Primo giorno di vendita dei biglietti', 'INTERNO', 'Organizzazione'),
    ('edizione', 'inizio_fiera', 'Primo giorno di fiera', 'INTERNO', 'Organizzazione'),
    ('edizione', 'fine_fiera', 'Ultimo giorno di fiera', 'INTERNO', 'Organizzazione'),
    ('categoria_biglietto', 'codice', 'Codice della categoria', 'INTERNO', 'Biglietteria'),
    ('categoria_biglietto', 'descrizione', 'Nome leggibile', 'INTERNO', 'Biglietteria'),
    ('categoria_biglietto', 'persone_incluse', 'Persone che entrano con un biglietto, 4 per il Family', 'INTERNO', 'Biglietteria'),
    ('canale_vendita', 'codice', 'Codice del canale', 'INTERNO', 'Biglietteria'),
    ('canale_vendita', 'descrizione', 'Nome leggibile', 'INTERNO', 'Biglietteria'),
    ('padiglione', 'codice', 'Codice del padiglione', 'PUBBLICO', 'Organizzazione'),
    ('varco', 'codice', 'Codice del varco', 'INTERNO', 'Controllo accessi'),
    ('varco', 'padiglione', 'Padiglione servito dal varco', 'INTERNO', 'Controllo accessi'),
    ('stand', 'codice', 'Codice dello stand, per esempio P1-A02', 'INTERNO', 'Organizzazione'),
    ('stand', 'padiglione', 'Padiglione dello stand', 'INTERNO', 'Organizzazione'),
    ('stand', 'superficie_mq', 'Superficie in metri quadri, da ricevere dal cliente', 'INTERNO', 'Organizzazione'),
    ('espositore', 'id_espositore', 'Codice dell''espositore', 'INTERNO', 'Organizzazione'),
    ('espositore', 'ragione_sociale', 'Ragione sociale, non presente nei dati ricevuti', 'INTERNO', 'Organizzazione'),
    ('assegnazione_stand', 'anno', 'Edizione', 'INTERNO', 'Organizzazione'),
    ('assegnazione_stand', 'codice_stand', 'Stand assegnato', 'INTERNO', 'Organizzazione'),
    ('assegnazione_stand', 'id_espositore', 'Espositore che lo occupa', 'INTERNO', 'Organizzazione'),
    ('ordine', 'id_ordine', 'Codice dell''ordine', 'INTERNO', 'Biglietteria'),
    ('ordine', 'anno', 'Edizione', 'INTERNO', 'Biglietteria'),
    ('ordine', 'canale', 'Canale di vendita dell''ordine', 'INTERNO', 'Biglietteria'),
    ('biglietto', 'codice', 'Codice del biglietto, letto ai varchi', 'INTERNO', 'Biglietteria'),
    ('biglietto', 'id_evento', 'Chiave della riga nel registro unico, per ripetere il caricamento', 'INTERNO', 'Biglietteria'),
    ('biglietto', 'id_ordine', 'Ordine di appartenenza', 'INTERNO', 'Biglietteria'),
    ('biglietto', 'anno', 'Edizione', 'INTERNO', 'Biglietteria'),
    ('biglietto', 'categoria', 'Categoria del biglietto', 'INTERNO', 'Biglietteria'),
    ('biglietto', 'giorno_valido', 'Giorno di validità, vuoto se valido tutti i giorni', 'INTERNO', 'Biglietteria'),
    ('biglietto', 'registrato_il', 'Orario di registrazione della vendita, ora italiana', 'INTERNO', 'Biglietteria'),
    ('biglietto', 'fascia_eta', 'Fascia d''età del titolare, quasi-identificatore', 'RISERVATO', 'Biglietteria'),
    ('biglietto', 'minore', 'Titolare minorenne, tutela minori', 'RISERVATO', 'Biglietteria'),
    ('biglietto', 'provincia', 'Provincia di residenza, quasi-identificatore', 'RISERVATO', 'Biglietteria'),
    ('biglietto', 'codice_sconto', 'Codice sconto usato', 'INTERNO', 'Biglietteria'),
    ('biglietto', 'quantita', 'Persone coperte dal biglietto', 'INTERNO', 'Biglietteria'),
    ('biglietto', 'importo_eur', 'Importo pagato in euro', 'INTERNO', 'Biglietteria'),
    ('biglietto', 'flag_qualita', 'Anomalie rilevate sulla riga, vuoto se nessuna', 'INTERNO', 'Biglietteria'),
    ('accesso', 'id_evento', 'Chiave della riga nel registro unico', 'INTERNO', 'Controllo accessi'),
    ('accesso', 'anno', 'Edizione', 'INTERNO', 'Controllo accessi'),
    ('accesso', 'varco', 'Varco del passaggio', 'INTERNO', 'Controllo accessi'),
    ('accesso', 'letto_il', 'Orario della lettura, ora italiana', 'INTERNO', 'Controllo accessi'),
    ('accesso', 'codice_biglietto', 'Codice letto, senza vincolo perché 70 codici non esistono in biglietteria', 'INTERNO', 'Controllo accessi'),
    ('accesso', 'esito', 'INGRESSO oppure INGRESSO_RIFIUTATO', 'INTERNO', 'Controllo accessi'),
    ('accesso', 'persone', 'Persone entrate, 0 per i rifiuti', 'INTERNO', 'Controllo accessi'),
    ('accesso', 'flag_qualita', 'Anomalie rilevate sulla riga', 'INTERNO', 'Controllo accessi'),
    ('visita_stand_ora', 'id_riferimento', 'Codice della rilevazione oraria', 'RISERVATO', 'Espositore'),
    ('visita_stand_ora', 'id_evento', 'Chiave della riga nel registro unico', 'RISERVATO', 'Espositore'),
    ('visita_stand_ora', 'anno', 'Edizione', 'RISERVATO', 'Espositore'),
    ('visita_stand_ora', 'codice_stand', 'Stand', 'RISERVATO', 'Espositore'),
    ('visita_stand_ora', 'ora_inizio', 'Inizio dell''ora, ora italiana', 'RISERVATO', 'Espositore'),
    ('visita_stand_ora', 'scansioni', 'Scansioni nell''ora', 'RISERVATO', 'Espositore'),
    ('visita_stand_ora', 'flag_qualita', 'Anomalie rilevate sulla riga', 'RISERVATO', 'Espositore'),
    ('fascia_stand_mancante', 'codice_stand', 'Stand', 'INTERNO', 'Espositore'),
    ('fascia_stand_mancante', 'ora_inizio', 'Ora mancante, ora italiana', 'INTERNO', 'Espositore'),
    ('contatto_stand', 'id_contatto', 'Codice del contatto', 'RISERVATO', 'Espositore'),
    ('contatto_stand', 'id_evento', 'Chiave della riga nel registro unico', 'RISERVATO', 'Espositore'),
    ('contatto_stand', 'anno', 'Edizione', 'RISERVATO', 'Espositore'),
    ('contatto_stand', 'codice_stand', 'Stand che ha raccolto il contatto', 'RISERVATO', 'Espositore'),
    ('contatto_stand', 'id_espositore', 'Espositore proprietario del contatto, base del filtro per espositore', 'RISERVATO', 'Espositore'),
    ('contatto_stand', 'raccolto_il', 'Orario di raccolta, ora italiana', 'RISERVATO', 'Espositore'),
    ('contatto_stand', 'fascia_eta', 'Fascia d''età dichiarata, quasi-identificatore', 'RISERVATO', 'Espositore'),
    ('contatto_stand', 'provincia', 'Provincia dichiarata, quasi-identificatore', 'RISERVATO', 'Espositore'),
    ('contatto_stand', 'interesse', 'Interesse espresso dal visitatore', 'RISERVATO', 'Espositore'),
    ('contatto_stand', 'consenso_marketing', 'Consenso al marketing dato dal visitatore', 'RISERVATO', 'Espositore'),
    ('contatto_stand', 'utilizzabile_marketing', 'Vero se il contatto si può usare per il marketing', 'RISERVATO', 'Espositore'),
    ('contatto_stand', 'motivo_esclusione', 'Perché non è utilizzabile, per esempio minore di 14-17 anni', 'RISERVATO', 'Espositore'),
    ('contatto_stand', 'email_su_piu_stand', 'Stessa email lasciata a più stand', 'RISERVATO', 'Espositore'),
    ('contatto_stand', 'flag_qualita', 'Anomalie rilevate sulla riga', 'RISERVATO', 'Espositore'),
    ('contatto_riservato', 'id_contatto', 'Contatto a cui appartiene l''email', 'PERSONALE', 'Responsabile dati'),
    ('contatto_riservato', 'email', 'Indirizzo email del visitatore', 'PERSONALE', 'Responsabile dati'),
    ('importazione', 'id_importazione', 'Numero dell''importazione', 'INTERNO', 'Data Engineering'),
    ('importazione', 'file', 'File importato', 'INTERNO', 'Data Engineering'),
    ('importazione', 'iniziata_il', 'Inizio', 'INTERNO', 'Data Engineering'),
    ('importazione', 'terminata_il', 'Fine', 'INTERNO', 'Data Engineering'),
    ('importazione', 'righe_lette', 'Righe lette dal file', 'INTERNO', 'Data Engineering'),
    ('importazione', 'righe_caricate', 'Righe caricate nelle tabelle', 'INTERNO', 'Data Engineering'),
    ('importazione', 'righe_scartate', 'Righe scartate in pulizia', 'INTERNO', 'Data Engineering'),
    ('scarto_importazione', 'id', 'Numero progressivo', 'INTERNO', 'Data Engineering'),
    ('scarto_importazione', 'id_importazione', 'Importazione che ha registrato lo scarto', 'INTERNO', 'Data Engineering'),
    ('scarto_importazione', 'fonte', 'Fonte della riga', 'INTERNO', 'Data Engineering'),
    ('scarto_importazione', 'motivo', 'Motivo dello scarto', 'INTERNO', 'Data Engineering'),
    ('scarto_importazione', 'riga_originale', 'Riga come ricevuta', 'INTERNO', 'Data Engineering'),
    ('catalogo_anomalia', 'fonte', 'Fonte dei dati', 'INTERNO', 'Data Engineering'),
    ('catalogo_anomalia', 'codice', 'Codice dell''anomalia', 'INTERNO', 'Data Engineering'),
    ('catalogo_anomalia', 'descrizione', 'Descrizione', 'INTERNO', 'Data Engineering'),
    ('catalogo_anomalia', 'righe_coinvolte', 'Righe coinvolte', 'INTERNO', 'Data Engineering'),
    ('catalogo_anomalia', 'gestione', 'Come è stata gestita', 'INTERNO', 'Data Engineering'),
    ('parametri_stima', 'anno', 'Edizione', 'INTERNO', 'Data Engineering'),
    ('parametri_stima', 'ore_permanenza', 'Ore di permanenza per stimare le presenze dagli ingressi', 'INTERNO', 'Data Engineering'),
    ('parametri_stima', 'peso_medio_kg', 'Peso medio di una persona', 'INTERNO', 'Data Engineering'),
    ('parametri_stima', 'soglia_rumore_kg', 'Variazione di peso da ignorare come rumore', 'INTERNO', 'Data Engineering'),
    ('parametri_stima', 'persone_per_mq', 'Capienza di persone per metro quadro', 'INTERNO', 'Data Engineering'),
    ('rilevazione_peso', 'id', 'Numero progressivo', 'INTERNO', 'Controllo accessi'),
    ('rilevazione_peso', 'anno', 'Edizione', 'INTERNO', 'Controllo accessi'),
    ('rilevazione_peso', 'codice_stand', 'Stand', 'INTERNO', 'Controllo accessi'),
    ('rilevazione_peso', 'rilevato_il', 'Orario della lettura', 'INTERNO', 'Controllo accessi'),
    ('rilevazione_peso', 'peso_lordo_kg', 'Peso totale letto', 'INTERNO', 'Controllo accessi'),
    ('rilevazione_peso', 'tara_kg', 'Peso a vuoto', 'INTERNO', 'Controllo accessi'),
    ('rilevazione_peso', 'fonte', 'SIMULATA o SENSORE', 'INTERNO', 'Controllo accessi')
) AS d (tabella, colonna, descrizione, sensibilita, titolare)
JOIN pg_attribute a ON a.attrelid = ('arcade.' || d.tabella)::regclass AND a.attname = d.colonna;

-- Controllo: ogni colonna delle tabelle deve avere una riga nel dizionario
DO $$
DECLARE mancanti text;
BEGIN
    SELECT string_agg(c.table_name || '.' || c.column_name, ', ') INTO mancanti
    FROM information_schema.columns c
    JOIN information_schema.tables t USING (table_schema, table_name)
    WHERE c.table_schema = 'arcade' AND t.table_type = 'BASE TABLE' AND c.table_name <> 'dizionario_dati'
      AND NOT EXISTS (SELECT 1 FROM dizionario_dati d WHERE d.tabella = c.table_name AND d.colonna = c.column_name);
    IF mancanti IS NOT NULL THEN RAISE EXCEPTION 'Colonne senza descrizione nel dizionario: %', mancanti; END IF;
END $$;
