#!/usr/bin/env bash
# Park Viet — one-click start (Mac / Linux / WSL2)
# Host:   MySQL 5.7
# Docker: Rails app + Webpack + Redis + Elasticsearch
set -e

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'
info()    { echo -e "${CYAN}▶  $*${NC}"; }
ok()      { echo -e "${GREEN}✔  $*${NC}"; }
warn()    { echo -e "${YELLOW}⚠  $*${NC}"; }
die()     { echo -e "${RED}✖  $*${NC}"; exit 1; }

APP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$APP_DIR"

[[ "$(uname)" == "Darwin" ]] && OS=mac || OS=linux

echo -e "\n${BOLD}=== Park Việt ===${NC}\n"

# ── Docker ────────────────────────────────────────────────────────────────────
command -v docker >/dev/null 2>&1 || die "Docker not found. Install Docker Desktop first."
docker info >/dev/null 2>&1       || die "Docker is not running. Start Docker Desktop and try again."
ok "Docker is running"

# ── MySQL (host) ──────────────────────────────────────────────────────────────
info "Starting MySQL on host..."
if [[ "$OS" == "mac" ]]; then
  brew services start mysql@5.7 2>/dev/null || brew services start mysql 2>/dev/null || die "MySQL not installed. See INSTALLATION.md."
else
  sudo service mysql start 2>/dev/null || sudo systemctl start mysql 2>/dev/null || die "MySQL not installed. See INSTALLATION.md."
fi
until mysqladmin -u root -pthuy425 ping --silent 2>/dev/null; do sleep 2; done
ok "MySQL ready"

# ── Build image if needed ─────────────────────────────────────────────────────
if ! docker image inspect parkviet-web >/dev/null 2>&1; then
  info "Building Docker image (first time, ~5-10 min)..."
  docker compose build || die "Docker build failed."
  ok "Image built"
fi

# ── First-time database setup ─────────────────────────────────────────────────
if [[ ! -f tmp/.setup_done ]]; then
  info "First-time setup (starts Redis + Elasticsearch in Docker too)..."

  docker compose run --rm web bundle exec rails db:create RAILS_ENV=development
  docker compose run --rm web bundle exec rails db:migrate RAILS_ENV=development
  docker compose run --rm web bundle exec rails db:seed RAILS_ENV=development

  DIADANH="$APP_DIR/db/diadanh_2018-05-05.sql"
  if [[ -f "$DIADANH" ]]; then
    info "Importing provinces/districts/communes..."
    docker compose run --rm web /bin/bash -c \
      "mysql -h host.docker.internal -u root -pthuy425 ParkViet_development < db/diadanh_2018-05-05.sql"
    ok "Geographic data imported"
  else
    warn "db/diadanh_2018-05-05.sql not found — skipping"
  fi

  docker compose run --rm web bundle exec rails runner \
    "Chewy.strategy(:atomic){ ProductsIndex.reset!; CustomersIndex.reset!; SuppliersIndex.reset! }" \
    RAILS_ENV=development || warn "Elasticsearch index build failed — search may not work"

  mkdir -p tmp && touch tmp/.setup_done
  ok "Database ready"
else
  docker compose run --rm web bundle exec rails db:migrate RAILS_ENV=development 2>/dev/null || true
fi

# ── Launch ────────────────────────────────────────────────────────────────────
echo -e "\n${BOLD}Starting app...${NC}"
echo -e "  ${GREEN}http://localhost:3000${NC}"
echo -e "  Stop: Ctrl+C\n"

docker compose up
