#!/usr/bin/env bash
# One command for local development: Firebase emulators + Go API (backend/scripts/dev.sh)
# and the Flutter web app in Chrome, pointed at them. Ctrl+C stops everything.
# Usage: mobile/scripts/dev_all.sh [extra flutter run args]
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"

"$ROOT/backend/scripts/dev.sh" &
BACKEND_PID=$!
trap 'kill $BACKEND_PID 2>/dev/null; wait $BACKEND_PID 2>/dev/null' EXIT

echo "waiting for API on :8080..."
for _ in $(seq 1 90); do
  curl -sf http://localhost:8080/healthz >/dev/null && break
  sleep 1
done

cd "$ROOT/mobile/app"
flutter run -d chrome --web-port 5000 \
  --dart-define=API_BASE_URL=http://localhost:8080 \
  --dart-define=USE_EMULATORS=true "$@"
