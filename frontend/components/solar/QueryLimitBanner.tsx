'use client';

import { Alert, AlertTitle } from '@mui/material';
import InfoOutlinedIcon       from '@mui/icons-material/InfoOutlined';

interface Props {
  queryLimitDays: number;
}

// Prominently displays the user's current query limit on the Solar Trends page.
// This is always shown — not just when a limit is exceeded — so users always
// know the bounds of their data access.
export default function QueryLimitBanner({ queryLimitDays }: Props) {
  return (
    <Alert
      severity="info"
      icon={<InfoOutlinedIcon />}
      sx={{ mt: 1 }}
    >
      <AlertTitle>Query Limit</AlertTitle>
      Your account is permitted to query up to{' '}
      <strong>{queryLimitDays} days</strong> of data at once. Contact an admin
      or manager to adjust this limit.
    </Alert>
  );
}
