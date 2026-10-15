#!/usr/bin/env bash
# Runs the events API on :8084 against the Firebase emulators.
# The emulators (and the demo event) come from backend/maps: run `make dev` and `make seed` there first,
# then `make seed` here for the demo agenda.
# Usage: backend/events/scripts/dev.sh   (GEMINI_API_KEY in backend/events/.env enables AI extraction)
set -euo pipefail
cd "$(dirname "$0")/.."

[ -f .env ] && set -a && . ./.env && set +a
export FIREBASE_PROJECT_ID="${FIREBASE_PROJECT_ID:-demo-eho}"
export FIRESTORE_EMULATOR_HOST="${FIRESTORE_EMULATOR_HOST:-127.0.0.1:8081}"
export FIREBASE_AUTH_EMULATOR_HOST="${FIREBASE_AUTH_EMULATOR_HOST:-127.0.0.1:9099}"
export PORT="${PORT:-8084}"
export LOG_LEVEL="${LOG_LEVEL:-debug}"

curl -sf "http://$FIRESTORE_EMULATOR_HOST/" >/dev/null || {
  echo "Firestore emulator not reachable on $FIRESTORE_EMULATOR_HOST: start it with \`make dev\` in backend/maps" >&2
  exit 1
}

go run ./cmd/api
