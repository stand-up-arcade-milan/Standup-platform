# Specifiche delle schermate

Schede funzionali per le schermate dell'MVP ARCADE Milano 2026. Sono basate su [requisiti MVP](../requisiti-mvp.md), [blueprint](../blueprint-digitale.md), [requisiti frontend](../frontend-portale.md) e [contratto API](../openapi.yaml).

Le schermate descritte non sono ancora implementate: i nomi servono a riconoscere le viste, non fissano gli URL frontend. Le API citate sono quelle della bozza OpenAPI e non implicano che siano già implementate. Se manca un endpoint necessario, la scheda lo segnala per l'allineamento BID–BAD.

## Schermate

| Area | Schermata | Utenti | Client |
| --- | --- | --- | --- |
| Pubblico | [Home portale](home-portale.md) | Visitatori, espositori | React |
| Pubblico | [Registrazione visitatore](registrazione-visitatore.md) | Visitatori | React |
| Pubblico | [Richiesta stand](richiesta-stand.md) | Potenziali espositori | React |
| Accesso | [Login espositore](login-espositore.md) | Espositori | React |
| Accesso | [Accettazione invito](accettazione-invito.md) | Espositori invitati | React |
| Accesso | [Recupero password](recupero-password.md) | Espositori | React |
| Pubblico | [Elenco espositori](elenco-espositori.md) | Visitatori, staff | React |
| Pubblico | [Scheda espositore pubblica](scheda-espositore.md) | Visitatori, staff | React |
| Pubblico | [Mappa interattiva](mappa-interattiva.md) | Visitatori, staff; calore per Direzione | React; Power BI per la vista direzionale |
| Espositore | [Area espositore](area-espositore.md) | Espositore | React |
| Espositore | [Contatti e lead](contatti-espositore.md) | Espositore | React |
| Staff | [Operatività evento](operativita-staff.md) | Staff | React |
| Staff | [Scansione allo stand](scansione-stand.md) | Staff, espositore autorizzato | Web mobile React o Power Apps, da validare |
| Staff | [Verifica biglietti e accessi](verifica-accessi.md) | Staff autorizzato | Client operativo da definire |
| Commerciale | [Back office commerciale](backoffice-commerciale.md) | Commerciale | Power Apps |
| Commerciale | [Scheda pratica](scheda-pratica.md) | Commerciale | Power Apps |
| Commerciale | [Listino e planimetria stand](listino-stand.md) | Commerciale | Power Apps |
| Direzione | [Cruscotto direzionale](cruscotto-direzione.md) | Direzione | Power BI |
| Direzione | [Report](report.md) | Direzione, ruoli autorizzati | Power BI |
| Amministrazione | [Configurazione e avvisi](amministrazione.md) | Amministratore | Client da definire |

## Regole comuni

- Edizione, date e sede si leggono dai dati dell'edizione, non si duplicano nei client.
- Ruoli e perimetro dei dati sono verificati dall'API. Nascondere un pulsante non sostituisce l'autorizzazione lato server.
- Ogni pagina deve gestire caricamento, assenza di dati, errore e accesso negato; le azioni di scrittura devono confermare esito o conflitto.
- Il portale è responsive, utilizzabile da tastiera, con link “Vai al contenuto” e contrasto minimo 4,5:1.
- I KPI sono ricevuti da BAD tramite il contratto concordato; BID li valida, conserva e serve ai client. Le interfacce non ricalcolano formule.
- Le voci segnate **da concordare** non sono requisiti già approvati.
