const base = '/api/v1'
const exhibitorTokenKey = 'standup.exhibitor.token'
const internalTokenKey = 'standup.internal.token'

export type ApiProblem = {
  code?: string
  detail?: string
  title?: string
  status?: number
}

export class ApiError extends Error {
  status: number
  code?: string

  constructor(status: number, problem?: ApiProblem) {
    super(problem?.detail ?? problem?.title ?? `Richiesta non riuscita (${status})`)
    this.status = status
    this.code = problem?.code
  }
}

export function saveToken(kind: 'exhibitor' | 'internal', value: string) {
  sessionStorage.setItem(kind === 'exhibitor' ? exhibitorTokenKey : internalTokenKey, value)
}

export function readToken(kind: 'exhibitor' | 'internal') {
  return sessionStorage.getItem(kind === 'exhibitor' ? exhibitorTokenKey : internalTokenKey)
}

export function clearToken(kind: 'exhibitor' | 'internal') {
  sessionStorage.removeItem(kind === 'exhibitor' ? exhibitorTokenKey : internalTokenKey)
}

export async function api<T>(path: string, options: RequestInit = {}, tokenKind?: 'exhibitor' | 'internal'): Promise<T> {
  const headers = new Headers(options.headers)
  if (options.body && !headers.has('Content-Type')) headers.set('Content-Type', 'application/json')
  const token = tokenKind ? readToken(tokenKind) : null
  if (token) headers.set('Authorization', `Bearer ${token}`)

  const response = await fetch(`${base}${path}`, { ...options, headers })
  if (response.status === 204) return undefined as T
  const body = await response.json().catch(() => undefined)
  if (!response.ok) throw new ApiError(response.status, body as ApiProblem | undefined)
  return body as T
}

export function query(values: Record<string, string | number | boolean | undefined>) {
  const params = new URLSearchParams()
  for (const [key, value] of Object.entries(values)) {
    if (value !== undefined && String(value).length) params.set(key, String(value))
  }
  return params.size ? `?${params}` : ''
}

export function formatEuro(value?: number | null) {
  if (value == null) return 'Non disponibile'
  return new Intl.NumberFormat('it-IT', { style: 'currency', currency: 'EUR' }).format(value)
}

export function formatDate(value?: string | null) {
  if (!value) return 'Non disponibile'
  const date = new Date(value)
  return Number.isNaN(date.valueOf()) ? value : new Intl.DateTimeFormat('it-IT', { dateStyle: 'medium' }).format(date)
}
