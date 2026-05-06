#!/usr/bin/env bash
# =============================================================================
# SolarPeak — Project Setup Script
# =============================================================================
#
# Run once after cloning the repo. Installs dependencies, creates the database,
# and runs migrations. This script is Ubuntu-specific.
#
# Prerequisites:
#   • Ubuntu 24.04+ recommended
#   • PostgreSQL running locally or via Docker (docker compose up -d postgres redis)
#   • Redis running locally or via Docker
#   • backend/.env and frontend/.env.local present
#
# Usage:
#   chmod +x setup.sh
#   ./setup.sh -y
#   ./setup.sh -a
#   ./setup.sh -y --bypass-mode true
#
# Flags:
#   -a   Auto-install required Ubuntu packages with apt, then continue setup
#   -y   Required confirmation to run install steps when -a is not used
#   --bypass-mode true|false
#        When true, generate backend/.env and frontend/.env.local for auth bypass
#   -h   Show help
# =============================================================================

set -euo pipefail

# ── Colours ───────────────────────────────────────────────────────────────────
GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; BOLD='\033[1m'; NC='\033[0m'
ok()   { echo -e "${GREEN}  ✓${NC} $1"; }
warn() { echo -e "${YELLOW}  ⚠${NC} $1"; }
fail() { echo -e "${RED}  ✗${NC} $1"; exit 1; }
step() { echo -e "\n${BOLD}▶ $1${NC}"; }

AUTO_INSTALL=false
CONFIRMED=false
BYPASS_MODE=false

usage() {
  cat <<'USAGE'
Usage: ./setup.sh [-a] [-y] [-h]

  -a   Auto-install required Ubuntu packages with apt and continue
  -y   Confirm running install steps when -a is not used
  --bypass-mode true|false
       Generate bypass env files automatically when set to true
  -h   Show this help message

Examples:
  ./setup.sh -a
  ./setup.sh -y
  ./setup.sh -y --bypass-mode true
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -a)
      AUTO_INSTALL=true
      shift
      ;;
    -y)
      CONFIRMED=true
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    --bypass-mode)
      if [[ $# -lt 2 ]]; then
        fail "--bypass-mode requires a value: true or false"
      fi

      case "$2" in
        true)  BYPASS_MODE=true ;;
        false) BYPASS_MODE=false ;;
        *)
          fail "Invalid value for --bypass-mode: $2 (expected true or false)"
          ;;
      esac

      shift 2
      ;;
    --bypass-mode=*)
      value="${1#*=}"
      case "$value" in
        true)  BYPASS_MODE=true ;;
        false) BYPASS_MODE=false ;;
        *)
          fail "Invalid value for --bypass-mode: $value (expected true or false)"
          ;;
      esac
      shift
      ;;
    *)
      usage
      fail "Unknown option: $1"
      ;;
  esac
done

if [[ "$AUTO_INSTALL" == "false" && "$CONFIRMED" == "false" ]]; then
  usage
  fail "Refusing to run installs without confirmation. Pass -y, or use -a for automatic Ubuntu package install."
fi

echo -e "\n${BOLD}════════════════════════════════════════════${NC}"
echo -e "${BOLD}  SolarPeak — Setup${NC}"
echo -e "${BOLD}════════════════════════════════════════════${NC}\n"

step "Validating operating system"
if [[ ! -f /etc/os-release ]]; then
  fail "Cannot detect OS. This setup script supports Ubuntu only."
fi

# shellcheck disable=SC1091
source /etc/os-release
if [[ "${ID:-}" != "ubuntu" ]]; then
  fail "Unsupported OS: ${ID:-unknown}. This setup script supports Ubuntu only."
fi
ok "Detected Ubuntu ${VERSION_ID:-unknown}"

generate_bypass_env_files() {
  step "Generating bypass mode env files (--bypass-mode true)"

  if [[ -f backend/.env ]]; then
    warn "Overwriting existing backend/.env for bypass mode"
  fi

  if [[ -f frontend/.env.local ]]; then
    warn "Overwriting existing frontend/.env.local for bypass mode"
  fi

  cat > backend/.env <<'EOF'
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
MAX_QUERY_LIMIT_DAYS=90
HOST=http://localhost
EOF

  cat > frontend/.env.local <<'EOF'
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

  ok "Bypass env files generated"
}

if [[ "$BYPASS_MODE" == "true" ]]; then
  generate_bypass_env_files
fi

if [[ "$AUTO_INSTALL" == "true" ]]; then
  step "Installing required Ubuntu packages (-a mode)"
  sudo apt-get update
  sudo DEBIAN_FRONTEND=noninteractive apt-get install -y \
    build-essential \
    ca-certificates \
    curl \
    docker.io \
    docker-compose-v2 \
    git \
    libpq-dev \
    nodejs \
    npm \
    postgresql-client \
    redis-tools \
    ruby-full
  ok "Required Ubuntu packages installed"
fi

# ── Check prerequisites ───────────────────────────────────────────────────────
step "Checking prerequisites"

command -v ruby  >/dev/null 2>&1 || fail "Ruby not found. Install via rbenv: https://github.com/rbenv/rbenv"
command -v node  >/dev/null 2>&1 || fail "Node.js not found. Install via nvm: https://github.com/nvm-sh/nvm"
command -v docker >/dev/null 2>&1 || warn "Docker not found — if DB/Redis are containerized, install Docker first"
command -v psql  >/dev/null 2>&1 || warn "psql not found — ensure PostgreSQL is reachable via DATABASE_URL"
command -v redis-cli >/dev/null 2>&1 || warn "redis-cli not found — ensure Redis is reachable via REDIS_URL"

ok "Ruby  $(ruby --version | awk '{print $2}')"
ok "Node  $(node --version)"

# ── Check env files ───────────────────────────────────────────────────────────
step "Checking environment files"

if [ ! -f backend/.env ]; then
  warn "backend/.env not found."
  echo "       Run: ruby scripts/auth0_setup.rb"
  echo "       Or create backend/.env manually for bypass mode."
  echo "       Then re-run this script."
  exit 1
fi

if [ ! -f frontend/.env.local ]; then
  warn "frontend/.env.local not found."
  echo "       Run: ruby scripts/auth0_setup.rb"
  echo "       Or create frontend/.env.local manually for bypass mode."
  echo "       Then re-run this script."
  exit 1
fi

ok "backend/.env present"
ok "frontend/.env.local present"

if ! grep -q '^MAX_QUERY_LIMIT_DAYS=' backend/.env; then
  warn "MAX_QUERY_LIMIT_DAYS is not set in backend/.env (default 90 will be used)"
fi

# ── Backend ───────────────────────────────────────────────────────────────────
step "Installing Ruby gems (backend)"
cd backend
bundle install
ok "Gems installed"

step "Creating and migrating database"
bin/rails db:create db:migrate
ok "Database ready"

step "Seeding initial admin (if ADMIN_AUTH0_SUB + ADMIN_EMAIL are set)"
bin/rails db:seed
ok "Seed complete"

step "Generating OpenAPI spec (Rswag → public/openapi/v1/swagger.json)"
RAILS_ENV=test bin/rails rswag:specs:swaggerize 2>/dev/null || \
  warn "Spec generation failed — run manually once specs pass: bin/rails rswag:specs:swaggerize"
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
echo -e "  Start infrastructure:    ${BOLD}docker compose up -d postgres redis${NC}"
echo -e "  Start Rails API:         ${BOLD}cd backend && bin/rails s -p 3001${NC}"
echo -e "  Start Next.js:           ${BOLD}cd frontend && npm run dev${NC}"
echo -e "  View API docs (Redocly): ${BOLD}http://localhost:3001/api-docs${NC}"
echo -e "  Raw OpenAPI spec:        ${BOLD}http://localhost:3001/openapi/v1/swagger.json${NC}"
echo
