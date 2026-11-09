/**
 * Tipi del pannello di controllo direzione.
 *
 * Rispecchiano le risposte reali delle API BID (docs/openapi.yaml: KpiObservation,
 * KpiResponse). Il backend camelizza tutte le risposte, quindi i campi arrivano in
 * camelCase anche se in tabella sono in snake_case.
 */

/** Qualità dichiarata da BID per una singola osservazione. */
export type KpiQuality = 'OK' | 'ATTENZIONE' | 'DA_VERIFICARE'

/** Singola osservazione KPI restituita da GET /kpi/.... */
export type KpiObservation = {
  codice: string
  valore: number
  unita: string
  edizione: number
  periodoDal?: string | null
  periodoAl?: string | null
  dimensioni?: Record<string, string>
  calcolatoIl: string
  formulaVersione: string
  fonte: string[]
  qualita: KpiQuality
  flagQualita?: string[]
  stimato: boolean
  simulato: boolean
  nota?: string | null
}

/** Risposta di GET /kpi/direzione e GET /kpi/affluenza. */
export type KpiResponse = {
  edizione: number
  items: KpiObservation[]
}

/** Indicatori mostrati nelle card, indicizzati per codice reale. */
export type KpiData = {
  visitatoriVenduti: KpiObservation | null
  ingressiEffettivi: KpiObservation | null
  piccoPresenza: KpiObservation | null
  saturazionePct: KpiObservation | null
  ricavoPerMq: KpiObservation | null
}

/** Dati generici per i grafici Chart.js. */
export type ChartData = {
  labels: string[]
  datasets: Array<{
    label: string
    data: number[]
    backgroundColor?: string | string[]
    borderColor?: string
  }>
}
