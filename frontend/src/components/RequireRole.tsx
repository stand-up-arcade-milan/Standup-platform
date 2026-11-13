import type { ReactNode } from 'react';
import { Link } from '@tanstack/react-router';
import { useAuth } from './AuthProvider';

type RequireRoleProps = {
  roles: string[];
  children: ReactNode;
};

const RUOLI_LABEL: Record<string, string> = {
  DIREZIONE: 'Direzione',
  COMMERCIALE: 'Commerciale',
  STAFF: 'Staff operativo',
  ESPOSITORE: 'Espositore',
  AMMINISTRATORE: 'Amministratore',
};

function ruoloLabel(role: string): string {
  return RUOLI_LABEL[role] ?? role;
}

/**
 * La verifica del ruolo qui serve solo a mostrare il messaggio giusto:
 * l'autorizzazione effettiva la applica il server su ogni richiesta.
 */
export function RequireRole({ roles, children }: RequireRoleProps) {
  const { session } = useAuth();

  if (!session) {
    return (
      <section className="panel auth-guard">
        <div className="panel-heading"><div><p className="eyebrow">ACCESSO RICHIESTO</p><h3>Sessione non attiva</h3></div></div>
        <p>Per vedere questa schermata devi prima accedere con il tuo account.</p>
        <Link className="button button--lime" to="/accesso">Vai all'accesso</Link>
      </section>
    );
  }

  if (!roles.includes(session.role)) {
    return (
      <section className="panel auth-guard">
        <div className="panel-heading"><div><p className="eyebrow">ACCESSO NON AUTORIZZATO</p><h3>Area riservata</h3></div></div>
        <p>
          Sei acceduto come <strong>{ruoloLabel(session.role)}</strong>, ma questa schermata &egrave; riservata a:{' '}
          <strong>{roles.map(ruoloLabel).join(', ')}</strong>.
        </p>
        <p className="muted">Se ritieni di doverci accedere, contatta la direzione per aggiornare il tuo ruolo.</p>
        <Link className="button button--outline" to="/accesso">Cambio account</Link>
      </section>
    );
  }

  return <>{children}</>;
}
