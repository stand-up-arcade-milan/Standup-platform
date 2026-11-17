-- =====================================================================
-- ARCADE Milano · Standup-platform · Viste per Metabase (PostgreSQL)
-- Gruppo 3 · Prove sui dati 2024-2025 (biglietteria, tornelli, stand,
-- contratti). Ogni vista porta sia i numeratori sia i denominatori dei
-- KPI, così in Metabase i rapporti si calcolano sulle somme, mai come
-- media di rapporti (vedi foglio "Formule_Metabase" dell'Excel).
--
-- ORDINE DI ESECUZIONE: sezioni 1 -> 2 -> 3 -> 4 (per ogni sezione dall'alto).
-- CARICAMENTO DATI: tabelle stg_* = file originali importati "così come
-- sono" (tutto testo); la pulizia sta nelle viste, non nei file.
-- =====================================================================


-- =====================================================================
-- 1. TABELLE DI APPOGGIO (STAGING) E ANAGRAFICHE
-- =====================================================================

-- Dimensione edizioni (2026 senza date finché non sono decise)
CREATE TABLE edizione (
  anno         smallint PRIMARY KEY,
  data_inizio  date,
  data_fine    date,
  note         text
);
INSERT INTO edizione VALUES
  (2024, DATE '2024-12-20', DATE '2024-12-22', 'Dati storici'),
  (2025, DATE '2025-12-19', DATE '2025-12-21', 'Dati storici'),
  (2026, NULL, NULL, 'In pianificazione');

-- Biglietteria 2024 e 2025: stessi tracciati, separatore ';'.
-- COPY stg_biglietteria (id_ordine,id_biglietto,data_acquisto,canale,tipo_biglietto,
--   giorno_valido,prezzo,persone,fascia_eta,provincia,codice_sconto)
--   FROM 'biglietteria_2025.csv' WITH (FORMAT csv, DELIMITER ';', HEADER true);
-- poi: UPDATE stg_biglietteria SET edizione = 2025 WHERE edizione IS NULL;
CREATE TABLE stg_biglietteria (
  edizione        smallint,
  id_ordine       text,
  id_biglietto    text PRIMARY KEY,
  data_acquisto   text,      -- 'GG/MM/AAAA HH:MM'
  canale          text,
  tipo_biglietto  text,
  giorno_valido   text,      -- 'GG/MM/AAAA' oppure '3 giorni'
  prezzo          text,      -- '55,00' (virgola decimale)
  persone         integer,
  fascia_eta      text,
  provincia       text,
  codice_sconto   text
);

-- Tornelli: i due anni hanno tracciati diversi, restano due tabelle.
CREATE TABLE stg_tornelli_2024 (   -- data;ora;varco;codice;esito  (ora locale, esito 1/0)
  data text, ora text, varco text, codice text, esito text
);
CREATE TABLE stg_tornelli_2025 (   -- timestamp_utc,ticket_code,gate_id,result  (UTC, OK/KO)
  timestamp_utc text, ticket_code text, gate_id text, result text
);

CREATE TABLE stg_visite_stand (    -- scansioni per stand e ora (2025)
  codice_stand text, data date, ora text, scansioni integer
);
CREATE TABLE stg_contatti_stand (  -- lead raccolti dagli stand (2025)
  id_contatto text PRIMARY KEY, codice_stand text, id_espositore text, data_ora text,
  email text, fascia_eta text, provincia text, consenso_marketing text, interesse text
);

-- Commerciale (fogli di ARCADE_Commerciale.xlsx)
CREATE TABLE espositore (
  id_espositore text PRIMARY KEY, ragione_sociale text, partita_iva text,
  settore text, citta text, referente text, email_referente text
);
CREATE TABLE planimetria (
  codice_stand text PRIMARY KEY, padiglione text, nome_padiglione text,
  mq numeric(8,2), posizione text, attivo_dal smallint
);
CREATE TABLE contratto (
  id_contratto text PRIMARY KEY, edizione smallint, id_espositore text,
  ragione_sociale text, partita_iva text, codice_stand text, data_firma date,
  imponibile_listino_eur numeric(12,2), sconto_pct numeric(5,4), imponibile_eur numeric(12,2),
  acconto_scadenza date, acconto_pagato_il date, saldo_scadenza date, saldo_pagato_il date,
  rinnovo boolean
);
CREATE TABLE riga_contratto (
  id_contratto text, riga integer, codice_voce text, descrizione text,
  quantita numeric(10,2), prezzo_unitario_eur numeric(12,2), importo_eur numeric(12,2),
  PRIMARY KEY (id_contratto, riga)
);
CREATE TABLE listino (   -- foglio Listino_2026
  codice text PRIMARY KEY, voce text, unita text, prezzo_unitario_eur numeric(12,2),
  disponibilita text, note text
);

-- ---- Mappature e parametri (da compilare / validare dal gruppo) ----

-- I nomi dei tipi di biglietto cambiano da un anno all'altro: li riportiamo a un tipo standard
CREATE TABLE map_tipo_biglietto (
  tipo_originale text PRIMARY KEY, tipo_std text NOT NULL
);
INSERT INTO map_tipo_biglietto VALUES
  ('Intero','Intero'), ('Giornaliero intero','Intero'),
  ('Abb. 3gg','Abbonamento 3 giorni'), ('Abbonamento 3 giorni','Abbonamento 3 giorni'),
  ('Ridotto','Ridotto'), ('Giornaliero ridotto 8-14 anni','Ridotto'),
  ('Family','Family'), ('Family 2 adulti + 2 ragazzi','Family'),
  ('Omaggio U8','Gratuito under 8'), ('Gratuito under 8','Gratuito under 8'),
  ('Business','Business Day'), ('Business Day (venerdì mattina)','Business Day'),
  ('VIP','VIP'), ('VIP Experience','VIP'),
  ('Stampa','Stampa'), ('Accredito stampa','Stampa');

-- Province scritte per esteso, in maiuscole/minuscole diverse: sigla unica
CREATE TABLE map_provincia (nome text PRIMARY KEY, sigla text NOT NULL);
INSERT INTO map_provincia VALUES
  ('MILANO','MI'),('MONZA E BRIANZA','MB'),('BERGAMO','BG'),('VARESE','VA'),('TORINO','TO'),
  ('BRESCIA','BS'),('COMO','CO'),('ROMA','RM'),('GENOVA','GE'),('PAVIA','PV'),('BOLOGNA','BO'),
  ('LECCO','LC'),('PARMA','PR'),('PADOVA','PD'),('FIRENZE','FI'),('CREMONA','CR'),('LODI','LO'),
  ('PIACENZA','PC'),('VERONA','VR'),('NOVARA','NO'),('NAPOLI','NA');

-- Contratti 2024 senza id_espositore: abbinamento per nome (da verificare a mano dove indicato)
CREATE TABLE contratto_espositore_map (
  id_contratto text PRIMARY KEY, id_espositore text NOT NULL,
  metodo text NOT NULL,            -- 'nome_esatto' | 'nome_simile'
  da_verificare boolean NOT NULL
);
INSERT INTO contratto_espositore_map VALUES
  ('C2024-0001','ESP013','nome_simile',true),
  ('C2024-0002','ESP034','nome_esatto',false),
  ('C2024-0003','ESP029','nome_esatto',false),
  ('C2024-0004','ESP066','nome_esatto',false),
  ('C2024-0005','ESP096','nome_esatto',false),
  ('C2024-0006','ESP067','nome_esatto',false),
  ('C2024-0007','ESP072','nome_esatto',false),
  ('C2024-0008','ESP075','nome_esatto',false),
  ('C2024-0009','ESP089','nome_esatto',false),
  ('C2024-0010','ESP074','nome_esatto',false),
  ('C2024-0011','ESP116','nome_esatto',false),
  ('C2024-0012','ESP058','nome_esatto',false),
  ('C2024-0013','ESP048','nome_esatto',false),
  ('C2024-0014','ESP051','nome_esatto',false),
  ('C2024-0015','ESP060','nome_esatto',false),
  ('C2024-0016','ESP099','nome_esatto',false),
  ('C2024-0017','ESP087','nome_esatto',false),
  ('C2024-0018','ESP076','nome_esatto',false),
  ('C2024-0019','ESP110','nome_esatto',false),
  ('C2024-0020','ESP065','nome_esatto',false),
  ('C2024-0021','ESP020','nome_esatto',false),
  ('C2024-0022','ESP045','nome_esatto',false),
  ('C2024-0023','ESP004','nome_esatto',false),
  ('C2024-0024','ESP062','nome_esatto',false),
  ('C2024-0025','ESP014','nome_esatto',false),
  ('C2024-0026','ESP038','nome_esatto',false),
  ('C2024-0027','ESP054','nome_esatto',false),
  ('C2024-0028','ESP011','nome_simile',true),
  ('C2024-0029','ESP015','nome_esatto',false),
  ('C2024-0030','ESP019','nome_esatto',false),
  ('C2024-0031','ESP097','nome_esatto',false),
  ('C2024-0032','ESP040','nome_esatto',false),
  ('C2024-0033','ESP044','nome_esatto',false),
  ('C2024-0034','ESP059','nome_esatto',false),
  ('C2024-0035','ESP027','nome_esatto',false),
  ('C2024-0036','ESP113','nome_esatto',false),
  ('C2024-0037','ESP095','nome_simile',true),
  ('C2024-0038','ESP088','nome_esatto',false),
  ('C2024-0039','ESP061','nome_esatto',false),
  ('C2024-0040','ESP118','nome_esatto',false),
  ('C2024-0041','ESP057','nome_esatto',false),
  ('C2024-0042','ESP107','nome_esatto',false),
  ('C2024-0043','ESP041','nome_esatto',false),
  ('C2024-0044','ESP009','nome_esatto',false),
  ('C2024-0045','ESP039','nome_esatto',false),
  ('C2024-0046','ESP006','nome_simile',true),
  ('C2024-0047','ESP090','nome_esatto',false),
  ('C2024-0048','ESP003','nome_esatto',false),
  ('C2024-0049','ESP086','nome_esatto',false),
  ('C2024-0050','ESP094','nome_esatto',false),
  ('C2024-0051','ESP022','nome_esatto',false),
  ('C2024-0052','ESP032','nome_esatto',false),
  ('C2024-0053','ESP023','nome_esatto',false),
  ('C2024-0054','ESP021','nome_esatto',false),
  ('C2024-0055','ESP043','nome_esatto',false),
  ('C2024-0056','ESP036','nome_simile',true),
  ('C2024-0057','ESP028','nome_esatto',false),
  ('C2024-0058','ESP030','nome_esatto',false),
  ('C2024-0059','ESP112','nome_esatto',false),
  ('C2024-0060','ESP052','nome_esatto',false),
  ('C2024-0061','ESP026','nome_esatto',false),
  ('C2024-0062','ESP101','nome_esatto',false),
  ('C2024-0063','ESP012','nome_esatto',false),
  ('C2024-0064','ESP056','nome_simile',true),
  ('C2024-0065','ESP078','nome_esatto',false),
  ('C2024-0066','ESP064','nome_esatto',false),
  ('C2024-0067','ESP082','nome_esatto',false),
  ('C2024-0068','ESP077','nome_esatto',false),
  ('C2024-0069','ESP002','nome_esatto',false),
  ('C2024-0070','ESP079','nome_esatto',false),
  ('C2024-0071','ESP108','nome_esatto',false),
  ('C2024-0072','ESP093','nome_esatto',false),
  ('C2024-0073','ESP085','nome_esatto',false),
  ('C2024-0074','ESP025','nome_esatto',false),
  ('C2024-0075','ESP001','nome_esatto',false),
  ('C2024-0076','ESP069','nome_esatto',false),
  ('C2024-0077','ESP092','nome_esatto',false),
  ('C2024-0078','ESP018','nome_esatto',false),
  ('C2024-0079','ESP005','nome_esatto',false),
  ('C2024-0080','ESP037','nome_esatto',false),
  ('C2024-0081','ESP035','nome_simile',true),
  ('C2024-0082','ESP055','nome_simile',true),
  ('C2024-0083','ESP024','nome_esatto',false),
  ('C2024-0084','ESP104','nome_simile',true),
  ('C2024-0085','ESP114','nome_esatto',false),
  ('C2024-0086','ESP016','nome_esatto',false),
  ('C2024-0087','ESP017','nome_esatto',false),
  ('C2024-0088','ESP091','nome_esatto',false);


-- Capienze: DA COMPILARE (ambito = 'evento' oppure codice padiglione 'P1','P2','P3').
-- Senza capienza la saturazione resta NULL.  Esempio:
--   INSERT INTO param_capienza VALUES (2026, 'evento', 12000, 'Dato da definire con la direzione');
CREATE TABLE param_capienza (
  edizione smallint, ambito text, capienza integer, note text,
  PRIMARY KEY (edizione, ambito)
);

-- Costi: DA COMPILARE per il costo per contatto / per ingresso. Esempio:
--   INSERT INTO param_costo VALUES (2026, 'marketing', 'Campagna social', 15000);
CREATE TABLE param_costo (
  edizione smallint, categoria text, descrizione text, importo_eur numeric(12,2)
);

-- Coordinate degli stand per la mappa (x,y in % della planimetria): DA COMPILARE
CREATE TABLE stand_coordinate (
  codice_stand text PRIMARY KEY, x_pct numeric(5,2), y_pct numeric(5,2)
);

-- Turni dello staff (schermata Operatività evento): DA COMPILARE
CREATE TABLE turno_staff (
  id_turno integer PRIMARY KEY, edizione smallint, data date, ora_inizio text, ora_fine text,
  area text, id_staff text, ruolo_turno text
);

-- Accesso e ruoli (schermata Accesso)
CREATE TABLE ruolo (id_ruolo text PRIMARY KEY, nome text);
INSERT INTO ruolo VALUES
  ('DIR','Direzione'),('COM','Commerciale'),('STF','Staff operativo'),
  ('ESP','Espositore'),('ADM','Amministratore');

CREATE TABLE utente_app (
  email text PRIMARY KEY, nome text, id_ruolo text REFERENCES ruolo(id_ruolo),
  id_espositore text,          -- valorizzato solo per il ruolo ESP (filtro di riga)
  attivo boolean NOT NULL DEFAULT true
);

-- Matrice ruolo -> schermata, dalla tabella "Schermate da progettare".
-- Da validare: chi sono i "ruoli autorizzati" del Report e lo "staff/espositore autorizzato".
CREATE TABLE ruolo_schermata (
  id_ruolo text REFERENCES ruolo(id_ruolo), schermata text, note text,
  PRIMARY KEY (id_ruolo, schermata)
);
INSERT INTO ruolo_schermata VALUES
  ('DIR','Cruscotto direzionale',NULL), ('DIR','Mappa interattiva','Mappa di calore'), ('DIR','Report',NULL),
  ('COM','Back office commerciale',NULL),
  ('STF','Operatività evento',NULL), ('STF','Scansione allo stand','Solo se autorizzato'),
  ('STF','Biglietteria e accessi','Solo staff autorizzato'), ('STF','Mappa interattiva',NULL),
  ('ESP','Area espositore','Solo la propria azienda'), ('ESP','Scansione allo stand','Solo se autorizzato'),
  ('ESP','Mappa interattiva',NULL),
  ('ADM','Cruscotto direzionale',NULL), ('ADM','Operatività evento',NULL),
  ('ADM','Back office commerciale',NULL), ('ADM','Area espositore',NULL),
  ('ADM','Scansione allo stand',NULL), ('ADM','Biglietteria e accessi',NULL),
  ('ADM','Mappa interattiva',NULL), ('ADM','Report',NULL);

-- Definizione ufficiale dei KPI (richiesta dal README: definizione, fonte, formula, frequenza, responsabile)
CREATE TABLE kpi_definizione (
  kpi text PRIMARY KEY, definizione text, formula text, vista_fonte text,
  frequenza_aggiornamento text, responsabile text
);
INSERT INTO kpi_definizione VALUES
 ('Ingressi','Persone entrate dai varchi, senza doppie scansioni e al massimo pari alle persone del biglietto','COUNT(*) su v_ingresso','v_ingresso','Tempo reale durante l''evento','DA ASSEGNARE'),
 ('Picco orario','Ora con il massimo numero di ingressi nell''edizione','MAX(ingressi) per ora su v_s02_picchi','v_s02_picchi','Tempo reale','DA ASSEGNARE'),
 ('Saturazione','Ingressi cumulati del giorno / capienza. Limite superiore: i varchi registrano solo le entrate, non le uscite','ingressi_cumulati / capienza','v_s02_picchi + param_capienza','Tempo reale','DA ASSEGNARE'),
 ('Ricavi biglietteria','Somma dei prezzi dei biglietti venduti (omaggi a prezzo 0)','SUM(prezzo)','v_biglietto','Giornaliera','DA ASSEGNARE'),
 ('Biglietti non utilizzati','Biglietti venduti senza alcun ingresso valido / biglietti venduti','no_show / biglietti_venduti','v_s07_biglietto_stato','A fine evento','DA ASSEGNARE'),
 ('Occupazione stand','m² venduti / m² disponibili (attivi nell''edizione)','mq_venduti / mq_disponibili','v_s02_kpi_edizione','Settimanale in vendita','DA ASSEGNARE'),
 ('Ricavi per m²','Imponibile contratti (dopo sconti, incluse extra e sponsor) / m² venduti','imponibile_stand / mq_venduti','v_s02_kpi_edizione','Settimanale in vendita','DA ASSEGNARE'),
 ('Ricavi per m² (solo area)','Area e maggiorazioni a prezzo di listino / m² venduti','area_listino / mq_venduti','v_s04_scheda_contratto','Settimanale in vendita','DA ASSEGNARE'),
 ('Tasso di rinnovo','Espositori dell''edizione precedente presenti anche in questa / espositori dell''edizione precedente','rinnovati / (rinnovati + non rinnovati)','v_s04_rinnovi','A fine vendite','DA ASSEGNARE'),
 ('Contatti raccolti','Lead acquisiti dagli stand (uno per persona e stand)','COUNT(*)','v_contatto_stand','Tempo reale','DA ASSEGNARE'),
 ('Contatti per 100 scansioni','Contatti / scansioni agli stand x 100 (scansioni escluse quelle fuori orario)','contatti / scansioni * 100','v_s06_stand_performance','Tempo reale','DA ASSEGNARE'),
 ('Costo per contatto','Costi dell''edizione (param_costo) / contatti raccolti. NULL finché i costi non sono inseriti','costo_totale / contatti','v_s02_kpi_edizione','A fine evento','DA ASSEGNARE');


-- =====================================================================
-- 2. VISTE DI PULIZIA (base di tutte le schermate)
-- =====================================================================

-- Biglietti con tipi, date, prezzi e province normalizzati
CREATE VIEW v_biglietto AS
SELECT
  b.edizione, b.id_ordine, b.id_biglietto,
  (substr(b.data_acquisto,7,4)||'-'||substr(b.data_acquisto,4,2)||'-'||substr(b.data_acquisto,1,2)||' '||substr(b.data_acquisto,12,5))::timestamp AS data_acquisto,
  b.canale,
  COALESCE(m.tipo_std, b.tipo_biglietto) AS tipo_std,
  b.tipo_biglietto AS tipo_originale,
  (b.giorno_valido = '3 giorni') AS is_abbonamento,
  CASE WHEN b.giorno_valido = '3 giorni' THEN NULL
       ELSE (substr(b.giorno_valido,7,4)||'-'||substr(b.giorno_valido,4,2)||'-'||substr(b.giorno_valido,1,2))::date END AS giorno_valido,
  replace(b.prezzo, ',', '.')::numeric(10,2) AS prezzo,
  b.persone,
  NULLIF(b.fascia_eta,'') AS fascia_eta,
  CASE WHEN NULLIF(trim(b.provincia),'') IS NULL THEN NULL
       WHEN length(trim(b.provincia)) = 2 THEN upper(trim(b.provincia))
       ELSE COALESCE(p.sigla, upper(trim(b.provincia))) END AS provincia,
  NULLIF(b.codice_sconto,'') AS codice_sconto
FROM stg_biglietteria b
LEFT JOIN map_tipo_biglietto m ON m.tipo_originale = b.tipo_biglietto
LEFT JOIN map_provincia p ON p.nome = upper(trim(b.provincia));

-- Tornelli 2024 e 2025 portati allo stesso formato: ora locale (Europe/Rome), varco 'P1-Nord', esito booleano
CREATE VIEW v_tornello AS
SELECT 2024::smallint AS edizione,
       (substr(data,7,4)||'-'||substr(data,4,2)||'-'||substr(data,1,2)||' '||ora)::timestamp AS ts,
       replace(varco,' ','-') AS varco,
       codice AS id_biglietto,
       (esito = '1') AS esito_ok
FROM stg_tornelli_2024
UNION ALL
SELECT 2025::smallint,
       (timestamp_utc::timestamptz AT TIME ZONE 'Europe/Rome'),
       gate_id, ticket_code, (result = 'OK')
FROM stg_tornelli_2025;
-- Per un'edizione nuova: aggiungere un altro UNION ALL con il suo tracciato.

-- INGRESSI PULITI. Regole (verificate sui dati 2024-2025):
--  a) solo esiti OK su biglietti esistenti in biglietteria;
--  b) si scartano le doppie scansioni dello stesso biglietto entro 10 secondi;
--  c) per ogni biglietto e giorno al massimo "persone" ingressi (Family = 4 scansioni, uno per persona).
CREATE VIEW v_ingresso AS
WITH ok AS (
  SELECT t.edizione, t.ts, t.varco, t.id_biglietto,
         b.persone, b.canale, b.tipo_std, b.is_abbonamento
  FROM v_tornello t
  JOIN v_biglietto b ON b.id_biglietto = t.id_biglietto
  WHERE t.esito_ok
),
gap AS (
  SELECT ok.*,
         ts - LAG(ts) OVER (PARTITION BY id_biglietto, CAST(ts AS date) ORDER BY ts) AS dal_precedente
  FROM ok
),
nodup AS (
  SELECT gap.*,
         ROW_NUMBER() OVER (PARTITION BY id_biglietto, CAST(ts AS date) ORDER BY ts) AS n
  FROM gap
  WHERE dal_precedente IS NULL OR dal_precedente > INTERVAL '10 seconds'
)
SELECT edizione, ts, CAST(ts AS date) AS data, EXTRACT(HOUR FROM ts)::int AS ora,
       varco, substr(varco,1,2) AS area, id_biglietto, canale, tipo_std, is_abbonamento
FROM nodup
WHERE n <= persone;

-- Visite agli stand: si escludono le scansioni fuori dall'orario 09:00-18:59 (es. 912 scansioni alle 08:00 su P1-A02)
CREATE VIEW v_visita_stand AS
SELECT EXTRACT(YEAR FROM v.data)::smallint AS edizione,
       v.codice_stand, p.padiglione, v.data, v.ora, substr(v.ora,1,2)::int AS ora_num, v.scansioni
FROM stg_visite_stand v
LEFT JOIN planimetria p ON p.codice_stand = v.codice_stand
WHERE v.ora >= '09:00' AND v.ora < '19:00';

-- Contatti: consenso non registrato = non utilizzabile; minorenni esclusi dal marketing; email mascherata
CREATE VIEW v_contatto_stand AS
SELECT c.id_contatto,
       EXTRACT(YEAR FROM c.data_ora::timestamp)::smallint AS edizione,
       c.codice_stand, c.id_espositore, c.data_ora::timestamp AS data_ora,
       c.fascia_eta, c.provincia, c.interesse,
       COALESCE(c.consenso_marketing = 'SI', false) AS consenso_marketing,
       COALESCE(c.fascia_eta = '14-17', false) AS minorenne,
       (COALESCE(c.consenso_marketing = 'SI', false) AND COALESCE(c.fascia_eta,'') <> '14-17') AS utilizzabile_marketing,
       left(c.email,2) || '***@' || split_part(c.email,'@',2) AS email_mascherata
FROM stg_contatti_stand c;

-- Contratti con stand, espositore risolto (anche 2024), e ripartizione dell'importo a listino
CREATE VIEW v_contratto AS
WITH r AS (
  SELECT id_contratto,
         COALESCE(SUM(importo_eur) FILTER (WHERE codice_voce IN ('SPAZIO','MAGG')),0) AS area_listino_eur,
         COALESCE(SUM(importo_eur) FILTER (WHERE codice_voce LIKE 'EX-%'),0)          AS extra_listino_eur,
         COALESCE(SUM(importo_eur) FILTER (WHERE codice_voce LIKE 'SP-%'),0)          AS sponsor_listino_eur
  FROM riga_contratto GROUP BY id_contratto
)
SELECT c.id_contratto, c.edizione,
       COALESCE(c.id_espositore, m.id_espositore) AS id_espositore,
       COALESCE(e.ragione_sociale, c.ragione_sociale) AS ragione_sociale,
       e.settore,
       (c.id_espositore IS NULL AND m.id_espositore IS NOT NULL) AS espositore_da_abbinamento,
       c.codice_stand, p.padiglione, p.nome_padiglione, p.mq,
       c.data_firma, c.imponibile_listino_eur, c.sconto_pct, c.imponibile_eur,
       r.area_listino_eur, r.extra_listino_eur, r.sponsor_listino_eur,
       c.acconto_scadenza, c.acconto_pagato_il, c.saldo_scadenza, c.saldo_pagato_il,
       c.rinnovo
FROM contratto c
LEFT JOIN contratto_espositore_map m ON m.id_contratto = c.id_contratto
LEFT JOIN espositore e ON e.id_espositore = COALESCE(c.id_espositore, m.id_espositore)
LEFT JOIN planimetria p ON p.codice_stand = c.codice_stand
LEFT JOIN r ON r.id_contratto = c.id_contratto;


-- =====================================================================
-- 3. VISTE PER SCHERMATA
-- =====================================================================

-- ---------- S01 · Accesso ----------
CREATE VIEW v_s01_permessi AS
SELECT u.email, u.nome, r.id_ruolo, r.nome AS ruolo, u.id_espositore, u.attivo,
       s.schermata, s.note
FROM utente_app u
JOIN ruolo r ON r.id_ruolo = u.id_ruolo
JOIN ruolo_schermata s ON s.id_ruolo = u.id_ruolo
WHERE u.attivo;

-- ---------- S02 · Cruscotto direzionale ----------
-- Ingressi per ora con picco e saturazione (limite superiore: mancano le uscite)
CREATE VIEW v_s02_picchi AS
WITH h AS (
  SELECT edizione, data, ora, COUNT(*) AS ingressi
  FROM v_ingresso GROUP BY edizione, data, ora
)
SELECT h.edizione, h.data,
       DENSE_RANK() OVER (PARTITION BY h.edizione ORDER BY h.data) AS giornata,
       h.ora, h.ingressi,
       SUM(h.ingressi) OVER (PARTITION BY h.edizione, h.data ORDER BY h.ora) AS ingressi_cumulati,
       c.capienza,
       ROUND(100.0 * SUM(h.ingressi) OVER (PARTITION BY h.edizione, h.data ORDER BY h.ora)
             / NULLIF(c.capienza,0), 1) AS saturazione_pct_max,
       (h.ingressi = MAX(h.ingressi) OVER (PARTITION BY h.edizione)) AS is_picco_edizione
FROM h
LEFT JOIN param_capienza c ON c.edizione = h.edizione AND c.ambito = 'evento';

-- KPI per edizione (una riga per edizione). Colonne additive + rapporti pronti.
CREATE VIEW v_s02_kpi_edizione AS
WITH ing AS (SELECT edizione, COUNT(*) AS ingressi FROM v_ingresso GROUP BY edizione),
pk AS (SELECT edizione, MAX(ingressi) AS ingressi_ora_picco FROM v_s02_picchi GROUP BY edizione),
big AS (
  SELECT edizione, COUNT(*) AS biglietti_venduti, SUM(persone) AS persone_vendute, SUM(prezzo) AS ricavi_biglietteria
  FROM v_biglietto GROUP BY edizione
),
nos AS (
  SELECT b.edizione, COUNT(*) AS biglietti_mai_scansionati
  FROM v_biglietto b
  WHERE NOT EXISTS (SELECT 1 FROM v_ingresso i WHERE i.id_biglietto = b.id_biglietto)
  GROUP BY b.edizione
),
con AS (
  SELECT edizione, COUNT(*) AS contratti, COUNT(DISTINCT codice_stand) AS stand_venduti,
         SUM(mq) AS mq_venduti, SUM(imponibile_eur) AS imponibile_stand,
         SUM(imponibile_listino_eur) AS imponibile_listino
  FROM v_contratto GROUP BY edizione
),
disp AS (
  SELECT e.anno AS edizione, COUNT(*) AS stand_disponibili, SUM(p.mq) AS mq_disponibili
  FROM edizione e JOIN planimetria p ON p.attivo_dal <= e.anno GROUP BY e.anno
),
ct AS (SELECT edizione, COUNT(*) AS contatti, COUNT(*) FILTER (WHERE utilizzabile_marketing) AS contatti_marketing
       FROM v_contatto_stand GROUP BY edizione),
vs AS (SELECT edizione, SUM(scansioni) AS scansioni_stand FROM v_visita_stand GROUP BY edizione),
cs AS (SELECT edizione, SUM(importo_eur) AS costo_totale FROM param_costo GROUP BY edizione)
SELECT e.anno AS edizione,
       ing.ingressi, pk.ingressi_ora_picco,
       big.biglietti_venduti, big.persone_vendute, big.ricavi_biglietteria,
       ROUND(big.ricavi_biglietteria / NULLIF(big.biglietti_venduti,0), 2) AS ricavo_medio_biglietto,
       nos.biglietti_mai_scansionati,
       ROUND(100.0 * nos.biglietti_mai_scansionati / NULLIF(big.biglietti_venduti,0), 1) AS no_show_pct,
       con.contratti, con.stand_venduti, disp.stand_disponibili,
       ROUND(100.0 * con.stand_venduti / NULLIF(disp.stand_disponibili,0), 1) AS stand_venduti_pct,
       con.mq_venduti, disp.mq_disponibili,
       ROUND(100.0 * con.mq_venduti / NULLIF(disp.mq_disponibili,0), 1) AS mq_venduti_pct,
       con.imponibile_stand, con.imponibile_listino,
       ROUND(100.0 * (1 - con.imponibile_stand / NULLIF(con.imponibile_listino,0)), 1) AS sconto_medio_pct,
       ROUND(con.imponibile_stand / NULLIF(con.mq_venduti,0), 1) AS ricavi_per_mq,
       ct.contatti, ct.contatti_marketing, vs.scansioni_stand,
       ROUND(100.0 * ct.contatti / NULLIF(vs.scansioni_stand,0), 2) AS contatti_per_100_scansioni,
       cs.costo_totale,
       ROUND(cs.costo_totale / NULLIF(ct.contatti,0), 2) AS costo_per_contatto,
       ROUND(cs.costo_totale / NULLIF(ing.ingressi,0), 2) AS costo_per_ingresso
FROM edizione e
LEFT JOIN ing ON ing.edizione = e.anno
LEFT JOIN pk  ON pk.edizione  = e.anno
LEFT JOIN big ON big.edizione = e.anno
LEFT JOIN nos ON nos.edizione = e.anno
LEFT JOIN con ON con.edizione = e.anno
LEFT JOIN disp ON disp.edizione = e.anno
LEFT JOIN ct  ON ct.edizione  = e.anno
LEFT JOIN vs  ON vs.edizione  = e.anno
LEFT JOIN cs  ON cs.edizione  = e.anno;

-- Ricavi stand per padiglione
CREATE VIEW v_s02_ricavi_padiglione AS
WITH v AS (
  SELECT edizione, padiglione, COUNT(DISTINCT codice_stand) AS stand_venduti,
         SUM(mq) AS mq_venduti, SUM(imponibile_eur) AS imponibile_eur
  FROM v_contratto GROUP BY edizione, padiglione
),
d AS (
  SELECT e.anno AS edizione, p.padiglione, COUNT(*) AS stand_disponibili, SUM(p.mq) AS mq_disponibili
  FROM edizione e JOIN planimetria p ON p.attivo_dal <= e.anno GROUP BY e.anno, p.padiglione
)
SELECT d.edizione, d.padiglione, d.stand_disponibili, d.mq_disponibili,
       COALESCE(v.stand_venduti,0) AS stand_venduti, COALESCE(v.mq_venduti,0) AS mq_venduti,
       COALESCE(v.imponibile_eur,0) AS imponibile_eur,
       ROUND(v.imponibile_eur / NULLIF(v.mq_venduti,0), 1) AS ricavi_per_mq,
       ROUND(100.0 * COALESCE(v.mq_venduti,0) / NULLIF(d.mq_disponibili,0), 1) AS mq_venduti_pct
FROM d LEFT JOIN v ON v.edizione = d.edizione AND v.padiglione = d.padiglione;

-- ---------- S03 · Operatività evento (staff) ----------
-- Flusso per varco e ora, con scansioni scartate dalla pulizia
CREATE VIEW v_s03_varchi_ora AS
WITH g AS (
  SELECT edizione, CAST(ts AS date) AS data, EXTRACT(HOUR FROM ts)::int AS ora, varco,
         COUNT(*) FILTER (WHERE esito_ok)     AS scansioni_ok,
         COUNT(*) FILTER (WHERE NOT esito_ok) AS scansioni_ko
  FROM v_tornello GROUP BY edizione, CAST(ts AS date), EXTRACT(HOUR FROM ts)::int, varco
),
p AS (
  SELECT edizione, data, ora, varco, COUNT(*) AS ingressi FROM v_ingresso GROUP BY edizione, data, ora, varco
)
SELECT g.edizione, g.data, g.ora, g.varco, substr(g.varco,1,2) AS area,
       g.scansioni_ok, g.scansioni_ko,
       COALESCE(p.ingressi,0) AS ingressi,
       g.scansioni_ok - COALESCE(p.ingressi,0) AS scansioni_scartate
FROM g LEFT JOIN p ON p.edizione = g.edizione AND p.data = g.data AND p.ora = g.ora AND p.varco = g.varco;

-- Avvisi: ogni esito KO con il motivo
CREATE VIEW v_s03_avvisi AS
WITH primo_ok AS (
  SELECT id_biglietto, MIN(ts) AS ts_primo_ok FROM v_tornello WHERE esito_ok GROUP BY id_biglietto
)
SELECT t.edizione, t.ts, t.varco, t.id_biglietto, b.tipo_std,
       CASE WHEN b.id_biglietto IS NULL THEN 'Codice non presente in biglietteria'
            WHEN po.ts_primo_ok < t.ts THEN 'Biglietto già utilizzato'
            ELSE 'KO da verificare' END AS motivo
FROM v_tornello t
LEFT JOIN v_biglietto b ON b.id_biglietto = t.id_biglietto
LEFT JOIN primo_ok po ON po.id_biglietto = t.id_biglietto
WHERE NOT t.esito_ok;

-- Riepilogo per area (padiglione): scansioni agli stand per ora
CREATE VIEW v_s03_riepilogo_area AS
SELECT edizione, data, ora_num AS ora, padiglione AS area,
       COUNT(DISTINCT codice_stand) AS stand_con_dati, SUM(scansioni) AS scansioni_stand
FROM v_visita_stand GROUP BY edizione, data, ora_num, padiglione;

-- Turni (vuota finché non si caricano i turni)
CREATE VIEW v_s03_turni AS
SELECT edizione, data, area, ora_inizio, ora_fine, id_staff, ruolo_turno FROM turno_staff;

-- ---------- S04 · Back office commerciale ----------
-- Scheda pratica unica: offerta, contratto, acconto e saldo
CREATE VIEW v_s04_scheda_contratto AS
SELECT c.*,
       CASE WHEN c.acconto_pagato_il IS NULL THEN 'Non pagato'
            WHEN c.acconto_pagato_il > c.acconto_scadenza THEN 'Pagato in ritardo'
            ELSE 'Pagato nei termini' END AS stato_acconto,
       CASE WHEN c.saldo_pagato_il IS NULL THEN 'Non pagato'
            WHEN c.saldo_pagato_il > c.saldo_scadenza THEN 'Pagato in ritardo'
            ELSE 'Pagato nei termini' END AS stato_saldo,
       CASE WHEN c.saldo_pagato_il IS NULL THEN (CURRENT_DATE - c.saldo_scadenza)
            ELSE (c.saldo_pagato_il - c.saldo_scadenza) END AS giorni_saldo_vs_scadenza,
       (c.saldo_pagato_il IS NULL) AS saldo_aperto
FROM v_contratto c;
-- Nota: nei dati manca l'importo di acconto/saldo. "Imponibile con saldo aperto" è l'importo
-- del CONTRATTO, non la quota di saldo da incassare.

-- Stand liberi per edizione (anche 2026: tutti liberi finché non ci sono contratti)
CREATE VIEW v_s04_stand_liberi AS
SELECT e.anno AS edizione, p.codice_stand, p.padiglione, p.nome_padiglione, p.mq, p.posizione
FROM edizione e
JOIN planimetria p ON p.attivo_dal <= e.anno
WHERE NOT EXISTS (SELECT 1 FROM contratto c WHERE c.edizione = e.anno AND c.codice_stand = p.codice_stand);

-- Rinnovi: stato di ogni espositore rispetto all'edizione precedente
CREATE VIEW v_s04_rinnovi AS
WITH part AS (SELECT DISTINCT edizione, id_espositore FROM v_contratto WHERE id_espositore IS NOT NULL)
SELECT a.edizione, a.id_espositore, e.ragione_sociale, e.settore,
       CASE WHEN EXISTS (SELECT 1 FROM part p WHERE p.edizione = a.edizione - 1 AND p.id_espositore = a.id_espositore)
            THEN 'Rinnovato' ELSE 'Nuovo' END AS stato
FROM part a LEFT JOIN espositore e ON e.id_espositore = a.id_espositore
WHERE a.edizione > (SELECT MIN(edizione) FROM part)
UNION ALL
SELECT pr.edizione + 1, pr.id_espositore, e.ragione_sociale, e.settore, 'Non rinnovato'
FROM part pr LEFT JOIN espositore e ON e.id_espositore = pr.id_espositore
WHERE pr.edizione + 1 IN (SELECT edizione FROM part)
  AND NOT EXISTS (SELECT 1 FROM part p WHERE p.edizione = pr.edizione + 1 AND p.id_espositore = pr.id_espositore);

-- Listino 2026
CREATE VIEW v_s04_listino AS
SELECT codice, voce, unita, prezzo_unitario_eur, disponibilita, note FROM listino;

-- ---------- S05 · Area espositore (filtro di riga su id_espositore) ----------
CREATE VIEW v_s05_espositore AS
WITH base AS (
  SELECT edizione, id_espositore, ragione_sociale,
         COUNT(*) AS contratti, COUNT(DISTINCT codice_stand) AS stand, SUM(mq) AS mq,
         SUM(imponibile_eur) AS imponibile_eur,
         COUNT(*) FILTER (WHERE saldo_pagato_il IS NULL) AS saldi_aperti
  FROM v_contratto GROUP BY edizione, id_espositore, ragione_sociale
),
vis AS (
  SELECT c.edizione, c.id_espositore, SUM(v.scansioni) AS scansioni_stand
  FROM v_contratto c JOIN v_visita_stand v ON v.edizione = c.edizione AND v.codice_stand = c.codice_stand
  GROUP BY c.edizione, c.id_espositore
),
ct AS (
  SELECT edizione, id_espositore, COUNT(*) AS contatti,
         COUNT(*) FILTER (WHERE utilizzabile_marketing) AS contatti_marketing
  FROM v_contatto_stand GROUP BY edizione, id_espositore
)
SELECT b.*, COALESCE(vis.scansioni_stand,0) AS scansioni_stand,
       COALESCE(ct.contatti,0) AS contatti, COALESCE(ct.contatti_marketing,0) AS contatti_marketing,
       ROUND(100.0 * COALESCE(ct.contatti,0) / NULLIF(vis.scansioni_stand,0), 2) AS contatti_per_100_scansioni
FROM base b
LEFT JOIN vis ON vis.edizione = b.edizione AND vis.id_espositore = b.id_espositore
LEFT JOIN ct  ON ct.edizione  = b.edizione AND ct.id_espositore  = b.id_espositore;

-- ---------- S06 · Scansione allo stand ----------
CREATE VIEW v_s06_visite_ora AS
SELECT v.edizione, v.codice_stand, v.padiglione, v.data, v.ora_num AS ora, v.scansioni
FROM v_visita_stand v;

-- Contatti senza dati personali (email mascherata): mostrare altro solo se necessario e autorizzato
CREATE VIEW v_s06_contatti AS
SELECT id_contatto, edizione, codice_stand, id_espositore, data_ora, fascia_eta, provincia,
       interesse, consenso_marketing, minorenne, utilizzabile_marketing, email_mascherata
FROM v_contatto_stand;

CREATE VIEW v_s06_stand_performance AS
WITH s AS (SELECT edizione, codice_stand, SUM(scansioni) AS scansioni FROM v_visita_stand GROUP BY edizione, codice_stand),
c AS (SELECT edizione, codice_stand, COUNT(*) AS contatti,
             COUNT(*) FILTER (WHERE utilizzabile_marketing) AS contatti_marketing
      FROM v_contatto_stand GROUP BY edizione, codice_stand)
SELECT s.edizione, s.codice_stand, p.padiglione, p.mq, s.scansioni,
       COALESCE(c.contatti,0) AS contatti, COALESCE(c.contatti_marketing,0) AS contatti_marketing,
       ROUND(100.0 * COALESCE(c.contatti,0) / NULLIF(s.scansioni,0), 2) AS contatti_per_100_scansioni,
       ROUND(s.scansioni / NULLIF(p.mq,0), 1) AS scansioni_per_mq
FROM s
LEFT JOIN c ON c.edizione = s.edizione AND c.codice_stand = s.codice_stand
LEFT JOIN planimetria p ON p.codice_stand = s.codice_stand;

-- ---------- S07 · Biglietteria e accessi ----------
-- Vendite (additive: sommare in Metabase)
CREATE VIEW v_s07_vendite AS
SELECT edizione, CAST(data_acquisto AS date) AS data_acquisto, canale, tipo_std, provincia, fascia_eta,
       COUNT(*) AS biglietti, SUM(persone) AS persone, SUM(prezzo) AS ricavi
FROM v_biglietto GROUP BY edizione, CAST(data_acquisto AS date), canale, tipo_std, provincia, fascia_eta;

-- Stato del singolo biglietto (verifica al varco, no-show, ritentativi)
CREATE VIEW v_s07_biglietto_stato AS
WITH i AS (
  SELECT id_biglietto, COUNT(*) AS ingressi, MIN(ts) AS prima_scansione, MAX(ts) AS ultima_scansione,
         COUNT(DISTINCT data) AS giorni_con_ingresso
  FROM v_ingresso GROUP BY id_biglietto
),
k AS (SELECT id_biglietto, COUNT(*) AS tentativi_ko FROM v_tornello WHERE NOT esito_ok GROUP BY id_biglietto)
SELECT b.edizione, b.id_biglietto, b.id_ordine, b.canale, b.tipo_std, b.giorno_valido, b.is_abbonamento,
       b.persone, b.prezzo,
       COALESCE(i.ingressi,0) AS ingressi, i.prima_scansione, i.ultima_scansione,
       COALESCE(i.giorni_con_ingresso,0) AS giorni_con_ingresso,
       COALESCE(k.tentativi_ko,0) AS tentativi_ko,
       (i.id_biglietto IS NULL) AS no_show
FROM v_biglietto b
LEFT JOIN i ON i.id_biglietto = b.id_biglietto
LEFT JOIN k ON k.id_biglietto = b.id_biglietto;

-- Eccezioni da gestire: KO e ingressi in un giorno diverso da quello del biglietto
CREATE VIEW v_s07_eccezioni AS
SELECT edizione, ts, varco, id_biglietto, tipo_std, motivo FROM v_s03_avvisi
UNION ALL
SELECT i.edizione, i.ts, i.varco, i.id_biglietto, i.tipo_std, 'Ingresso in giorno diverso da quello del biglietto'
FROM v_ingresso i
JOIN v_biglietto b ON b.id_biglietto = i.id_biglietto
WHERE NOT b.is_abbonamento AND b.giorno_valido <> i.data;

-- ---------- S08 · Mappa interattiva ----------
-- Coordinate NULL finché stand_coordinate non è compilata
CREATE VIEW v_s08_mappa_stand AS
WITH v AS (SELECT edizione, codice_stand, SUM(scansioni) AS scansioni FROM v_visita_stand GROUP BY edizione, codice_stand)
SELECT c.edizione, c.codice_stand, c.padiglione, c.mq, c.id_espositore, c.ragione_sociale, c.settore,
       k.x_pct, k.y_pct, COALESCE(v.scansioni,0) AS scansioni,
       ROUND(COALESCE(v.scansioni,0) / NULLIF(c.mq,0), 1) AS scansioni_per_mq
FROM v_contratto c
LEFT JOIN stand_coordinate k ON k.codice_stand = c.codice_stand
LEFT JOIN v ON v.edizione = c.edizione AND v.codice_stand = c.codice_stand;

-- Mappa di calore (direzione): affollamento per stand e ora
CREATE VIEW v_s08_calore AS
SELECT v.edizione, v.data, v.ora_num AS ora, v.codice_stand, v.padiglione, v.scansioni, k.x_pct, k.y_pct
FROM v_visita_stand v LEFT JOIN stand_coordinate k ON k.codice_stand = v.codice_stand;

-- ---------- S09 · Report ----------
-- Filtri: edizione, giornata, area (padiglione del varco), fonte (canale di vendita)
CREATE VIEW v_s09_report_ingressi AS
WITH g AS (
  SELECT i.*, DENSE_RANK() OVER (PARTITION BY i.edizione ORDER BY i.data) AS giornata FROM v_ingresso i
)
SELECT edizione, giornata, data, ora, area, varco, canale AS fonte, tipo_std, COUNT(*) AS ingressi
FROM g GROUP BY edizione, giornata, data, ora, area, varco, canale, tipo_std;

-- Confronto edizioni in formato lungo (una riga per KPI ed edizione)
CREATE VIEW v_s09_confronto_edizioni AS
SELECT * FROM (
SELECT edizione, 'Ingressi' AS kpi, ingressi::numeric AS valore FROM v_s02_kpi_edizione
UNION ALL SELECT edizione, 'Ingressi nell''ora di picco', ingressi_ora_picco::numeric FROM v_s02_kpi_edizione
UNION ALL SELECT edizione, 'Ricavi biglietteria (€)', ricavi_biglietteria::numeric FROM v_s02_kpi_edizione
UNION ALL SELECT edizione, 'Ricavo medio per biglietto (€)', ricavo_medio_biglietto::numeric FROM v_s02_kpi_edizione
UNION ALL SELECT edizione, 'Biglietti non utilizzati (%)', no_show_pct::numeric FROM v_s02_kpi_edizione
UNION ALL SELECT edizione, 'Contratti stand', contratti::numeric FROM v_s02_kpi_edizione
UNION ALL SELECT edizione, 'Stand venduti (%)', stand_venduti_pct::numeric FROM v_s02_kpi_edizione
UNION ALL SELECT edizione, 'm² venduti (%)', mq_venduti_pct::numeric FROM v_s02_kpi_edizione
UNION ALL SELECT edizione, 'Imponibile stand (€)', imponibile_stand::numeric FROM v_s02_kpi_edizione
UNION ALL SELECT edizione, 'Sconto medio (%)', sconto_medio_pct::numeric FROM v_s02_kpi_edizione
UNION ALL SELECT edizione, 'Ricavi per m² (€)', ricavi_per_mq::numeric FROM v_s02_kpi_edizione
UNION ALL SELECT edizione, 'Contatti raccolti', contatti::numeric FROM v_s02_kpi_edizione
UNION ALL SELECT edizione, 'Contatti per 100 scansioni', contatti_per_100_scansioni::numeric FROM v_s02_kpi_edizione
UNION ALL SELECT edizione, 'Costo per contatto (€)', costo_per_contatto::numeric FROM v_s02_kpi_edizione
) k
WHERE valore IS NOT NULL;  -- i KPI senza dati (es. costi non inseriti) non compaiono

-- Definizioni dei KPI da mostrare nel report
CREATE VIEW v_s09_kpi_definizioni AS
SELECT kpi, definizione, formula, vista_fonte, frequenza_aggiornamento, responsabile FROM kpi_definizione;


-- =====================================================================
-- 4. CONTROLLI DI QUALITÀ (eseguirli dopo ogni caricamento)
-- =====================================================================
CREATE VIEW v_qc_controlli AS
SELECT 'Biglietti con tipo non mappato' AS controllo, COUNT(*) AS righe
FROM v_biglietto b WHERE NOT EXISTS (SELECT 1 FROM map_tipo_biglietto m WHERE m.tipo_originale = b.tipo_originale)
UNION ALL SELECT 'Province non riconosciute (né sigla né nome mappato)', COUNT(*)
FROM v_biglietto WHERE provincia IS NOT NULL AND length(provincia) <> 2
UNION ALL SELECT 'Contratti senza espositore risolto', COUNT(*) FROM v_contratto WHERE id_espositore IS NULL
UNION ALL SELECT 'Contratti abbinati per nome simile (da verificare)', COUNT(*)
FROM contratto_espositore_map WHERE da_verificare
UNION ALL SELECT 'Contratti su stand non in planimetria', COUNT(*) FROM contratto c
WHERE NOT EXISTS (SELECT 1 FROM planimetria p WHERE p.codice_stand = c.codice_stand)
UNION ALL SELECT 'Stand venduti due volte nella stessa edizione', COUNT(*)
FROM (SELECT edizione, codice_stand FROM contratto GROUP BY edizione, codice_stand HAVING COUNT(*) > 1) d
UNION ALL SELECT 'Scansioni stand fuori orario (escluse)', COUNT(*)
FROM stg_visite_stand WHERE ora < '09:00' OR ora >= '19:00'
UNION ALL SELECT 'Scansioni stand su stand senza contratto nell''edizione', COUNT(*)
FROM v_visita_stand v WHERE NOT EXISTS (SELECT 1 FROM contratto c WHERE c.edizione = v.edizione AND c.codice_stand = v.codice_stand)
UNION ALL SELECT 'Contatti senza consenso registrato', COUNT(*) FROM stg_contatti_stand WHERE consenso_marketing IS NULL
UNION ALL SELECT 'Contatti di minorenni (14-17)', COUNT(*) FROM v_contatto_stand WHERE minorenne
UNION ALL SELECT 'Tornelli: codici non presenti in biglietteria', COUNT(*)
FROM v_tornello t WHERE NOT EXISTS (SELECT 1 FROM v_biglietto b WHERE b.id_biglietto = t.id_biglietto);
