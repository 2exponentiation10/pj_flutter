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

cd "$PROJECT_ROOT"
flutter pub get
flutter build web --release --pwa-strategy=none --dart-define=API_BASE_URL="$API_BASE_URL"

mkdir -p "$TARGET_WEB_DIR"
rsync -az --delete "$PROJECT_ROOT/build/web/" "$TARGET_WEB_DIR/"

run_docker compose -f "$COMPOSE_FILE" restart nginx
