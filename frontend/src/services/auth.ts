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

export type Session = {
  role: string;
  subject: string;
  expiresAt: number;
};

/**
 * Il ruolo serve solo alla UI per scegliere la destinazione e nascondere voci di menu:
 * l'autorizzazione vale solo se applicata dal server su ogni richiesta.
 */
export function parseSession(token: string | null): Session | null {
  if (!token) return null;
  const parts = token.split('.');
  if (parts.length !== 3) return null;
  try {
    const normalized = parts[1].replace(/-/g, '+').replace(/_/g, '/');
    const padded = normalized + '='.repeat((4 - (normalized.length % 4)) % 4);
    const claims = JSON.parse(atob(padded)) as { sub?: string; role?: string; exp?: number };
    if (!claims.sub || !claims.role || !claims.exp) return null;
    if (claims.exp * 1000 <= Date.now()) return null;
    return { role: claims.role, subject: claims.sub, expiresAt: claims.exp * 1000 };
  } catch {
    return null;
  }
}

/** Ripristina la sessione della scheda corrente e rimuove i token scaduti o illeggibili. */
export function getSession(): Session | null {
  const token = getAuthToken();
  const session = parseSession(token);
  if (!session && token) clearAuthToken();
  return session;
}

export function homeFor(role: string): string {
  switch (role) {
    case 'DIREZIONE':
    case 'AMMINISTRATORE':
      return '/pannello-controllo';
    case 'COMMERCIALE':
      return '/commerciale';
    case 'STAFF':
      return '/operativita';
    default:
      return '/espositore';
  }
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
