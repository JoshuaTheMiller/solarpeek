import useSWR from 'swr';
import type { User, ApiResponse } from '@/lib/types';

const fetcher = (url: string) =>
  fetch(url).then(async (r) => {
    const body = await r.json();
    if (!r.ok) throw new Error(body?.error ?? 'Failed to fetch users');
    return body as ApiResponse<User[]>;
  });

export function useUsers() {
  const { data, error, isLoading, mutate } = useSWR<ApiResponse<User[]>>(
    '/api/proxy/users',
    fetcher
  );

  return {
    users:     data?.data ?? ([] as User[]),
    isLoading,
    error:     error?.message ?? null,
    mutate,
  };
}
