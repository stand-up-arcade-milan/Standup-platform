import { createFileRoute } from '@tanstack/react-router'
import { useCallback, useEffect, useState } from 'react'
import type { FormEvent } from 'react'
import { api, ApiError, clearToken, downloadFile, formatDate, formatEuro, query, readToken, saveToken } from '../services/api'

export const Route = createFileRoute('/espositore')({ component: ExhibitorPage })

type Stand = { codice: string; padiglione: string; superficieMq?: number; stato: string }
type Profile = { id: string; ragioneSociale: string; edizione: number; stand?: Stand | null; pacchetto?: string }
type Contract = { edizione: number; stato: string; pacchetto: string; codiceStand?: string; totaleEur?: number | null; accontiEur?: number | null; acconti?: { importoEur: number; ricevutoIl: string }[]; documenti?: { id: string; tipo: string; nome: string; url?: string | null; downloadUrl?: string | null; dimensioneByte?: number | null; sha256?: string | null; creatoIl: string }[] }
type Contact = { id: string; anno: number; codiceStand: string; raccoltoIl: string; interesse: string; idLeadMagnet?: number | null; email: string }
type Kpi = { codice: string; valore: number; unita: string; qualita: string; stimato: boolean; simulato: boolean; nota?: string }
type Notice = { id: string; titolo: string; testo: string; pubblicatoIl: string }
type WeightSeries = { minuto: string; presenzeStimate: number; letture: number; fonte?: string }

function ExhibitorPage() {
  const [edition, setEdition] = useState('2026')
  const [email, setEmail] = useState('')
  const [password, setPassword] = useState('')
  const [connected, setConnected] = useState(Boolean(readToken('exhibitor')))
  const [profile, setProfile] = useState<Profile | null>(null)
  const [contract, setContract] = useState<Contract | null>(null)
  const [contacts, setContacts] = useState<Contact[]>([])
  const [contactCursor, setContactCursor] = useState<string | null>(null)
  const [kpis, setKpis] = useState<Kpi[]>([])
  const [notices, setNotices] = useState<Notice[]>([])
  const [loading, setLoading] = useState(false)
  const [busyLogin, setBusyLogin] = useState(false)
  const [authMode, setAuthMode] = useState<'login' | 'recovery' | 'reset'>('login')
  const [recoveryToken, setRecoveryToken] = useState('')
  const [newPassword, setNewPassword] = useState('')
  const [busyRecovery, setBusyRecovery] = useState(false)
  const [loginNotice, setLoginNotice] = useState('')
  const [messages, setMessages] = useState<Record<string, string>>({})

  const load = useCallback(async () => {
    if (!readToken('exhibitor')) return
    setLoading(true)
    setMessages({})
    let currentProfile: Profile | null = null
    try { currentProfile = await api<Profile>(`/espositori/me${query({ edizione: edition })}`, {}, 'exhibitor'); setProfile(currentProfile) }
    catch (error) {
      setMessages({ profile: error instanceof Error ? error.message : 'Profilo non disponibile.' })
      setLoading(false)
      if (error instanceof ApiError && error.status === 401) { clearToken('exhibitor'); setConnected(false) }
      return
    }
    const tasks = [
      ['contract', api<Contract>(`/espositori/me/contratto${query({ edizione: edition })}`, {}, 'exhibitor').then(setContract)],
      ['contacts', api<{ items: Contact[]; page?: { nextCursor?: string | null } }>(`/espositori/me/contatti${query({ edizione: edition, limit: 200 })}`, {}, 'exhibitor').then((value) => { setContacts(value.items ?? []); setContactCursor(value.page?.nextCursor ?? null) })],
      ['kpis', api<{ items: Kpi[] }>(`/kpi/espositori/${encodeURIComponent(currentProfile.id)}${query({ edizione: edition })}`, {}, 'exhibitor').then((value) => setKpis(value.items ?? []))],
      ['notices', api<{ items: Notice[] }>('/avvisi?pubblico=ESPOSITORI', {}, 'exhibitor').then((value) => setNotices(value.items ?? []))],
    ] as const
    const results = await Promise.allSettled(tasks.map(([, promise]) => promise))
    const next: Record<string, string> = {}
    results.forEach((result, index) => {
      if (result.status === 'rejected') {
        const key = tasks[index][0]
        const error = result.reason
        next[key] = error instanceof Error ? error.message : 'Dati temporaneamente non disponibili.'
        if (error instanceof ApiError && error.status === 401) {
          clearToken('exhibitor'); setConnected(false)
        }
      }
    })
    setMessages(next)
    setLoading(false)
  }, [edition])

  useEffect(() => { if (connected) void load() }, [connected, load])

  async function loadMoreContacts() {
    if (!contactCursor) return
    try {
      const next = await api<{ items: Contact[]; page?: { nextCursor?: string | null } }>(`/espositori/me/contatti${query({ edizione: edition, limit: 200, cursor: contactCursor })}`, {}, 'exhibitor')
      setContacts((current) => [...current, ...(next.items ?? [])])
      setContactCursor(next.page?.nextCursor ?? null)
    } catch (error) { setMessages((current) => ({ ...current, contacts: error instanceof Error ? error.message : 'Altri contatti non disponibili.' })) }
  }

  async function login(event: FormEvent) {
    event.preventDefault(); setBusyLogin(true); setMessages({}); setLoginNotice('')
    try {
      const result = await api<{ accessToken: string }>('/auth/login', { method: 'POST', body: JSON.stringify({ email, password }) })
      saveToken('exhibitor', result.accessToken)
      setConnected(true); setPassword('')
    } catch (error) {
      setMessages({ login: error instanceof Error ? error.message : 'Accesso non riuscito.' })
    } finally { setBusyLogin(false) }
  }

  async function requestPasswordRecovery(event: FormEvent) {
    event.preventDefault(); setBusyRecovery(true); setMessages({})
    try {
      await api('/auth/password/recupero', { method: 'POST', body: JSON.stringify({ email }) })
      setMessages({ recovery: 'Richiesta registrata. Se l’account esiste, le istruzioni saranno inviate quando sarà configurato il servizio email.' })
    } catch (error) {
      setMessages({ recovery: error instanceof Error ? error.message : 'Richiesta non riuscita.' })
    } finally { setBusyRecovery(false) }
  }

  async function resetPassword(event: FormEvent) {
    event.preventDefault(); setBusyRecovery(true); setMessages({})
    try {
      await api('/auth/password/reimposta', { method: 'POST', body: JSON.stringify({ token: recoveryToken.trim(), password: newPassword }) })
      setAuthMode('login'); setRecoveryToken(''); setNewPassword(''); setLoginNotice('Password aggiornata. Accedi con la nuova password.')
    } catch (error) {
      setMessages({ reset: error instanceof Error ? error.message : 'Reimpostazione non riuscita.' })
    } finally { setBusyRecovery(false) }
  }

  function logout() { clearToken('exhibitor'); setConnected(false); setProfile(null); setContract(null); setContacts([]); setKpis([]); setNotices([]) }

  const balance = contract?.totaleEur == null || contract.accontiEur == null ? null : contract.totaleEur - contract.accontiEur
  const premium = profile?.pacchetto === 'PREMIUM' || contract?.pacchetto === 'PREMIUM'

  if (!connected) return <section className="login-page">
    <div className="login-aside"><p className="eyebrow">AREA ESPOSITORI · 05</p><h2>La tua presenza<br />in fiera, a colpo d’occhio.</h2><p>Contratto, stand, documenti e risultati condivisi per la tua organizzazione.</p><span className="login-mark">ARCADE<br />MILANO</span></div>
    <div className="login-panel">
      {authMode === 'login' && <form className="auth-form" onSubmit={login}>
        <p className="eyebrow">ACCESSO RISERVATO</p><h3>Entra nella tua area</h3><p className="muted">Usa l’account associato al tuo invito espositore.</p>
        {loginNotice && <p className="alert alert--success" role="status">{loginNotice}</p>}
        <label>Email<input type="email" autoComplete="username" required value={email} onChange={(event) => setEmail(event.target.value)} /></label>
        <label>Password<input type="password" autoComplete="current-password" required value={password} onChange={(event) => setPassword(event.target.value)} /></label>
        <button className="button button--lime button--wide" disabled={busyLogin}>{busyLogin ? 'Accesso…' : 'Accedi'}</button>
        {messages.login && <p className="alert alert--error" role="alert">{messages.login}</p>}
        <button type="button" className="text-button" onClick={() => { setMessages({}); setAuthMode('recovery') }}>Hai dimenticato la password?</button>
      </form>}
      {authMode === 'recovery' && <form className="auth-form" onSubmit={requestPasswordRecovery}>
        <p className="eyebrow">RECUPERO ACCESSO</p><h3>Richiedi un nuovo link</h3><p className="muted">Inserisci l’email associata al tuo account. La risposta non rivela se l’indirizzo è registrato.</p>
        {messages.recovery && <p className="alert alert--success" role="status">{messages.recovery}</p>}
        <label>Email<input type="email" autoComplete="email" required value={email} onChange={(event) => setEmail(event.target.value)} /></label>
        <button className="button button--lime button--wide" disabled={busyRecovery}>{busyRecovery ? 'Invio…' : 'Richiedi recupero'}</button>
        <button type="button" className="text-button" onClick={() => { setMessages({}); setAuthMode('reset') }}>Ho già un token di recupero</button>
        <button type="button" className="text-button text-button--muted" onClick={() => { setMessages({}); setAuthMode('login') }}>Torna all’accesso</button>
      </form>}
      {authMode === 'reset' && <form className="auth-form" onSubmit={resetPassword}>
        <p className="eyebrow">NUOVA PASSWORD</p><h3>Reimposta l’accesso</h3><p className="muted">Usa il token monouso ricevuto dall’amministratore o dal servizio email.</p>
        {messages.reset && <p className="alert alert--error" role="alert">{messages.reset}</p>}
        <label>Token di recupero<input required autoComplete="one-time-code" value={recoveryToken} onChange={(event) => setRecoveryToken(event.target.value)} /></label>
        <label>Nuova password<input type="password" required minLength={12} autoComplete="new-password" value={newPassword} onChange={(event) => setNewPassword(event.target.value)} /></label>
        <small className="form-note">La password deve contenere almeno 12 caratteri.</small>
        <button className="button button--lime button--wide" disabled={busyRecovery}>{busyRecovery ? 'Aggiornamento…' : 'Imposta password'}</button>
        <button type="button" className="text-button text-button--muted" onClick={() => { setMessages({}); setAuthMode('login') }}>Torna all’accesso</button>
      </form>}
    </div>
  </section>

  return <section className="exhibitor-page">
    <div className="page-heading page-heading--exhibitor"><div><p className="eyebrow">AREA ESPOSITORI · {edition}</p><h2>{profile?.ragioneSociale ?? 'Il tuo spazio in fiera'}</h2><p className="intro">Informazioni e documenti della tua partecipazione.</p></div><div className="header-actions"><label className="edition-picker">Edizione<select value={edition} onChange={(event) => setEdition(event.target.value)}><option>2026</option><option>2025</option><option>2024</option></select></label><button className="button button--outline" onClick={logout}>Esci</button></div></div>

    {loading && <p className="inline-loading" role="status">Aggiornamento dati…</p>}
    {messages.profile && <p className="alert alert--error" role="alert">Profilo: {messages.profile}</p>}
    <div className="exhibitor-hero">
      <div><p className="eyebrow">IL TUO STAND</p><strong>{profile?.stand?.codice ?? contract?.codiceStand ?? 'Assegnazione non disponibile'}</strong><p>{profile?.stand ? `${profile.stand.padiglione} · ${profile.stand.superficieMq ?? '—'} m²` : 'Contatta il team commerciale per conoscere i prossimi passaggi.'}</p></div>
      <div className="hero-edition"><span>EDIZIONE</span><strong>{edition}</strong><span className={`package-pill ${premium ? 'package-pill--premium' : ''}`}>{contract?.pacchetto ?? profile?.pacchetto ?? 'Pacchetto non disponibile'}</span></div>
    </div>

    <div className="exhibitor-summary">
      <article className="summary-card summary-card--contract"><span>STATO CONTRATTO</span><strong>{contract?.stato?.replaceAll('_', ' ') ?? 'Non disponibile'}</strong><small>{contract ? `Totale ${formatEuro(contract.totaleEur)}` : messages.contract ?? 'Nessun contratto disponibile per questa edizione.'}</small></article>
      <article className="summary-card"><span>ACCONTI REGISTRATI</span><strong>{formatEuro(contract?.accontiEur ?? null)}</strong><small>{contract?.acconti?.length ?? 0} pagamenti con importo registrato</small></article>
      <article className="summary-card"><span>RESIDUO CONTRATTO</span><strong>{formatEuro(balance)}</strong><small>Calcolato dai pagamenti registrati nell’API</small></article>
      <article className="summary-card"><span>CONTATTI MOSTRATI</span><strong>{contacts.length}</strong><small>{messages.contacts ?? 'Email visibile solo con consenso alla condivisione'}</small></article>
    </div>

    <div className="content-grid content-grid--bottom">
      <section className="panel">
        <div className="panel-heading"><div><p className="eyebrow">ANDAMENTO</p><h3>Indicatori condivisi</h3></div><span className="powered-by">Dati BID · calcolo BAD</span></div>
        {messages.kpis ? <p className="quiet-state">{messages.kpis}</p> : kpis.length === 0 ? <p className="quiet-state">Gli indicatori non sono ancora disponibili per questa edizione.</p> : <div className="kpi-list">{kpis.map((item) => <article key={item.codice} className="kpi-row"><div><strong>{item.codice.replaceAll('_', ' ')}</strong><small>{item.nota ?? item.qualita}</small></div><span className="kpi-value">{new Intl.NumberFormat('it-IT', { maximumFractionDigits: 1 }).format(item.valore)} <small>{item.unita}</small></span><span className="quality-tag">{item.simulato ? 'SIMULATO' : item.stimato ? 'STIMATO' : item.qualita}</span></article>)}</div>}
        {premium ? <WeightSummary edition={edition} /> : <div className="premium-callout"><span>PREMIUM</span><p>La stima presenze basata sulle rilevazioni di peso è disponibile solo con il pacchetto PREMIUM.</p></div>}
      </section>

      <section className="panel">
        <div className="panel-heading"><div><p className="eyebrow">DOCUMENTI</p><h3>Contratto e offerte</h3></div><span className="count-pill">{contract?.documenti?.length ?? 0}</span></div>
        {messages.contract ? <p className="quiet-state">{messages.contract}</p> : !contract?.documenti?.length ? <p className="quiet-state">I documenti compariranno qui quando saranno archiviati dal team commerciale.</p> : <ul className="document-list">{contract.documenti.map((document) => <li key={document.id}><span className="document-icon">{document.tipo}</span><span><strong>{document.nome}</strong><small>Caricato il {formatDate(document.creatoIl)}</small></span>{document.downloadUrl ? <button className="text-button" onClick={() => void downloadFile(document.downloadUrl!.replace('/api/v1', ''), document.nome, 'exhibitor').catch((error) => setMessages((current) => ({ ...current, contract: error instanceof Error ? error.message : 'Download non riuscito.' })))}>Scarica PDF</button> : document.url ? <a href={document.url} target="_blank" rel="noreferrer">Apri</a> : <small>File non ancora archiviato</small>}</li>)}</ul>}
        <div className="notice-section"><div className="panel-heading"><div><p className="eyebrow">AVVISI</p><h3>Comunicazioni per te</h3></div></div>{messages.notices ? <p className="quiet-state">{messages.notices}</p> : notices.length === 0 ? <p className="quiet-state">Nessun avviso attivo.</p> : notices.map((item) => <article className="notice-card" key={item.id}><div><strong>{item.titolo}</strong><small>{formatDate(item.pubblicatoIl)}</small></div><p>{item.testo}</p></article>)}</div>
      </section>
    </div>

    <section className="panel contacts-panel">
      <div className="panel-heading"><div><p className="eyebrow">CONTATTI ALLO STAND</p><h3>Lead condivisi</h3></div><span className="privacy-mark">{contacts.length} lead idonei</span></div>
      {messages.contacts ? <p className="quiet-state">{messages.contacts}</p> : contacts.length === 0 ? <p className="quiet-state">Qui compaiono solo lead adulti con consenso alla condivisione, consenso marketing e interesse qualificato.</p> : <>
        <div className="table-wrap"><table><thead><tr><th>Stand</th><th>Data e ora</th><th>Interesse</th><th>Email condivisa</th></tr></thead><tbody>{contacts.map((item) => <tr key={item.id}><td>{item.codiceStand}</td><td>{formatDate(item.raccoltoIl)}</td><td>{item.interesse}</td><td>{item.email}</td></tr>)}</tbody></table></div>
        {contactCursor && <button className="button button--outline" onClick={() => void loadMoreContacts()}>Carica altri lead</button>}
      </>}
    </section>
  </section>
}

function WeightSummary({ edition }: { edition: string }) {
  const [message, setMessage] = useState('')
  const [series, setSeries] = useState<WeightSeries[]>([])
  const [margin, setMargin] = useState<number | null>(null)
  useEffect(() => {
    api<{ items: WeightSeries[]; erroreAttesoPercentuale: number }>(`/espositori/me/presenze-peso${query({ edizione: edition })}`, {}, 'exhibitor')
      .then((data) => { setSeries(data.items ?? []); setMargin(data.erroreAttesoPercentuale); setMessage('') })
      .catch((error: unknown) => setMessage(error instanceof Error ? error.message : 'Stima non disponibile.'))
  }, [edition])
  const latest = series.at(-1)
  return <div className="weight-panel"><div><span className="eyebrow">STIMA PREMIUM DAL PESO</span><strong>{latest?.presenzeStimate ?? '—'}</strong><small>presenze stimate · aggiornamento {latest ? formatDate(latest.minuto) : 'non disponibile'}</small></div><div className="weight-details">{message ? <p>{message}</p> : <><p>Margine dichiarato ±{margin ?? '—'}% · {latest?.letture ?? 0} letture nell’ultimo minuto</p><div className="weight-series" aria-label="Ultime stime per minuto">{series.slice(-12).map((item) => <span key={item.minuto} title={`${item.presenzeStimate} presenze stimate, ${item.letture} letture`} style={{ height: `${Math.max(8, Math.min(100, item.presenzeStimate * 4))}%` }} />)}</div></>}</div></div>
}
