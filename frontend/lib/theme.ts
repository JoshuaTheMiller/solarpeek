import { createTheme } from '@mui/material/styles';

// SolarPeak theme — amber/orange primary evokes solar energy
export const theme = createTheme({
  palette: {
    mode: 'light',
    primary: {
      main:  '#F59E0B',  // amber-500
      light: '#FCD34D',
      dark:  '#D97706',
    },
    secondary: {
      main: '#0EA5E9',   // sky-500 — sky/atmosphere contrast
    },
    background: {
      default: '#F8FAFC',
      paper:   '#FFFFFF',
    },
  },
  typography: {
    fontFamily: '"Inter", "Roboto", "Helvetica", "Arial", sans-serif',
    h4: { fontWeight: 700 },
    h5: { fontWeight: 600 },
    h6: { fontWeight: 600 },
  },
  shape: {
    borderRadius: 10,
  },
  components: {
    MuiButton: {
      styleOverrides: {
        root: { textTransform: 'none', fontWeight: 600 },
      },
    },
    MuiCard: {
      styleOverrides: {
        root: { boxShadow: '0 1px 4px rgba(0,0,0,0.08)' },
      },
    },
  },
});
