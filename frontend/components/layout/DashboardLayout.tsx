'use client';

import { useState }       from 'react';
import { Box, AppBar, Toolbar, Typography, IconButton,
         Avatar, Menu, MenuItem, Tooltip, Divider, Alert } from '@mui/material';
import MenuIcon            from '@mui/icons-material/Menu';
import LogoutIcon          from '@mui/icons-material/Logout';
import WarningAmberIcon    from '@mui/icons-material/WarningAmber';
import { useUser }         from '@auth0/nextjs-auth0/client';
import Sidebar             from './Sidebar';
import { useMe }           from '@/lib/hooks/useMe';

const DRAWER_WIDTH = 240;

export default function DashboardLayout({ children }: { children: React.ReactNode }) {
  const [sidebarOpen, setSidebarOpen] = useState(true);
  const [anchorEl,    setAnchorEl]    = useState<null | HTMLElement>(null);

  const { user }    = useUser();   // null in bypass mode — Auth0 session does not exist
  const { me }      = useMe();     // always populated (proxy → Rails bypass user)
  const bypassMode  = me?.bypass_mode === true;

  // In bypass mode, Auth0's useUser() returns nothing; fall back to the Rails /me identity
  const displayEmail   = user?.email   ?? me?.email   ?? 'dev@localhost';
  const displayName    = user?.name    ?? me?.email   ?? 'Dev User';
  const initials       = displayName
    .split(' ')
    .map((p: string) => p[0])
    .join('')
    .toUpperCase()
    .slice(0, 2);

  return (
    <Box sx={{ display: 'flex', minHeight: '100vh' }}>
      {/* ── Top AppBar ───────────────────────────────────────────────── */}
      <AppBar
        position="fixed"
        elevation={0}
        sx={{
          zIndex: (t) => t.zIndex.drawer + 1,
          borderBottom: '1px solid',
          borderColor: 'divider',
          bgcolor: 'background.paper',
          color: 'text.primary',
        }}
      >
        <Toolbar>
          <IconButton edge="start" sx={{ mr: 2 }} onClick={() => setSidebarOpen((o) => !o)}>
            <MenuIcon />
          </IconButton>

          {/* Logo */}
          <Typography variant="h6" sx={{ flexGrow: 1, color: 'primary.main', fontWeight: 800 }}>
            ☀ SolarPeak
          </Typography>

          {/* Role badge */}
          {me && (
            <Box
              sx={{
                px: 1.5, py: 0.5, mr: 2,
                borderRadius: 99,
                bgcolor: 'primary.main',
                color: 'white',
                fontSize: '0.7rem',
                fontWeight: 700,
                textTransform: 'uppercase',
                letterSpacing: '0.05em',
              }}
            >
              {me.role}
            </Box>
          )}

          {/* Avatar menu */}
          <Tooltip title={displayEmail}>
            <IconButton onClick={(e) => setAnchorEl(e.currentTarget)} size="small">
              <Avatar
                sx={{
                  width: 34, height: 34, fontSize: '0.85rem',
                  bgcolor: bypassMode ? 'warning.main' : 'secondary.main',
                }}
              >
                {bypassMode ? '⚠' : initials}
              </Avatar>
            </IconButton>
          </Tooltip>

          <Menu
            anchorEl={anchorEl}
            open={Boolean(anchorEl)}
            onClose={() => setAnchorEl(null)}
            transformOrigin={{ horizontal: 'right', vertical: 'top' }}
            anchorOrigin={{  horizontal: 'right', vertical: 'bottom' }}
          >
            <MenuItem disabled sx={{ fontSize: '0.85rem' }}>{displayEmail}</MenuItem>
            {bypassMode && (
              <MenuItem disabled sx={{ fontSize: '0.75rem', color: 'warning.main' }}>
                Auth bypass active — no real session
              </MenuItem>
            )}
            <Divider />
            {/* Hide logout in bypass mode — there is no Auth0 session to clear */}
            {!bypassMode && (
              <MenuItem
                component="a"
                href="/api/auth/logout"
                onClick={() => setAnchorEl(null)}
              >
                <LogoutIcon fontSize="small" sx={{ mr: 1 }} />
                Sign out
              </MenuItem>
            )}
          </Menu>
        </Toolbar>
      </AppBar>

      {/* ── Sidebar ──────────────────────────────────────────────────── */}
      <Sidebar open={sidebarOpen} role={me?.role ?? 'viewer'} />

      {/* ── Main content ─────────────────────────────────────────────── */}
      <Box
        component="main"
        sx={{
          flexGrow: 1,
          p: 3,
          mt: '64px', // AppBar height + bypass banner handled by Alert below
          ml: sidebarOpen ? `${DRAWER_WIDTH}px` : 0,
          transition: 'margin 0.2s ease',
          bgcolor: 'background.default',
          minHeight: 'calc(100vh - 64px)',
        }}
      >
        {/* ── Bypass mode banner ─────────────────────────────────────── */}
        {bypassMode && (
          <Alert
            severity="warning"
            icon={<WarningAmberIcon />}
            sx={{ mb: 2, fontWeight: 500 }}
          >
            <strong>Auth bypass active</strong> — DISABLE_AUTH=true + AM_I_SURE=yes.
            You are signed in as <code>dev@localhost</code> (admin).
            Auth0 is not required in this mode. Do not use in production.
          </Alert>
        )}

        {children}
      </Box>
    </Box>
  );
}
