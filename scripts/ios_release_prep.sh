#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"

echo "[1/5] flutter pub get"
flutter pub get

echo "[2/5] pod install"
cd ios
pod install
cd "$ROOT_DIR"

echo "[3/5] static analysis"
flutter analyze

echo "[4/5] iOS archive preflight (no codesign)"
flutter build ios --release --no-codesign

echo "[5/5] done"
echo "iOS release preflight completed."
