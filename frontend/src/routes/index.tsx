import { createFileRoute } from '@tanstack/react-router'
import { loadServiceHealth } from '../services/serviceHealth'

// A route loader makes the connection checks explicit and easy to replace later.
export const Route = createFileRoute('/')({
  loader: loadServiceHealth,
  component: ConnectionsPage,
})

function ConnectionsPage() {
  const health = Route.useLoaderData()

  return (
    <section>
      <p className="eyebrow">BOILERPLATE</p>
      <h2>Connessioni dei servizi</h2>
      <p className="intro">
        Questa pagina verifica il percorso browser → Vite → Spring Boot → PostgreSQL.
      </p>
      <div className="status-grid">
        <StatusCard title="API Spring Boot" status={health.api.status} detail={health.api.detail} />
        <StatusCard title="PostgreSQL via Actuator" status={health.database.status} detail={health.database.detail} />
      </div>
      <p className="footnote">
        Gli endpoint di stato servono solo a verificare l'ambiente locale; qui non ci sono flussi applicativi.
      </p>
    </section>
  )
}

function StatusCard({ title, status, detail }: { title: string; status: string; detail: string }) {
  return (
    <article className="status-card">
      <h3>{title}</h3>
      <p className={`status status--${status.toLowerCase()}`}>{status}</p>
      <code>{detail}</code>
    </article>
  )
}
