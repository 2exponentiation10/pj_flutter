#!/usr/bin/env bash
set -euo pipefail

DEPLOY_ROOT="${DEPLOY_ROOT:-/opt/protfolio/satoori}"
API_BASE_URL="${API_BASE_URL:-https://satoori-api.protfolio.store/api}"
PROJECT_ROOT="${GITHUB_WORKSPACE:-$(pwd)}"
TARGET_WEB_DIR="$DEPLOY_ROOT/pj_flutter_web"
COMPOSE_FILE="$DEPLOY_ROOT/docker-compose.yml"
DOCKER_SUDO="${DOCKER_SUDO:-false}"

run_docker() {
  if [ "$DOCKER_SUDO" = "true" ]; then
    sudo docker "$@"
  else
    docker "$@"
  fi
}

run_predeploy_backup() {
  local backup_script="${PORTFOLIO_BACKUP_SCRIPT:-/home/lsy/bin/portfolio_backup.sh}"
  if [ "${SKIP_PORTFOLIO_BACKUP:-false}" = "true" ]; then
    echo "[deploy] skip portfolio backup"
    return 0
  fi
  if [ ! -x "$backup_script" ]; then
    echo "::error::Portfolio backup script is missing or not executable: $backup_script"
    echo "Set SKIP_PORTFOLIO_BACKUP=true only for non-production dry runs."
    exit 1
  fi
  echo "[deploy] pre-deploy backup: satoori"
  "$backup_script" satoori
}

cd "$PROJECT_ROOT"
flutter pub get
flutter build web --release --pwa-strategy=none --dart-define=API_BASE_URL="$API_BASE_URL"

run_predeploy_backup

mkdir -p "$TARGET_WEB_DIR"
rsync -az --delete --no-owner --no-group "$PROJECT_ROOT/build/web/" "$TARGET_WEB_DIR/"

run_docker compose -f "$COMPOSE_FILE" restart nginx
