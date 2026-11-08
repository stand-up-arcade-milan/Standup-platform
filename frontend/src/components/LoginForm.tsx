import { useState, FormEvent } from 'react';
import { useAuth } from './AuthProvider';

export type LoginFormProps = {
  title?: string;
  subtitle?: string;
  showRecoveryLink?: boolean;
};

export function LoginForm({
  title = 'Entra nella tua area',
  subtitle = 'Usa l\\'account associato al tuo invito.',
  showRecoveryLink = true,
}: LoginFormProps) {
  const { login, isLoading, error, setAuthMode } = useAuth();
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');

  const handleSubmit = async (event: FormEvent) => {
    event.preventDefault();
    await login({ email, password });
  };

  return (
    <form className="auth-form" onSubmit={handleSubmit}>
      <p className="eyebrow">ACCESSO RISERVATO</p>
      <h3>{title}</h3>
      <p className="muted">{subtitle}</p>

      {error && <p className="alert alert--error" role="alert">{error}</p>}

      <label>
        Email
        <input
          type="email"
          autoComplete="username"
          required
          value={email}
          onChange={(e) => setEmail(e.target.value)}
          disabled={isLoading}
        />
      </label>

      <label>
        Password
        <input
          type="password"
          autoComplete="current-password"
          required
          value={password}
          onChange={(e) => setPassword(e.target.value)}
          disabled={isLoading}
        />
      </label>

      <button className="button button--lime button--wide" disabled={isLoading}>
        {isLoading ? 'Accesso...' : 'Accedi'}
      </button>

      {showRecoveryLink && (
        <button
          type="button"
          className="text-button"
          onClick={() => setAuthMode('recovery')}
        >
          Hai dimenticato la password?
        </button>
      )}
    </form>
  );
}

export function RecoveryForm() {
  const { requestRecovery, isLoading, error, successMessage, setAuthMode, clearError } = useAuth();
  const [email, setEmail] = useState('');

  const handleSubmit = async (event: FormEvent) => {
    event.preventDefault();
    clearError();
    await requestRecovery(email);
  };

  return (
    <form className="auth-form" onSubmit={handleSubmit}>
      <p className="eyebrow">RECUPERO ACCESSO</p>
      <h3>Richiedi un nuovo link</h3>
      <p className="muted">Inserisci l'email associata al tuo account.</p>

      {successMessage && <p className="alert alert--success" role="status">{successMessage}</p>}
      {error && <p className="alert alert--error" role="alert">{error}</p>}

      <label>
        Email
        <input
          type="email"
          autoComplete="email"
          required
          value={email}
          onChange={(e) => setEmail(e.target.value)}
          disabled={isLoading}
        />
      </label>

      <button className="button button--lime button--wide" disabled={isLoading}>
        {isLoading ? 'Invio...' : 'Richiedi recupero'}
      </button>

      <button
        type="button"
        className="text-button"
        onClick={() => setAuthMode('reset')}
      >
        Ho già un token di recupero
      </button>

      <button
        type="button"
        className="text-button text-button--muted"
        onClick={() => setAuthMode('login')}
      >
        Torna all'accesso
      </button>
    </form>
  );
}

export function ResetForm() {
  const { resetPassword, isLoading, error, setAuthMode, clearError } = useAuth();
  const [recoveryToken, setRecoveryToken] = useState('');
  const [newPassword, setNewPassword] = useState('');

  const handleSubmit = async (event: FormEvent) => {
    event.preventDefault();
    clearError();
    await resetPassword(recoveryToken, newPassword);
  };

  return (
    <form className="auth-form" onSubmit={handleSubmit}>
      <p className="eyebrow">NUOVA PASSWORD</p>
      <h3>Reimposta l'accesso</h3>
      <p className="muted">Usa il token ricevuto.</p>

      {error && <p className="alert alert--error" role="alert">{error}</p>}

      <label>
        Token di recupero
        <input
          required
          autoComplete="one-time-code"
          value={recoveryToken}
          onChange={(e) => setRecoveryToken(e.target.value)}
          disabled={isLoading}
        />
      </label>

      <label>
        Nuova password
        <input
          type="password"
          required
          minLength={12}
          autoComplete="new-password"
          value={newPassword}
          onChange={(e) => setNewPassword(e.target.value)}
          disabled={isLoading}
        />
      </label>

      <small className="form-note">La password deve contenere almeno 12 caratteri.</small>

      <button className="button button--lime button--wide" disabled={isLoading}>
        {isLoading ? 'Aggiornamento...' : 'Imposta password'}
      </button>

      <button
        type="button"
        className="text-button text-button--muted"
        onClick={() => setAuthMode('login')}
      >
        Torna all'accesso
      </button>
    </form>
  );
}
