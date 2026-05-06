'use client';

import { useMemo } from 'react';
import {
  Box,
  Typography,
  Alert,
  CircularProgress,
  Card,
  CardContent,
  Table,
  TableHead,
  TableRow,
  TableCell,
  TableBody,
} from '@mui/material';
import dayjs from 'dayjs';

import OverlaySolarChart from '@/components/solar/OverlaySolarChart';
import { useMe } from '@/lib/hooks/useMe';
import { useSolarData } from '@/lib/hooks/useSolarData';
import type { SolarReading } from '@/lib/types';

interface BreakdownRow {
  label: string;
  date: string;
  peakKw: number;
  averageKw: number;
  totalKwh: number;
}

function estimateEnergyKwh(readings: SolarReading[]): number {
  if (!readings.length) return 0;

  const sorted = [...readings].sort((a, b) => dayjs(a.timestamp).valueOf() - dayjs(b.timestamp).valueOf());
  if (sorted.length === 1) return sorted[0].wattage / 1000;

  let wattHours = 0;

  for (let i = 0; i < sorted.length - 1; i += 1) {
    const current = sorted[i];
    const next = sorted[i + 1];
    const dtHours = Math.max(0, dayjs(next.timestamp).diff(dayjs(current.timestamp), 'second') / 3600);
    const avgWatts = (current.wattage + next.wattage) / 2;
    wattHours += avgWatts * dtHours;
  }

  return wattHours / 1000;
}

function buildRow(label: string, date: string | null, readings: SolarReading[]): BreakdownRow {
  const peakWatts = readings.reduce((peak, point) => Math.max(peak, point.wattage), 0);
  const totalWatts = readings.reduce((sum, point) => sum + point.wattage, 0);

  return {
    label,
    date: date ?? 'N/A',
    peakKw: peakWatts / 1000,
    averageKw: readings.length ? totalWatts / readings.length / 1000 : 0,
    totalKwh: estimateEnergyKwh(readings),
  };
}

export default function SolarOverlayPage() {
  const { me, isLoading: meLoading } = useMe();

  // No date range — the backend defaults to the rolling past year.
  const {
    bestReadings,
    bestDate,
    worstReadings,
    worstDate,
    todayReadings,
    todayDate,
    isLoading,
    error,
  } = useSolarData({
    returnBestDay: true,
    returnWorstDay: true,
    returnToday: true,
    enabled: !meLoading,
  });

  const breakdownRows = useMemo(
    () => [
      buildRow('Today', todayDate, todayReadings),
      buildRow('Best', bestDate, bestReadings),
      buildRow('Worst', worstDate, worstReadings),
    ],
    [todayDate, todayReadings, bestDate, bestReadings, worstDate, worstReadings]
  );

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
        Solar Overlay
      </Typography>

      <Typography color="text.secondary" sx={{ mb: 2 }}>
        Hour-by-hour comparison of today's generation against the best and worst days in the last year.
      </Typography>

      <Typography color="text.secondary" sx={{ mb: 2 }}>
        Today: {todayDate ?? 'N/A'} | Best: {bestDate ?? 'N/A'} | Worst: {worstDate ?? 'N/A'}
      </Typography>

      {me && me.query_limit_days < 365 && (
        <Alert severity="warning" sx={{ mb: 2 }}>
          Your query limit is {me.query_limit_days} days, so this view may not include a full year.
        </Alert>
      )}

      {error && (
        <Alert severity="error" sx={{ mb: 2 }}>
          {error}
        </Alert>
      )}

      <OverlaySolarChart
        bestReadings={bestReadings}
        worstReadings={worstReadings}
        todayReadings={todayReadings}
        isLoading={isLoading}
      />

      <Card sx={{ mt: 2 }}>
        <CardContent>
          <Typography variant="h6" gutterBottom>
            Table Breakdown
          </Typography>
          <Typography variant="body2" color="text.secondary" sx={{ mb: 2 }}>
            Peak and average are shown in kW. Total energy is estimated kWh for each day.
          </Typography>

          <Table size="small">
            <TableHead>
              <TableRow>
                <TableCell>Series</TableCell>
                <TableCell>Date</TableCell>
                <TableCell align="right">Peak (kW)</TableCell>
                <TableCell align="right">Average (kW)</TableCell>
                <TableCell align="right">Total (kWh)</TableCell>
              </TableRow>
            </TableHead>
            <TableBody>
              {breakdownRows.map((row) => (
                <TableRow key={row.label}>
                  <TableCell>{row.label}</TableCell>
                  <TableCell>{row.date}</TableCell>
                  <TableCell align="right">{row.peakKw.toFixed(2)}</TableCell>
                  <TableCell align="right">{row.averageKw.toFixed(2)}</TableCell>
                  <TableCell align="right">{row.totalKwh.toFixed(2)}</TableCell>
                </TableRow>
              ))}
            </TableBody>
          </Table>
        </CardContent>
      </Card>
    </Box>
  );
}
