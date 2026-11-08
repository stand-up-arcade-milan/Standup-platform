import { createFileRoute } from '@tanstack/react-router'
import { useCallback, useEffect, useMemo, useState } from 'react'
import type { FormEvent } from 'react'
import { api, ApiError, formatDate, formatEuro, query, readToken, saveToken } from '../services/api'

export const Route = createFileRoute('/commerciale')({ component: CommercialPage })

type Page<T> = { items: T[]; page?: { nextCursor?: string | null } }
type Stand = { codice: string; padiglione: string; superficieMq?: number; stato: string }
type Listino = { codiceVoce: string; descrizione: string; tipo: string; unita: string; prezzoEur: number; disponibilita?: string; nota?: string }
type Exhibitor = { id: string; nomePubblico: string }
type RequestRow = { id: string; tipo: string; stato: string; azienda?: string; categoria?: string; metriQuadriDesiderati?: number; creataIl?: string }
type Practice = { id: string; edizione: number; idEspositore: string; codiceStand?: string; stato: string; pacchetto: string; totaleEur: number; scontoPercentuale?: number; createdAt: string }

function CommercialPage() {
  const [edition, setEdition] = useState('2026')
  const [stateFilter, setStateFilter] = useState('')
  const [tokenInput, setTokenInput] = useState(readToken('internal') ?? '')
  const [requests, setRequests] = useState<RequestRow[]>([])
  const [practices, setPractices] = useState<Practice[]>([])
  const [stands, setStands] = useState<Stand[]>([])
  const [catalog, setCatalog] = useState<Listino[]>([])
  const [exhibitors, setExhibitors] = useState<Exhibitor[]>([])
  const [standSearch, setStandSearch] = useState('')
  const [standPage, setStandPage] = useState(0)
  const [selected, setSelected] = useState<Practice | null>(null)
  const [documents, setDocuments] = useState<{ id: string; tipo: string; nome: string; url?: string | null; creatoIl: string }[]>([])
  const [offerDiscount, setOfferDiscount] = useState(0)
  const [busy, setBusy] = useState(true)
  const [notice, setNotice] = useState('')
  const [failure, setFailure] = useState('')
  const [publicFailure, setPublicFailure] = useState('')
  const [newPractice, setNewPractice] = useState({ idEspositore: '', codiceStand: '', pacchetto: 'BASE', codiceArea: '' })
  const [extras, setExtras] = useState<string[]>([])

  const load = useCallback(async () => {
    setBusy(true)
    setFailure('')
    setPublicFailure('')
    try {
      const [requestPage, practicePage, standPage, exhibitorPage, listinoPage] = await Promise.allSettled([
        api<Page<RequestRow>>(`/richieste${query({ limit: 200 })}`, {}, 'internal'),
        api<Page<Practice>>(`/pratiche${query({ edizione: edition, stato: stateFilter || undefined, limit: 200 })}`, {}, 'internal'),
        api<{ items: Stand[] }>(`/stand${query({ edizione: edition, limit: 200 })}`, {}, 'internal'),
        api<Page<Exhibitor>>(`/espositori${query({ limit: 200 })}`),
        api<{ items: Listino[] }>(`/listino${query({ edizione: edition })}`, {}, 'internal'),
      ])
      setRequests(requestPage.status === 'fulfilled' ? requestPage.value.items ?? [] : [])
      setPractices(practicePage.status === 'fulfilled' ? practicePage.value.items ?? [] : [])
      setStands(standPage.status === 'fulfilled' ? standPage.value.items ?? [] : [])
      setExhibitors(exhibitorPage.status === 'fulfilled' ? exhibitorPage.value.items ?? [] : [])
      setCatalog(listinoPage.status === 'fulfilled' ? listinoPage.value.items ?? [] : [])
      if (exhibitorPage.status === 'rejected') setPublicFailure('I profili pubblici non sono disponibili.')
      const protectedError = [requestPage, practicePage, standPage, listinoPage].find((result) => result.status === 'rejected')
      if (protectedError?.status === 'rejected') {
        const error = protectedError.reason
        setFailure(error instanceof ApiError && error.status === 401
          ? 'Inserisci un bearer token interno valido per accedere alle richieste, alle pratiche e agli stand.'
          : error instanceof Error ? error.message : 'Non e stato possibile caricare il back office.')
      }
    } catch (error) {
      setFailure(error instanceof Error ? error.message : 'Non è stato possibile caricare il back office.')
      if (error instanceof ApiError && error.status === 401) setFailure('Inserisci un bearer token interno valido per accedere alle richieste, alle pratiche e agli stand.')
    } finally {
      setBusy(false)
    }
  }, [edition, stateFilter])

  useEffect(() => { void load() }, [load])

  const counts = useMemo(() => ({
    requests: requests.filter((item) => item.stato === 'NUOVA').length,
    drafts: practices.filter((item) => item.stato === 'BOZZA').length,
    signed: practices.filter((item) => item.stato === 'FIRMATA' || item.stato === 'ACCONTO_RICEVUTO').length,
    free: stands.filter((item) => item.stato === 'LIBERO').length,
  }), [requests, practices, stands])
  const filteredStands = useMemo(() => stands.filter((item) => `${item.codice} ${item.padiglione} ${item.stato}`.toLowerCase().includes(standSearch.trim().toLowerCase())), [stands, standSearch])
  const visibleStands = filteredStands.slice(standPage * 12, standPage * 12 + 12)
  const dataReady = !busy && !failure

  function connect(event: FormEvent) {
    event.preventDefault()
    saveToken('internal', tokenInput.trim())
    setNotice('Token disponibile solo in questa scheda del browser.')
    void load()
  }

  async function createPractice(event: FormEvent) {
    event.preventDefault()
    setFailure(''); setNotice('')
    try {
      const area = stands.find((item) => item.codice === newPractice.codiceStand)?.superficieMq ?? 0
      const voci = [{ codiceVoce: newPractice.codiceArea, quantita: area }, ...extras.map((code) => {
        const item = catalog.find((entry) => entry.codiceVoce === code)
        return { codiceVoce: code, quantita: item?.unita === 'MQ' ? area : 1 }
      })]
      const created = await api<Practice>('/pratiche', { method: 'POST', body: JSON.stringify({ edizione: Number(edition), idEspositore: newPractice.idEspositore, codiceStand: newPractice.codiceStand, pacchetto: newPractice.pacchetto, voci }) }, 'internal')
      setNotice(`Pratica ${created.id} creata in Bozza.`)
      setNewPractice({ idEspositore: '', codiceStand: '', pacchetto: 'BASE', codiceArea: '' }); setExtras([])
      await load()
    } catch (error) { setFailure(error instanceof Error ? error.message : 'Creazione pratica non riuscita.') }
  }

  async function selectPractice(item: Practice) {
    setSelected(item); setDocuments([])
    setOfferDiscount(item.scontoPercentuale ?? 0)
    try {
      const result = await api<{ items: typeof documents }>(`/pratiche/${item.id}/documenti`, {}, 'internal')
      setDocuments(result.items ?? [])
    } catch { setDocuments([]) }
  }

  async function transition(next: string) {
    if (!selected) return
    try {
      const updated = await api<Practice>(`/pratiche/${selected.id}/stato`, { method: 'PATCH', body: JSON.stringify({ stato: next }) }, 'internal')
      setSelected(updated); setNotice(`Stato aggiornato: ${next}.`); await load()
    } catch (error) { setFailure(error instanceof Error ? error.message : 'Cambio stato non riuscito.') }
  }

  async function createOffer() {
    if (!selected) return
    try {
      const doc = await api<{ nome: string }>('/pratiche/' + selected.id + '/offerta', { method: 'POST', body: JSON.stringify({ scontoPercentuale: offerDiscount }) }, 'internal')
      setNotice(`Metadati offerta registrati: ${doc.nome}. Il file sarà disponibile dopo la configurazione dell’archivio documentale.`)
      await selectPractice(selected)
      await load()
    } catch (error) { setFailure(error instanceof Error ? error.message : 'Creazione offerta non riuscita.') }
  }

  async function renewPractice() {
    if (!selected) return
    try {
      const renewed = await api<Practice>(`/pratiche/${selected.id}/rinnovo`, { method: 'POST' }, 'internal')
      setNotice(`Rinnovo creato per l’edizione ${renewed.edizione}.`); await load()
    } catch (error) { setFailure(error instanceof Error ? error.message : 'Rinnovo non riuscito.') }
  }

  async function addAdvance(event: FormEvent<HTMLFormElement>) {
    event.preventDefault()
    if (!selected) return
    const form = new FormData(event.currentTarget)
    try {
      await api(`/pratiche/${selected.id}/acconti`, { method: 'POST', body: JSON.stringify({ importoEur: Number(form.get('amount')), ricevutoIl: new Date(String(form.get('date'))).toISOString(), riferimento: String(form.get('reference') || '') }) }, 'internal')
      setNotice('Acconto registrato.'); await load()
    } catch (error) { setFailure(error instanceof Error ? error.message : 'Registrazione acconto non riuscita.') }
  }

  return (
    <section className="workbench">
      <div className="page-heading">
        <div><p className="eyebrow">AREA COMMERCIALE · 04</p><h2>Back office commerciale</h2><p className="intro">Richieste, pratiche e assegnazioni della fiera in un’unica vista operativa.</p></div>
        <label className="edition-picker">Edizione<select value={edition} onChange={(event) => { setEdition(event.target.value); setStandPage(0) }}><option value="2026">2026</option><option value="2025">2025</option><option value="2024">2024</option></select></label>
      </div>

      <form className="access-strip" onSubmit={connect}>
        <label htmlFor="internal-token">Token aziendale</label><input id="internal-token" value={tokenInput} onChange={(event) => setTokenInput(event.target.value)} type="password" autoComplete="off" placeholder="Bearer token interno" />
        <button className="button button--dark" type="submit">Collega</button><span>Il token resta nella sessione corrente.</span>
      </form>
      {failure && <p className="alert alert--error" role="alert">{failure}</p>}
      {notice && <p className="alert alert--success" role="status">{notice}</p>}

      <div className="metric-grid" aria-label="Riepilogo attività">
        <Metric label="Richieste nuove" value={dataReady ? counts.requests : '—'} accent="lime" />
        <Metric label="Pratiche in bozza" value={dataReady ? counts.drafts : '—'} />
        <Metric label="Firmate / acconto" value={dataReady ? counts.signed : '—'} accent="teal" />
        <Metric label="Stand liberi" value={dataReady ? counts.free : '—'} accent="brick" />
      </div>

      <div className="content-grid content-grid--commercial">
        <section className="panel">
          <div className="panel-heading"><div><p className="eyebrow">PIPELINE</p><h3>Pratiche commerciali</h3></div><label className="compact-field">Stato<select value={stateFilter} onChange={(event) => setStateFilter(event.target.value)}><option value="">Tutti</option><option>BOZZA</option><option>INVIATA</option><option>FIRMATA</option><option>ACCONTO_RICEVUTO</option></select></label></div>
          {busy ? <Loading /> : failure ? <Empty text="Le pratiche non sono disponibili. Verifica il token e riprova." /> : practices.length === 0 ? <Empty text="Nessuna pratica disponibile per questi filtri." /> : <div className="table-wrap"><table><thead><tr><th>Espositore</th><th>Stand</th><th>Stato</th><th>Pacchetto</th><th>Totale</th></tr></thead><tbody>{practices.map((item) => <tr key={item.id} className={selected?.id === item.id ? 'row-selected' : ''}><td><button className="text-button" onClick={() => void selectPractice(item)}>{exhibitors.find((company) => company.id === item.idEspositore)?.nomePubblico ?? item.idEspositore}</button><small>{item.id.slice(0, 8)}</small></td><td>{item.codiceStand ?? 'Da assegnare'}</td><td><StateBadge value={item.stato} /></td><td>{item.pacchetto}</td><td>{formatEuro(item.totaleEur)}</td></tr>)}</tbody></table></div>}
        </section>

        <section className="panel panel--requests">
          <div className="panel-heading"><div><p className="eyebrow">IN INGRESSO</p><h3>Richieste ricevute</h3></div><span className="count-pill">{dataReady ? requests.length : '—'}</span></div>
          {busy ? <Loading /> : failure ? <Empty text="Le richieste non sono disponibili. Verifica il token e riprova." /> : requests.length === 0 ? <Empty text="Non ci sono richieste da mostrare." /> : <div className="request-list">{requests.map((item) => <article className="request-card" key={item.id}><div><StateBadge value={item.stato} /><span className="muted">{formatDate(item.creataIl)}</span></div><h4>{item.azienda ?? 'Richiesta visitatore'}</h4><p>{item.categoria ?? item.tipo} · {item.metriQuadriDesiderati ? `${item.metriQuadriDesiderati} m² richiesti` : 'Nessuna superficie indicata'}</p><small>Rif. {item.id.slice(0, 8)}</small></article>)}</div>}
        </section>
      </div>

      <div className="content-grid content-grid--bottom">
        <section className="panel">
          <div className="panel-heading"><div><p className="eyebrow">NUOVA PRATICA</p><h3>Assegna stand e pacchetto</h3></div></div>
          <form className="stack-form" onSubmit={createPractice}>
            <label>Espositore<select required value={newPractice.idEspositore} onChange={(event) => setNewPractice({ ...newPractice, idEspositore: event.target.value })}><option value="">Seleziona un espositore</option>{exhibitors.map((item) => <option key={item.id} value={item.id}>{item.nomePubblico}</option>)}</select></label>
            <div className="form-row"><label>Stand libero<select required value={newPractice.codiceStand} onChange={(event) => setNewPractice({ ...newPractice, codiceStand: event.target.value, codiceArea: '' })}><option value="">Seleziona</option>{stands.filter((item) => item.stato === 'LIBERO').map((item) => <option key={item.codice} value={item.codice}>{item.codice} · {item.padiglione} · {item.superficieMq ?? '—'} m²</option>)}</select></label><label>Pacchetto espositore<select value={newPractice.pacchetto} onChange={(event) => setNewPractice({ ...newPractice, pacchetto: event.target.value })}><option>BASE</option><option>PREMIUM</option></select></label></div>
            <label>Tariffa area<select required value={newPractice.codiceArea} onChange={(event) => setNewPractice({ ...newPractice, codiceArea: event.target.value })}><option value="">Seleziona tariffa</option>{catalog.filter((item) => item.codiceVoce.startsWith('SPAZIO-')).map((item) => <option key={item.codiceVoce} value={item.codiceVoce}>{item.descrizione} · {formatEuro(item.prezzoEur)}/m²</option>)}</select></label>
            <fieldset className="catalog-options"><legend>Servizi e pacchetti aggiuntivi</legend>{catalog.filter((item) => item.tipo !== 'STAND' && item.unita !== 'PERCENTUALE').map((item) => <label key={item.codiceVoce} className="catalog-option"><input type="checkbox" checked={extras.includes(item.codiceVoce)} onChange={(event) => setExtras(event.target.checked ? [...extras, item.codiceVoce] : extras.filter((code) => code !== item.codiceVoce))} /><span><strong>{item.descrizione}</strong><small>{item.unita === 'PERCENTUALE_MQ' ? `${Math.round(item.prezzoEur * 100)}% dell’area` : `${formatEuro(item.prezzoEur)} · ${item.unita === 'MQ' ? 'per m²' : 'forfait'}`}</small></span></label>)}</fieldset>
            <button className="button button--lime" disabled={!readToken('internal') || busy || Boolean(failure)}>Crea pratica in Bozza</button>
            <p className="form-note">La creazione viene verificata dal server: uno stand già assegnato genera un conflitto.</p>
          </form>
        </section>

        <section className="panel panel--detail">
          <div className="panel-heading"><div><p className="eyebrow">DETTAGLIO</p><h3>{selected ? 'Gestione pratica' : 'Seleziona una pratica'}</h3></div></div>
          {selected ? <>
            <dl className="detail-list"><div><dt>Espositore</dt><dd>{exhibitors.find((company) => company.id === selected.idEspositore)?.nomePubblico ?? selected.idEspositore}</dd></div><div><dt>Edizione</dt><dd>{selected.edizione}</dd></div><div><dt>Stand</dt><dd>{selected.codiceStand ?? 'Da assegnare'}</dd></div><div><dt>Importo</dt><dd>{formatEuro(selected.totaleEur)}</dd></div></dl>
            <div className="action-row">{selected.stato === 'BOZZA' && <button className="button button--dark" onClick={() => void transition('INVIATA')}>Invia</button>}{selected.stato === 'INVIATA' && <button className="button button--dark" onClick={() => void transition('FIRMATA')}>Segna firmata</button>}{selected.stato === 'FIRMATA' && <button className="button button--dark" onClick={() => void transition('ACCONTO_RICEVUTO')}>Acconto ricevuto</button>}<button className="button button--outline" onClick={() => void createOffer()}>Prepara offerta</button><button className="button button--outline" onClick={() => void renewPractice()}>Crea rinnovo</button></div>
            <label className="discount-field">Sconto offerta (%)<input type="number" min="0" max="100" step="0.01" value={offerDiscount} onChange={(event) => setOfferDiscount(Number(event.target.value))} /></label>
            {documents.length > 0 && <ul className="document-list">{documents.map((document) => <li key={document.id}><span className="document-icon">{document.tipo}</span><span><strong>{document.nome}</strong><small>{formatDate(document.creatoIl)}</small></span>{document.url ? <a href={document.url} target="_blank" rel="noreferrer">Apri ↗</a> : <small>File non archiviato</small>}</li>)}</ul>}
            <form className="advance-form" onSubmit={(event) => void addAdvance(event)}><strong>Registra un acconto</strong><div className="form-row"><label>Importo (€)<input name="amount" type="number" min="0.01" step="0.01" required /></label><label>Data<input name="date" type="date" required /></label></div><label>Riferimento<input name="reference" maxLength={120} placeholder="Riferimento pagamento" /></label><button className="button button--lime">Registra pagamento</button></form>
          </> : <Empty text="Apri una riga della pipeline per vedere i dettagli e le azioni consentite." />}
        </section>
      </div>
      <div className="content-grid content-grid--bottom">
        <section className="panel"><div className="panel-heading"><div><p className="eyebrow">ANAGRAFICA PUBBLICA</p><h3>Espositori</h3></div><span className="count-pill">{publicFailure ? null : exhibitors.length}</span></div>{busy ? <Loading /> : publicFailure ? <Empty text="I profili pubblici non sono disponibili." /> : exhibitors.length === 0 ? <Empty text="Nessun profilo pubblico disponibile." /> : <div className="table-wrap"><table><thead><tr><th>Organizzazione</th><th>Riferimento</th></tr></thead><tbody>{exhibitors.map((item) => <tr key={item.id}><td>{item.nomePubblico}</td><td><small>{item.id}</small></td></tr>)}</tbody></table></div>}</section>
        <section className="panel"><div className="panel-heading"><div><p className="eyebrow">PLANIMETRIA E LISTINO</p><h3>Stand e tariffe</h3></div><span className="count-pill">{dataReady ? `${filteredStands.length} stand` : '—'}</span></div><label className="stand-search">Cerca stand o padiglione<input value={standSearch} onChange={(event) => { setStandSearch(event.target.value); setStandPage(0) }} placeholder="Codice, padiglione o stato" /></label>{busy ? <Loading /> : failure ? <Empty text="Planimetria e listino non sono disponibili." /> : <><div className="table-wrap stand-table-wrap"><table><thead><tr><th>Stand</th><th>Padiglione</th><th>Area</th><th>Stato</th></tr></thead><tbody>{visibleStands.map((item) => <tr key={item.codice}><td>{item.codice}</td><td>{item.padiglione}</td><td>{item.superficieMq ?? '—'} m²</td><td><StateBadge value={item.stato} /></td></tr>)}</tbody></table></div><div className="stand-pagination"><small>{filteredStands.length === 0 ? 'Nessuno stand corrisponde al filtro' : `Pagina ${standPage + 1} di ${Math.ceil(filteredStands.length / 12)}`}</small><div><button className="button button--outline" disabled={standPage === 0} onClick={() => setStandPage((page) => Math.max(0, page - 1))}>Precedente</button><button className="button button--outline" disabled={(standPage + 1) * 12 >= filteredStands.length} onClick={() => setStandPage((page) => page + 1)}>Successiva</button></div></div><div className="catalog-mini">{catalog.map((item) => <div key={item.codiceVoce}><span>{item.descrizione}</span><strong>{item.unita === 'PERCENTUALE_MQ' ? `${Math.round(item.prezzoEur * 100)}%` : formatEuro(item.prezzoEur)}</strong></div>)}</div></>}</section>
      </div>
      <p className="screen-footnote">I dati personali dei referenti non sono mostrati in questa vista. Richieste e pratiche sono restituite dall’API BID in base al ruolo aziendale.</p>
    </section>
  )
}

function Metric({ label, value, accent = '' }: { label: string; value: number | string; accent?: string }) { return <article className={`metric-card ${accent ? `metric-card--${accent}` : ''}`}><span>{label}</span><strong>{value}</strong></article> }
function StateBadge({ value }: { value: string }) { return <span className={`state-badge state-badge--${value.toLowerCase()}`}>{value.replaceAll('_', ' ')}</span> }
function Loading() { return <p className="quiet-state" role="status">Caricamento…</p> }
function Empty({ text }: { text: string }) { return <p className="quiet-state">{text}</p> }
