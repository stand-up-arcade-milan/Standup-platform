import { createRootRoute, Link, Outlet } from '@tanstack/react-router'
import { AuthProvider, useAuth } from '../components/AuthProvider'

/** Navigation component with role-based links */
function Navigation() {
  const { role } = useAuth()
  const isAdmin = role === 'DIREZIONE' || role === 'AMMINISTRATORE'

  return (
    <nav aria-label="Navigazione principale">
      <Link to="/commerciale" activeProps={{ className: 'active' }}>
        Commerciale
      </Link>
      <Link to="/espositore" activeProps={{ className: 'active' }}>
        Area espositore
      </Link>
      <Link to="/scansione" activeProps={{ className: 'active' }}>
        Scansione stand
      </Link>
      {isAdmin && (
        <Link to="/pannello-controllo" activeProps={{ className: 'active' }}>
          Pannello di Controllo
        </Link>
      )}
    </nav>
  )
}

/** Shared page frame; future screens can be nested under this layout. */
export const Route = createRootRoute({
  component: RootLayout,
  notFoundComponent: () => <p className="notice">Schermata non trovata.</p>,
})

function RootLayout() {
  return (
    <AuthProvider>
      <div className="shell">
        <a className="skip-link" href="#main-content">Vai al contenuto</a>
        <header className="topbar">
          <div>
            <p className="eyebrow">ARCADE MILANO &middot; PIATTAFORMA</p>
            <h1><span className="brand-mark">S</span>Stand up</h1>
          </div>
          <Navigation />
        </header>
        <main id="main-content">
          <Outlet />
        </main>
        <footer className="site-footer">
          <span>ARCADE MILANO 2026</span>
          <span>Un'unica piattaforma, dati condivisi.</span>
          <Link to="/" className="footer-link">Stato servizi</Link>
        </footer>
      </div>
    </AuthProvider>
  )
}
