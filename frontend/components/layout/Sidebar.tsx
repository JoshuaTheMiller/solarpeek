'use client';

import { Fragment } from 'react';
import { usePathname } from 'next/navigation';
import NextLink        from 'next/link';
import {
  Drawer, List, ListItem, ListItemButton,
  ListItemIcon, ListItemText, Toolbar,
  useMediaQuery,
} from '@mui/material';
import { useTheme } from '@mui/material/styles';
import BarChartIcon from '@mui/icons-material/BarChart';
import PeopleIcon   from '@mui/icons-material/People';
import type { Role } from '@/lib/types';

const DRAWER_WIDTH = 240;

interface NavItem {
  label:    string;
  href:     string;
  icon:     React.ReactNode;
  roles:    Role[];          // which roles can see this item
  children?: Array<{
    label: string;
    href: string;
  }>;
}

const NAV_ITEMS: NavItem[] = [
  {
    label: 'Solar Trends',
    href:  '/dashboard/solar',
    icon:  <BarChartIcon />,
    roles: ['viewer', 'manager', 'admin'],
    children: [
      { label: 'Dashboard', href: '/dashboard/solar/dashboard' },
      { label: 'Overlay', href: '/dashboard/solar/overlay' },
    ],
  },
  {
    label: 'Users',
    href:  '/dashboard/users',
    icon:  <PeopleIcon />,
    roles: ['manager', 'admin'],
  },
];

interface Props {
  open: boolean;
  role: Role;
  onClose: () => void;
}

export default function Sidebar({ open, role, onClose }: Props) {
  const pathname = usePathname();
  const theme = useTheme();
  const isMobile = useMediaQuery(theme.breakpoints.down('md'));

  const visibleItems = NAV_ITEMS.filter((item) => item.roles.includes(role));

  const isActivePath = (href: string) => pathname === href || pathname.startsWith(`${href}/`);

  return (
    <Drawer
      variant={isMobile ? 'temporary' : 'persistent'}
      open={open}
      onClose={onClose}
      ModalProps={{ keepMounted: true }}
      sx={{
        width: DRAWER_WIDTH,
        flexShrink: 0,
        '& .MuiDrawer-paper': {
          width: DRAWER_WIDTH,
          boxSizing: 'border-box',
          borderRight: '1px solid',
          borderColor: 'divider',
        },
      }}
    >
      <Toolbar /> {/* Spacer below AppBar */}
      <List sx={{ pt: 1 }}>
        {visibleItems.map((item) => {
          const active = isActivePath(item.href);
          return (
            <Fragment key={item.href}>
              <ListItem disablePadding>
                <ListItemButton
                  component={NextLink}
                  href={item.children?.[0]?.href ?? item.href}
                  onClick={() => {
                    if (isMobile) onClose();
                  }}
                  selected={active}
                  sx={{
                    mx: 1,
                    borderRadius: 2,
                    '&.Mui-selected': {
                      bgcolor: 'primary.main',
                      color: 'white',
                      '& .MuiListItemIcon-root': { color: 'white' },
                      '&:hover': { bgcolor: 'primary.dark' },
                    },
                  }}
                >
                  <ListItemIcon sx={{ minWidth: 38 }}>{item.icon}</ListItemIcon>
                  <ListItemText primary={item.label} />
                </ListItemButton>
              </ListItem>

              {item.children?.map((child) => {
                const childActive = pathname === child.href;
                return (
                  <ListItem key={child.href} disablePadding sx={{ pl: 3 }}>
                    <ListItemButton
                      component={NextLink}
                      href={child.href}
                      onClick={() => {
                        if (isMobile) onClose();
                      }}
                      selected={childActive}
                      sx={{
                        mx: 1,
                        borderRadius: 2,
                        '&.Mui-selected': {
                          bgcolor: 'action.selected',
                          color: 'text.primary',
                        },
                      }}
                    >
                      <ListItemText primary={child.label} primaryTypographyProps={{ fontSize: 14 }} />
                    </ListItemButton>
                  </ListItem>
                );
              })}
            </Fragment>
          );
        })}
      </List>
    </Drawer>
  );
}
