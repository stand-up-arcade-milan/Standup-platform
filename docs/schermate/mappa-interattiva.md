# Mappa interattiva

**Utenti:** visitatori e staff; la vista di calore direzionale è in Power BI · **Client:** React / Power BI · **Priorità:** RF-29 facoltativo.

## Contenuto

- Planimetria per padiglione con stand, varchi, legenda e stato dei dati.
- Ricerca espositore, evidenziazione del suo stand e indicazione del varco più vicino quando la planimetria lo consente.
- Aree affollate tramite indicatori aggregati, solo quando l'opzione è disponibile e la fonte è aggiornata.

## Azioni e API

- Caricare `GET /mappa?edizione=&includiAffollamento=` e, se necessario, `GET /espositori?q=`.
- Selezionare padiglione/stand, aprire una scheda espositore e azzerare la ricerca.
- Il percorso è una guida visuale fino allo stand, non navigazione turn-by-turn.

## Stati e limiti

- Distinguere dato non disponibile, area senza conteggi e area con conteggio pari a zero.
- Non esporre coordinate personali o tracce individuali. L'affollamento è aggregato.
- La mappa di calore per stand e padiglioni è una vista direzionale/report, con fonte e aggiornamento; non va mostrata come dato live se il contratto non lo garantisce.
