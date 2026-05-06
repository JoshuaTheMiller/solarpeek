// ── Domain types ──────────────────────────────────────────────────────────────

export type Role = 'viewer' | 'manager' | 'admin';

export interface User {
  id:               number;
  email:            string;
  role:             Role;
  query_limit_days: number;
  active:           boolean;
  invited_by_id:    number | null;
  created_at:       string;
  /** Present and true when the Rails server is running in auth bypass mode. */
  bypass_mode?:                    boolean;
  query_limit_banner_dismissed:    boolean;
}

export interface SolarReading {
  timestamp: string;  // ISO 8601
  wattage:   number;  // watts
}

// ── API response wrappers ─────────────────────────────────────────────────────

export interface ApiResponse<T> {
  data: T;
  meta?: Record<string, unknown>;
}

export interface SolarResponse {
  data: SolarReading[];
  best_readings?: SolarReading[];
  best_date?: string | null;
  worst_readings?: SolarReading[];
  worst_date?: string | null;
  today_readings?: SolarReading[];
  today_date?: string | null;
  meta: {
    query_limit_days: number;
    requested_days:   number;
  };
}

export interface ApiError {
  error: string;
}
