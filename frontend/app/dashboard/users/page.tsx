'use client';

import { useState }             from 'react';
import { Box, Typography, Button, Alert, CircularProgress } from '@mui/material';
import PersonAddIcon             from '@mui/icons-material/PersonAdd';

import UsersTable          from '@/components/users/UsersTable';
import InviteUserDialog    from '@/components/users/InviteUserDialog';
import EditQueryLimitDialog from '@/components/users/EditQueryLimitDialog';
import { useMe }           from '@/lib/hooks/useMe';
import { useUsers }        from '@/lib/hooks/useUsers';
import type { User }       from '@/lib/types';

export default function UsersPage() {
  const { me, isLoading: meLoading }       = useMe();
  const { users, isLoading, error, mutate } = useUsers();

  const [inviteOpen,    setInviteOpen]    = useState(false);
  const [limitTarget,   setLimitTarget]   = useState<User | null>(null);

  if (meLoading || isLoading) {
    return (
      <Box display="flex" justifyContent="center" alignItems="center" minHeight="60vh">
        <CircularProgress />
      </Box>
    );
  }

  // Viewers should never land here (Sidebar hides the link), but guard anyway
  if (me?.role === 'viewer') {
    return <Alert severity="error">You do not have permission to view this page.</Alert>;
  }

  return (
    <Box>
      <Box display="flex" justifyContent="space-between" alignItems="center" mb={3}>
        <Typography variant="h4" fontWeight={700}>
          Users
        </Typography>
        <Button
          variant="contained"
          startIcon={<PersonAddIcon />}
          onClick={() => setInviteOpen(true)}
        >
          Invite User
        </Button>
      </Box>

      {error && <Alert severity="error" sx={{ mb: 2 }}>{error}</Alert>}

      <UsersTable
        users={users ?? []}
        currentUser={me!}
        onEditLimit={(user) => setLimitTarget(user)}
        onDeactivate={mutate}
        onReactivate={mutate}
      />

      <InviteUserDialog
        open={inviteOpen}
        currentUserRole={me!.role}
        onClose={() => setInviteOpen(false)}
        onSuccess={() => { setInviteOpen(false); mutate(); }}
      />

      {limitTarget && (
        <EditQueryLimitDialog
          user={limitTarget}
          onClose={() => setLimitTarget(null)}
          onSuccess={() => { setLimitTarget(null); mutate(); }}
        />
      )}
    </Box>
  );
}
