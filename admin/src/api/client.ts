import type {
  AuthResponse,
  AdminUserResponse,
  AdminServerResponse,
  ServerTrafficResponse,
  CreateServerRequest,
  GeoIPCountry,
  CountryCIDRsResponse,
} from '../types';

const API_URL = import.meta.env.VITE_API_URL ?? '';

async function request<T>(path: string, options?: RequestInit): Promise<T> {
  const token = localStorage.getItem('access_token');
  const res = await fetch(`${API_URL}${path}`, {
    ...options,
    headers: {
      'Content-Type': 'application/json',
      ...(token && { Authorization: `Bearer ${token}` }),
      ...options?.headers,
    },
  });

  if (res.status === 401) {
    const refreshToken = localStorage.getItem('refresh_token');
    if (refreshToken) {
      try {
        const refreshRes = await fetch(`${API_URL}/api/v1/auth/refresh`, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ refresh_token: refreshToken }),
        });
        if (refreshRes.ok) {
          const tokens: AuthResponse = await refreshRes.json();
          localStorage.setItem('access_token', tokens.access_token);
          localStorage.setItem('refresh_token', tokens.refresh_token);
          // Retry original request with new token
          const retryRes = await fetch(`${API_URL}${path}`, {
            ...options,
            headers: {
              'Content-Type': 'application/json',
              Authorization: `Bearer ${tokens.access_token}`,
              ...options?.headers,
            },
          });
          if (!retryRes.ok) throw new Error(await retryRes.text());
          return retryRes.json();
        }
      } catch {
        // Refresh failed
      }
    }
    localStorage.removeItem('access_token');
    localStorage.removeItem('refresh_token');
    window.location.href = '/login';
    throw new Error('Unauthorized');
  }

  if (!res.ok) {
    const body = await res.json().catch(() => ({ detail: res.statusText }));
    throw new Error(body.detail || res.statusText);
  }
  return res.json();
}

export const api = {
  login: (email: string, password: string) =>
    request<AuthResponse>('/api/v1/auth/login', {
      method: 'POST',
      body: JSON.stringify({ email, password }),
    }),

  listUsers: () => request<AdminUserResponse[]>('/api/v1/admin/users'),

  getUser: (id: string) =>
    request<AdminUserResponse>(`/api/v1/admin/users/${id}`),

  resetPassword: (id: string, newPassword: string) =>
    request<{ message: string }>(`/api/v1/admin/users/${id}/reset-password`, {
      method: 'POST',
      body: JSON.stringify({ new_password: newPassword }),
    }),

  deleteUser: (id: string) =>
    request<{ message: string }>(`/api/v1/admin/users/${id}`, {
      method: 'DELETE',
    }),

  listServers: () => request<AdminServerResponse[]>('/api/v1/admin/servers'),

  getServer: (id: string) =>
    request<ServerTrafficResponse>(`/api/v1/admin/servers/${id}`),

  createServer: (data: CreateServerRequest) =>
    request<AdminServerResponse>('/api/v1/admin/servers', {
      method: 'POST',
      body: JSON.stringify(data),
    }),

  deleteServer: (id: string) =>
    request<{ message: string }>(`/api/v1/admin/servers/${id}`, {
      method: 'DELETE',
    }),

  updateServer: (id: string, data: { is_active: boolean }) =>
    request<{ message: string }>(`/api/v1/admin/servers/${id}`, {
      method: 'PATCH',
      body: JSON.stringify(data),
    }),

  listGeoIPCountries: () => request<GeoIPCountry[]>('/api/v1/geoip/countries'),

  getCountryCIDRs: (country: string) =>
    request<CountryCIDRsResponse>(`/api/v1/geoip/${country}`),
};
