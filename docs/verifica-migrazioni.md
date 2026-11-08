# Verifica della catena delle migrazioni, 8 novembre sera

Applicate `V001`–`V026` su un PostgreSQL 16 vuoto, come fa Docker alla prima accensione.

## Esito prima delle correzioni: la catena si rompeva

Due errori bloccanti su un database pulito.

**La `V025` falliva.** Il controllo di completezza del dizionario trovava 29 colonne senza descrizione, su cinque tabelle:

- `turno` e `assegnazione_turno` e `membro_staff_riservato`, create dalla `V024`: le righe del dizionario erano state tolte e il controllo in fondo alla `V024` commentato;
- `auth_login_rate_limit` e `audit_event`, create dalla `V015`, che non ha mai inserito le proprie righe.

**La `V026` falliva.** `GRANT ... TO arcade_backend` su un ruolo che nessuna migrazione crea.

Siccome PostgreSQL interrompe l'inizializzazione al primo errore, una installazione da zero si fermava alla `V025`, e la `V026` non partiva affatto.

### Perché la CI era verde lo stesso

Quando uno script di inizializzazione fallisce, il contenitore esce, ma la cartella dei dati è già stata creata. Al riavvio PostgreSQL la trova non vuota, salta l'inizializzazione e parte regolarmente, con lo schema a metà. L'API si collega, il controllo di salute risponde, e la CI diventa verde su un database incompleto.

È il motivo per cui il controllo Compose non basta: va affiancato da un passo che applichi le migrazioni e si fermi davvero al primo errore.

## Correzioni

| File | Cosa è stato fatto |
| --- | --- |
| `V015` | Aggiunte le righe del dizionario per `auth_login_rate_limit` e `audit_event`, le due tabelle che crea |
| `V024` | Rimesse le 18 righe del dizionario per `membro_staff_riservato`, `turno` e `assegnazione_turno`, e riattivato il controllo di completezza |
| `V026` | Il ruolo `arcade_backend` viene creato se manca, invece di far fallire la migrazione |

Dopo le correzioni le ventisei migrazioni si applicano in ordine senza errori: 59 tabelle, 351 colonne descritte. Riprovati anche i turni: la stessa persona su due turni sovrapposti viene ancora rifiutata.

## Una cosa buona, da dire alla SAL

La `V015` di Farid chiude il buco che avevo segnalato stamattina. La regola di visibilità dei contatti ora è questa:

```
id_espositore = <espositore corrente>
AND consenso_espositori
AND consenso_marketing = 'SI'
AND utilizzabile_marketing
AND fascia_eta IN ('18-24','25-34','35-44','45+')
AND motivo_esclusione = 'NESSUNO'
AND (anno < 2026 OR id_lead_magnet IS NOT NULL)
```

Oltre a questo, la `V015` crea i ruoli con cui l'applicazione dovrebbe girare al posto del proprietario del database, e aggiunge il registro degli accessi ai dati personali. Resta da verificare che il codice Java si colleghi davvero con quei ruoli e imposti `arcade.id_espositore` a ogni richiesta: finché non lo fa, le regole restano scritte ma non applicate.

## Cosa resta da decidere

- La superficie degli stand sta sia in `stand` sia in `planimetria_stand`. Le proiezioni per BAD usano `coalesce(planimetria, stand)`, mentre `v_ricavo_per_mq` usa ancora solo `stand`: due indicatori sulla stessa cosa possono dare numeri diversi.
- `recupero_password` ammette più token validi per lo stesso account.
