'use client';

import { useMemo } from 'react';
import { Card, CardContent, Typography, Box, Skeleton } from '@mui/material';
import {
  LineChart,
  Line,
  XAxis,
  YAxis,
  CartesianGrid,
  Tooltip,
  ResponsiveContainer,
  Legend,
} from 'recharts';
import dayjs from 'dayjs';
import type { SolarReading } from '@/lib/types';

interface Props {
  bestReadings: SolarReading[];
  worstReadings: SolarReading[];
  todayReadings: SolarReading[];
  isLoading: boolean;
}

interface OverlayPoint {
  time: string;
  best?: number;
  worst?: number;
  today?: number;
}

function seriesByTime(readings: SolarReading[]): Record<string, number> {
  return readings.reduce<Record<string, number>>((acc, reading) => {
    const key = dayjs(reading.timestamp).format('HH:mm');
    acc[key] = reading.wattage;
    return acc;
  }, {});
}

function CustomTooltip({ active, payload, label }: any) {
  if (!active || !payload?.length) return null;

  return (
    <Box
      sx={{
        bgcolor: 'background.paper',
        border: '1px solid',
        borderColor: 'divider',
        borderRadius: 2,
        p: 1.5,
        boxShadow: 2,
      }}
    >
      <Typography variant="caption" color="text.secondary">
        {label}
      </Typography>
      {payload.map((item: any) => (
        <Typography key={item.dataKey} sx={{ color: item.color, fontWeight: 700 }}>
          {item.name}: {Number(item.value ?? 0).toLocaleString()} W
        </Typography>
      ))}
    </Box>
  );
}

export default function OverlaySolarChart({
  bestReadings,
  worstReadings,
  todayReadings,
  isLoading,
}: Props) {
  const chartData = useMemo<OverlayPoint[]>(() => {
    const best = seriesByTime(bestReadings);
    const worst = seriesByTime(worstReadings);
    const today = seriesByTime(todayReadings);

    const timeKeys = Array.from(
      new Set([...Object.keys(best), ...Object.keys(worst), ...Object.keys(today)])
    ).sort();

    return timeKeys.map((time) => ({
      time,
      best: best[time],
      worst: worst[time],
      today: today[time],
    }));
  }, [bestReadings, worstReadings, todayReadings]);

  if (isLoading) {
    return (
      <Card>
        <CardContent>
          <Skeleton variant="rectangular" height={320} sx={{ borderRadius: 2 }} />
        </CardContent>
      </Card>
    );
  }

  if (!chartData.length) {
    return (
      <Card>
        <CardContent>
          <Box display="flex" justifyContent="center" alignItems="center" height={220}>
            <Typography color="text.secondary">
              No overlay data is available for the selected period.
            </Typography>
          </Box>
        </CardContent>
      </Card>
    );
  }

  return (
    <Card>
      <CardContent>
        <Typography variant="h6" gutterBottom>
          Best vs Worst vs Today (Hourly Overlay)
        </Typography>
        <ResponsiveContainer width="100%" height={360}>
          <LineChart data={chartData} margin={{ top: 10, right: 20, left: 10, bottom: 20 }}>
            <CartesianGrid strokeDasharray="3 3" stroke="#E2E8F0" />
            <XAxis dataKey="time" tick={{ fontSize: 11 }} interval="preserveStartEnd" />
            <YAxis tickFormatter={(v) => `${(v / 1000).toFixed(1)}kW`} tick={{ fontSize: 11 }} width={55} />
            <Tooltip content={<CustomTooltip />} />
            <Legend />
            <Line
              type="monotone"
              dataKey="today"
              stroke="#2563EB"
              strokeWidth={2.5}
              dot={false}
              name="Today"
              connectNulls
            />
            <Line
              type="monotone"
              dataKey="best"
              stroke="#16A34A"
              strokeWidth={2}
              strokeDasharray="6 4"
              dot={false}
              name="Best Day"
              connectNulls
            />
            <Line
              type="monotone"
              dataKey="worst"
              stroke="#DC2626"
              strokeWidth={2}
              strokeDasharray="3 3"
              dot={false}
              name="Worst Day"
              connectNulls
            />
          </LineChart>
        </ResponsiveContainer>
      </CardContent>
    </Card>
  );
}
