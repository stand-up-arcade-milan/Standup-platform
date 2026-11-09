import { api, saveToken, readToken, clearToken } from './api';

export type AuthMode = 'login' | 'recovery' | 'reset';

export type LoginCredentials = {
  email: string;
  password: string;
};

/**
 * Al server va solo l'ID token: e lui a verificarne la firma e a ricavarne identificativo
 * ed email. Mandare email o subject dal browser significherebbe farsi credere sulla parola.
 */
export type OAuthCredentials = {
  provider: 'google' | 'microsoft';
  token: string;
};

export type RecoveryCredentials = {
  email: string;
};

export type ResetCredentials = {
  token: string;
  password: string;
};


export function getAuthToken(): string | null {
  return readToken('exhibitor');
}

export function hasAuthToken(): boolean {
  return getAuthToken() !== null;
}

/**
 * Legge il claim `role` dal payload del JWT. Non verifica la firma: quella è
 * responsabilità del server, qui serve solo a decidere cosa mostrare nel frontend.
 */
function decodeRole(token: string): string | null {
  try {
    const payload = token.split('.')[1];
    if (!payload) return null;
    const base64 = payload.replace(/-/g, '+').replace(/_/g, '/');
    const padded = base64.padEnd(base64.length + ((4 - (base64.length % 4)) % 4), '=');
    const claims = JSON.parse(atob(padded)) as { role?: unknown };
    return typeof claims.role === 'string' ? claims.role : null;
  } catch {
    return null;
  }
}

export function getAuthRole(): string | null {
  const token = getAuthToken();
  return token ? decodeRole(token) : null;
}

export async function login(credentials: LoginCredentials): Promise<{ accessToken: string }> {
  const result = await api<{ accessToken: string }>('/auth/login', {
    method: 'POST',
    body: JSON.stringify(credentials),
  });
  return result;
}

export async function loginWithOAuth(credentials: OAuthCredentials): Promise<{ accessToken: string }> {
  const endpoint = credentials.provider === 'google' ? '/auth/google' : '/auth/microsoft';
  const result = await api<{ accessToken: string }>(endpoint, {
    method: 'POST',
    body: JSON.stringify({ token: credentials.token }),
  });
  return result;
}

export async function requestPasswordRecovery(email: string): Promise<void> {
  await api('/auth/password/recupero', {
    method: 'POST',
    body: JSON.stringify({ email }),
  });
}

export async function resetPassword(credentials: ResetCredentials): Promise<void> {
  await api('/auth/password/reimposta', {
    method: 'POST',
    body: JSON.stringify(credentials),
  });
}

export function saveAuthToken(token: string): void {
  saveToken('exhibitor', token);
}

export function clearAuthToken(): void {
  clearToken('exhibitor');
}
