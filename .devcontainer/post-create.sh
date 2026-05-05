#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# SolarPeak — Dev Container Post-Create Script
#
# Runs automatically once after the container is first created.
# Writes bypass .env files, installs all dependencies, creates and migrates
# the database, and generates the OpenAPI spec.
#
# Auth bypass is always enabled inside the dev container — Auth0 credentials
# are not required.  See README "Quick Start — Bypass Mode" for details.
# ─────────────────────────────────────────────────────────────────────────────

set -euo pipefail

ROOT=/workspaces/SolarPeak
GREEN='\033[0;32m'; BOLD='\033[1m'; NC='\033[0m'
ok()   { echo -e "${GREEN}  ✓${NC} $1"; }
step() { echo -e "\n${BOLD}▶ $1${NC}"; }

echo -e "\n${BOLD}════════════════════════════════════════════${NC}"
echo -e "${BOLD}  SolarPeak — Dev Container Setup${NC}"
echo -e "${BOLD}════════════════════════════════════════════${NC}\n"

# ── 1. Write backend/.env (bypass mode) ──────────────────────────────────────
step "Writing backend/.env (bypass mode)"

cat > "${ROOT}/backend/.env" << 'EOF'
DATABASE_URL=postgresql://solarpeak:solarpeak@postgres/solarpeak_development
REDIS_URL=redis://redis:6379/0
FRONTEND_URL=http://localhost:3000
AUTH0_DOMAIN=bypass.local
AUTH0_AUDIENCE=https://api.solarpeak.dev
AUTH0_MANAGEMENT_CLIENT_ID=bypass
AUTH0_MANAGEMENT_CLIENT_SECRET=bypass
AUTH0_MANAGEMENT_AUDIENCE=bypass
DISABLE_AUTH=true
AM_I_SURE=yes
EOF

ok "backend/.env written"

# ── 2. Write frontend/.env.local (bypass mode) ───────────────────────────────
step "Writing frontend/.env.local (bypass mode)"

cat > "${ROOT}/frontend/.env.local" << 'EOF'
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

ok "frontend/.env.local written"

# ── 3. Wait for PostgreSQL to be ready ───────────────────────────────────────
step "Waiting for PostgreSQL"
until pg_isready -h postgres -U solarpeak -q; do
  echo "  … waiting for postgres"
  sleep 2
done
ok "PostgreSQL ready"

# ── 4. Wait for Redis to be ready ────────────────────────────────────────────
step "Waiting for Redis"
until redis-cli -h redis ping | grep -q PONG; do
  echo "  … waiting for redis"
  sleep 2
done
ok "Redis ready"

# ── 5. Install Ruby gems ──────────────────────────────────────────────────────
step "Installing Ruby gems"
cd "${ROOT}/backend"
bundle install --jobs "$(nproc)" --retry 3
ok "Gems installed ($(bundle list | wc -l) gems)"

# ── 6. Create, migrate, and seed the database ────────────────────────────────
step "Setting up the database"
bundle exec rails db:create db:migrate db:seed
ok "Database ready"

# ── 7. Generate the OpenAPI spec ─────────────────────────────────────────────
step "Generating OpenAPI spec"
RAILS_ENV=test bundle exec rails rswag:specs:swaggerize 2>/dev/null \
  && ok "OpenAPI spec generated → public/openapi/v1/swagger.json" \
  || echo "  ⚠  Spec generation skipped (run manually once specs pass)"

cd "${ROOT}"

# ── 8. Install Node packages ──────────────────────────────────────────────────
step "Installing Node packages"
cd "${ROOT}/frontend"
npm install
ok "npm packages installed"

cd "${ROOT}"

# ── Done ─────────────────────────────────────────────────────────────────────
echo -e "\n${BOLD}════════════════════════════════════════════${NC}"
echo -e "${GREEN}${BOLD}  ✓ Dev container ready!${NC}"
echo -e "${BOLD}════════════════════════════════════════════${NC}"
echo
echo -e "  In the VS Code terminal, start the servers:"
echo
echo -e "    ${BOLD}Terminal 1${NC}  cd backend  && bundle exec rails s -p 3001"
echo -e "    ${BOLD}Terminal 2${NC}  cd frontend && npm run dev"
echo
echo -e "  Then open:"
echo -e "    Frontend:  http://localhost:3000"
echo -e "    API docs:  http://localhost:3001/api-docs"
echo
echo -e "  ⚠  Auth bypass is active — signed in as dev@localhost (admin)."
echo -e "     To use real Auth0, replace backend/.env and frontend/.env.local"
echo -e "     with values from: ruby scripts/auth0_setup.rb"
echo
