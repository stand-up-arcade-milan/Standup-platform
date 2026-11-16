import { createFileRoute, Link } from '@tanstack/react-router'

export const Route = createFileRoute('/biglietteria')({
  component: BigliettiPage,
})

function BigliettiPage() {
  return (
    <section className="home-section">
      <p className="eyebrow">BIGLIETTERIA</p>
      <h2>Biglietteria in arrivo</h2>
      <div className="panel ticket-panel">
        <p className="home-hero__lead">
          Stiamo timbrando gli ultimi biglietti. A breve qui potrai scaricare il pass gratuito
          e pagare con Satispay, Google Pay o Apple Pay.
        </p>
        <button type="button" className="button button--dark" disabled title="Biglietteria in arrivo">
          Presto disponibile
        </button>
        <p className="footnote">
          Punto aperto: link alla biglietteria reale da confermare con il cliente
          (vedi docs/decisioni-da-confermare.md).
        </p>
      </div>
      <p className="footnote">
        <Link to="/">Torna alla home</Link>
      </p>
    </section>
  )
}
