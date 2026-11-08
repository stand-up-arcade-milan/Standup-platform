import { api, saveToken, readToken, clearToken } from './api';

export type AuthMode = 'login' | 'recovery' | 'reset';

export type LoginCredentials = {
  email: string;
  password: string;
};

export type OAuthCredentials = {
  provider: 'google' | 'microsoft';
  token: string;
  email: string;
  subject: string;
};

export type RecoveryCredentials = {
  email: string;
};

export type ResetCredentials = {
  token: string;
  password: string;
};

const EXHIBITOR_TOKEN_KEY = 'standup.exhibitor.token';

export function getAuthToken(): string | null {
  return readToken('exhibitor');
}

export function hasAuthToken(): boolean {
  return getAuthToken() !== null;
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
    body: JSON.stringify({
      token: credentials.token,
      email: credentials.email,
      subject: credentials.subject,
    }),
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
