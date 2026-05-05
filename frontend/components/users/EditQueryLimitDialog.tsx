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
  const [days,    setDays]    = useState(String(user.query_limit_days));
  const [loading, setLoading] = useState(false);
  const [error,   setError]   = useState<string | null>(null);

  const parsed = parseInt(days, 10);
  const valid  = !Number.isNaN(parsed) && parsed > 0;

  async function handleSave() {
    if (!valid) {
      setError('Must be a positive number');
      return;
    }
    setLoading(true);
    setError(null);

    try {
      const res = await fetch(`/api/proxy/users/${user.id}/query_limit`, {
        method:  'PATCH',
        headers: { 'Content-Type': 'application/json' },
        body:    JSON.stringify({ query_limit_days: parsed }),
      });

      const body = await res.json();
      if (!res.ok) {
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

        {error && <Alert severity="error" sx={{ mb: 2 }}>{error}</Alert>}

        <TextField
          label="Query limit (days)"
          type="number"
          fullWidth
          value={days}
          onChange={(e) => setDays(e.target.value)}
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
          onClick={handleSave}
          disabled={loading || !valid}
          startIcon={loading ? <CircularProgress size={16} /> : undefined}
        >
          {loading ? 'Saving…' : 'Save'}
        </Button>
      </DialogActions>
    </Dialog>
  );
}
