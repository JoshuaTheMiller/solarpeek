'use client';

import { Grid, Card, CardContent, Typography, Skeleton } from '@mui/material';
import BoltIcon          from '@mui/icons-material/Bolt';
import TrendingUpIcon    from '@mui/icons-material/TrendingUp';
import SolarPowerIcon    from '@mui/icons-material/SolarPower';
import type { SolarReading } from '@/lib/types';

interface Props {
  readings:  SolarReading[];
  isLoading: boolean;
}

function StatCard({
  label, value, unit, icon, isLoading,
}: {
  label: string; value: string; unit: string; icon: React.ReactNode; isLoading: boolean;
}) {
  return (
    <Card>
      <CardContent>
        <Typography variant="caption" color="text.secondary" gutterBottom>
          {label}
        </Typography>
        {isLoading ? (
          <Skeleton variant="text" width="60%" height={40} />
        ) : (
          <Typography variant="h5" fontWeight={700} color="primary.dark">
            {value}
            <Typography component="span" variant="body2" color="text.secondary" ml={0.5}>
              {unit}
            </Typography>
          </Typography>
        )}
        <Typography color="text.disabled" sx={{ mt: 0.5 }}>
          {icon}
        </Typography>
      </CardContent>
    </Card>
  );
}

export default function SummaryCards({ readings, isLoading }: Props) {
  const wattages   = readings.map((r) => r.wattage);
  const peakW      = wattages.length ? Math.max(...wattages) : 0;
  const avgW       = wattages.length ? wattages.reduce((a, b) => a + b, 0) / wattages.length : 0;

  // Total energy (Wh) integrated across sample intervals using a left Riemann sum.
  // This supports non-hourly cadence (e.g. 5/10-minute readings).
  const totalWh = readings.slice(0, -1).reduce((acc, current, idx) => {
    const next = readings[idx + 1];
    const startMs = Date.parse(current.timestamp);
    const endMs = Date.parse(next.timestamp);
    if (Number.isNaN(startMs) || Number.isNaN(endMs) || endMs <= startMs) return acc;

    const hours = (endMs - startMs) / 3_600_000;
    return acc + current.wattage * hours;
  }, 0);

  const totalKwh   = totalWh / 1000;

  return (
    <Grid container spacing={2}>
      <Grid item xs={12} sm={4}>
        <StatCard
          label="Peak Output"
          value={peakW >= 1000 ? (peakW / 1000).toFixed(2) : peakW.toFixed(0)}
          unit={peakW >= 1000 ? 'kW' : 'W'}
          icon={<TrendingUpIcon />}
          isLoading={isLoading}
        />
      </Grid>
      <Grid item xs={12} sm={4}>
        <StatCard
          label="Average Output"
          value={avgW >= 1000 ? (avgW / 1000).toFixed(2) : avgW.toFixed(0)}
          unit={avgW >= 1000 ? 'kW' : 'W'}
          icon={<BoltIcon />}
          isLoading={isLoading}
        />
      </Grid>
      <Grid item xs={12} sm={4}>
        <StatCard
          label="Total Energy"
          value={totalKwh.toFixed(1)}
          unit="kWh"
          icon={<SolarPowerIcon />}
          isLoading={isLoading}
        />
      </Grid>
    </Grid>
  );
}
