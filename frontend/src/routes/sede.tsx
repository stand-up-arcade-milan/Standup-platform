import { createFileRoute, Link } from '@tanstack/react-router'

export const Route = createFileRoute('/sede')({
  component: SedePage,
})

function SedePage() {
  return (
    <section className="home-section">
      <p className="eyebrow">SEDE</p>
      <h2>Mappa in arrivo</h2>
      <div className="panel ticket-panel">
        <p className="home-hero__lead">
          La sede della fiera è ancora in definizione. Appena sarà confermata, qui
          troverai l'indirizzo e la mappa per raggiungerla.
        </p>
        <button type="button" className="button button--dark" disabled title="Sede in definizione">
          Presto disponibile
        </button>
      </div>
      <p className="footnote">
        <Link to="/">Torna alla home</Link>
      </p>
    </section>
  )
}
