'use client';

import { useState } from 'react';
import { Box, Typography, Grid, Alert, CircularProgress } from '@mui/material';
import dayjs, { Dayjs } from 'dayjs';
import { DatePicker } from '@mui/x-date-pickers/DatePicker';
import { LocalizationProvider } from '@mui/x-date-pickers/LocalizationProvider';
import { AdapterDayjs } from '@mui/x-date-pickers/AdapterDayjs';

import QueryLimitBanner from '@/components/solar/QueryLimitBanner';
import SolarChart       from '@/components/solar/SolarChart';
import SummaryCards     from '@/components/solar/SummaryCards';
import { useMe }        from '@/lib/hooks/useMe';
import { useSolarData } from '@/lib/hooks/useSolarData';

export default function DashboardPage() {
  const { me, isLoading: meLoading } = useMe();

  const defaultEnd   = dayjs();
  const defaultStart = defaultEnd.subtract(6, 'day');

  const [startDate, setStartDate] = useState<Dayjs>(defaultStart);
  const [endDate,   setEndDate]   = useState<Dayjs>(defaultEnd);

  // Clamp the selectable range to the user's query limit
  const limit         = me?.query_limit_days ?? 30;
  const requestedDays = endDate.diff(startDate, 'day') + 1;
  const overLimit     = requestedDays > limit;

  const { readings, isLoading: dataLoading, error } = useSolarData({
    startDate: startDate.format('YYYY-MM-DD'),
    endDate:   endDate.format('YYYY-MM-DD'),
    enabled:   !overLimit,
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
        Solar Trends
      </Typography>

      {/* Query limit banner — always visible */}
      <QueryLimitBanner queryLimitDays={limit} />

      {/* Date range pickers */}
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

      {/* Over-limit warning */}
      {overLimit && (
        <Alert severity="warning" sx={{ mt: 1 }}>
          Selected range is <strong>{requestedDays} days</strong> but your limit is{' '}
          <strong>{limit} days</strong>. Please narrow the range.
        </Alert>
      )}

      {/* API error */}
      {error && !overLimit && (
        <Alert severity="error" sx={{ mt: 1 }}>
          {error}
        </Alert>
      )}

      {/* Summary cards */}
      <Box mt={3}>
        <SummaryCards readings={readings ?? []} isLoading={dataLoading} />
      </Box>

      {/* Chart */}
      <Box mt={3}>
        <SolarChart readings={readings ?? []} isLoading={dataLoading} />
      </Box>
    </Box>
  );
}
