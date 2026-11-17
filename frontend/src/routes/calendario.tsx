import { createFileRoute, Link } from '@tanstack/react-router'

export const Route = createFileRoute('/calendario')({
  component: CalendarioPage,
})

function CalendarioPage() {
  return (
    <section className="home-section">
      <p className="eyebrow">CALENDARIO</p>
      <h2>Masterclass in arrivo</h2>
      <div className="panel ticket-panel">
        <p className="home-hero__lead">
          Il programma delle masterclass e degli eventi in calendario è in preparazione.
          Torna a trovarci a breve per la lista completa.
        </p>
        <button type="button" className="button button--dark" disabled title="Calendario in arrivo">
          Presto disponibile
        </button>
      </div>
      <p className="footnote">
        <Link to="/">Torna alla home</Link>
      </p>
    </section>
  )
}
