import { withMiddlewareAuthRequired } from '@auth0/nextjs-auth0/edge';
import { type NextFetchEvent, type NextRequest, NextResponse } from 'next/server';

// ── Auth bypass ───────────────────────────────────────────────────────────────
// Both variables must be set together. Neither alone has any effect.
// When active, all /dashboard routes are accessible without Auth0.
const BYPASS_AUTH =
  process.env.DISABLE_AUTH?.trim().toLowerCase() === 'true' &&
  process.env.AM_I_SURE?.trim().toLowerCase()    === 'yes';

export default function middleware(req: NextRequest, event: NextFetchEvent) {
  // Short-circuit before any Auth0 code runs.
  // Auth0 env vars are not required in bypass mode.
  if (BYPASS_AUTH) return NextResponse.next();

  // withMiddlewareAuthRequired() is constructed here — at request time —
  // not at module initialisation, so missing Auth0 env vars in bypass mode
  // never cause an error.
  return withMiddlewareAuthRequired()(req, event);
}

export const config = {
  matcher: ['/dashboard/:path*'],
};
