'use client';

import { useState }  from 'react';
import {
  Dialog, DialogTitle, DialogContent, DialogActions,
  TextField, Button, Alert, CircularProgress, Typography,
} from '@mui/material';
import type { User } from '@/lib/types';

interface Props {
  user:      User;
  onClose:   () => void;
  onSuccess: () => void;
}

export default function EditQueryLimitDialog({ user, onClose, onSuccess }: Props) {
  const [days,         setDays]         = useState(String(user.query_limit_days));
  const [loading,      setLoading]      = useState(false);
  const [error,        setError]        = useState<string | null>(null);
  const [suggestedMax, setSuggestedMax] = useState<number | null>(null);

  const parsed = parseInt(days, 10);
  const valid  = !Number.isNaN(parsed) && parsed > 0;

  async function handleSave(overrideDays?: number) {
    const parsedDays = overrideDays ?? parseInt(days, 10);
    if (Number.isNaN(parsedDays) || parsedDays <= 0) {
      setError('Must be a positive number');
      return;
    }

    setLoading(true);
    setError(null);
    setSuggestedMax(null);

    try {
      const res = await fetch(`/api/proxy/users/${user.id}/query_limit`, {
        method:  'PATCH',
        headers: { 'Content-Type': 'application/json' },
        body:    JSON.stringify({ query_limit_days: parsedDays }),
      });

      const body = await res.json();
      if (!res.ok) {
        if (body.error_code === 'query_limit_exceeds_hard_max' && typeof body.max_query_limit_days === 'number') {
          setSuggestedMax(body.max_query_limit_days);
        }
        setError(body.error ?? 'Update failed');
      } else {
        onSuccess();
      }
    } catch {
      setError('Network error. Please try again.');
    } finally {
      setLoading(false);
    }
  }

  return (
    <Dialog open onClose={onClose} fullWidth maxWidth="xs">
      <DialogTitle>Edit Query Limit</DialogTitle>
      <DialogContent sx={{ pt: '12px !important' }}>
        <Typography variant="body2" color="text.secondary" gutterBottom>
          Setting the query limit for <strong>{user.email}</strong>.
          This controls how many days of solar data they can request at once.
        </Typography>

        {suggestedMax && (
          <Alert
            severity="warning"
            sx={{ mb: 2 }}
            action={(
              <Button
                color="inherit"
                size="small"
                disabled={loading}
                onClick={() => {
                  setDays(String(suggestedMax));
                  handleSave(suggestedMax);
                }}
              >
                Set to {suggestedMax}
              </Button>
            )}
          >
            Requested value exceeds the system hard limit of {suggestedMax} days. Set it to {suggestedMax}
            now, or contact the real admin for more information.
          </Alert>
        )}

        {error && <Alert severity="error" sx={{ mb: 2 }}>{error}</Alert>}

        <TextField
          label="Query limit (days)"
          type="number"
          fullWidth
          value={days}
          onChange={(e) => {
            setDays(e.target.value);
            setSuggestedMax(null);
          }}
          inputProps={{ min: 1, step: 1 }}
          onKeyDown={(e) => e.key === 'Enter' && handleSave()}
          autoFocus
          sx={{ mt: 1 }}
        />
      </DialogContent>

      <DialogActions sx={{ px: 3, pb: 2 }}>
        <Button onClick={onClose} disabled={loading}>Cancel</Button>
        <Button
          variant="contained"
          onClick={() => {
            handleSave();
          }}
          disabled={loading || !valid}
          startIcon={loading ? <CircularProgress size={16} /> : undefined}
        >
          {loading ? 'Saving…' : 'Save'}
        </Button>
      </DialogActions>
    </Dialog>
  );
}
