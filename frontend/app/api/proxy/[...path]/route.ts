import { NextRequest, NextResponse } from 'next/server';

// ── Auth bypass ───────────────────────────────────────────────────────────────
// In bypass mode, getAccessToken() is never called (Auth0 env vars may be absent).
// The Rails API is also running in bypass mode and will authenticate the request
// as the local dev admin without requiring a Bearer token.
const BYPASS_AUTH =
  process.env.DISABLE_AUTH?.trim().toLowerCase() === 'true' &&
  process.env.AM_I_SURE?.trim().toLowerCase()    === 'yes';

const RAILS_API = process.env.NEXT_PUBLIC_API_URL ?? 'http://localhost:3001';

async function handler(
  req: NextRequest,
  { params }: { params: { path: string[] } }
) {
  const path = params.path.join('/');
  const url  = `${RAILS_API}/api/v1/${path}${req.nextUrl.search}`;

  const isReadMethod = ['GET', 'HEAD'].includes(req.method);
  const body         = isReadMethod ? undefined : await req.text();

  const headers: Record<string, string> = { 'Content-Type': 'application/json' };

  if (BYPASS_AUTH) {
    // No Authorization header — Rails bypass mode handles authentication.
    // No Auth0 SDK calls needed.
  } else {
    try {
      // Dynamic import: keeps getAccessToken out of the module graph in bypass mode.
      const { getAccessToken } = await import('@auth0/nextjs-auth0');
      const { accessToken }    = await getAccessToken();
      if (accessToken) headers['Authorization'] = `Bearer ${accessToken}`;
    } catch {
      return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });
    }
  }

  try {
    const upstream = await fetch(url, {
      method:  req.method,
      headers,
      body,
    });

    const data = await upstream.json().catch(() => ({}));
    return NextResponse.json(data, { status: upstream.status });
  } catch (err) {
    console.error('[proxy] upstream error:', err);
    return NextResponse.json({ error: 'Upstream request failed' }, { status: 502 });
  }
}

export { handler as GET, handler as POST, handler as PATCH, handler as DELETE };
