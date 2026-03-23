export interface AuthResponse {
  access_token: string;
  refresh_token: string;
}

export interface PeerSummary {
  server_id: string;
  server_name: string;
  assigned_ip: string;
  connected_at: string;
}

export interface AdminUserResponse {
  id: string;
  email: string;
  is_admin: boolean;
  created_at: string;
  peer: PeerSummary | null;
}

export interface AdminServerResponse {
  id: string;
  name: string;
  country: string;
  host: string;
  port: number;
  public_key: string;
  is_active: boolean;
  created_at: string;
  peer_count: number;
  tx_bytes: number;
  rx_bytes: number;
}

export interface PeerTraffic {
  user_id: string;
  email: string;
  public_key: string;
  assigned_ip: string;
  rx_bytes: number;
  tx_bytes: number;
}

export interface ServerTrafficResponse {
  server_id: string;
  name: string;
  country: string;
  host: string;
  port: number;
  is_active: boolean;
  total_rx_bytes: number;
  total_tx_bytes: number;
  peers: PeerTraffic[];
}

export interface CreateServerRequest {
  name: string;
  country: string;
  host: string;
  port: number;
  public_key: string;
}

export interface GeoIPCountry {
  country: string;
  count: number;
}

export interface CountryCIDRsResponse {
  country: string;
  cidrs: string[];
}
