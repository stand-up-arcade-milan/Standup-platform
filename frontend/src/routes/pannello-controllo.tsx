import { createFileRoute } from '@tanstack/react-router'
import { useState, useEffect, useCallback } from 'react'
import { KpiCard, FilterBar, ChartContainer } from '../components'
import { RequireRole } from '../components/RequireRole'
import { fetchEdizioni, fetchKpi, fetchAffluenza, fetchKpiItems } from '../services/dashboard'
import type { KpiData, KpiObservation, ChartData } from '../types/dashboard'
import {
  FaUsers,
  FaTicket,
  FaChartLine,
  FaPercent,
  FaMoneyBill,
  FaRotate,
  FaFileCsv,
  FaFilePdf,
  FaRotateLeft,
  FaGear,
} from 'react-icons/fa6'

const allowedRoles = ['DIREZIONE', 'AMMINISTRATORE']

export const Route = createFileRoute('/pannello-controllo')({
  component: () => (
    <RequireRole roles={allowedRoles}>
      <PannelloControlloPage />
    </RequireRole>
  ),
  loader: async () => {
    const edizioni = await fetchEdizioni()
    return { edizioni }
  },
})

/** Formatta il valore di un indicatore insieme alla sua unità di misura. */
function formatKpi(observation: KpiObservation | null): string {
  if (!observation) return '—'
  const value = observation.valore.toLocaleString('it-IT', { maximumFractionDigits: 2 })
  return observation.unita ? `${value} ${observation.unita}` : value
}

/** Intervallo di default: ultimi 30 giorni. */
function defaultRange() {
  return {
    from: new Date(new Date().setDate(new Date().getDate() - 30)).toISOString().split('T')[0],
    to: new Date().toISOString().split('T')[0],
  }
}

function PannelloControlloPage() {
  const { edizioni } = Route.useLoaderData()
  const [selectedEdizione, setSelectedEdizione] = useState<number>(edizioni[0] || 2026)
  const [dateRange, setDateRange] = useState(defaultRange)
  const [kpi, setKpi] = useState<KpiData | null>(null)
  const [affluenza, setAffluenza] = useState<ChartData | null>(null)
  const [loading, setLoading] = useState<boolean>(true)
  const [error, setError] = useState<string | null>(null)
  const [showSettings, setShowSettings] = useState<boolean>(false)

  const loadData = useCallback(async () => {
    try {
      setLoading(true)
      setError(null)
      const [kpiData, affluenzaData] = await Promise.all([
        fetchKpi(selectedEdizione, dateRange.from, dateRange.to),
        fetchAffluenza(selectedEdizione, dateRange.from, dateRange.to),
      ])
      setKpi(kpiData)
      setAffluenza(affluenzaData)
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Errore nel caricamento dei dati')
    } finally {
      setLoading(false)
    }
  }, [selectedEdizione, dateRange.from, dateRange.to])

  useEffect(() => {
    loadData()
  }, [loadData])

  // Card degli indicatori direzionali, allineate ai codici reali restituiti da BID.
  const cards = [
    { title: 'Visitatori venduti', observation: kpi?.visitatoriVenduti ?? null, icon: <FaUsers />, color: 'lime' as const },
    { title: 'Ingressi effettivi', observation: kpi?.ingressiEffettivi ?? null, icon: <FaTicket />, color: 'teal' as const },
    { title: 'Picco di presenza', observation: kpi?.piccoPresenza ?? null, icon: <FaChartLine />, color: 'brick' as const },
    { title: 'Saturazione', observation: kpi?.saturazionePct ?? null, icon: <FaPercent />, color: 'teal' as const },
    { title: 'Ricavo per m²', observation: kpi?.ricavoPerMq ?? null, icon: <FaMoneyBill />, color: 'lime' as const },
  ]

  const handleResetFiltri = () => {
    setSelectedEdizione(edizioni[0] || 2026)
    setDateRange(defaultRange())
  }

  const handleExportCSV = () => {
    if (!kpi) return
    const rows = [
      ['Metrica', 'Valore', 'Unità'],
      ['Edizione', String(selectedEdizione), ''],
      ['Periodo', `${dateRange.from} - ${dateRange.to}`, ''],
      ['', '', ''],
      ...cards.map((card) => [
        card.title,
        card.observation ? String(card.observation.valore) : '',
        card.observation?.unita ?? '',
      ]),
    ]
    const csvContent = rows.map((row) => row.join(',')).join('\n')
    const blob = new Blob([csvContent], { type: 'text/csv;charset=utf-8;' })
    const url = URL.createObjectURL(blob)
    const link = document.createElement('a')
    link.href = url
    link.download = `kpi-arcade-${selectedEdizione}-${dateRange.from}-${dateRange.to}.csv`
    link.click()
    URL.revokeObjectURL(url)
  }

  // Soluzione semplice: delega la stampa al browser (nessuna libreria aggiuntiva).
  const handleExportPDF = () => {
    window.print()
  }

  if (loading) {
    return (
      <div className="pannello-controllo">
        <h1>Pannello di Controllo</h1>
        <p className="quiet-state" role="status">Caricamento dati…</p>
      </div>
    )
  }

  if (error) {
    return (
      <div className="pannello-controllo">
        <h1>Pannello di Controllo</h1>
        <div className="alert alert--error">{error}</div>
        <button onClick={loadData} className="button button--lime">Riprova</button>
      </div>
    )
  }

  if (!kpi || !affluenza) {
    return (
      <div className="pannello-controllo">
        <h1>Pannello di Controllo</h1>
        <p className="quiet-state">Nessun dato disponibile</p>
      </div>
    )
  }

  return (
    <div className="pannello-controllo">
      <div className="page-heading">
        <div>
          <p className="eyebrow">DIREZIONE · ARCADE {selectedEdizione}</p>
          <h2>Pannello di Controllo</h2>
        </div>
        <div className="action-row">
          <button onClick={loadData} className="button button--lime" disabled={loading} title="Ricarica i dati">
            <FaRotate /> Aggiorna
          </button>
          <button onClick={handleExportCSV} className="button button--dark" title="Esporta in CSV">
            <FaFileCsv /> CSV
          </button>
          <button onClick={handleExportPDF} className="button button--dark" title="Esporta in PDF">
            <FaFilePdf /> PDF
          </button>
          <button onClick={handleResetFiltri} className="button button--dark" title="Resetta filtri">
            <FaRotateLeft /> Reset
          </button>
          <button onClick={() => setShowSettings(!showSettings)} className="button button--dark" title="Impostazioni">
            <FaGear /> Impostazioni
          </button>
        </div>
      </div>

      {/* Modal Impostazioni */}
      {showSettings && (
        <div className="modal-overlay" onClick={() => setShowSettings(false)}>
          <div className="modal" onClick={(e) => e.stopPropagation()}>
            <h2>Impostazioni Visualizzazione</h2>
            <div className="modal-body">
              <p>Personalizza la visualizzazione del pannello di controllo.</p>
              <div className="form-group">
                <label>
                  <input type="checkbox" defaultChecked /> Mostra KPI
                </label>
              </div>
              <div className="form-group">
                <label>
                  <input type="checkbox" defaultChecked /> Mostra Grafici
                </label>
              </div>
            </div>
            <div className="modal-footer">
              <button className="button" onClick={() => setShowSettings(false)}>
                Chiudi
              </button>
              <button className="button button--lime" onClick={() => setShowSettings(false)}>
                Salva
              </button>
            </div>
          </div>
        </div>
      )}

      <FilterBar
        edizioni={edizioni}
        selectedEdizione={selectedEdizione}
        from={dateRange.from}
        to={dateRange.to}
        onEdizioneChange={setSelectedEdizione}
        onDateRangeChange={(from, to) => setDateRange({ from, to })}
      />

      <div className="metric-grid" aria-label="Indicatori direzionali">
        {cards.map((card) => (
          <KpiCard
            key={card.title}
            title={card.title}
            value={formatKpi(card.observation)}
            icon={card.icon}
            color={card.color}
          />
        ))}
      </div>

      <div className="charts-grid">
        <ChartContainer type="line" data={affluenza} title="Andamento affluenza" height={350} />
      </div>

      <ConfrontoEdizioni edizioni={edizioni} edizioneCorrente={selectedEdizione} />
      <QualitaDati edizione={selectedEdizione} />
    </div>
  )
}

/** Etichette leggibili per i codici KPI reali restituiti da BID. */
const etichetteKpi: Record<string, string> = {
  ingressi_effettivi: 'Visitatori (ingressi)',
  ingressi_totale: 'Visitatori (ingressi)',
  biglietti_venduti: 'Biglietti venduti',
  persone_uniche: 'Persone uniche',
  picco_presenza: 'Picco di presenza',
  saturazione_pct: 'Saturazione',
  visitatori_per_m2: 'Visitatori per m²',
  ricavi_per_m2: 'Ricavi per m²',
  ricavo_per_mq: 'Ricavi per m²',
  ricavi_biglietteria: 'Ricavi biglietteria',
  ricavo_medio_biglietto: 'Ricavo medio per biglietto',
  no_show_pct: 'Biglietti non utilizzati',
  stand_venduti_pct: 'Stand venduti',
  mq_venduti_pct: 'm² venduti',
  sconto_medio_pct: 'Sconto medio',
  mql: 'Contatti raccolti (MQL)',
  contatti: 'Contatti raccolti',
  contatti_per_100_scansioni: 'Contatti per 100 scansioni',
  costo_per_contatto: 'Costo per contatto',
  costo_per_mql: 'Costo per contatto',
  resa_lead_magnet: 'Resa lead magnet',
  interesse_pubblico: 'Interesse pubblico',
}

function etichettaKpi(codice: string): string {
  return etichetteKpi[codice] ?? codice.replaceAll('_', ' ')
}

function formatValore(item: KpiObservation): string {
  const value = new Intl.NumberFormat('it-IT', { maximumFractionDigits: 1 }).format(item.valore)
  if (item.unita === '%' || item.codice.endsWith('_pct')) return `${value}%`
  if (item.unita === 'EUR' || item.unita === '€') return `€ ${value}`
  return value
}

function qualityTag(item: KpiObservation): string {
  if (item.simulato) return 'SIMULATO'
  if (item.stimato) return 'STIMATO'
  return item.qualita.replaceAll('_', ' ')
}

/** Un codice può avere più osservazioni (giornate/aree): vale l'ultima, contate le altre. */
function latestByCode(items: KpiObservation[]): Map<string, KpiObservation[]> {
  const grouped = new Map<string, KpiObservation[]>()
  for (const item of items) {
    const list = grouped.get(item.codice) ?? []
    list.push(item)
    grouped.set(item.codice, list)
  }
  for (const list of grouped.values()) {
    list.sort((a, b) => String(a.periodoAl ?? a.periodoDal ?? '').localeCompare(String(b.periodoAl ?? b.periodoDal ?? '')))
  }
  return grouped
}

/** Stesso indicatore affiancato tra le edizioni: assenza = vuoto, mai zero. */
function ConfrontoEdizioni({ edizioni, edizioneCorrente }: { edizioni: number[]; edizioneCorrente: number }) {
  const [batches, setBatches] = useState<Record<number, KpiObservation[]>>({})
  const [message, setMessage] = useState('')

  useEffect(() => {
    let cancelled = false
    Promise.allSettled(edizioni.map((anno) => fetchKpiItems(anno)))
      .then((results) => {
        if (cancelled) return
        const next: Record<number, KpiObservation[]> = {}
        results.forEach((result, index) => {
          next[edizioni[index]] = result.status === 'fulfilled' ? result.value : []
        })
        setBatches(next)
        setMessage('')
      })
    return () => { cancelled = true }
  }, [edizioni])

  const codes = Array.from(new Set(Object.values(batches).flatMap((items) => items.map((item) => item.codice)))).sort()
  return (
    <section className="panel">
      <div className="panel-heading">
        <div><p className="eyebrow">CONFRONTO TRA EDIZIONI</p><h3>Stesso indicatore, edizioni a fianco</h3></div>
        <span className="powered-by">Dati BID · calcolo BAD</span>
      </div>
      {codes.length === 0
        ? <p className="quiet-state">Nessun lotto KPI disponibile: il confronto appare quando BAD pubblica gli indicatori.</p>
        : (
          <div className="table-wrap">
            <table>
              <thead>
                <tr>
                  <th>Indicatore</th>
                  {edizioni.map((anno) => <th key={anno}>{anno}{anno === edizioneCorrente ? ' · corrente' : ''}</th>)}
                  <th>Qualità</th>
                </tr>
              </thead>
              <tbody>
                {codes.map((code) => (
                  <tr key={code}>
                    <td>{etichettaKpi(code)}</td>
                    {edizioni.map((anno) => {
                      const grouped = latestByCode(batches[anno] ?? [])
                      const list = grouped.get(code)
                      const item = list?.[list.length - 1]
                      return <td key={anno}>{item ? formatValore(item) : <span className="muted">Non disponibile</span>}</td>
                    })}
                    <td><span className="quality-tag">{(() => { const grouped = latestByCode(batches[edizioneCorrente] ?? []); const item = grouped.get(code)?.at(-1); return item ? qualityTag(item) : '—' })()}</span></td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      <p className="form-note">Le percentuali si confrontano in punti percentuali, i valori in variazione relativa. Un'edizione senza lotto resta vuota, non a zero.</p>
      {message && <p className="alert alert--error" role="alert">{message}</p>}
    </section>
  )
}

/** Come leggere i numeri: qualità, stime, simulazioni e ultimo aggiornamento. */
function QualitaDati({ edizione }: { edizione: number }) {
  const [items, setItems] = useState<KpiObservation[]>([])
  const [message, setMessage] = useState('')

  useEffect(() => {
    let cancelled = false
    fetchKpiItems(edizione)
      .then((value) => { if (!cancelled) { setItems(value); setMessage('') } })
      .catch((error: unknown) => { if (!cancelled) setMessage(error instanceof Error ? error.message : 'Qualità non disponibile.') })
    return () => { cancelled = true }
  }, [edizione])

  const segnalate = items.filter((item) => item.stimato || item.simulato || (item.flagQualita?.length ?? 0) > 0 || item.nota)
  const lastUpdate = items.map((item) => item.calcolatoIl).filter(Boolean).sort().at(-1)
  return (
    <section className="panel">
      <div className="panel-heading">
        <div><p className="eyebrow">QUALITÀ DEI DATI</p><h3>Come leggere i numeri</h3></div>
        {lastUpdate && <span className="count-pill">Ultimo aggiornamento {new Date(lastUpdate).toLocaleDateString('it-IT', { dateStyle: 'medium' })}</span>}
      </div>
      {message
        ? <p className="quiet-state">{message}</p>
        : segnalate.length === 0
          ? <p className="quiet-state">Nessuna segnalazione di qualità per questa edizione.</p>
          : (
            <div className="kpi-list">
              {segnalate.map((item, index) => (
                <article className="kpi-row" key={`${item.codice}-${index}`}>
                  <div>
                    <strong>{etichettaKpi(item.codice)}</strong>
                    <small>{item.nota ?? item.formulaVersione ?? item.qualita}{item.flagQualita?.length ? ` · ${item.flagQualita.join(', ')}` : ''}</small>
                  </div>
                  <span className="kpi-value">{formatValore(item)}</span>
                  <span className="quality-tag">{qualityTag(item)}</span>
                </article>
              ))}
            </div>
          )}
    </section>
  )
}
