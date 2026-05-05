import useSWR from 'swr';
import type { SolarReading, SolarResponse } from '@/lib/types';

interface UseSolarDataParams {
  startDate: string;
  endDate:   string;
  enabled?:  boolean;
}

const fetcher = (url: string) =>
  fetch(url).then(async (r) => {
    const body = await r.json();
    if (!r.ok) throw new Error(body?.error ?? 'Failed to fetch solar data');
    return body as SolarResponse;
  });

export function useSolarData({ startDate, endDate, enabled = true }: UseSolarDataParams) {
  const key = enabled
    ? `/api/proxy/solar/readings?start_date=${startDate}&end_date=${endDate}`
    : null;

  const { data, error, isLoading } = useSWR<SolarResponse>(key, fetcher);

  return {
    readings:  data?.data    ?? ([] as SolarReading[]),
    meta:      data?.meta    ?? null,
    isLoading,
    error:     error?.message ?? null,
  };
}
