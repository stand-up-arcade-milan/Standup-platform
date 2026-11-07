-- V009: area commerciale e servizi dell'API.
-- Listino, pratiche con acconti e documenti, richieste, profilo pubblico degli espositori, account e inviti, avvisi
-- e lotti di KPI ricevuti da BAD. Le email e le password non stanno mai nelle tabelle di lettura generale.
SET search_path TO arcade;

DO $$
BEGIN
    IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'arcade_autenticazione') THEN
        CREATE ROLE arcade_autenticazione NOLOGIN;
    END IF;
END $$;
GRANT USAGE ON SCHEMA arcade TO arcade_autenticazione;

-- Soglia di sconto oltre la quale serve l'approvazione, proposta 10%
ALTER TABLE parametri_stima
    ADD COLUMN soglia_sconto_approvazione numeric(5,2) NOT NULL DEFAULT 10
        CHECK (soglia_sconto_approvazione BETWEEN 0 AND 100);

-- Profilo pubblico degli espositori

CREATE TABLE categoria_espositore (
    codice text PRIMARY KEY,
    nome   text NOT NULL
);

CREATE TABLE profilo_espositore (
    id_espositore text PRIMARY KEY REFERENCES espositore (id_espositore),
    nome_pubblico text NOT NULL,
    descrizione   text,
    logo_url      text,
    sito_web      text,
    in_evidenza   boolean NOT NULL DEFAULT false
);

CREATE TABLE espositore_categoria (
    id_espositore    text NOT NULL REFERENCES espositore (id_espositore),
    codice_categoria text NOT NULL REFERENCES categoria_espositore (codice),
    PRIMARY KEY (id_espositore, codice_categoria)
);

-- Listino: prezzi al netto di IVA, riservati ai ruoli interni

CREATE TABLE listino_voce (
    anno        smallint NOT NULL REFERENCES edizione (anno),
    codice_voce text NOT NULL,
    descrizione text NOT NULL,
    tipo        text NOT NULL CHECK (tipo IN ('STAND','PACCHETTO','SERVIZIO')),
    unita       text NOT NULL CHECK (unita IN ('MQ','FORFAIT')),
    prezzo_eur  numeric(10,2) NOT NULL CHECK (prezzo_eur >= 0),
    PRIMARY KEY (anno, codice_voce)
);

-- Pratica commerciale: dal preventivo al contratto, in quattro stati

CREATE TABLE pratica (
    id_pratica            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    anno                  smallint NOT NULL REFERENCES edizione (anno),
    id_espositore         text NOT NULL REFERENCES espositore (id_espositore),
    codice_stand          text REFERENCES stand (codice),
    stato                 text NOT NULL DEFAULT 'BOZZA' CHECK (stato IN ('BOZZA','INVIATA','FIRMATA','ACCONTO_RICEVUTO')),
    pacchetto             text NOT NULL DEFAULT 'BASE' CHECK (pacchetto IN ('BASE','PREMIUM')),
    sconto_percentuale    numeric(5,2) NOT NULL DEFAULT 0 CHECK (sconto_percentuale BETWEEN 0 AND 100),
    approvazione_richiesta boolean NOT NULL DEFAULT false,
    id_pratica_precedente uuid REFERENCES pratica (id_pratica),
    creata_il             timestamptz NOT NULL DEFAULT now(),
    aggiornata_il         timestamptz NOT NULL DEFAULT now(),
    UNIQUE (anno, id_espositore),
    UNIQUE (id_pratica, anno),
    CHECK (stato = 'BOZZA' OR codice_stand IS NOT NULL)
);

CREATE TABLE voce_pratica (
    id_pratica          uuid NOT NULL,
    anno                smallint NOT NULL,
    codice_voce         text NOT NULL,
    quantita            numeric(10,3) NOT NULL CHECK (quantita > 0),
    prezzo_unitario_eur numeric(10,2) NOT NULL CHECK (prezzo_unitario_eur >= 0),
    PRIMARY KEY (id_pratica, codice_voce),
    FOREIGN KEY (id_pratica, anno) REFERENCES pratica (id_pratica, anno) ON DELETE CASCADE,
    FOREIGN KEY (anno, codice_voce) REFERENCES listino_voce (anno, codice_voce)
);

CREATE TABLE documento_pratica (
    id_documento uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    id_pratica   uuid NOT NULL REFERENCES pratica (id_pratica) ON DELETE CASCADE,
    tipo         text NOT NULL CHECK (tipo IN ('OFFERTA','CONTRATTO','ALTRO')),
    nome         text NOT NULL,
    url          text NOT NULL,
    creato_il    timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE acconto (
    id_acconto  uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    id_pratica  uuid NOT NULL REFERENCES pratica (id_pratica) ON DELETE CASCADE,
    importo_eur numeric(10,2) NOT NULL CHECK (importo_eur > 0),
    ricevuto_il timestamptz NOT NULL,
    riferimento text
);

-- Controlli del database sulla pratica: transizioni di stato in ordine, approvazione dello sconto.
CREATE FUNCTION pratica_controlla() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
    IF TG_OP = 'UPDATE' AND NEW.stato <> OLD.stato
       AND (OLD.stato, NEW.stato) NOT IN (('BOZZA','INVIATA'), ('INVIATA','FIRMATA'), ('FIRMATA','ACCONTO_RICEVUTO')) THEN
        RAISE EXCEPTION 'Transizione di stato non valida: % verso %', OLD.stato, NEW.stato USING ERRCODE = '23514';
    END IF;
    NEW.aggiornata_il := now();
    NEW.approvazione_richiesta := NEW.sconto_percentuale >
        coalesce((SELECT soglia_sconto_approvazione FROM parametri_stima WHERE anno = NEW.anno), 10);
    RETURN NEW;
END $$;

CREATE TRIGGER pratica_controlla BEFORE INSERT OR UPDATE ON pratica
    FOR EACH ROW EXECUTE FUNCTION pratica_controlla();

-- Alla firma, nella stessa transazione, lo stand viene assegnato e il pacchetto registrato.
-- Se lo stand è già assegnato o non è disponibile la firma fallisce e non cambia nulla.
CREATE FUNCTION pratica_alla_firma() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
    IF NOT (SELECT disponibile FROM stand WHERE codice = NEW.codice_stand) THEN
        RAISE EXCEPTION 'Lo stand % non è disponibile', NEW.codice_stand USING ERRCODE = '23514';
    END IF;
    INSERT INTO assegnazione_stand (anno, codice_stand, id_espositore)
    VALUES (NEW.anno, NEW.codice_stand, NEW.id_espositore);
    INSERT INTO pacchetto_espositore (anno, id_espositore, livello)
    VALUES (NEW.anno, NEW.id_espositore, NEW.pacchetto)
    ON CONFLICT (anno, id_espositore) DO UPDATE SET livello = EXCLUDED.livello;
    RETURN NULL;
END $$;

CREATE TRIGGER pratica_alla_firma AFTER UPDATE OF stato ON pratica
    FOR EACH ROW WHEN (OLD.stato <> 'FIRMATA' AND NEW.stato = 'FIRMATA')
    EXECUTE FUNCTION pratica_alla_firma();

-- Richieste dal sito: il nome e l'email del referente stanno in una tabella riservata

CREATE TABLE richiesta (
    id_richiesta            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    tipo                    text NOT NULL CHECK (tipo IN ('ESPOSITORE','VISITATORE')),
    stato                   text NOT NULL DEFAULT 'NUOVA' CHECK (stato IN ('NUOVA','IN_LAVORAZIONE','CHIUSA')),
    anno                    smallint REFERENCES edizione (anno),
    azienda                 text,
    categoria               text,
    metri_quadri_desiderati numeric(8,2) CHECK (metri_quadri_desiderati > 0),
    note                    text,
    consenso_privacy        boolean NOT NULL DEFAULT false,
    consenso_marketing      boolean NOT NULL DEFAULT false,
    id_pratica              uuid REFERENCES pratica (id_pratica),
    creata_il               timestamptz NOT NULL DEFAULT now(),
    CHECK (tipo = 'VISITATORE' OR (azienda IS NOT NULL AND consenso_privacy))
);

CREATE TABLE richiesta_riservata (
    id_richiesta uuid PRIMARY KEY REFERENCES richiesta (id_richiesta) ON DELETE CASCADE,
    referente    text,
    email        text NOT NULL
);

-- Accesso degli espositori: account, inviti monouso. Password e token si conservano solo come impronta.

CREATE TABLE account_espositore (
    id_account     uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    id_espositore  text NOT NULL REFERENCES espositore (id_espositore),
    email          text NOT NULL UNIQUE,
    password_hash  text NOT NULL,
    attivo         boolean NOT NULL DEFAULT true,
    creato_il      timestamptz NOT NULL DEFAULT now(),
    ultimo_accesso timestamptz
);

CREATE TABLE invito_espositore (
    token_hash    text PRIMARY KEY,
    id_espositore text NOT NULL REFERENCES espositore (id_espositore),
    email         text NOT NULL,
    scade_il      timestamptz NOT NULL,
    usato_il      timestamptz
);

-- Avvisi di servizio

CREATE TABLE avviso (
    id_avviso    uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    titolo       text NOT NULL,
    testo        text NOT NULL,
    pubblico     text NOT NULL CHECK (pubblico IN ('VISITATORI','ESPOSITORI','STAFF')),
    pubblicato_il timestamptz NOT NULL DEFAULT now(),
    attivo       boolean NOT NULL DEFAULT true
);

-- Lotti di KPI calcolati da BAD e ricevuti dall'API. Nessun dato personale.

CREATE TABLE lotto_kpi (
    batch_id            uuid PRIMARY KEY,
    anno                smallint NOT NULL REFERENCES edizione (anno),
    calcolato_il        timestamptz NOT NULL,
    formula_versione    text NOT NULL,
    intervallo_dati_dal timestamptz,
    intervallo_dati_al  timestamptz,
    ricevuto_il         timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE kpi_osservazione (
    id_osservazione bigserial PRIMARY KEY,
    batch_id        uuid NOT NULL REFERENCES lotto_kpi (batch_id) ON DELETE CASCADE,
    codice          text NOT NULL CHECK (codice ~ '^[a-z][a-z0-9_]*$'),
    valore          numeric NOT NULL,
    unita           text NOT NULL,
    periodo_dal     timestamptz,
    periodo_al      timestamptz,
    dimensioni      jsonb NOT NULL DEFAULT '{}',
    fonte           text[] NOT NULL DEFAULT '{}',
    qualita         text NOT NULL CHECK (qualita IN ('OK','ATTENZIONE','DA_VERIFICARE')),
    flag_qualita    text[] NOT NULL DEFAULT '{}',
    stimato         boolean NOT NULL,
    simulato        boolean NOT NULL,
    nota            text
);
CREATE INDEX kpi_osservazione_codice_idx ON kpi_osservazione (codice, batch_id);

-- Viste

-- Pratica con imponibile del listino, totale dopo lo sconto e acconti. security_invoker: l'espositore vede solo la propria
CREATE VIEW v_pratica WITH (security_invoker = true) AS
SELECT p.id_pratica, p.anno, p.id_espositore, p.codice_stand, p.stato, p.pacchetto,
       p.sconto_percentuale, p.approvazione_richiesta, p.creata_il, p.aggiornata_il,
       round(coalesce(v.imponibile_listino, 0), 2) AS imponibile_listino_eur,
       round(coalesce(v.imponibile_listino, 0) * (1 - p.sconto_percentuale / 100), 2) AS totale_eur,
       coalesce(a.acconti, 0) AS acconti_eur
FROM pratica p
LEFT JOIN (SELECT id_pratica, sum(quantita * prezzo_unitario_eur) AS imponibile_listino
             FROM voce_pratica GROUP BY id_pratica) v ON v.id_pratica = p.id_pratica
LEFT JOIN (SELECT id_pratica, sum(importo_eur) AS acconti
             FROM acconto GROUP BY id_pratica) a ON a.id_pratica = p.id_pratica;

-- Ricavo per m²: contratti firmati al netto di IVA e sconti, diviso i m² venduti, per padiglione
CREATE VIEW v_ricavo_per_mq AS
SELECT p.anno,
       s.padiglione,
       sum(p.totale_eur) AS ricavo_eur,
       sum(s.superficie_mq) AS mq_venduti,
       round(sum(p.totale_eur) / nullif(sum(s.superficie_mq), 0), 2) AS ricavo_per_mq
FROM v_pratica p
JOIN stand s ON s.codice = p.codice_stand
WHERE p.stato IN ('FIRMATA','ACCONTO_RICEVUTO')
GROUP BY p.anno, s.padiglione;

-- Espositori per categoria e edizione, informazione pubblica
CREATE VIEW v_categoria_conteggio AS
SELECT e.anno, c.codice, c.nome, count(DISTINCT a.id_espositore) AS conteggio
FROM edizione e
CROSS JOIN categoria_espositore c
LEFT JOIN espositore_categoria ec ON ec.codice_categoria = c.codice
LEFT JOIN assegnazione_stand a ON a.anno = e.anno AND a.id_espositore = ec.id_espositore
GROUP BY e.anno, c.codice, c.nome;

-- Permessi

GRANT SELECT ON categoria_espositore, profilo_espositore, espositore_categoria, listino_voce, pratica, voce_pratica,
                documento_pratica, acconto, richiesta, avviso, lotto_kpi, kpi_osservazione,
                v_pratica, v_ricavo_per_mq, v_categoria_conteggio
    TO arcade_lettura;
GRANT SELECT ON richiesta_riservata TO arcade_dati_personali;
GRANT SELECT, INSERT, UPDATE ON account_espositore, invito_espositore TO arcade_autenticazione;

-- Profilo, categorie e conteggi sono pubblici. Il listino, le richieste, gli account e i KPI non lo sono.
GRANT SELECT ON categoria_espositore, profilo_espositore, espositore_categoria, v_categoria_conteggio
    TO arcade_espositore;

ALTER TABLE pratica           ENABLE ROW LEVEL SECURITY;
ALTER TABLE voce_pratica      ENABLE ROW LEVEL SECURITY;
ALTER TABLE documento_pratica ENABLE ROW LEVEL SECURITY;
ALTER TABLE acconto           ENABLE ROW LEVEL SECURITY;
ALTER TABLE avviso            ENABLE ROW LEVEL SECURITY;

CREATE POLICY lettura_completa ON pratica           FOR SELECT TO arcade_lettura USING (true);
CREATE POLICY lettura_completa ON voce_pratica      FOR SELECT TO arcade_lettura USING (true);
CREATE POLICY lettura_completa ON documento_pratica FOR SELECT TO arcade_lettura USING (true);
CREATE POLICY lettura_completa ON acconto           FOR SELECT TO arcade_lettura USING (true);
CREATE POLICY lettura_completa ON avviso            FOR SELECT TO arcade_lettura USING (true);

-- L'espositore vede la propria pratica, le sue voci, i suoi documenti e i suoi acconti
CREATE POLICY solo_propria_pratica ON pratica FOR SELECT TO arcade_espositore
    USING (id_espositore = current_setting('arcade.id_espositore', true));
CREATE POLICY solo_proprie_voci ON voce_pratica FOR SELECT TO arcade_espositore
    USING (EXISTS (SELECT 1 FROM pratica p WHERE p.id_pratica = voce_pratica.id_pratica
                      AND p.id_espositore = current_setting('arcade.id_espositore', true)));
CREATE POLICY solo_propri_documenti ON documento_pratica FOR SELECT TO arcade_espositore
    USING (EXISTS (SELECT 1 FROM pratica p WHERE p.id_pratica = documento_pratica.id_pratica
                      AND p.id_espositore = current_setting('arcade.id_espositore', true)));
CREATE POLICY solo_propri_acconti ON acconto FOR SELECT TO arcade_espositore
    USING (EXISTS (SELECT 1 FROM pratica p WHERE p.id_pratica = acconto.id_pratica
                      AND p.id_espositore = current_setting('arcade.id_espositore', true)));
CREATE POLICY avvisi_per_espositori ON avviso FOR SELECT TO arcade_espositore
    USING (attivo AND pubblico IN ('ESPOSITORI','VISITATORI'));

GRANT SELECT ON pratica, voce_pratica, documento_pratica, acconto, avviso, v_pratica TO arcade_espositore;

-- Dizionario dati delle tabelle e delle colonne nuove

INSERT INTO dizionario_dati (tabella, colonna, tipo, descrizione, sensibilita, titolare)
SELECT d.tabella, d.colonna, format_type(a.atttypid, a.atttypmod), d.descrizione, d.sensibilita, d.titolare
FROM (VALUES
    ('parametri_stima', 'soglia_sconto_approvazione', 'Sconto in percentuale oltre il quale serve l''approvazione, 10 di partenza', 'INTERNO', 'Commerciale'),
    ('categoria_espositore', 'codice', 'Codice della categoria', 'PUBBLICO', 'Organizzazione'),
    ('categoria_espositore', 'nome', 'Nome mostrato nel portale', 'PUBBLICO', 'Organizzazione'),
    ('profilo_espositore', 'id_espositore', 'Espositore', 'PUBBLICO', 'Organizzazione'),
    ('profilo_espositore', 'nome_pubblico', 'Nome mostrato nel portale', 'PUBBLICO', 'Organizzazione'),
    ('profilo_espositore', 'descrizione', 'Presentazione dell''espositore', 'PUBBLICO', 'Organizzazione'),
    ('profilo_espositore', 'logo_url', 'Indirizzo del logo', 'PUBBLICO', 'Organizzazione'),
    ('profilo_espositore', 'sito_web', 'Sito dell''espositore', 'PUBBLICO', 'Organizzazione'),
    ('profilo_espositore', 'in_evidenza', 'Vero se l''espositore è messo in evidenza nel portale', 'PUBBLICO', 'Organizzazione'),
    ('espositore_categoria', 'id_espositore', 'Espositore', 'PUBBLICO', 'Organizzazione'),
    ('espositore_categoria', 'codice_categoria', 'Categoria dell''espositore', 'PUBBLICO', 'Organizzazione'),
    ('listino_voce', 'anno', 'Edizione', 'INTERNO', 'Commerciale'),
    ('listino_voce', 'codice_voce', 'Codice della voce di listino', 'INTERNO', 'Commerciale'),
    ('listino_voce', 'descrizione', 'Nome leggibile della voce', 'INTERNO', 'Commerciale'),
    ('listino_voce', 'tipo', 'STAND, PACCHETTO oppure SERVIZIO', 'INTERNO', 'Commerciale'),
    ('listino_voce', 'unita', 'MQ se il prezzo è per metro quadro, FORFAIT se è a corpo', 'INTERNO', 'Commerciale'),
    ('listino_voce', 'prezzo_eur', 'Prezzo al netto di IVA, simulato finché il cliente non fornisce il listino', 'INTERNO', 'Commerciale'),
    ('pratica', 'id_pratica', 'Identificativo della pratica', 'INTERNO', 'Commerciale'),
    ('pratica', 'anno', 'Edizione', 'INTERNO', 'Commerciale'),
    ('pratica', 'id_espositore', 'Espositore della pratica', 'INTERNO', 'Commerciale'),
    ('pratica', 'codice_stand', 'Stand scelto, obbligatorio dopo la bozza', 'INTERNO', 'Commerciale'),
    ('pratica', 'stato', 'BOZZA, INVIATA, FIRMATA oppure ACCONTO_RICEVUTO, solo in avanti', 'INTERNO', 'Commerciale'),
    ('pratica', 'pacchetto', 'BASE o PREMIUM, alla firma diventa il pacchetto dell''espositore', 'INTERNO', 'Commerciale'),
    ('pratica', 'sconto_percentuale', 'Sconto sull''imponibile del listino', 'INTERNO', 'Commerciale'),
    ('pratica', 'approvazione_richiesta', 'Vero se lo sconto supera la soglia, calcolato dal database', 'INTERNO', 'Commerciale'),
    ('pratica', 'id_pratica_precedente', 'Pratica dell''edizione precedente da cui nasce il rinnovo', 'INTERNO', 'Commerciale'),
    ('pratica', 'creata_il', 'Orario di creazione', 'INTERNO', 'Commerciale'),
    ('pratica', 'aggiornata_il', 'Orario dell''ultima modifica, aggiornato dal database', 'INTERNO', 'Commerciale'),
    ('voce_pratica', 'id_pratica', 'Pratica di appartenenza', 'INTERNO', 'Commerciale'),
    ('voce_pratica', 'anno', 'Edizione della pratica e del listino', 'INTERNO', 'Commerciale'),
    ('voce_pratica', 'codice_voce', 'Voce di listino acquistata', 'INTERNO', 'Commerciale'),
    ('voce_pratica', 'quantita', 'Metri quadri o numero di forfait', 'INTERNO', 'Commerciale'),
    ('voce_pratica', 'prezzo_unitario_eur', 'Prezzo applicato al momento dell''offerta, resta invariato se il listino cambia', 'INTERNO', 'Commerciale'),
    ('documento_pratica', 'id_documento', 'Identificativo del documento', 'INTERNO', 'Commerciale'),
    ('documento_pratica', 'id_pratica', 'Pratica di appartenenza', 'INTERNO', 'Commerciale'),
    ('documento_pratica', 'tipo', 'OFFERTA, CONTRATTO oppure ALTRO', 'INTERNO', 'Commerciale'),
    ('documento_pratica', 'nome', 'Nome del file', 'INTERNO', 'Commerciale'),
    ('documento_pratica', 'url', 'Collegamento al documento su SharePoint', 'INTERNO', 'Commerciale'),
    ('documento_pratica', 'creato_il', 'Orario di creazione', 'INTERNO', 'Commerciale'),
    ('acconto', 'id_acconto', 'Identificativo dell''acconto', 'INTERNO', 'Commerciale'),
    ('acconto', 'id_pratica', 'Pratica di appartenenza', 'INTERNO', 'Commerciale'),
    ('acconto', 'importo_eur', 'Importo ricevuto, i pagamenti non passano dalla piattaforma', 'INTERNO', 'Commerciale'),
    ('acconto', 'ricevuto_il', 'Quando l''acconto è stato ricevuto', 'INTERNO', 'Commerciale'),
    ('acconto', 'riferimento', 'Riferimento del bonifico o della ricevuta', 'INTERNO', 'Commerciale'),
    ('richiesta', 'id_richiesta', 'Identificativo della richiesta', 'INTERNO', 'Commerciale'),
    ('richiesta', 'tipo', 'ESPOSITORE oppure VISITATORE', 'INTERNO', 'Commerciale'),
    ('richiesta', 'stato', 'NUOVA, IN_LAVORAZIONE oppure CHIUSA', 'INTERNO', 'Commerciale'),
    ('richiesta', 'anno', 'Edizione richiesta', 'INTERNO', 'Commerciale'),
    ('richiesta', 'azienda', 'Nome dell''azienda che chiede lo stand', 'INTERNO', 'Commerciale'),
    ('richiesta', 'categoria', 'Categoria indicata nella richiesta', 'INTERNO', 'Commerciale'),
    ('richiesta', 'metri_quadri_desiderati', 'Metri quadri richiesti', 'INTERNO', 'Commerciale'),
    ('richiesta', 'note', 'Note libere della richiesta', 'INTERNO', 'Commerciale'),
    ('richiesta', 'consenso_privacy', 'Consenso al trattamento dei dati per gestire la richiesta', 'INTERNO', 'Commerciale'),
    ('richiesta', 'consenso_marketing', 'Consenso a ricevere novità, per le richieste dei visitatori', 'INTERNO', 'Marketing'),
    ('richiesta', 'id_pratica', 'Pratica creata dalla richiesta', 'INTERNO', 'Commerciale'),
    ('richiesta', 'creata_il', 'Orario della richiesta', 'INTERNO', 'Commerciale'),
    ('richiesta_riservata', 'id_richiesta', 'Richiesta di appartenenza', 'PERSONALE', 'Commerciale'),
    ('richiesta_riservata', 'referente', 'Nome del referente o del visitatore', 'PERSONALE', 'Commerciale'),
    ('richiesta_riservata', 'email', 'Email del referente o del visitatore', 'PERSONALE', 'Commerciale'),
    ('account_espositore', 'id_account', 'Identificativo dell''account', 'INTERNO', 'Sicurezza'),
    ('account_espositore', 'id_espositore', 'Espositore a cui è collegato l''account', 'INTERNO', 'Sicurezza'),
    ('account_espositore', 'email', 'Email di accesso', 'PERSONALE', 'Sicurezza'),
    ('account_espositore', 'password_hash', 'Impronta della password, mai la password', 'RISERVATO', 'Sicurezza'),
    ('account_espositore', 'attivo', 'Falso se l''account è disattivato', 'INTERNO', 'Sicurezza'),
    ('account_espositore', 'creato_il', 'Orario di attivazione', 'INTERNO', 'Sicurezza'),
    ('account_espositore', 'ultimo_accesso', 'Orario dell''ultimo accesso', 'INTERNO', 'Sicurezza'),
    ('invito_espositore', 'token_hash', 'Impronta del token dell''invito, il token in chiaro non si conserva', 'RISERVATO', 'Sicurezza'),
    ('invito_espositore', 'id_espositore', 'Espositore invitato', 'INTERNO', 'Sicurezza'),
    ('invito_espositore', 'email', 'Email a cui è stato inviato l''invito', 'PERSONALE', 'Sicurezza'),
    ('invito_espositore', 'scade_il', 'Scadenza dell''invito', 'INTERNO', 'Sicurezza'),
    ('invito_espositore', 'usato_il', 'Quando l''invito è stato usato, vuoto se ancora valido', 'INTERNO', 'Sicurezza'),
    ('avviso', 'id_avviso', 'Identificativo dell''avviso', 'INTERNO', 'Organizzazione'),
    ('avviso', 'titolo', 'Titolo dell''avviso', 'PUBBLICO', 'Organizzazione'),
    ('avviso', 'testo', 'Testo dell''avviso', 'PUBBLICO', 'Organizzazione'),
    ('avviso', 'pubblico', 'A chi è rivolto: VISITATORI, ESPOSITORI oppure STAFF', 'INTERNO', 'Organizzazione'),
    ('avviso', 'pubblicato_il', 'Orario di pubblicazione', 'INTERNO', 'Organizzazione'),
    ('avviso', 'attivo', 'Falso se l''avviso è stato disattivato', 'INTERNO', 'Organizzazione'),
    ('lotto_kpi', 'batch_id', 'Identificativo stabile del lotto, rende ripetibile l''invio', 'INTERNO', 'Data Engineering'),
    ('lotto_kpi', 'anno', 'Edizione dei KPI', 'INTERNO', 'Data Engineering'),
    ('lotto_kpi', 'calcolato_il', 'Quando BAD ha calcolato i KPI', 'INTERNO', 'Data Engineering'),
    ('lotto_kpi', 'formula_versione', 'Versione delle formule usate', 'INTERNO', 'Data Engineering'),
    ('lotto_kpi', 'intervallo_dati_dal', 'Inizio dei dati usati nel calcolo', 'INTERNO', 'Data Engineering'),
    ('lotto_kpi', 'intervallo_dati_al', 'Fine dei dati usati nel calcolo', 'INTERNO', 'Data Engineering'),
    ('lotto_kpi', 'ricevuto_il', 'Quando il lotto è stato ricevuto', 'INTERNO', 'Data Engineering'),
    ('kpi_osservazione', 'id_osservazione', 'Numero progressivo', 'INTERNO', 'Data Engineering'),
    ('kpi_osservazione', 'batch_id', 'Lotto di appartenenza', 'INTERNO', 'Data Engineering'),
    ('kpi_osservazione', 'codice', 'Codice dell''indicatore, per esempio picco_presenza', 'INTERNO', 'Data Engineering'),
    ('kpi_osservazione', 'valore', 'Valore calcolato', 'INTERNO', 'Data Engineering'),
    ('kpi_osservazione', 'unita', 'Unità di misura, per esempio persone o euro', 'INTERNO', 'Data Engineering'),
    ('kpi_osservazione', 'periodo_dal', 'Inizio del periodo misurato', 'INTERNO', 'Data Engineering'),
    ('kpi_osservazione', 'periodo_al', 'Fine del periodo misurato', 'INTERNO', 'Data Engineering'),
    ('kpi_osservazione', 'dimensioni', 'Filtri come padiglione, stand o categoria, mai dati personali', 'INTERNO', 'Data Engineering'),
    ('kpi_osservazione', 'fonte', 'Tabelle o sistemi da cui nasce il valore', 'INTERNO', 'Data Engineering'),
    ('kpi_osservazione', 'qualita', 'OK, ATTENZIONE oppure DA_VERIFICARE', 'INTERNO', 'Data Engineering'),
    ('kpi_osservazione', 'flag_qualita', 'Anomalie che riguardano il valore', 'INTERNO', 'Data Engineering'),
    ('kpi_osservazione', 'stimato', 'Vero se il valore è una stima e non un conteggio', 'INTERNO', 'Data Engineering'),
    ('kpi_osservazione', 'simulato', 'Vero se i dati di partenza sono simulati', 'INTERNO', 'Data Engineering'),
    ('kpi_osservazione', 'nota', 'Nota esplicativa facoltativa', 'INTERNO', 'Data Engineering')
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
