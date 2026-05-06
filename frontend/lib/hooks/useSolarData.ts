import useSWR from 'swr';
import type { SolarReading, SolarResponse } from '@/lib/types';

interface UseSolarDataParams {
  startDate?: string;
  endDate?:   string;
  enabled?:   boolean;
  returnBestDay?: boolean;
  returnWorstDay?: boolean;
  returnToday?: boolean;
}

const fetcher = (url: string) =>
  fetch(url).then(async (r) => {
    const body = await r.json();
    if (!r.ok) throw new Error(body?.error ?? 'Failed to fetch solar data');
    return body as SolarResponse;
  });

export function useSolarData({
  startDate,
  endDate,
  enabled = true,
  returnBestDay = false,
  returnWorstDay = false,
  returnToday = false,
}: UseSolarDataParams) {
  const query = new URLSearchParams();
  if (startDate)  query.set('start_date',     startDate);
  if (endDate)    query.set('end_date',       endDate);
  query.set('return_best_day',  String(returnBestDay));
  query.set('return_worst_day', String(returnWorstDay));
  query.set('return_today',     String(returnToday));

  const key = enabled ? `/api/proxy/solar/readings?${query.toString()}` : null;

  const { data, error, isLoading } = useSWR<SolarResponse>(key, fetcher);

  return {
    readings:  data?.data    ?? ([] as SolarReading[]),
    bestReadings: data?.best_readings ?? ([] as SolarReading[]),
    bestDate: data?.best_date ?? null,
    worstReadings: data?.worst_readings ?? ([] as SolarReading[]),
    worstDate: data?.worst_date ?? null,
    todayReadings: data?.today_readings ?? ([] as SolarReading[]),
    todayDate: data?.today_date ?? null,
    meta:      data?.meta    ?? null,
    isLoading,
    error:     error?.message ?? null,
  };
}
