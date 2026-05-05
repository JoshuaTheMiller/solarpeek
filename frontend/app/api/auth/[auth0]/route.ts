import { NextResponse } from 'next/server';

// ── Auth bypass ───────────────────────────────────────────────────────────────
// When active, Auth0 env vars are not required and this route returns a stub.
// handleAuth() is dynamically imported so it is never evaluated in bypass mode
// (it reads AUTH0_* env vars on construction and would throw if they are absent).
const BYPASS_AUTH =
  process.env.DISABLE_AUTH?.trim().toLowerCase() === 'true' &&
  process.env.AM_I_SURE?.trim().toLowerCase()    === 'yes';

export async function GET(req: Request, ctx: { params: { auth0: string } }) {
  if (BYPASS_AUTH) {
    return NextResponse.json({
      message: 'Auth0 is disabled (DISABLE_AUTH=true + AM_I_SURE=yes). ' +
               'Use the app directly — you are already signed in as the bypass admin.',
    });
  }

  // Dynamic import keeps handleAuth() out of the module graph in bypass mode.
  const { handleAuth } = await import('@auth0/nextjs-auth0');
  return handleAuth()(req, ctx);
}
