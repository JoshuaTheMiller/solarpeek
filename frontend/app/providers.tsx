'use client';

import { UserProvider }    from '@auth0/nextjs-auth0/client';
import { ThemeProvider, CssBaseline } from '@mui/material';
import { AppRouterCacheProvider } from '@mui/material-nextjs/v14-appRouter';
import { theme }           from '@/lib/theme';

export default function Providers({ children }: { children: React.ReactNode }) {
  return (
    <UserProvider>
      <AppRouterCacheProvider>
        <ThemeProvider theme={theme}>
          <CssBaseline />
          {children}
        </ThemeProvider>
      </AppRouterCacheProvider>
    </UserProvider>
  );
}
