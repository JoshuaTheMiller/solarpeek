'use client';

import { useState } from 'react';
import { Box, Typography, Alert, CircularProgress } from '@mui/material';
import dayjs, { Dayjs } from 'dayjs';
import { DatePicker } from '@mui/x-date-pickers/DatePicker';
import { LocalizationProvider } from '@mui/x-date-pickers/LocalizationProvider';
import { AdapterDayjs } from '@mui/x-date-pickers/AdapterDayjs';

import QueryLimitBanner from '@/components/solar/QueryLimitBanner';
import SolarChart from '@/components/solar/SolarChart';
import SummaryCards from '@/components/solar/SummaryCards';
import { useMe } from '@/lib/hooks/useMe';
import { useSolarData } from '@/lib/hooks/useSolarData';

export default function SolarDashboardPage() {
  const { me, isLoading: meLoading, mutate } = useMe();

  const defaultEnd = dayjs();
  const defaultStart = defaultEnd.subtract(6, 'day');

  const [startDate, setStartDate] = useState<Dayjs>(defaultStart);
  const [endDate, setEndDate] = useState<Dayjs>(defaultEnd);

  const limit = me?.query_limit_days ?? 30;
  const requestedDays = endDate.diff(startDate, 'day') + 1;
  const overLimit = requestedDays > limit;

  const bannerDismissed = me?.query_limit_banner_dismissed ?? false;

  async function handleDismissBanner() {
    await mutate(
      async (current) => {
        await fetch('/api/proxy/me/preferences', {
          method: 'PATCH',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ preferences: { query_limit_banner_dismissed: true } }),
        });
        if (!current) return current;
        return { ...current, data: { ...current.data, query_limit_banner_dismissed: true } };
      },
      { revalidate: false }
    );
  }

  const { readings, isLoading: dataLoading, error } = useSolarData({
    startDate: startDate.format('YYYY-MM-DD'),
    endDate: endDate.format('YYYY-MM-DD'),
    enabled: !overLimit,
  });

  if (meLoading) {
    return (
      <Box display="flex" justifyContent="center" alignItems="center" minHeight="60vh">
        <CircularProgress />
      </Box>
    );
  }

  return (
    <Box>
      <Typography variant="h4" fontWeight={700} gutterBottom>
        Solar Trends Dashboard
      </Typography>

      {!bannerDismissed && <QueryLimitBanner queryLimitDays={limit} onDismiss={handleDismissBanner} />}

      <LocalizationProvider dateAdapter={AdapterDayjs}>
        <Box display="flex" gap={2} mt={3} mb={1} flexWrap="wrap">
          <DatePicker
            label="Start date"
            value={startDate}
            onChange={(v) => v && setStartDate(v)}
            maxDate={endDate}
          />
          <DatePicker
            label="End date"
            value={endDate}
            onChange={(v) => v && setEndDate(v)}
            minDate={startDate}
            maxDate={dayjs()}
          />
        </Box>
      </LocalizationProvider>

      {overLimit && (
        <Alert severity="warning" sx={{ mt: 1 }}>
          Selected range is <strong>{requestedDays} days</strong> but your limit is{' '}
          <strong>{limit} days</strong>. Please narrow the range.
        </Alert>
      )}

      {error && !overLimit && (
        <Alert severity="error" sx={{ mt: 1 }}>
          {error}
        </Alert>
      )}

      <Box mt={3}>
        <SummaryCards readings={readings ?? []} isLoading={dataLoading} />
      </Box>

      <Box mt={3}>
        <SolarChart readings={readings ?? []} isLoading={dataLoading} />
      </Box>
    </Box>
  );
}
