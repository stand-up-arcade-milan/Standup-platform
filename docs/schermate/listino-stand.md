# Listino e planimetria stand

**Utenti:** Commerciale · **Client:** React (`/commerciale`) · **Priorità:** requisito MVP RF-10.

## Contenuto e azioni

- Planimetria per padiglione con stand liberi, assegnati o non disponibili.
- Elenco con codice, posizione, superficie, stato e prezzo di listino.
- Filtro per edizione/padiglione/stato e apertura della pratica per associare uno stand libero.
- Caricare gli stand con `GET /stand?edizione=&padiglione=&stato=`; lo schema include superficie e prezzo listino, che può essere nullo.

## Stati e regole

- Evidenziare prezzo/superficie simulati finché il cliente non fornisce i valori definitivi.
- Non offrire stand `ASSEGNATO` o `NON_DISPONIBILE`; la verifica finale è comunque atomica lato API/database.
- Gestire stand senza coordinate in planimetria come riga consultabile, non inventare una posizione grafica.
- Il contratto espone i dati stand ma non un endpoint CRUD per modificare il listino o la planimetria; gli aggiornamenti e il proprietario del dato vanno concordati.
