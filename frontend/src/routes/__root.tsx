import { createRootRoute, Link, Outlet, useNavigate } from '@tanstack/react-router'
import { AuthProvider, useAuth } from '../components/AuthProvider'

/** Shared page frame; future screens can be nested under this layout. */
export const Route = createRootRoute({
  component: RootLayout,
  notFoundComponent: () => <p className="notice">Schermata non trovata.</p>,
})

const RUOLI_LABEL: Record<string, string> = {
  DIREZIONE: 'Direzione',
  COMMERCIALE: 'Commerciale',
  STAFF: 'Staff',
  ESPOSITORE: 'Espositore',
  AMMINISTRATORE: 'Amministratore',
}

type NavItem = { to: string; label: string; roles: string[] }

const NAV: NavItem[] = [
  { to: '/commerciale', label: 'Commerciale', roles: ['COMMERCIALE', 'AMMINISTRATORE'] },
  { to: '/espositore', label: 'Area espositore', roles: ['ESPOSITORE', 'AMMINISTRATORE'] },
  { to: '/scansione', label: 'Scansione stand', roles: ['STAFF', 'ESPOSITORE', 'AMMINISTRATORE'] },
]

function RootLayout() {
  return (
    <AuthProvider>
      <Shell />
    </AuthProvider>
  )
}

function Shell() {
  const { session, logout, successMessage } = useAuth()
  const navigate = useNavigate()
  const role = session?.role ?? null
  const visible = NAV.filter((item) => role && item.roles.includes(role))

  return (
    <div className="shell">
      <a className="skip-link" href="#main-content">Vai al contenuto</a>
      <header className="topbar">
        <div>
          <p className="eyebrow">ARCADE MILANO &middot; PIATTAFORMA</p>
          <h1><span className="brand-mark">S</span>Stand up</h1>
        </div>
        <nav aria-label="Navigazione principale">
          {visible.map((item) => (
            <Link key={item.to} to={item.to} activeProps={{ className: 'active' }}>
              {item.label}
            </Link>
          ))}
          {session ? (
            <span className="session-chip">
              <span className="session-role">{RUOLI_LABEL[session.role] ?? session.role}</span>
              <button
                type="button"
                className="text-button"
                onClick={() => {
                  logout()
                  void navigate({ to: '/accesso' })
                }}
              >
                Esci
              </button>
            </span>
          ) : (
            <Link to="/accesso" activeProps={{ className: 'active' }}>Accedi</Link>
          )}
        </nav>
      </header>
      {successMessage && <p className="alert alert--success" role="status">{successMessage}</p>}
      <main id="main-content">
        <Outlet />
      </main>
      <footer className="site-footer">
        <span>ARCADE MILANO 2026</span>
        <span>Un'unica piattaforma, dati condivisi.</span>
        <Link to="/" className="footer-link">Stato servizi</Link>
      </footer>
    </div>
  )
}
