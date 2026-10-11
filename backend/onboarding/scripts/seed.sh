#!/usr/bin/env bash
# Seeds all demo data into the running emulators, in order:
#   1. backend/maps   — demo organizer + "devfest" event with a published venue map (needs the map API on :8080)
#   2. backend/events — the devfest agenda
#   3. this module    — organizer role, 20 participants, two more events, invitations, reviews
# Usage: backend/onboarding/scripts/seed.sh   (with scripts/dev.sh running)
set -euo pipefail
HERE="$(cd "$(dirname "$0")/.." && pwd)"

export FIREBASE_PROJECT_ID="${FIREBASE_PROJECT_ID:-demo-eho}"
export FIRESTORE_EMULATOR_HOST=127.0.0.1:8081
export FIREBASE_AUTH_EMULATOR_HOST=127.0.0.1:9099
export STORAGE_EMULATOR_HOST=http://127.0.0.1:9199

curl -sf http://localhost:8080/healthz >/dev/null || { echo "map API not running: start scripts/dev.sh first" >&2; exit 1; }

(cd "$HERE/../maps" && make seed)
(cd "$HERE/../events" && make seed)
cd "$HERE" && go run ./cmd/seed
