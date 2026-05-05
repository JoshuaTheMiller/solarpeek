'use client';

import { useState }  from 'react';
import {
  Dialog, DialogTitle, DialogContent, DialogActions,
  TextField, MenuItem, Button, Alert, CircularProgress,
} from '@mui/material';
import type { Role } from '@/lib/types';

// Roles a given caller is allowed to invite
const INVITABLE_ROLES: Record<Role, Role[]> = {
  admin:   ['admin', 'manager', 'viewer'],
  manager: ['manager', 'viewer'],
  viewer:  [],
};

interface Props {
  open:            boolean;
  currentUserRole: Role;
  onClose:         () => void;
  onSuccess:       () => void;
}

export default function InviteUserDialog({
  open, currentUserRole, onClose, onSuccess,
}: Props) {
  const [email,   setEmail]   = useState('');
  const [role,    setRole]    = useState<Role>('viewer');
  const [loading, setLoading] = useState(false);
  const [error,   setError]   = useState<string | null>(null);

  const allowedRoles = INVITABLE_ROLES[currentUserRole];

  async function handleSubmit() {
    if (!email.trim()) {
      setError('Email is required');
      return;
    }
    setLoading(true);
    setError(null);

    try {
      const res = await fetch('/api/proxy/invitations', {
        method:  'POST',
        headers: { 'Content-Type': 'application/json' },
        body:    JSON.stringify({ invitation: { email: email.trim().toLowerCase(), role } }),
      });

      const body = await res.json();

      if (!res.ok) {
        setError(body.error ?? 'Invitation failed');
      } else {
        setEmail('');
        setRole('viewer');
        onSuccess();
      }
    } catch {
      setError('Network error. Please try again.');
    } finally {
      setLoading(false);
    }
  }

  function handleClose() {
    if (loading) return;
    setEmail('');
    setRole('viewer');
    setError(null);
    onClose();
  }

  return (
    <Dialog open={open} onClose={handleClose} fullWidth maxWidth="xs">
      <DialogTitle>Invite User</DialogTitle>
      <DialogContent sx={{ pt: '12px !important' }}>
        {error && <Alert severity="error" sx={{ mb: 2 }}>{error}</Alert>}

        <TextField
          label="Email address"
          type="email"
          fullWidth
          value={email}
          onChange={(e) => setEmail(e.target.value)}
          onKeyDown={(e) => e.key === 'Enter' && handleSubmit()}
          autoFocus
          sx={{ mb: 2 }}
        />

        <TextField
          label="Role"
          select
          fullWidth
          value={role}
          onChange={(e) => setRole(e.target.value as Role)}
        >
          {allowedRoles.map((r) => (
            <MenuItem key={r} value={r} sx={{ textTransform: 'capitalize' }}>
              {r}
            </MenuItem>
          ))}
        </TextField>
      </DialogContent>

      <DialogActions sx={{ px: 3, pb: 2 }}>
        <Button onClick={handleClose} disabled={loading}>Cancel</Button>
        <Button
          variant="contained"
          onClick={handleSubmit}
          disabled={loading || !email.trim()}
          startIcon={loading ? <CircularProgress size={16} /> : undefined}
        >
          {loading ? 'Sending…' : 'Send Invitation'}
        </Button>
      </DialogActions>
    </Dialog>
  );
}
