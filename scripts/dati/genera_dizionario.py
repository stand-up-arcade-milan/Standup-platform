# Genera V005 (dizionario nel database) e docs/dizionario-dati.md da una sola definizione.
import json,sys
# livelli: PUBBLICO, INTERNO, RISERVATO (quasi-identificatori, solo aggregati o proprietario), PERSONALE (identifica la persona)
T = {
 'edizione': ('Organizzazione','Calendario delle edizioni della fiera','INTERNO',[
   ('anno','Anno dell\'edizione, chiave'),('inizio_vendite','Primo giorno di vendita dei biglietti'),
   ('inizio_fiera','Primo giorno di fiera'),('fine_fiera','Ultimo giorno di fiera')]),
 'categoria_biglietto': ('Biglietteria','Tipi di biglietto uniformati tra 2024 e 2025','INTERNO',[
   ('codice','Codice della categoria'),('descrizione','Nome leggibile'),('persone_incluse','Persone che entrano con un biglietto, 4 per il Family')]),
 'canale_vendita': ('Biglietteria','Canali di vendita','INTERNO',[('codice','Codice del canale'),('descrizione','Nome leggibile')]),
 'padiglione': ('Organizzazione','Padiglioni della fiera','PUBBLICO',[('codice','Codice del padiglione')]),
 'varco': ('Controllo accessi','Varchi con tornello','INTERNO',[('codice','Codice del varco'),('padiglione','Padiglione servito dal varco')]),
 'stand': ('Organizzazione','Stand della fiera','INTERNO',[
   ('codice','Codice dello stand, per esempio P1-A02'),('padiglione','Padiglione dello stand'),('superficie_mq','Superficie in metri quadri, da ricevere dal cliente')]),
 'espositore': ('Organizzazione','Espositori, anonimi nei dati ricevuti','INTERNO',[
   ('id_espositore','Codice dell\'espositore'),('ragione_sociale','Ragione sociale, non presente nei dati ricevuti')]),
 'assegnazione_stand': ('Organizzazione','Quale espositore occupa quale stand in ogni edizione','INTERNO',[
   ('anno','Edizione'),('codice_stand','Stand assegnato'),('id_espositore','Espositore che lo occupa')]),
 'ordine': ('Biglietteria','Ordini di vendita, raggruppano più biglietti','INTERNO',[
   ('id_ordine','Codice dell\'ordine'),('anno','Edizione'),('canale','Canale di vendita dell\'ordine')]),
 'biglietto': ('Biglietteria','Un biglietto venduto, senza nome né contatto del titolare','INTERNO',[
   ('codice','Codice del biglietto, letto ai varchi'),('id_evento','Chiave della riga nel registro unico, per ripetere il caricamento'),
   ('id_ordine','Ordine di appartenenza'),('anno','Edizione'),('categoria','Categoria del biglietto'),
   ('giorno_valido','Giorno di validità, vuoto se valido tutti i giorni'),('registrato_il','Orario di registrazione della vendita, ora italiana'),
   ('fascia_eta','Fascia d\'età del titolare, quasi-identificatore','RISERVATO'),('minore','Titolare minorenne, tutela minori','RISERVATO'),
   ('provincia','Provincia di residenza, quasi-identificatore','RISERVATO'),('codice_sconto','Codice sconto usato'),
   ('quantita','Persone coperte dal biglietto'),('importo_eur','Importo pagato in euro'),('flag_qualita','Anomalie rilevate sulla riga, vuoto se nessuna')]),
 'accesso': ('Controllo accessi','Passaggi ai tornelli, ingressi e rifiuti','INTERNO',[
   ('id_evento','Chiave della riga nel registro unico'),('anno','Edizione'),('varco','Varco del passaggio'),('letto_il','Orario della lettura, ora italiana'),
   ('codice_biglietto','Codice letto, senza vincolo perché 70 codici non esistono in biglietteria'),('esito','INGRESSO oppure INGRESSO_RIFIUTATO'),
   ('persone','Persone entrate, 0 per i rifiuti'),('flag_qualita','Anomalie rilevate sulla riga')]),
 'visita_stand_ora': ('Espositore','Scansioni orarie di uno stand, aggregate, nessun visitatore identificabile','RISERVATO',[
   ('id_riferimento','Codice della rilevazione oraria'),('id_evento','Chiave della riga nel registro unico'),('anno','Edizione'),
   ('codice_stand','Stand'),('ora_inizio','Inizio dell\'ora, ora italiana'),('scansioni','Scansioni nell\'ora'),('flag_qualita','Anomalie rilevate sulla riga')]),
 'fascia_stand_mancante': ('Espositore','Ore senza rilevazione, scanner spento o dato perso','INTERNO',[
   ('codice_stand','Stand'),('ora_inizio','Ora mancante, ora italiana')]),
 'contatto_stand': ('Espositore','Contatti raccolti dallo stand, senza email','RISERVATO',[
   ('id_contatto','Codice del contatto'),('id_evento','Chiave della riga nel registro unico'),('anno','Edizione'),('codice_stand','Stand che ha raccolto il contatto'),
   ('id_espositore','Espositore proprietario del contatto, base del filtro per espositore'),('raccolto_il','Orario di raccolta, ora italiana'),
   ('fascia_eta','Fascia d\'età dichiarata, quasi-identificatore'),('provincia','Provincia dichiarata, quasi-identificatore'),
   ('interesse','Interesse espresso dal visitatore'),('consenso_marketing','Consenso al marketing dato dal visitatore'),
   ('utilizzabile_marketing','Vero se il contatto si può usare per il marketing'),('motivo_esclusione','Perché non è utilizzabile, per esempio minore di 14-17 anni'),
   ('email_su_piu_stand','Stessa email lasciata a più stand'),('flag_qualita','Anomalie rilevate sulla riga')]),
 'contatto_riservato': ('Responsabile dati','Email dei contatti, unico dato personale diretto','PERSONALE',[
   ('id_contatto','Contatto a cui appartiene l\'email'),('email','Indirizzo email del visitatore','PERSONALE')]),
 'importazione': ('Data Engineering','Registro delle importazioni','INTERNO',[
   ('id_importazione','Numero dell\'importazione'),('file','File importato'),('iniziata_il','Inizio'),('terminata_il','Fine'),
   ('righe_lette','Righe lette dal file'),('righe_caricate','Righe caricate nelle tabelle'),('righe_scartate','Righe scartate in pulizia')]),
 'scarto_importazione': ('Data Engineering','Righe rimosse in pulizia, con il motivo','INTERNO',[
   ('id','Numero progressivo'),('id_importazione','Importazione che ha registrato lo scarto'),('fonte','Fonte della riga'),
   ('motivo','Motivo dello scarto'),('riga_originale','Riga come ricevuta')]),
 'catalogo_anomalia': ('Data Engineering','Anomalie trovate in pulizia e come sono gestite','INTERNO',[
   ('fonte','Fonte dei dati'),('codice','Codice dell\'anomalia'),('descrizione','Descrizione'),('righe_coinvolte','Righe coinvolte'),('gestione','Come è stata gestita')]),
 'parametri_stima': ('Data Engineering','Parametri della stima delle presenze','INTERNO',[
   ('anno','Edizione'),('ore_permanenza','Ore di permanenza per stimare le presenze dagli ingressi'),('peso_medio_kg','Peso medio di una persona'),
   ('soglia_rumore_kg','Variazione di peso da ignorare come rumore'),('persone_per_mq','Capienza di persone per metro quadro')]),
 'rilevazione_peso': ('Controllo accessi','Rilevazioni di peso dello stand, simulate nella demo','INTERNO',[
   ('id','Numero progressivo'),('anno','Edizione'),('codice_stand','Stand'),('rilevato_il','Orario della lettura'),
   ('peso_lordo_kg','Peso totale letto'),('tara_kg','Peso a vuoto'),('fonte','SIMULATA o SENSORE')]),
}
rows=[]
for t,(own,desc,lvl,cols) in T.items():
    for c in cols:
        rows.append((t,c[0],c[1],c[2] if len(c)>2 else lvl,own,desc))
q=lambda s:"'"+s.replace("'","''")+"'"
sql=["-- V005: dizionario dati. Ogni colonna ha descrizione, livello di sensibilità e titolare.",
"-- Livelli: PUBBLICO, INTERNO, RISERVATO (quasi-identificatori, solo aggregati o solo il proprietario), PERSONALE (identifica la persona).",
"-- Generato da scripts/dati/genera_dizionario.py: non modificare a mano.",
"SET search_path TO arcade;","",
"CREATE TABLE dizionario_dati (",
"    tabella       text NOT NULL,","    colonna       text NOT NULL,","    tipo          text NOT NULL,",
"    descrizione   text NOT NULL,","    sensibilita   text NOT NULL CHECK (sensibilita IN ('PUBBLICO','INTERNO','RISERVATO','PERSONALE')),",
"    titolare      text NOT NULL,","    PRIMARY KEY (tabella, colonna)",");","",
"INSERT INTO dizionario_dati (tabella, colonna, tipo, descrizione, sensibilita, titolare)",
"SELECT d.tabella, d.colonna, format_type(a.atttypid, a.atttypmod), d.descrizione, d.sensibilita, d.titolare",
"FROM (VALUES"]
sql.append(",\n".join(f"    ({q(t)}, {q(c)}, {q(d)}, {q(s)}, {q(o)})" for t,c,d,s,o,_ in rows))
sql+=[") AS d (tabella, colonna, descrizione, sensibilita, titolare)",
"JOIN pg_attribute a ON a.attrelid = ('arcade.' || d.tabella)::regclass AND a.attname = d.colonna;","",
"-- Controllo: ogni colonna delle tabelle deve avere una riga nel dizionario",
"DO $$",
"DECLARE mancanti text;",
"BEGIN",
"    SELECT string_agg(c.table_name || '.' || c.column_name, ', ') INTO mancanti",
"    FROM information_schema.columns c",
"    JOIN information_schema.tables t USING (table_schema, table_name)",
"    WHERE c.table_schema = 'arcade' AND t.table_type = 'BASE TABLE' AND c.table_name <> 'dizionario_dati'",
"      AND NOT EXISTS (SELECT 1 FROM dizionario_dati d WHERE d.tabella = c.table_name AND d.colonna = c.column_name);",
"    IF mancanti IS NOT NULL THEN RAISE EXCEPTION 'Colonne senza descrizione nel dizionario: %', mancanti; END IF;",
"END $$;",""]
open('database/migrations/V005__dizionario_dati.sql','w',encoding='utf-8').write("\n".join(sql))
md=["# Dizionario dati","",
"Descrive ogni colonna del database: significato, livello di sensibilità e titolare. È generato da `scripts/dati/genera_dizionario.py` e vive anche nel database, nella tabella `arcade.dizionario_dati`.","",
"| Livello | Significato | Chi può vederlo |","|---|---|---|",
"| PUBBLICO | Può comparire sul portale | Tutti |",
"| INTERNO | Dato operativo senza persone identificabili | Organizzazione e team |",
"| RISERVATO | Quasi-identificatore o dato di uno solo | Proprietario, oppure solo aggregato |",
"| PERSONALE | Identifica una persona | Solo il responsabile dei dati |",""]
for t,(own,desc,lvl,cols) in T.items():
    md+=[f"## {t}","",f"{desc}. Titolare: {own}. Livello della tabella: {lvl}.","","| Colonna | Descrizione | Livello |","|---|---|---|"]
    md+=[f"| `{c[0]}` | {c[1]} | {c[2] if len(c)>2 else lvl} |" for c in cols]
    md.append("")
open('docs/dizionario-dati.md','w',encoding='utf-8').write("\n".join(md))
print(len(rows),"colonne")
