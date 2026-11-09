import { createFileRoute, Navigate } from '@tanstack/react-router'
import { useState, useEffect, useCallback } from 'react'
import { KpiCard, FilterBar, ChartContainer } from '../components'
import { useAuth } from '../components/AuthProvider'
import { fetchEdizioni, fetchKpi, fetchAffluenza } from '../services/dashboard'
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
  component: PannelloControlloPage,
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
  const { isAuthenticated, role } = useAuth()
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

  if (!isAuthenticated || !allowedRoles.includes(role ?? '')) {
    return <Navigate to="/accesso" />
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
    </div>
  )
}
