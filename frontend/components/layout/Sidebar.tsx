'use client';

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
}

const NAV_ITEMS: NavItem[] = [
  {
    label: 'Solar Trends',
    href:  '/dashboard',
    icon:  <BarChartIcon />,
    roles: ['viewer', 'manager', 'admin'],
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
          const active = pathname === item.href;
          return (
            <ListItem key={item.href} disablePadding>
              <ListItemButton
                component={NextLink}
                href={item.href}
                onClick={() => {
                  if (isMobile) onClose();
                }}
                selected={active}
                sx={{
                  mx: 1,
                  borderRadius: 2,
                  '&.Mui-selected': {
                    bgcolor: 'primary.main',
                    color:   'white',
                    '& .MuiListItemIcon-root': { color: 'white' },
                    '&:hover': { bgcolor: 'primary.dark' },
                  },
                }}
              >
                <ListItemIcon sx={{ minWidth: 38 }}>{item.icon}</ListItemIcon>
                <ListItemText primary={item.label} />
              </ListItemButton>
            </ListItem>
          );
        })}
      </List>
    </Drawer>
  );
}
