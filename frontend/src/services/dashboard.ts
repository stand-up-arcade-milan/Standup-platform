import { api, query } from './api'
import type { ChartData, KpiData, KpiObservation, KpiResponse } from '../types/dashboard'

/** Edizione come restituita da GET /edizioni. */
export type Edizione = {
  anno: number
  sede?: string | null
  stato?: 'PIANIFICATA' | 'ATTIVA' | 'CONCLUSA'
}

/** Anni delle edizioni disponibili, dalla più recente. Endpoint pubblico. */
export async function fetchEdizioni(): Promise<number[]> {
  const data = await api<{ items: Edizione[] }>('/edizioni')
  return (data.items ?? []).map((edizione) => edizione.anno).sort((a, b) => b - a)
}

/** Indicatori del cruscotto direzionale (GET /kpi/direzione). */
export async function fetchKpi(edizione: number, dal?: string, al?: string): Promise<KpiData> {
  const data = await api<KpiResponse>(
    `/kpi/direzione${query({ edizione, dal, al })}`,
    {},
    'exhibitor',
  )
  const byCode = new Map((data.items ?? []).map((item) => [item.codice, item]))
  return {
    visitatoriVenduti: byCode.get('visitatori_venduti') ?? null,
    ingressiEffettivi: byCode.get('ingressi_effettivi') ?? null,
    piccoPresenza: byCode.get('picco_presenza') ?? null,
    saturazionePct: byCode.get('saturazione_pct') ?? null,
    ricavoPerMq: byCode.get('ricavo_per_mq') ?? null,
  }
}

/** Etichette leggibili per i codici di affluenza restituiti da BID. */
const etichetteAffluenza: Record<string, string> = {
  ingressi_effettivi: 'Ingressi effettivi',
  picco_presenza: 'Picco di presenza',
  saturazione_pct: 'Saturazione (%)',
}

/** Serie di affluenza per il grafico (GET /kpi/affluenza). */
export async function fetchAffluenza(edizione: number, dal?: string, al?: string): Promise<ChartData> {
  const data = await api<KpiResponse>(
    `/kpi/affluenza${query({ edizione, dal, al })}`,
    {},
    'exhibitor',
  )
  const items: KpiObservation[] = data.items ?? []
  return {
    labels: items.map((item) => etichetteAffluenza[item.codice] ?? item.codice),
    datasets: [
      {
        label: 'Affluenza',
        data: items.map((item) => item.valore),
        borderColor: '#cbff8c',
        backgroundColor: 'rgba(203, 255, 140, 0.2)',
      },
    ],
  }
}
