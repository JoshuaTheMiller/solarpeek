import useSWR   from 'swr';
import type { User, ApiResponse } from '@/lib/types';

const fetcher = (url: string) =>
  fetch(url).then((r) => {
    if (!r.ok) throw new Error('Failed to fetch user profile');
    return r.json();
  });

export function useMe() {
  const { data, error, isLoading } = useSWR<ApiResponse<User>>(
    '/api/proxy/me',
    fetcher,
    { revalidateOnFocus: false }
  );

  return {
    me:        data?.data ?? null,
    isLoading,
    error:     error?.message ?? null,
  };
}
