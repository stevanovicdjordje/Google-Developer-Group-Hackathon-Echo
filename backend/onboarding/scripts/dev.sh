#!/usr/bin/env bash
# Runs the onboarding web app against the shared Firebase emulators.
# If the emulators aren't running yet, starts them together with the map API
# (backend/maps/scripts/dev.sh). Ctrl+C stops what this script started.
# Usage: backend/onboarding/scripts/dev.sh
set -euo pipefail
HERE="$(cd "$(dirname "$0")/.." && pwd)"
MAPS="$HERE/../maps"

# Homebrew installs Java 21 "keg-only" (not on PATH); the emulators need it.
if ! java -version >/dev/null 2>&1 && [ -x /opt/homebrew/opt/openjdk@21/bin/java ]; then
  export PATH="/opt/homebrew/opt/openjdk@21/bin:$PATH"
fi

export FIREBASE_PROJECT_ID="${FIREBASE_PROJECT_ID:-demo-eho}"
export FIRESTORE_EMULATOR_HOST=127.0.0.1:8081
export FIREBASE_AUTH_EMULATOR_HOST=127.0.0.1:9099
export STORAGE_EMULATOR_HOST=http://127.0.0.1:9199

if ! curl -sf "http://$FIRESTORE_EMULATOR_HOST/" >/dev/null; then
  echo "starting Firebase emulators + map API (backend/maps)..."
  "$MAPS/scripts/dev.sh" &
  MAPS_PID=$!
  trap 'kill $MAPS_PID 2>/dev/null; wait $MAPS_PID 2>/dev/null' EXIT
  for _ in $(seq 1 120); do
    curl -sf "http://$FIRESTORE_EMULATOR_HOST/" >/dev/null && curl -sf http://localhost:8080/healthz >/dev/null && break
    sleep 1
  done
fi

cd "$HERE"
echo "onboarding web app: ${EHO_BASE_URL:-http://localhost:8090}  (Firebase emulator UI: http://localhost:4000)"
go run ./cmd/eho-web
