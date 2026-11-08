import { createFileRoute, useNavigate } from '@tanstack/react-router';
import { useState, useEffect, useCallback } from 'react';
import { GoogleOAuthProvider, useGoogleLogin } from '@react-oauth/google';
import { useAuth } from '../components/AuthProvider';
import { LoginForm, RecoveryForm, ResetForm } from '../components/LoginForm';

const GOOGLE_CLIENT_ID = import.meta.env.VITE_GOOGLE_OAUTH_CLIENT_ID ?? '';
const MICROSOFT_CLIENT_ID = import.meta.env.VITE_MICROSOFT_OAUTH_CLIENT_ID ?? '';

/**
 * Il server verifica la firma dell'ID token e ne ricava identificativo ed email,
 * quindi al backend va mandato solo il token: email e subject presi dal browser
 * sarebbero dichiarazioni non verificate.
 */
function MicrosoftLoginButton({ onSuccess }: { onSuccess: (token: string) => void }) {
  const configurato = MICROSOFT_CLIENT_ID !== '';
  return (
    <button
      type="button"
      className="button button--oauth"
      disabled={!configurato}
      onClick={() => {
        if (!configurato) return;
        onSuccess('');
      }}
      title={configurato ? undefined : "Accesso non ancora disponibile: manca la registrazione dell'app su Entra ID"}
    >
      <svg className="oauth-icon" viewBox="0 0 24 24" width="20" height="20" aria-hidden="true">
        <path fill="#F25022" d="M2 2h9.2v9.2H2z" />
        <path fill="#7FBA00" d="M12.8 2H22v9.2h-9.2z" />
        <path fill="#00A4EF" d="M2 12.8h9.2V22H2z" />
        <path fill="#FFB900" d="M12.8 12.8H22V22h-9.2z" />
      </svg>
      <span className="oauth-etichetta">Continua con Microsoft</span>
      {!configurato && <span className="oauth-nota">non ancora attivo</span>}
    </button>
  );
}

function GoogleLoginButton({ onSuccess, onError }: { onSuccess: (token: string) => void; onError: (messaggio: string) => void }) {
  const configurato = GOOGLE_CLIENT_ID !== '';
  const login = useGoogleLogin({
    flow: 'implicit',
    scope: 'openid email profile',
    onSuccess: (risposta) => {
      // Con il flusso implicito arriva un access token, che non e un ID token e che il
      // server rifiuterebbe. L'ID token sta in credential quando Google lo restituisce.
      const idToken = (risposta as { credential?: string }).credential;
      if (!idToken) {
        onError("Google non ha restituito un ID token. Verifica la configurazione del client OAuth.");
        return;
      }
      onSuccess(idToken);
    },
    onError: () => onError('Accesso con Google non riuscito.'),
  });

  return (
    <button
      type="button"
      className="button button--oauth"
      disabled={!configurato}
      onClick={() => configurato && login()}
      title={configurato ? undefined : "Accesso non ancora disponibile: manca il client OAuth di Google"}
    >
      <svg className="oauth-icon" viewBox="0 0 24 24" width="20" height="20" aria-hidden="true">
        <path fill="#4285F4" d="M22.56 12.25c0-.78-.07-1.53-.2-2.25H12v4.26h5.92c-.26 1.37-1.04 2.53-2.21 3.31v2.77h3.57c2.08-1.92 3.28-4.74 3.28-8.09z" />
        <path fill="#34A853" d="M12 23c2.97 0 5.46-.98 7.28-2.66l-3.57-2.77c-.98.66-2.23 1.06-3.71 1.06-2.86 0-5.29-1.93-6.16-4.53H2.18v2.84C3.99 20.53 7.7 23 12 23z" />
        <path fill="#FBBC05" d="M5.84 14.09c-.22-.66-.35-1.36-.35-2.09s.13-1.43.35-2.09V7.07H2.18C1.43 8.55 1 10.22 1 12s.43 3.45 1.18 4.93l2.85-2.22.81-.62z" />
        <path fill="#EA4335" d="M12 5.38c1.62 0 3.06.56 4.21 1.64l3.15-3.15C17.45 2.09 14.97 1 12 1 7.7 1 3.99 3.47 2.18 7.07l3.66 2.84c.87-2.6 3.3-4.53 6.16-4.53z" />
      </svg>
      <span className="oauth-etichetta">Continua con Google</span>
      {!configurato && <span className="oauth-nota">non ancora attivo</span>}
    </button>
  );
}

function AuthPage() {
  const { isAuthenticated, authMode, loginWithOAuth } = useAuth();
  const navigate = useNavigate();
  const [oauthError, setOauthError] = useState<string | null>(null);

  useEffect(() => {
    if (isAuthenticated) void navigate({ to: '/espositore' });
  }, [isAuthenticated, navigate]);

  const handleOAuthSuccess = useCallback(async (token: string, provider: 'google' | 'microsoft') => {
    setOauthError(null);
    try {
      await loginWithOAuth({ provider, token });
    } catch (error) {
      setOauthError(error instanceof Error ? error.message : 'Accesso con il fornitore non riuscito.');
    }
  }, [loginWithOAuth]);

  const renderAuthForm = () => {
    switch (authMode) {
      case 'recovery': return <RecoveryForm />;
      case 'reset': return <ResetForm />;
      default:
        return (
          <>
            <LoginForm />
            <div className="oauth-divider"><span>oppure</span></div>
            <div className="oauth-buttons">
              <GoogleLoginButton onSuccess={(token) => handleOAuthSuccess(token, 'google')} onError={setOauthError} />
              <MicrosoftLoginButton onSuccess={(token) => handleOAuthSuccess(token, 'microsoft')} />
            </div>
            {oauthError && <p className="alert alert--error" role="alert">{oauthError}</p>}
          </>
        );
    }
  };

  if (isAuthenticated) return null;

  return (
    <section className="login-page">
      <div className="login-aside">
        <p className="eyebrow">ARCADE MILANO</p>
        <h2>Entra nella<br />piattaforma</h2>
        <p>Gestisci la tua partecipazione all'evento ARCADE Milano 2026.</p>
        <div className="login-features">
          <div className="feature-item">
            <svg className="feature-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
              <path d="M3 12l2-2m0 0l7-7 7 7M5 10v10a1 1 0 001 1h3m10-11l2 2m-2-2v10a1 1 0 01-1 1h-3m-6 0a1 1 0 001-1v-4a1 1 0 011-1h2a1 1 0 011 1v4a1 1 0 001 1m-6 0h6" />
            </svg>
            <span>Accesso rapido</span>
          </div>
          <div className="feature-item">
            <svg className="feature-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
              <path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10z" />
            </svg>
            <span>Sicuro e protetto</span>
          </div>
          <div className="feature-item">
            <svg className="feature-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
              <path d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z" />
            </svg>
            <span>Dati verificati</span>
          </div>
        </div>
        <span className="login-mark">STAND UP</span>
      </div>
      <div className="login-panel">{renderAuthForm()}</div>
    </section>
  );
}

export const Route = createFileRoute('/accesso')({
  component: () => (
    <GoogleOAuthProvider clientId={GOOGLE_CLIENT_ID}>
      <AuthPage />
    </GoogleOAuthProvider>
  ),
});
