import { createFileRoute, Link } from '@tanstack/react-router'
import { useCallback, useEffect, useState } from 'react'
import { api, formatDate } from '../services/api'
import { RequireRole } from '../components/RequireRole'

export const Route = createFileRoute('/operativita')({ component: OperationsPage })

type Edition = { anno: number; sede?: string | null; stato: string }

type KpiItem = {
  codice: string
  valore: number
  unita: string
  periodoDal?: string | null
  periodoAl?: string | null
  dimensioni?: Record<string, string>
  calcolatoIl?: string
  formulaVersione?: string
  fonte?: string[]
  qualita: string
  flagQualita?: string[]
  stimato: boolean
  simulato: boolean
  nota?: string
}

type Notice = { id: string; titolo: string; testo: string; pubblico: string; pubblicatoIl: string; attivo: boolean }

function label(codice: string): string {
  const known: Record<string, string> = {
    ingressi_effettivi: 'Ingressi effettivi',
    picco_presenza: 'Picco di presenza',
    saturazione_pct: 'Saturazione',
  }
  return known[codice] ?? codice.replaceAll('_', ' ')
}

function formatValue(item: KpiItem): string {
  const value = new Intl.NumberFormat('it-IT', { maximumFractionDigits: 1 }).format(item.valore)
  if (item.unita === '%' || item.codice.endsWith('_pct')) return `${value}%`
  return value
}

function dimensioneRilevante(item: KpiItem): string {
  const dimensions = item.dimensioni ?? {}
  const key = ['varco', 'padiglione', 'area', 'giornata'].find((name) => dimensions[name])
  return key ? `${key}: ${dimensions[key]}` : 'evento'
}

function OperationsPage() {
  const [editions, setEditions] = useState<Edition[]>([])
  const [edition, setEdition] = useState('')
  const [kpis, setKpis] = useState<KpiItem[]>([])
  const [notices, setNotices] = useState<Notice[]>([])
  const [messages, setMessages] = useState<Record<string, string>>({})
  const [loading, setLoading] = useState(false)

  useEffect(() => {
    api<{ items: Edition[] }>('/edizioni')
      .then((data) => {
        const list = data.items ?? []
        setEditions(list)
        setEdition((current) => current || String(list[0]?.anno ?? '2026'))
      })
      .catch((error: unknown) => setMessages((current) => ({ ...current, editions: error instanceof Error ? error.message : 'Edizioni non disponibili.' })))
  }, [])

  const load = useCallback(async () => {
    if (!edition) return
    setLoading(true)
    setMessages({})
    const results = await Promise.allSettled([
      api<{ items: KpiItem[] }>(`/kpi/affluenza?edizione=${edition}`),
      api<{ items: Notice[] }>('/avvisi?pubblico=STAFF'),
    ] as const)
    const [affluenza, avvisi] = results
    setKpis(affluenza.status === 'fulfilled' ? affluenza.value.items ?? [] : [])
    setNotices(avvisi.status === 'fulfilled' ? avvisi.value.items ?? [] : [])
    const failures: Record<string, string> = {}
    if (affluenza.status === 'rejected') failures.affluenza = affluenza.reason instanceof Error ? affluenza.reason.message : 'Affluenza non disponibile.'
    if (avvisi.status === 'rejected') failures.notices = avvisi.reason instanceof Error ? avvisi.reason.message : 'Avvisi non disponibili.'
    setMessages(failures)
    setLoading(false)
  }, [edition])

  useEffect(() => { void load() }, [load])

  const byCode = new Map<string, KpiItem[]>()
  for (const item of kpis) {
    const list = byCode.get(item.codice) ?? []
    list.push(item)
    byCode.set(item.codice, list)
  }
  const ingressi = (byCode.get('ingressi_effettivi') ?? []).reduce((total, item) => total + item.valore, 0)
  const picco = (byCode.get('picco_presenza') ?? []).reduce((max, item) => Math.max(max, item.valore), 0)
  const saturazione = (byCode.get('saturazione_pct') ?? []).reduce((max, item) => Math.max(max, item.valore), 0)
  const lastUpdate = kpis.map((item) => item.calcolatoIl ?? '').filter(Boolean).sort().at(-1)

  return (
    <RequireRole roles={['STAFF', 'DIREZIONE', 'AMMINISTRATORE']}>
      <section className="operations-page">
        <div className="page-heading">
          <div>
            <p className="eyebrow">ARCADE MILANO · OPERATIVITÀ</p>
            <h2>Operatività evento</h2>
            <p className="intro">Affluenza per varco e padiglione, saturazione rispetto alla capienza e avvisi operativi per lo staff.</p>
          </div>
          <div className="edition-picker">
            <label>
              Edizione
              <select value={edition} onChange={(event) => setEdition(event.target.value)} disabled={loading}>
                {editions.length === 0 && <option value={edition}>{edition || '…'}</option>}
                {editions.map((item) => <option key={item.anno} value={item.anno}>{item.anno}{item.stato === 'ATTIVA' ? ' · attiva' : ''}</option>)}
              </select>
            </label>
          </div>
        </div>

        {messages.editions && <p className="alert alert--error" role="alert">{messages.editions}</p>}
        {messages.affluenza && <p className="alert alert--error" role="alert">{messages.affluenza}</p>}

        <div className="status-grid">
          <article className="status-card"><h3>Ingressi</h3><p className="status">{kpis.length ? new Intl.NumberFormat('it-IT').format(ingressi) : 'Non disponibile'}</p><small>{kpis.length ? 'somma delle letture valide ai varchi' : 'nessuna lettura pubblicata per questa edizione'}</small></article>
          <article className="status-card"><h3>Picco orario</h3><p className="status">{kpis.length ? new Intl.NumberFormat('it-IT').format(picco) : 'Non disponibile'}</p><small>{kpis.length ? 'massimo di ingressi in una singola ora' : 'dato assente non significa zero'}</small></article>
          <article className="status-card"><h3>Saturazione</h3><p className="status">{saturazione > 0 ? `${new Intl.NumberFormat('it-IT', { maximumFractionDigits: 1 }).format(saturazione)}%` : 'Non disponibile'}</p><small>limite superiore: mancano le uscite dai varchi · richiede la capienza configurata</small></article>
          <article className="status-card"><h3>Ultimo aggiornamento</h3><p className="status">{lastUpdate ? formatDate(lastUpdate) : '—'}</p><small>dato in ritardo va segnalato, non simulato</small></article>
        </div>

        <div className="content-grid content-grid--bottom">
          <section className="panel">
            <div className="panel-heading">
              <div><p className="eyebrow">AFFLUENZA</p><h3>Serie per varco e ora</h3></div>
              <span className="powered-by">Dati BID · calcolo BAD</span>
            </div>
            {kpis.length === 0
              ? <p className="quiet-state">Nessuna lettura disponibile: durante l'evento qui compaiono ingressi, esiti KO e scansioni scartate per varco e ora.</p>
              : (
                <div className="table-wrap">
                  <table>
                    <thead>
                      <tr><th>Indicatore</th><th>Ambito</th><th>Periodo</th><th>Valore</th><th>Qualità</th></tr>
                    </thead>
                    <tbody>
                      {kpis.map((item, index) => (
                        <tr key={`${item.codice}-${index}`}>
                          <td>{label(item.codice)}</td>
                          <td>{dimensioneRilevante(item)}</td>
                          <td>{item.periodoDal ? `${formatDate(item.periodoDal)}${item.periodoAl ? ` – ${formatDate(item.periodoAl)}` : ''}` : '—'}</td>
                          <td>{formatValue(item)} <small>{item.unita !== '%' ? item.unita : ''}</small></td>
                          <td><span className="quality-tag">{item.simulato ? 'SIMULATO' : item.stimato ? 'STIMATO' : item.qualita.replaceAll('_', ' ')}</span></td>
                        </tr>
                      ))}
                    </tbody>
                  </table>
                </div>
              )}
            <p className="form-note">Ogni avviso di saturazione mostra padiglione, ora e soglia applicata: il calcolo resta nell'API, non nel browser.</p>
          </section>

          <section className="panel">
            <div className="panel-heading">
              <div><p className="eyebrow">AVVISI OPERATIVI</p><h3>Comunicazioni per lo staff</h3></div>
              <span className="count-pill">{notices.length}</span>
            </div>
            {messages.notices
              ? <p className="quiet-state">{messages.notices}</p>
              : notices.length === 0
                ? <p className="quiet-state">Nessun avviso attivo per lo staff.</p>
                : notices.map((item) => (
                  <article className="notice-card" key={item.id}>
                    <div><strong>{item.titolo}</strong><small>{formatDate(item.pubblicatoIl)}</small></div>
                    <p>{item.testo}</p>
                  </article>
                ))}
            <div className="notice-section">
              <div className="panel-heading"><div><p className="eyebrow">TURNI</p><h3>Pianificazione del personale</h3></div></div>
              <p className="quiet-state">I turni e le aree assegnate non sono ancora disponibili via API: appariranno qui quando il contratto li includerà.</p>
            </div>
            <div className="notice-section">
              <p className="form-note">Dalla schermata di <Link to="/scansione">scansione allo stand</Link> puoi registrare le visite, secondo le tue autorizzazioni.</p>
            </div>
          </section>
        </div>
      </section>
    </RequireRole>
  )
}
