# Scansione allo stand

**Utenti:** staff o espositore autorizzato · **Client:** web mobile React o Power Apps, scelta ancora da validare · **Priorità:** RF-22.

## Contenuto e azioni

- Selettore/contesto dello stand, fotocamera o lettore QR e feedback immediato.
- Esito della scansione, orario e conteggio aggiornato; non visualizzare nome/email del visitatore.
- Se previsto, selezione del lead magnet promosso dallo stand prima della scansione.
- Inviare la lettura a `POST /scansioni`; il contratto prevede `201` per una nuova lettura e `200` per un duplicato riconosciuto.

## Stati e sicurezza

- Gestire permesso fotocamera negato, QR illeggibile/non valido, duplicato, perdita rete e invio in corso.
- Il requisito stabilisce che una seconda scansione dello stesso codice allo stesso stand non raddoppi il conteggio.
- L'accesso è per operatori autorizzati. La verifica del ruolo/stand avviene sul server; nessun dato personale viene mostrato o scritto nei log client.
- Uso dei sensori AI reali solo dopo la DPIA; questa schermata non riceve immagini dal sensore AI.
