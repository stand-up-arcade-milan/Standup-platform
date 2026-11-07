import { createRootRoute, Link, Outlet } from '@tanstack/react-router'

/** Shared page frame; future screens can be nested under this layout. */
export const Route = createRootRoute({
  component: RootLayout,
  notFoundComponent: () => <p className="notice">Schermata non trovata.</p>,
})

function RootLayout() {
  return (
    <div className="shell">
      <header className="topbar">
        <div>
          <p className="eyebrow">ARCADE MILANO · PIATTAFORMA</p>
          <h1>Stand up</h1>
        </div>
        <nav aria-label="Navigazione principale">
          <Link to="/" activeProps={{ className: 'active' }}>
            Connessioni
          </Link>
          <Link to="/about" activeProps={{ className: 'active' }}>
            Architettura
          </Link>
        </nav>
      </header>
      <main>
        <Outlet />
      </main>
    </div>
  )
}
