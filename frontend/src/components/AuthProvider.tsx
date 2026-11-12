import { createContext, useContext, useState, useCallback, useEffect, type ReactNode } from 'react';
import {
  login,
  loginWithOAuth,
  requestPasswordRecovery,
  resetPassword,
  saveAuthToken,
  clearAuthToken,
  getSession,
  type AuthMode,
  type LoginCredentials,
  type OAuthCredentials,
  type Session,
} from '../services/auth';

type AuthContextType = {
  session: Session | null;
  isAuthenticated: boolean;
  isLoading: boolean;
  error: string | null;
  successMessage: string | null;
  authMode: AuthMode;
  login: (credentials: LoginCredentials) => Promise<void>;
  loginWithOAuth: (credentials: OAuthCredentials) => Promise<void>;
  requestRecovery: (email: string) => Promise<void>;
  resetPassword: (token: string, password: string) => Promise<void>;
  logout: () => void;
  setAuthMode: (mode: AuthMode) => void;
  clearError: () => void;
  clearSuccess: () => void;
};

const AuthContext = createContext<AuthContextType | undefined>(undefined);

export function AuthProvider({ children }: { children: ReactNode }) {
  const [session, setSession] = useState<Session | null>(() => getSession());
  const [isLoading, setIsLoading] = useState<boolean>(false);
  const [error, setError] = useState<string | null>(null);
  const [successMessage, setSuccessMessage] = useState<string | null>(null);
  const [authMode, setAuthMode] = useState<AuthMode>('login');

  useEffect(() => {
    setSession(getSession());
  }, []);

  useEffect(() => {
    if (!session) return;
    const remaining = session.expiresAt - Date.now();
    if (remaining <= 0) {
      clearAuthToken();
      setSession(null);
      setSuccessMessage('Sessione scaduta: accedi di nuovo per continuare.');
      return;
    }
    const timer = window.setTimeout(() => {
      clearAuthToken();
      setSession(null);
      setSuccessMessage('Sessione scaduta: accedi di nuovo per continuare.');
    }, remaining);
    return () => window.clearTimeout(timer);
  }, [session]);

  const clearError = useCallback(() => setError(null), []);
  const clearSuccess = useCallback(() => setSuccessMessage(null), []);

  const handleLogin = useCallback(async (credentials: LoginCredentials) => {
    setIsLoading(true);
    clearError();
    clearSuccess();
    try {
      const result = await login(credentials);
      saveAuthToken(result.accessToken);
      setSession(getSession());
      setAuthMode('login');
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Accesso non riuscito.');
    } finally {
      setIsLoading(false);
    }
  }, [clearError, clearSuccess]);

  const handleOAuthLogin = useCallback(async (credentials: OAuthCredentials) => {
    setIsLoading(true);
    clearError();
    clearSuccess();
    try {
      const result = await loginWithOAuth(credentials);
      saveAuthToken(result.accessToken);
      setSession(getSession());
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Accesso OAuth non riuscito.');
    } finally {
      setIsLoading(false);
    }
  }, [clearError, clearSuccess]);

  const handleRecovery = useCallback(async (email: string) => {
    setIsLoading(true);
    clearError();
    clearSuccess();
    try {
      await requestPasswordRecovery(email);
      setSuccessMessage("Richiesta registrata. Se l'account esiste, riceverai un link.");
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Richiesta non riuscita.');
    } finally {
      setIsLoading(false);
    }
  }, [clearError, clearSuccess]);

  const handleResetPassword = useCallback(async (token: string, password: string) => {
    setIsLoading(true);
    clearError();
    clearSuccess();
    try {
      await resetPassword({ token, password });
      setSuccessMessage('Password aggiornata. Accedi con la nuova password.');
      setAuthMode('login');
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Reimpostazione non riuscita.');
    } finally {
      setIsLoading(false);
    }
  }, [clearError, clearSuccess, setAuthMode]);

  const handleLogout = useCallback(() => {
    clearAuthToken();
    setSession(null);
    setError(null);
    setSuccessMessage(null);
    setAuthMode('login');
  }, []);

  const value: AuthContextType = {
    session,
    isAuthenticated: session !== null,
    isLoading,
    error,
    successMessage,
    authMode,
    login: handleLogin,
    loginWithOAuth: handleOAuthLogin,
    requestRecovery: handleRecovery,
    resetPassword: handleResetPassword,
    logout: handleLogout,
    setAuthMode,
    clearError,
    clearSuccess,
  };

  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>;
}

export function useAuth(): AuthContextType {
  const context = useContext(AuthContext);
  if (context === undefined) {
    throw new Error('useAuth deve essere usato dentro un AuthProvider');
  }
  return context;
}
