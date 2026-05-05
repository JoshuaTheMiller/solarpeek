'use client';

import { useMemo }     from 'react';
import { Card, CardContent, Typography, Box, Skeleton } from '@mui/material';
import {
  AreaChart, Area, XAxis, YAxis, CartesianGrid,
  Tooltip, ResponsiveContainer, Legend,
} from 'recharts';
import dayjs             from 'dayjs';
import type { SolarReading } from '@/lib/types';

interface Props {
  readings:  SolarReading[];
  isLoading: boolean;
}

// Format a timestamp for the X axis — show "Jan 5 09:00" style
function formatTick(ts: string) {
  return dayjs(ts).format('MMM D HH:mm');
}

// Custom tooltip
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
        {dayjs(label).format('MMM D, YYYY HH:mm')}
      </Typography>
      <Typography fontWeight={700} color="primary.dark">
        {Number(payload[0].value).toLocaleString()} W
      </Typography>
    </Box>
  );
}

export default function SolarChart({ readings, isLoading }: Props) {
  // Downsample to max 200 points to keep the chart performant
  const chartData = useMemo(() => {
    if (readings.length <= 200) return readings;
    const step = Math.ceil(readings.length / 200);
    return readings.filter((_, i) => i % step === 0);
  }, [readings]);

  if (isLoading) {
    return (
      <Card>
        <CardContent>
          <Skeleton variant="rectangular" height={300} sx={{ borderRadius: 2 }} />
        </CardContent>
      </Card>
    );
  }

  if (!readings.length) {
    return (
      <Card>
        <CardContent>
          <Box display="flex" justifyContent="center" alignItems="center" height={200}>
            <Typography color="text.secondary">
              Select a date range to view solar data.
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
          Wattage Over Time
        </Typography>
        <ResponsiveContainer width="100%" height={320}>
          <AreaChart data={chartData} margin={{ top: 10, right: 20, left: 10, bottom: 60 }}>
            <defs>
              <linearGradient id="solarGradient" x1="0" y1="0" x2="0" y2="1">
                <stop offset="5%"  stopColor="#F59E0B" stopOpacity={0.3} />
                <stop offset="95%" stopColor="#F59E0B" stopOpacity={0}   />
              </linearGradient>
            </defs>
            <CartesianGrid strokeDasharray="3 3" stroke="#E2E8F0" />
            <XAxis
              dataKey="timestamp"
              tickFormatter={formatTick}
              angle={-35}
              textAnchor="end"
              tick={{ fontSize: 11 }}
              interval="preserveStartEnd"
            />
            <YAxis
              tickFormatter={(v) => `${(v / 1000).toFixed(1)}kW`}
              tick={{ fontSize: 11 }}
              width={55}
            />
            <Tooltip content={<CustomTooltip />} />
            <Area
              type="monotone"
              dataKey="wattage"
              stroke="#F59E0B"
              strokeWidth={2}
              fill="url(#solarGradient)"
              name="Wattage"
              dot={false}
              activeDot={{ r: 4 }}
            />
          </AreaChart>
        </ResponsiveContainer>
      </CardContent>
    </Card>
  );
}
