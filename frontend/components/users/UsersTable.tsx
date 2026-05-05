'use client';

import { useState }  from 'react';
import {
  Table, TableHead, TableBody, TableRow, TableCell,
  TableContainer, Paper, Chip, IconButton, Tooltip,
  Typography, Box,
} from '@mui/material';
import EditIcon          from '@mui/icons-material/Edit';
import BlockIcon         from '@mui/icons-material/Block';
import CheckCircleIcon   from '@mui/icons-material/CheckCircle';
import type { User, Role } from '@/lib/types';

interface Props {
  users:       User[];
  currentUser: User;
  onEditLimit: (user: User) => void;
  onDeactivate: () => void;
  onReactivate: () => void;
}

const ROLE_COLORS: Record<Role, 'default' | 'primary' | 'error'> = {
  viewer:  'default',
  manager: 'primary',
  admin:   'error',
};

export default function UsersTable({
  users, currentUser, onEditLimit, onDeactivate, onReactivate,
}: Props) {
  const [busy, setBusy] = useState<number | null>(null);

  async function handleDeactivate(user: User) {
    if (!confirm(`Deactivate ${user.email}?`)) return;
    setBusy(user.id);
    try {
      const res = await fetch(`/api/proxy/users/${user.id}`, { method: 'DELETE' });
      if (!res.ok) {
        const b = await res.json();
        alert(b.error ?? 'Deactivation failed');
      } else {
        onDeactivate();
      }
    } finally {
      setBusy(null);
    }
  }

  async function handleReactivate(user: User) {
    setBusy(user.id);
    try {
      const res = await fetch(`/api/proxy/users/${user.id}/reactivate`, { method: 'PATCH' });
      if (!res.ok) {
        const b = await res.json();
        alert(b.error ?? 'Reactivation failed');
      } else {
        onReactivate();
      }
    } finally {
      setBusy(null);
    }
  }

  // Can the current user deactivate a given target?
  function canDeactivate(target: User) {
    if (target.id === currentUser.id) return false;
    if (target.role === 'admin')      return false;
    return currentUser.role === 'admin' || currentUser.role === 'manager';
  }

  if (!users.length) {
    return (
      <Box textAlign="center" py={6}>
        <Typography color="text.secondary">No users found.</Typography>
      </Box>
    );
  }

  return (
    <TableContainer component={Paper} variant="outlined" sx={{ overflowX: 'auto' }}>
      <Table size="small" sx={{ minWidth: 700 }}>
        <TableHead>
          <TableRow sx={{ '& th': { fontWeight: 700, bgcolor: 'grey.50' } }}>
            <TableCell>Email</TableCell>
            <TableCell>Role</TableCell>
            <TableCell align="center">Query Limit</TableCell>
            <TableCell align="center">Status</TableCell>
            <TableCell align="center">Actions</TableCell>
          </TableRow>
        </TableHead>
        <TableBody>
          {users.map((user) => (
            <TableRow
              key={user.id}
              sx={{ opacity: user.active ? 1 : 0.5, '&:last-child td': { border: 0 } }}
            >
              <TableCell>
                <Typography variant="body2">{user.email}</Typography>
                {user.id === currentUser.id && (
                  <Typography variant="caption" color="primary">(you)</Typography>
                )}
              </TableCell>

              <TableCell>
                <Chip
                  label={user.role}
                  color={ROLE_COLORS[user.role]}
                  size="small"
                  sx={{ textTransform: 'capitalize', fontWeight: 600 }}
                />
              </TableCell>

              <TableCell align="center">
                <Typography variant="body2">{user.query_limit_days} days</Typography>
              </TableCell>

              <TableCell align="center">
                <Chip
                  label={user.active ? 'Active' : 'Inactive'}
                  color={user.active ? 'success' : 'default'}
                  size="small"
                  variant={user.active ? 'filled' : 'outlined'}
                />
              </TableCell>

              <TableCell align="center">
                {/* Edit query limit */}
                <Tooltip title="Edit query limit">
                  <span>
                    <IconButton
                      size="small"
                      onClick={() => onEditLimit(user)}
                      disabled={
                        busy === user.id ||
                        !(currentUser.role === 'admin' || currentUser.role === 'manager')
                      }
                    >
                      <EditIcon fontSize="small" />
                    </IconButton>
                  </span>
                </Tooltip>

                {/* Deactivate / Reactivate */}
                {user.active ? (
                  <Tooltip title="Deactivate user">
                    <span>
                      <IconButton
                        size="small"
                        color="error"
                        onClick={() => handleDeactivate(user)}
                        disabled={busy === user.id || !canDeactivate(user)}
                      >
                        <BlockIcon fontSize="small" />
                      </IconButton>
                    </span>
                  </Tooltip>
                ) : (
                  <Tooltip title="Reactivate user">
                    <span>
                      <IconButton
                        size="small"
                        color="success"
                        onClick={() => handleReactivate(user)}
                        disabled={
                          busy === user.id ||
                          !(currentUser.role === 'admin' || currentUser.role === 'manager')
                        }
                      >
                        <CheckCircleIcon fontSize="small" />
                      </IconButton>
                    </span>
                  </Tooltip>
                )}
              </TableCell>
            </TableRow>
          ))}
        </TableBody>
      </Table>
    </TableContainer>
  );
}
