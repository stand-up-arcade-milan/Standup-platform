import type { ReactNode } from 'react'

type KpiCardProps = {
  title: string
  value: string | number
  icon: ReactNode
  color: 'lime' | 'teal' | 'brick'
}

/** Card di un indicatore: riusa lo stile `.metric-card` del resto della piattaforma. */
export function KpiCard({ title, value, icon, color }: KpiCardProps) {
  return (
    <article className={`metric-card metric-card--${color}`}>
      <span aria-hidden="true">{icon}</span>
      <span>{title}</span>
      <strong>{value}</strong>
    </article>
  )
}
