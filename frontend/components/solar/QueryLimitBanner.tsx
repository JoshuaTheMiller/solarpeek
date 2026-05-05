'use client';

import { Alert, AlertTitle } from '@mui/material';
import InfoOutlinedIcon       from '@mui/icons-material/InfoOutlined';

interface Props {
  queryLimitDays: number;
  onDismiss: () => void;
}

// Displays the user's current query limit on the Solar Trends page.
// Can be dismissed; the dismissed state is persisted per-user on the server.
export default function QueryLimitBanner({ queryLimitDays, onDismiss }: Props) {
  return (
    <Alert
      severity="info"
      icon={<InfoOutlinedIcon />}
      onClose={onDismiss}
      sx={{ mt: 1 }}
    >
      <AlertTitle>Query Limit</AlertTitle>
      Your account is permitted to query up to{' '}
      <strong>{queryLimitDays} days</strong> of data at once. Contact an admin
      or manager to adjust this limit.
    </Alert>
  );
}
