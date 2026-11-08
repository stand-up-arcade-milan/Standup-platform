import { createContext, useContext, useState, useCallback, useEffect, ReactNode } from 'react';
import {
  login,
  loginWithOAuth,
  requestPasswordRecovery,
  resetPassword,
  saveAuthToken,
  clearAuthToken,
  hasAuthToken,
  type AuthMode,
  type LoginCredentials,
  type OAuthCredentials,
} from '../services/auth';

type AuthContextType = {
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
  const [isAuthenticated, setIsAuthenticated] = useState<boolean>(hasAuthToken());
  const [isLoading, setIsLoading] = useState<boolean>(false);
  const [error, setError] = useState<string | null>(null);
  const [successMessage, setSuccessMessage] = useState<string | null>(null);
  const [authMode, setAuthMode] = useState<AuthMode>('login');

  useEffect(() => {
    setIsAuthenticated(hasAuthToken());
  }, []);

  const clearError = useCallback(() => setError(null), []);
  const clearSuccess = useCallback(() => setSuccessMessage(null), []);

  const handleLogin = useCallback(async (credentials: LoginCredentials) => {
    setIsLoading(true);
    clearError();
    clearSuccess();
    try {
      const result = await login(credentials);
      saveAuthToken(result.accessToken);
      setIsAuthenticated(true);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Accesso non riuscito.');
      setIsAuthenticated(false);
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
      setIsAuthenticated(true);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Accesso OAuth non riuscito.');
      setIsAuthenticated(false);
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
      setSuccessMessage('Richiesta registrata. Se l\\'account esiste, riceverai un link.');
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
    setIsAuthenticated(false);
    setError(null);
    setSuccessMessage(null);
  }, []);

  const value: AuthContextType = {
    isAuthenticated,
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
