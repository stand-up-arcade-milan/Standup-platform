import assert from 'node:assert/strict'
import { createHmac, randomUUID } from 'node:crypto'
import { readFile } from 'node:fs/promises'

const baseUrl = new URL(process.env.API_BASE_URL ?? 'http://localhost:8080/api/v1')
if (!['localhost', '127.0.0.1', '::1'].includes(baseUrl.hostname)) {
  throw new Error(`La suite rifiuta endpoint non locali: ${baseUrl.origin}`)
}
const secret = process.env.ARCADE_JWT_SECRET ?? 'local-development-secret-change-me-32-bytes'
const issuedOperations = new Set()
let requestIndex = 0

function b64url(value) {
  return Buffer.from(value).toString('base64url')
}

function token(role, exhibitorId) {
  const now = Math.floor(Date.now() / 1000)
  const header = b64url(JSON.stringify({ alg: 'HS256', typ: 'JWT' }))
  const payload = b64url(JSON.stringify({ sub: `ci-${role.toLowerCase()}`, role, iat: now, exp: now + 3600, ...(exhibitorId ? { idEspositore: exhibitorId } : {}) }))
  const content = `${header}.${payload}`
  return `${content}.${createHmac('sha256', secret).update(content).digest('base64url')}`
}

const tokens = {
  COMMERCIALE: token('COMMERCIALE'),
  STAFF: token('STAFF'),
  AMMINISTRATORE: token('AMMINISTRATORE'),
  DEVICE: token('DEVICE'),
  BAD: token('BAD'),
  EXHIBITOR: token('ESPOSITORE', 'CI-EXHIBITOR-01'),
  OTHER_EXHIBITOR: token('ESPOSITORE', 'CI-EXHIBITOR-02'),
  DIREZIONE: token('DIREZIONE'),
}

async function call(operationId, method, path, role, body, expectedStatus) {
  issuedOperations.add(operationId)
  requestIndex += 1
  const headers = new Headers()
  if (role) headers.set('Authorization', `Bearer ${tokens[role]}`)
  if (body !== undefined) headers.set('Content-Type', 'application/json')
  const response = await fetch(new URL(path.replace(/^\//, ''), `${baseUrl.toString().replace(/\/$/, '')}/`), {
    method,
    headers,
    ...(body !== undefined ? { body: JSON.stringify(body) } : {}),
  })
  const contentType = response.headers.get('content-type') ?? ''
  const raw = contentType.includes('application/pdf') ? Buffer.from(await response.arrayBuffer()) : await response.text()
  let json = null
  if (typeof raw === 'string' && raw.length) {
    try { json = JSON.parse(raw) } catch { /* A status assertion below reports unexpected text. */ }
  }
  const accepted = expectedStatus === undefined ? [] : (Array.isArray(expectedStatus) ? expectedStatus : [expectedStatus])
  // Un 5xx atteso e un esito previsto, per esempio il 503 di un fornitore di identita
  // non configurato su questo ambiente. Un 5xx non atteso resta un errore della suite.
  if (response.status >= 500 && !accepted.includes(response.status)) {
    throw new Error(`${operationId}: HTTP ${response.status} ${JSON.stringify(json ?? raw)}`)
  }
  if (expectedStatus !== undefined) {
    assert.ok(accepted.includes(response.status), `${operationId}: atteso HTTP ${accepted.join('/')} ricevuto ${response.status}: ${JSON.stringify(json ?? raw)}`)
  }
  if (json?.code === 'ROTTA_NON_TROVATA') throw new Error(`${operationId}: il controller non riconosce ${method} ${path}`)
  console.log(`${String(requestIndex).padStart(2, '0')} ${operationId}: ${response.status}`)
  return { response, body: json, raw }
}

function expect(condition, message) {
  assert.ok(condition, message)
}

function pdfDocument(result, label) {
  expect(result.response.headers.get('content-type')?.includes('application/pdf'), `${label}: Content-Type non PDF`)
  expect(result.response.headers.get('content-disposition')?.startsWith('attachment;'), `${label}: manca Content-Disposition`)
  expect(result.response.headers.get('cache-control') === 'private, no-store', `${label}: Cache-Control non privato`)
  expect(result.response.headers.get('x-content-type-options') === 'nosniff', `${label}: manca nosniff`)
  expect(Buffer.isBuffer(result.raw) && result.raw.subarray(0, 5).toString() === '%PDF-', `${label}: contenuto non PDF`)
  const etag = result.response.headers.get('etag')
  expect(etag && /^"[a-f0-9]{64}"$/.test(etag), `${label}: ETag SHA-256 non valido`)
}

const suffix = randomUUID()
const now = new Date().toISOString()
const secondAgo = new Date(Date.now() - 30_000).toISOString()
const minute = new Date()
minute.setSeconds(0, 0)
const minuteIso = minute.toISOString()

// Base routes and safe public portal entry points.
await call('getSystemHealth', 'GET', '/health', null, undefined, 200)
await call('listEdizioni', 'GET', '/edizioni?attiva=true', null, undefined, 200)
await call('listPadiglioni', 'GET', '/padiglioni?edizione=2026', null, undefined, 200)
await call('listStand', 'GET', '/stand?edizione=2026&limit=50', 'COMMERCIALE', undefined, 200)
await call('listListino', 'GET', '/listino?edizione=2026', 'COMMERCIALE', undefined, 200)
await call('getMappa', 'GET', '/mappa?edizione=2026', null, undefined, 200)
const exhibitors = await call('listEspositori', 'GET', '/espositori?limit=50', null, undefined, 200)
await call('listCategorieEspositori', 'GET', '/espositori/categorie', null, undefined, 200)
const publicExhibitor = await call('getEspositorePubblico', 'GET', '/espositori/CI-EXHIBITOR-01', null, undefined, 200)
expect(!JSON.stringify(publicExhibitor.body).toLowerCase().includes('partitaiva'), 'profilo pubblico espone dati fiscali')

// Public requests and visitor consent updates.
await call('createRichiestaEspositore', 'POST', '/richieste/espositore', null, {
  azienda: `Richiesta CI ${suffix}`, referente: 'Persona sintetica', email: `request-${suffix}@example.invalid`,
  categoria: 'Videogiochi', metriQuadriDesiderati: 18, consensoPrivacy: true,
}, 201)
await call('createRichiestaVisitatore', 'POST', '/richieste/visitatore', null, {
  email: `visitor-request-${suffix}@example.invalid`, consensoMarketing: false,
}, 201)
const registration = await call('createRegistrazioneVisitatore', 'POST', '/visitatori/registrazioni', null, {
  email: `registration-${suffix}@example.invalid`, fasciaEta: '25-34', consensoMarketing: true, consensoEspositori: false,
}, 201)
expect(registration.body?.tokenRevoca && registration.body?.id, 'registrazione: manca token di revoca o identificativo')
const consent = await call('updateConsensiVisitatore', 'PATCH', `/visitatori/registrazioni/${registration.body.id}/consensi`, null, {
  tokenRevoca: registration.body.tokenRevoca, consensoMarketing: false,
}, 200)
expect(consent.body?.profilabile === false, 'revoca marketing: il profilo deve cessare di essere profilabile')

// Public account routes return generic outcomes and never disclose account existence.
await call('loginEspositore', 'POST', '/auth/login', null, { email: `missing-${suffix}@example.invalid`, password: 'incorrect-password-for-ci' }, 401)
const rateLimitEmail = `rate-limit-${suffix}@example.invalid`
for (let attempt = 0; attempt < 5; attempt += 1) {
  await call('loginEspositore', 'POST', '/auth/login', null, { email: rateLimitEmail, password: 'incorrect-password-for-ci' }, 401)
}
const rateLimitedLogin = await call('loginEspositore', 'POST', '/auth/login', null, { email: rateLimitEmail, password: 'incorrect-password-for-ci' }, 429)
expect(rateLimitedLogin.body?.code === 'TROPPI_TENTATIVI', 'login: il blocco non usa il codice di errore previsto')
// Accesso con un fornitore esterno. Un token inventato non deve mai diventare un accesso:
// 401 se il fornitore e configurato su questo ambiente, 503 se non lo e. Un 200 qui
// significherebbe che il server si fida di cio che gli manda il client.
for (const [operationId, path] of [['loginConGoogle', '/auth/google'], ['loginConMicrosoft', '/auth/microsoft']]) {
  const esito = await call(operationId, 'POST', path, null, { token: `token-inventato-${suffix}` }, [401, 503])
  assert.ok(
    ['TOKEN_ESTERNO_NON_VALIDO', 'ACCESSO_ESTERNO_NON_CONFIGURATO'].includes(esito.body?.code),
    `${operationId}: codice di errore inatteso ${esito.body?.code}`,
  )
  assert.equal(esito.body?.accessToken, undefined, `${operationId}: un token non verificato non deve produrre un accesso`)
}

await call('acceptInvitoEspositore', 'POST', '/auth/invito/accetta', null, { token: `missing-${suffix}`, password: 'Valid-password-for-CI-2026' }, 404)
await call('requestPasswordRecovery', 'POST', '/auth/password/recupero', null, { email: `missing-${suffix}@example.invalid` }, 202)
await call('resetPassword', 'POST', '/auth/password/reimposta', null, { token: `missing-${suffix}`, password: 'Valid-password-for-CI-2026' }, 409)

// Commercial lifecycle: create, revise, generate/archive/download, sign, reconcile payment, renew.
await call('listRichiesteCommerciali', 'GET', '/richieste?limit=50', 'COMMERCIALE', undefined, 200)
await call('listPratiche', 'GET', '/pratiche?edizione=2026&limit=50', 'COMMERCIALE', undefined, 200)
const createdPractice = await call('createPratica', 'POST', '/pratiche', 'COMMERCIALE', {
  edizione: 2026, idEspositore: 'CI-EXHIBITOR-01', codiceStand: 'CI-STAND-01', pacchetto: 'PREMIUM',
  voci: [{ codiceVoce: 'SPAZIO-CI', quantita: 18 }],
}, 201)
const practiceId = createdPractice.body.id
expect(practiceId, 'pratica: manca id')
await call('getPratica', 'GET', `/pratiche/${practiceId}`, 'COMMERCIALE', undefined, 200)
await call('updatePratica', 'PATCH', `/pratiche/${practiceId}`, 'COMMERCIALE', { scontoPercentuale: 4 }, 200)
const offer = await call('generateOfferta', 'POST', `/pratiche/${practiceId}/offerta`, 'COMMERCIALE', {
  scontoPercentuale: 4, note: 'Proposta sintetica per la verifica integrata.',
}, 201)
expect(offer.body?.mimeType === 'application/pdf' && offer.body?.sha256?.length === 64 && offer.body?.downloadUrl, 'offerta: metadati archivio incompleti')
const docsAfterOffer = await call('listDocumentiPratica', 'GET', `/pratiche/${practiceId}/documenti`, 'COMMERCIALE', undefined, 200)
expect(docsAfterOffer.body?.items?.length === 1, 'offerta: il documento non compare nell’archivio')
const offerId = docsAfterOffer.body.items[0].id
const offerPdf = await call('downloadDocumentoPratica', 'GET', `/pratiche/${practiceId}/documenti/${offerId}/download`, 'COMMERCIALE', undefined, 200)
pdfDocument(offerPdf, 'offerta')
await call('updateStatoPratica', 'PATCH', `/pratiche/${practiceId}/stato`, 'COMMERCIALE', { stato: 'INVIATA' }, 200)
const signed = await call('updateStatoPratica', 'PATCH', `/pratiche/${practiceId}/stato`, 'COMMERCIALE', { stato: 'FIRMATA' }, 200)
expect(signed.body?.stato === 'FIRMATA', 'pratica: stato firmato non registrato')
const docsAfterSign = await call('listDocumentiPratica', 'GET', `/pratiche/${practiceId}/documenti`, 'COMMERCIALE', undefined, 200)
expect(docsAfterSign.body?.items?.length === 2, 'firma: riepilogo informativo non archiviato automaticamente')
const signedSummary = docsAfterSign.body.items.find((document) => document.tipo === 'ALTRO')
expect(signedSummary?.downloadUrl, 'firma: manca il riepilogo informativo scaricabile')
const summaryPdf = await call('downloadDocumentoPratica', 'GET', signedSummary.downloadUrl.replace('/api/v1', ''), 'COMMERCIALE', undefined, 200)
pdfDocument(summaryPdf, 'riepilogo firmato')
await call('addAcconto', 'POST', `/pratiche/${practiceId}/acconti`, 'COMMERCIALE', {
  importoEur: 200, ricevutoIl: now, riferimento: `CI-${suffix}`,
}, 201)
await call('createRinnovo', 'POST', `/pratiche/${practiceId}/rinnovo`, 'COMMERCIALE', {}, 201)

// Access + stand scanner: a consented adult lead is shared, a duplicate is not counted,
// and a scan without consent does not create a visitor contact.
const access = await call('createAccesso', 'POST', '/accessi', 'DEVICE', {
  eventId: `CI-ACCESS-${suffix}`, edizione: 2026, varco: 'P1-NORD', lettoIl: now, codiceBiglietto: 'CI-TICKET-01',
}, 201)
expect(access.body?.esito === 'INGRESSO' && access.body?.persone === 1, 'accesso con biglietto valido non riconosciuto')
const validScan = await call('createScansione', 'POST', '/scansioni', 'DEVICE', {
  eventId: `CI-SCAN-OK-${suffix}`, edizione: 2026, codiceStand: 'CI-STAND-01', operatoreId: 'scanner-ci',
  rilevataIl: now, ticketRef: `CI-QR-OK-${suffix}`, email: `lead-${suffix}@example.invalid`,
  fasciaEta: '25-34', consensoMarketing: true, consensoEspositori: true, idLeadMagnet: 990001,
}, 201)
expect(validScan.body?.leadAcquisito === true && validScan.body?.duplicata === false, 'scansione idonea: MQL non acquisito')
const duplicateScan = await call('createScansione', 'POST', '/scansioni', 'DEVICE', {
  eventId: `CI-SCAN-DUP-${suffix}`, edizione: 2026, codiceStand: 'CI-STAND-01', operatoreId: 'scanner-ci',
  rilevataIl: now, ticketRef: `CI-QR-OK-${suffix}`,
}, 200)
expect(duplicateScan.body?.duplicata === true && duplicateScan.body?.leadAcquisito === false, 'scansione duplicata conteggiata o condivisa')
const noConsent = await call('createScansione', 'POST', '/scansioni', 'DEVICE', {
  eventId: `CI-SCAN-NO-CONSENT-${suffix}`, edizione: 2026, codiceStand: 'CI-STAND-01', operatoreId: 'scanner-ci',
  rilevataIl: now, ticketRef: `CI-QR-PRIVATE-${suffix}`, email: `private-${suffix}@example.invalid`,
  fasciaEta: '25-34', consensoMarketing: false, consensoEspositori: false,
}, 201)
expect(noConsent.body?.leadAcquisito === false, 'scansione senza consenso ha creato un lead')

// Simulator write routes and the exhibitor's own weight view.
await call('createConteggioPedana', 'POST', '/pedane/conteggi', 'DEVICE', {
  eventId: `CI-PEDANA-${suffix}`, edizione: 2026, padiglione: 'P1', minuto: minuteIso, entrati: 2, usciti: 0, fonte: 'SIMULATA',
}, 201)
await call('createConteggioSensoreAi', 'POST', '/sensori-ai/conteggi', 'DEVICE', {
  eventId: `CI-SENSORE-${suffix}`, edizione: 2026, codiceStand: 'CI-STAND-01', minuto: minuteIso, nuovePersoneFermate: 2, fonte: 'SIMULATA',
}, 201)
await call('createRilevazionePeso', 'POST', '/rilevazioni/peso', 'DEVICE', {
  eventId: `CI-PESO-${suffix}`, edizione: 2026, codiceStand: 'CI-STAND-01', rilevatoIl: now,
  pesoLordoKg: 1340, taraKg: 100, fonte: 'SENSORE',
}, 201)

// BAD writes marked synthetic KPI observations; every report read must preserve the filters.
const batchId = randomUUID()
const batch = {
  edizione: 2026, calcolatoIl: now, formulaVersione: 'ci-sintetica-1', intervalloDatiDal: secondAgo, intervalloDatiAl: now,
  items: [
    ['visite_stand', 2, 'visite', { codiceStand: 'CI-STAND-01', idEspositore: 'CI-EXHIBITOR-01', padiglione: 'P1' }],
    ['mql', 1, 'contatti', { codiceStand: 'CI-STAND-01', idEspositore: 'CI-EXHIBITOR-01', padiglione: 'P1' }],
    ['ingressi_effettivi', 1, 'persone', { padiglione: 'P1' }],
    ['picco_presenza', 1, 'persone', { padiglione: 'P1' }],
    ['saturazione_pct', 1, 'percentuale', { padiglione: 'P1' }],
    ['interesse_pubblico', 1, 'contatti', { idEspositore: 'CI-EXHIBITOR-01' }],
  ].map(([codice, valore, unita, dimensioni]) => ({
    codice, valore, unita, edizione: 2026, periodoDal: secondAgo, periodoAl: now, dimensioni, calcolatoIl: now,
    formulaVersione: 'ci-sintetica-1', fonte: ['CI_SINTETICA'], qualita: 'DA_VERIFICARE',
    flagQualita: ['DATI_SINTETICI_TEST'], stimato: false, simulato: true, nota: 'Dato sintetico della suite CI.',
  })),
}
const incoming = await call('putKpiBad', 'PUT', `/integrazioni/bad/kpi/${batchId}`, 'BAD', batch, 201)
expect(incoming.body?.elementiAccettati === batch.items.length, 'BAD KPI: elementi non accettati')
const idempotent = await call('putKpiBad', 'PUT', `/integrazioni/bad/kpi/${batchId}`, 'BAD', batch, 200)
expect(idempotent.body?.stato === 'GIA_RICEVUTO', 'BAD KPI: il retry non e idempotente')

// Reports: scanner source takes precedence over the overlapping historical total (99).
const standReport = await call('exportFattiStandPerBad', 'GET', '/bi/dati/stand?edizione=2026&limit=100', 'BAD', undefined, 200)
const reconciled = standReport.body?.items?.find((item) => item.codiceStand === 'CI-STAND-01' && item.fonti?.includes('SCANSIONE_STAND'))
expect(reconciled?.visite === 2, `report stand: attese 2 visite da scansioni, ricevute ${reconciled?.visite}`)
expect(reconciled?.contatti === 1 && reconciled?.contattiConConsenso === 1, 'report stand: contatti non riconciliati o consenso non applicato')
expect(reconciled?.flagQualita?.includes('SCANNER_PREFERITO_FONTE_SOVRAPPOSTA'), 'report stand: manca il flag di fonti sovrapposte')
expect(!JSON.stringify(reconciled).toLowerCase().includes('email'), 'report stand: dati personali presenti')
const commercialReport = await call('exportDatiCommercialiPerBad', 'GET', '/bi/dati/commerciale?edizione=2026&limit=100', 'BAD', undefined, 200)
const reconciledCommercial = commercialReport.body?.items?.find((item) => item.espositoreRef === 'CI-EXHIBITOR-01')
expect(reconciledCommercial?.stato === 'ACCONTO_RICEVUTO', 'report commerciale: stato non coerente con la pratica')
expect(Number(reconciledCommercial?.accontoPagatoEur) === 200, 'report commerciale: acconto non coerente')
expect(reconciledCommercial?.dataFirma, 'report commerciale: timestamp firma non riconciliato')
expect(!JSON.stringify(reconciledCommercial).toLowerCase().includes('ragione_sociale'), 'report commerciale: dati personali/azienda non minimizzati')

await call('exportVenditePerBad', 'GET', '/bi/dati/vendite?edizione=2026&limit=100', 'BAD', undefined, 200)
await call('exportAccessiPerBad', 'GET', '/bi/dati/accessi?edizione=2026&limit=100', 'BAD', undefined, 200)
await call('exportQualitaPerBad', 'GET', '/bi/dati/qualita?edizione=2026&limit=100', 'BAD', undefined, 200)
const directionKpi = await call('getKpiDirezione', 'GET', '/kpi/direzione?edizione=2026&fonte=CI_SINTETICA', 'DIREZIONE', undefined, 200)
expect(directionKpi.body?.items?.length >= 3 && directionKpi.body.items.every((item) => item.simulato), 'KPI direzionali: filtro fonte o indicatore sintetico perso')
await call('getKpiAffluenza', 'GET', '/kpi/affluenza?edizione=2026&padiglione=P1&fonte=CI_SINTETICA', 'DIREZIONE', undefined, 200)
const standKpi = await call('getKpiStand', 'GET', '/kpi/stand/CI-STAND-01?edizione=2026&fonte=CI_SINTETICA', 'EXHIBITOR', undefined, 200)
expect(standKpi.body?.items?.some((item) => item.codice === 'visite_stand'), 'KPI stand: non coerente col fatto BAD')
const exhibitorKpi = await call('getKpiEspositore', 'GET', '/kpi/espositori/CI-EXHIBITOR-01?edizione=2026&fonte=CI_SINTETICA', 'EXHIBITOR', undefined, 200)
expect(exhibitorKpi.body?.items?.some((item) => item.codice === 'mql'), 'portale post-fiera: KPI MQL non trovato')
await call('getKpiLeadMagnet', 'GET', '/kpi/lead-magnet?edizione=2026&fonte=CI_SINTETICA', 'DIREZIONE', undefined, 200)

// Exhibitor portal: tenant isolation, own documents/contacts, report KPI and PREMIUM estimate.
await call('getMioEspositore', 'GET', '/espositori/me?edizione=2026', 'EXHIBITOR', undefined, 200)
const ownContract = await call('getMioContratto', 'GET', '/espositori/me/contratto?edizione=2026', 'EXHIBITOR', undefined, 200)
expect(ownContract.body?.documenti?.length === 2 && ownContract.body?.acconti?.length === 1, 'portale: documento o acconto non allineato al back office')
expect(ownContract.body?.stato === reconciledCommercial?.stato, 'riconciliazione back office/report/portale: stato pratica diverso')
expect(Number(ownContract.body?.totaleEur) === Number(reconciledCommercial?.imponibileEur), 'riconciliazione report/portale: imponibile netto diverso')
expect(ownContract.body.acconti.reduce((sum, payment) => sum + Number(payment.importoEur), 0) === Number(reconciledCommercial?.accontoPagatoEur),
  'riconciliazione report/portale: somma acconti diversa')
const ownDocs = ownContract.body.documenti
const exhibitorPdf = await call('downloadDocumentoPratica', 'GET', ownDocs.find((document) => document.downloadUrl)?.downloadUrl.replace('/api/v1', ''), 'EXHIBITOR', undefined, 200)
pdfDocument(exhibitorPdf, 'portale espositore')
const myContacts = await call('listMieiContatti', 'GET', '/espositori/me/contatti?edizione=2026', 'EXHIBITOR', undefined, 200)
expect(myContacts.body?.items?.some((contact) => contact.email === `lead-${suffix}@example.invalid`), 'portale: lead consenziente non visibile all’espositore titolare')
const otherTenant = await call('listDocumentiPratica', 'GET', `/pratiche/${practiceId}/documenti`, 'OTHER_EXHIBITOR', undefined, 404)
expect(otherTenant.body?.code !== 'ROTTA_NON_TROVATA', 'isolamento espositore: rotta sconosciuta')
const weights = await call('getMiePresenzePeso', 'GET', '/espositori/me/presenze-peso?edizione=2026', 'EXHIBITOR', undefined, 200)
expect(weights.body?.items?.length > 0, 'portale post-fiera: serie peso PREMIUM vuota')

// Remaining management routes.
const publicMagnets = await call('listLeadMagnet', 'GET', '/lead-magnet?edizione=2026&stand=CI-STAND-01', null, undefined, 200)
expect(publicMagnets.body?.items?.some((item) => item.id === 990001), 'lead magnet associato allo stand non pubblicato')
const newMagnet = await call('createLeadMagnet', 'POST', '/lead-magnet', 'COMMERCIALE', {
  edizione: 2026, idEspositore: 'CI-EXHIBITOR-02', tipo: 'CODICE_SCONTO', titolo: `Magnet ${suffix}`,
  interesse: 'PRODOTTO', attivo: true,
}, 201)
expect(newMagnet.body?.id, 'lead magnet: manca id')
await call('listAvvisi', 'GET', '/avvisi?pubblico=STAFF', 'STAFF', undefined, 200)
const notice = await call('createAvviso', 'POST', '/avvisi', 'STAFF', {
  titolo: `Avviso CI ${suffix}`, testo: 'Contenuto sintetico della suite integrata.', pubblico: 'STAFF',
}, 201)
await call('updateAvviso', 'PATCH', `/avvisi/${notice.body.id}`, 'STAFF', { attivo: false }, 200)
const turni = await call('listTurni', 'GET', '/turni?anno=2026', 'STAFF', undefined, 200)
expect(turni.body?.items?.some((item) => item.luogo === 'P1' && Number(item.personeAssegnate) === 1 && Number(item.personePreviste) === 1),
  'operativita: copertura del turno coperto non coerente')
expect(turni.body?.items?.some((item) => Number(item.personeMancanti) === 1), 'operativita: turno scoperto non segnalato')
await call('listTurni', 'GET', '/turni?anno=2026', 'EXHIBITOR', undefined, 403)
const auditLog = await call('listAuditEvents', 'GET', '/admin/audit?limit=100', 'AMMINISTRATORE', undefined, 200)
expect(auditLog.body?.items?.some((event) => event.resource === '/espositori/me/contratto' && event.actorRole === 'ESPOSITORE'),
  'audit privacy: la lettura del contratto del portale non viene registrata')
expect(!JSON.stringify(auditLog.body).includes(`${suffix}@example.invalid`), 'audit privacy: email presente nel registro')
await call('putEdizione', 'PUT', '/admin/edizioni/2028', 'AMMINISTRATORE', { stato: 'PIANIFICATA', sede: 'Fixture CI' }, 200)
const params = await call('updateParametriEdizione', 'PATCH', '/admin/edizioni/2026/parametri', 'AMMINISTRATORE', { orePermanenza: 4 }, 200)
expect(Number(params.body?.orePermanenza) === 4 && Number(params.body?.pesoMedioKg) === 70,
  'parametri edizione: PATCH parziale non preserva i default esistenti')

// The code-level coverage gate fails if OpenAPI gains an operation not represented above.
const openapi = await readFile(new URL('../../docs/openapi.yaml', import.meta.url), 'utf8')
const contractOperations = [...openapi.matchAll(/^\s+operationId:\s*([A-Za-z0-9_]+)\s*$/gm)].map((match) => match[1])
const missing = contractOperations.filter((operationId) => !issuedOperations.has(operationId))
const extra = [...issuedOperations].filter((operationId) => !contractOperations.includes(operationId))
assert.deepEqual(missing, [], `operationId OpenAPI senza test: ${missing.join(', ')}`)
assert.deepEqual(extra, [], `operationId nei test ma assenti da OpenAPI: ${extra.join(', ')}`)
console.log(`PASS: ${issuedOperations.size}/${contractOperations.length} operationId; ` +
  'flussi commerciale/documenti, accessi/scansione, post-fiera/report/portale; riconciliazione tra viste e archiviazione PDF.')
