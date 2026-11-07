import { createFileRoute } from '@tanstack/react-router'

export const Route = createFileRoute('/about')({
  component: ArchitecturePage,
})

function ArchitecturePage() {
  return (
    <section>
      <p className="eyebrow">MAPPA LOCALE</p>
      <h2>Architettura di sviluppo</h2>
      <ul className="architecture-list">
        <li><strong>Vite</strong> serve il frontend sulla porta 5173 e inoltra le richieste API.</li>
        <li><strong>Spring Boot</strong> espone l'API sulla porta 8080.</li>
        <li><strong>PostgreSQL</strong> ascolta sulla porta 5432; nel network Compose si chiama <code>db</code>.</li>
      </ul>
      <p className="footnote">Tra container si usano i nomi dei servizi Compose, non <code>localhost</code>.</p>
    </section>
  )
}
