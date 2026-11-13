import { createRootRoute, Link, Outlet } from '@tanstack/react-router'
import { AuthProvider } from '../components/AuthProvider'

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
          </nav>
        </header>
        <main id="main-content">
          <Outlet />
        </main>
        <footer className="site-footer">
          <span>ARCADE MILANO 2026</span>
          <span>Un'unica piattaforma, dati condivisi.</span>
          <Link to="/" className="footer-link">Home</Link>
        </footer>
      </div>
    </AuthProvider>
  )
}
