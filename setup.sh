#!/usr/bin/env bash
# =============================================================================
# SolarPeak — Project Setup Script
# =============================================================================
#
# Run once after cloning the repo. Installs dependencies, creates the database,
# and runs migrations.
#
# Prerequisites:
#   • Ruby 3.2+ (rbenv recommended)
#   • Node 20+
#   • PostgreSQL running locally or via Docker  (docker-compose up postgres redis)
#   • Redis running locally or via Docker
#   • backend/.env and frontend/.env.local present (run scripts/auth0_setup.rb first)
#
# Usage:
#   chmod +x setup.sh
#   ./setup.sh
# =============================================================================

set -euo pipefail

# ── Colours ───────────────────────────────────────────────────────────────────
GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; BOLD='\033[1m'; NC='\033[0m'
ok()   { echo -e "${GREEN}  ✓${NC} $1"; }
warn() { echo -e "${YELLOW}  ⚠${NC} $1"; }
fail() { echo -e "${RED}  ✗${NC} $1"; exit 1; }
step() { echo -e "\n${BOLD}▶ $1${NC}"; }

echo -e "\n${BOLD}════════════════════════════════════════════${NC}"
echo -e "${BOLD}  SolarPeak — Setup${NC}"
echo -e "${BOLD}════════════════════════════════════════════${NC}\n"

# ── Check prerequisites ───────────────────────────────────────────────────────
step "Checking prerequisites"

command -v ruby  >/dev/null 2>&1 || fail "Ruby not found. Install via rbenv: https://github.com/rbenv/rbenv"
command -v node  >/dev/null 2>&1 || fail "Node.js not found. Install via nvm: https://github.com/nvm-sh/nvm"
command -v psql  >/dev/null 2>&1 || warn "psql not found — ensure PostgreSQL is reachable via DATABASE_URL"
command -v redis-cli >/dev/null 2>&1 || warn "redis-cli not found — ensure Redis is reachable via REDIS_URL"

ok "Ruby  $(ruby --version | awk '{print $2}')"
ok "Node  $(node --version)"

# ── Check env files ───────────────────────────────────────────────────────────
step "Checking environment files"

if [ ! -f backend/.env ]; then
  warn "backend/.env not found."
  echo "       Run: ruby scripts/auth0_setup.rb"
  echo "       Then re-run this script."
  exit 1
fi

if [ ! -f frontend/.env.local ]; then
  warn "frontend/.env.local not found."
  echo "       Run: ruby scripts/auth0_setup.rb"
  echo "       Then re-run this script."
  exit 1
fi

ok "backend/.env present"
ok "frontend/.env.local present"

# ── Backend ───────────────────────────────────────────────────────────────────
step "Installing Ruby gems (backend)"
cd backend
bundle install
ok "Gems installed"

step "Creating and migrating database"
bundle exec rails db:create db:migrate
ok "Database ready"

step "Seeding initial admin (if ADMIN_AUTH0_SUB + ADMIN_EMAIL are set)"
bundle exec rails db:seed
ok "Seed complete"

step "Generating OpenAPI spec (Rswag → public/openapi/v1/swagger.json)"
RAILS_ENV=test bundle exec rails rswag:specs:swaggerize 2>/dev/null || \
  warn "Spec generation failed — run manually once specs pass: bundle exec rails rswag:specs:swaggerize"
ok "OpenAPI spec generated → public/openapi/v1/swagger.json"

cd ..

# ── Frontend ──────────────────────────────────────────────────────────────────
step "Installing Node packages (frontend)"
cd frontend
npm install
ok "Packages installed"
cd ..

# ── Done ──────────────────────────────────────────────────────────────────────
echo -e "\n${BOLD}════════════════════════════════════════════${NC}"
echo -e "${GREEN}${BOLD}  ✓ Setup complete!${NC}"
echo -e "${BOLD}════════════════════════════════════════════${NC}"
echo
echo -e "  Start infrastructure:    ${BOLD}docker-compose up postgres redis${NC}"
echo -e "  Start Rails API:         ${BOLD}cd backend && bundle exec rails s -p 3001${NC}"
echo -e "  Start Next.js:           ${BOLD}cd frontend && npm run dev${NC}"
echo -e "  View API docs (Redocly): ${BOLD}http://localhost:3001/api-docs${NC}"
echo -e "  Raw OpenAPI spec:        ${BOLD}http://localhost:3001/openapi/v1/swagger.json${NC}"
echo
