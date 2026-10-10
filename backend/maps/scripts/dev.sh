#!/usr/bin/env bash
# Starts the Firebase emulators and the Go API against them. Ctrl+C stops both.
# Usage: backend/maps/scripts/dev.sh
set -euo pipefail
cd "$(dirname "$0")/.."

export FIREBASE_PROJECT_ID="${FIREBASE_PROJECT_ID:-demo-eho}"
export FIRESTORE_EMULATOR_HOST=127.0.0.1:8081
export FIREBASE_AUTH_EMULATOR_HOST=127.0.0.1:9099
export STORAGE_EMULATOR_HOST=http://127.0.0.1:9199
export LOG_LEVEL="${LOG_LEVEL:-debug}"

command -v firebase >/dev/null || { echo "firebase CLI not found (see backend/maps/README.md → Setup)" >&2; exit 1; }

(cd firebase && firebase emulators:start --project "$FIREBASE_PROJECT_ID" --import=.emulator-data --export-on-exit=.emulator-data) &
EMU_PID=$!
trap 'kill $EMU_PID 2>/dev/null; wait $EMU_PID 2>/dev/null' EXIT

echo "waiting for Firestore emulator..."
for _ in $(seq 1 60); do
  curl -sf "http://$FIRESTORE_EMULATOR_HOST/" >/dev/null && break
  sleep 1
done

go run ./cmd/api
