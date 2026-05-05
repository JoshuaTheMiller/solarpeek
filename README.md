# ☀ SolarPeak

A full-stack web application for viewing historical solar generation trends.
Users sign in (via Auth0) and query wattage data over time, subject to per-user
date-range limits managed by admins and managers.

| Layer    | Technology                                                          |
| -------- | ------------------------------------------------------------------- |
| Frontend | Next.js 14 (App Router) · MUI v5 · Recharts · `@auth0/nextjs-auth0` |
| Backend  | Ruby on Rails 7.1 (API-only) · Pundit · Rswag → Redocly             |
| Database | PostgreSQL 16                                                       |
| Cache    | Redis 7                                                             |
| Auth     | Auth0 (Regular Web App + M2M)                                       |

---

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Quick Start — Bypass Mode](#quick-start--bypass-mode) ← fastest path, no Auth0 needed
3. [Full Setup — with Auth0](#full-setup--with-auth0)
4. [Daily Development](#daily-development)
5. [API Documentation](#api-documentation)
6. [Project Structure](#project-structure)
7. [Role & Permission Reference](#role--permission-reference)

---

## Prerequisites

Install these before anything else.

| Tool           | Version | Install                                                       |
| -------------- | ------- | ------------------------------------------------------------- |
| Ruby           | 3.2+    | [rbenv](https://github.com/rbenv/rbenv) recommended           |
| Node.js        | 20+     | [nvm](https://github.com/nvm-sh/nvm) recommended              |
| Docker Desktop | latest  | [docker.com](https://www.docker.com/products/docker-desktop/) |
| Git            | any     | —                                                             |

Verify:

```bash
ruby --version   # ruby 3.2.x
node --version   # v20.x.x
docker info      # should not error
```

---

## Quick Start — Bypass Mode

**Fastest path.** No Auth0 account required. All steps are automated.
Estimated time: **~5 minutes** (depending on `bundle install` / `npm install`).

Copy and run this script from the repo root:

```bash
#!/usr/bin/env bash
set -euo pipefail

echo "── SolarPeak Quick Start (bypass mode) ──────────────────────────"

# 1. Write backend env (bypass mode, no Auth0 needed)
cat > backend/.env << 'EOF'
DATABASE_URL=postgresql://solarpeak:solarpeak@localhost/solarpeak_development
REDIS_URL=redis://localhost:6379/0
FRONTEND_URL=http://localhost:3000
AUTH0_DOMAIN=bypass.local
AUTH0_AUDIENCE=https://api.solarpeak.dev
AUTH0_MANAGEMENT_CLIENT_ID=bypass
AUTH0_MANAGEMENT_CLIENT_SECRET=bypass
AUTH0_MANAGEMENT_AUDIENCE=bypass
DISABLE_AUTH=true
AM_I_SURE=yes
EOF

# 2. Write frontend env (bypass mode, no Auth0 needed)
cat > frontend/.env.local << 'EOF'
AUTH0_SECRET=dev-secret-not-for-production-use-only-32b
AUTH0_BASE_URL=http://localhost:3000
AUTH0_ISSUER_BASE_URL=https://bypass.local
AUTH0_CLIENT_ID=bypass
AUTH0_CLIENT_SECRET=bypass
AUTH0_AUDIENCE=https://api.solarpeak.dev
AUTH0_SCOPE=openid profile email
NEXT_PUBLIC_API_URL=http://localhost:3001
DISABLE_AUTH=true
AM_I_SURE=yes
EOF

# 3. Start PostgreSQL and Redis
echo "→ Starting infrastructure..."
docker compose up -d postgres redis
echo "  Waiting for postgres..."
until docker compose exec -T postgres pg_isready -U solarpeak -q; do sleep 1; done
echo "  Waiting for redis..."
until docker compose exec -T redis redis-cli ping | grep -q PONG; do sleep 1; done

# 4. Install gems and set up database
echo "→ Installing Ruby gems..."
cd backend && bundle install --quiet

echo "→ Creating and migrating database..."
bin/rails db:create db:migrate db:seed

echo "→ Generating OpenAPI spec..."
RAILS_ENV=test bin/rails rswag:specs:swaggerize 2>/dev/null || true

cd ..

# 5. Install Node packages
echo "→ Installing Node packages..."
cd frontend && npm install --silent && cd ..

echo ""
echo "✓ Setup complete!"
echo ""
echo "  Open two terminal tabs and run:"
echo ""
echo "    Terminal 1 → cd backend  && bin/rails s -p 3001"
echo "    Terminal 2 → cd frontend && npm run dev"
echo ""
echo "  Then visit:  http://localhost:3000"
echo "  API docs:    http://localhost:3001/api-docs"
echo ""
echo "  ⚠  Auth bypass is active — signed in as dev@localhost (admin)."
echo "     Set DISABLE_AUTH and AM_I_SURE to disable it."
```

> **What bypass mode does:** both servers skip Auth0 entirely. Every request is
> authenticated as a local `dev@localhost` admin. A yellow warning banner is
> shown in the UI. See [Full Setup](#full-setup--with-auth0) when you are ready
> to wire in real Auth0.

---

## Full Setup — with Auth0

Use this path when you want real authentication, invitations, and role enforcement.

### 1 — Create the Auth0 bootstrap app (manual, one-time)

1. Create a free account at [auth0.com](https://auth0.com) and create a tenant
   (e.g. `solarpeak-dev`)
2. In the Auth0 Dashboard:
   **Applications → Create Application**
   → Name: `SolarPeak Bootstrap` · Type: **Machine to Machine**
3. Select API: **Auth0 Management API** → check **Select All** → click **Authorize**
4. On the **Settings** tab, note your **Domain**, **Client ID**, and **Client Secret**

### 2 — Run the automated Auth0 setup script

```bash
ruby scripts/auth0_setup.rb
```

The script will prompt for your bootstrap credentials and then:

- Create the **SolarPeak Web** Regular Web Application (for Next.js)
- Create the **SolarPeak API** resource server (JWT audience for Rails)
- Create the **SolarPeak Backend** M2M application (for user invitations)
- Grant Management API scopes to the M2M app
- Write `backend/.env` and `frontend/.env.local` with all generated values

After it finishes, delete the `SolarPeak Bootstrap` M2M app from the Auth0
Dashboard (it held broad permissions and is no longer needed).

### 3 — Seed the first admin user

The first admin must be created manually because there is nobody yet to send an
invitation.

1. In the Auth0 Dashboard, create a user under **User Management → Users**
2. Note their `user_id` (format: `auth0|abc123...`)
3. Add to `backend/.env`:

```bash
ADMIN_AUTH0_SUB=auth0|your-user-id-here
ADMIN_EMAIL=you@example.com
```

### 4 — Install dependencies and start

```bash
# Start infrastructure
docker compose up -d postgres redis

# Install and set up
chmod +x setup.sh && ./setup.sh
```

### 5 — Start the servers

```bash
# Terminal 1
cd backend && bin/rails server -p 3001

# Terminal 2
cd frontend && npm run dev
```

Visit [http://localhost:3000](http://localhost:3000) — you will be redirected to
the Auth0 login page.

---

## Daily Development

### Runtime Modes

SolarPeak supports two Docker Compose workflows:

1. **Stable mode (default, recommended)**
   - Best for remote/devcontainer environments.
   - Runs app services from image contents (no bind mounts).

```bash
docker compose up --build -d
docker compose ps
```

2. **Hot-reload mode (optional)**
   - Best when bind mounts are known to work in your local Docker setup.
   - Uses mounted source code for faster edit-refresh loops.

```bash
docker compose -f docker-compose.yml -f docker-compose.hotreload.yml up --build -d
docker compose -f docker-compose.yml -f docker-compose.hotreload.yml ps
```

Stop commands:

```bash
# Stable mode
docker compose down

# Hot-reload mode
docker compose -f docker-compose.yml -f docker-compose.hotreload.yml down
```

### Start everything

```bash
# Infrastructure only (if running app locally outside compose)
docker compose up -d postgres redis

# Rails API (Terminal 1, local runtime mode)
cd backend && bin/rails server -p 3001

# Next.js (Terminal 2, local runtime mode)
cd frontend && npm run dev
```

### Useful commands

```bash
# ── Rails ────────────────────────────────────────────────────────────────────

# Open a Rails console
cd backend && bin/rails console

# Run all specs
cd backend && bundle exec rspec

# Run a specific spec file
cd backend && bundle exec rspec spec/requests/api/v1/solar_spec.rb

# Regenerate the OpenAPI spec after editing request specs
cd backend && RAILS_ENV=test bin/rails rswag:specs:swaggerize

# Reset the database
cd backend && bin/rails db:drop db:create db:migrate db:seed

# Check routes
cd backend && bin/rails routes --expanded

# ── Next.js ──────────────────────────────────────────────────────────────────

# Type-check without building
cd frontend && npx tsc --noEmit

# Lint
cd frontend && npm run lint

# Production build (check for errors)
cd frontend && npm run build

# ── Docker ───────────────────────────────────────────────────────────────────

# Stop infrastructure
docker compose down

# Wipe all data and start fresh
docker compose down -v
```

### Toggle bypass mode

Add or remove these two lines in **both** `backend/.env` and
`frontend/.env.local`, then restart both servers:

```bash
DISABLE_AUTH=true
AM_I_SURE=yes
```

Both must be present together. Neither alone has any effect. Bypass mode is
blocked entirely when `RAILS_ENV=production`.

---

## API Documentation

With the Rails server running:

| URL                                             | Description                      |
| ----------------------------------------------- | -------------------------------- |
| `http://localhost:3001/api-docs`                | Redocly interactive docs         |
| `http://localhost:3001/openapi/v1/swagger.json` | Raw OpenAPI 3.0 JSON             |
| `http://localhost:3001/health`                  | Health check (`{"status":"ok"}`) |

The OpenAPI spec is generated from the RSpec request specs using Rswag:

```bash
cd backend && RAILS_ENV=test bin/rails rswag:specs:swaggerize
```

Re-run this whenever you add or modify a request spec.

---

## Project Structure

```
SolarPeak/
│
├── backend/                        Rails 7.1 API
│   ├── app/
│   │   ├── controllers/
│   │   │   └── api/v1/
│   │   │       ├── me_controller.rb          GET /api/v1/me
│   │   │       ├── solar_controller.rb       GET /api/v1/solar/readings
│   │   │       ├── users_controller.rb       CRUD /api/v1/users
│   │   │       └── invitations_controller.rb POST /api/v1/invitations
│   │   ├── models/
│   │   │   └── user.rb                       roles enum, query_limit helpers
│   │   ├── policies/
│   │   │   ├── user_policy.rb                Pundit: who can manage users
│   │   │   └── solar_policy.rb               Pundit: enforces query_limit_days
│   │   └── services/
│   │       ├── json_web_token.rb             Auth0 JWT decode + JWKS caching
│   │       ├── solar_data_service.rb         stub → real API (replace later)
│   │       └── auth0_management_service.rb   invite users, block/unblock
│   ├── config/
│   │   ├── initializers/
│   │   │   ├── bypass_auth.rb                startup guard + warning banner
│   │   │   ├── cors.rb
│   │   │   ├── redis.rb
│   │   │   └── rswag.rb
│   │   └── routes.rb
│   ├── db/migrate/
│   │   └── 20240101000001_create_users.rb
│   ├── public/
│   │   ├── api-docs/index.html               Redocly viewer
│   │   └── openapi/v1/swagger.json           generated — do not edit by hand
│   └── spec/
│       ├── requests/api/v1/                  Rswag specs (also generate the docs)
│       └── factories/users.rb
│
├── frontend/                       Next.js 14 (App Router)
│   ├── app/
│   │   ├── api/
│   │   │   ├── auth/[auth0]/route.ts         Auth0 login/logout/callback
│   │   │   └── proxy/[...path]/route.ts      token-injecting API proxy
│   │   └── dashboard/
│   │       ├── page.tsx                      Solar Trends (chart + date picker)
│   │       └── users/page.tsx                User management (admin/manager)
│   ├── components/
│   │   ├── layout/   DashboardLayout, Sidebar
│   │   ├── solar/    SolarChart (Recharts), SummaryCards, QueryLimitBanner
│   │   └── users/    UsersTable, InviteUserDialog, EditQueryLimitDialog
│   ├── lib/
│   │   ├── hooks/    useMe, useSolarData, useUsers (SWR)
│   │   ├── types.ts
│   │   └── theme.ts  MUI amber/solar theme
│   └── middleware.ts                         protects /dashboard/* routes
│
├── scripts/
│   └── auth0_setup.rb              one-time Auth0 configuration + .env generation
│
├── docker-compose.yml              postgres + redis (+ optional app containers)
├── setup.sh                        install deps, migrate DB, generate spec
└── .gitignore
```

---

## Role & Permission Reference

| Action                              | Admin | Manager | Viewer |
| ----------------------------------- | :---: | :-----: | :----: |
| Query solar data (within own limit) |  ✅   |   ✅    |   ✅   |
| Invite managers                     |  ✅   |   ✅    |   ❌   |
| Invite viewers                      |  ✅   |   ✅    |   ❌   |
| Invite admins                       |  ✅   |   ❌    |   ❌   |
| Set any user's query limit          |  ✅   |   ✅    |   ❌   |
| View all users                      |  ✅   |   ✅    |   ❌   |
| Deactivate / reactivate users       |  ✅   |   ✅    |   ❌   |

**Default query limit:** 30 days for all newly invited users.  
Admins and managers can adjust this per user from the Users page.

---

## Environment Variable Reference

### `backend/.env`

| Variable                         | Required | Description                                        |
| -------------------------------- | -------- | -------------------------------------------------- |
| `DATABASE_URL`                   | ✅       | PostgreSQL connection string                       |
| `REDIS_URL`                      | ✅       | Redis connection string                            |
| `FRONTEND_URL`                   | ✅       | CORS allowed origin (e.g. `http://localhost:3000`) |
| `AUTH0_DOMAIN`                   | ✅\*     | Auth0 tenant domain                                |
| `AUTH0_AUDIENCE`                 | ✅\*     | API resource server identifier                     |
| `AUTH0_MANAGEMENT_CLIENT_ID`     | ✅\*     | M2M app client ID (for invitations)                |
| `AUTH0_MANAGEMENT_CLIENT_SECRET` | ✅\*     | M2M app client secret                              |
| `AUTH0_MANAGEMENT_AUDIENCE`      | ✅\*     | `https://<domain>/api/v2/`                         |
| `ADMIN_AUTH0_SUB`                | seeding  | Auth0 `sub` of the first admin (for `db:seed`)     |
| `ADMIN_EMAIL`                    | seeding  | Email of the first admin                           |
| `DISABLE_AUTH`                   | bypass   | Set to `true` (must pair with `AM_I_SURE`)         |
| `AM_I_SURE`                      | bypass   | Set to `yes` (must pair with `DISABLE_AUTH`)       |

\*Not required when bypass mode is active.

### `frontend/.env.local`

| Variable                | Required | Description                                       |
| ----------------------- | -------- | ------------------------------------------------- |
| `AUTH0_SECRET`          | ✅\*     | 32-byte hex string; encrypts the session cookie   |
| `AUTH0_BASE_URL`        | ✅\*     | Canonical URL of the Next.js app                  |
| `AUTH0_ISSUER_BASE_URL` | ✅\*     | `https://<auth0-domain>`                          |
| `AUTH0_CLIENT_ID`       | ✅\*     | Regular Web App client ID                         |
| `AUTH0_CLIENT_SECRET`   | ✅\*     | Regular Web App client secret                     |
| `AUTH0_AUDIENCE`        | ✅\*     | Must match Rails `AUTH0_AUDIENCE`                 |
| `NEXT_PUBLIC_API_URL`   | ✅       | Rails API base URL (e.g. `http://localhost:3001`) |
| `DISABLE_AUTH`          | bypass   | Set to `true` (must pair with `AM_I_SURE`)        |
| `AM_I_SURE`             | bypass   | Set to `yes` (must pair with `DISABLE_AUTH`)      |

\*Not required when bypass mode is active. Can be set to placeholder values.
