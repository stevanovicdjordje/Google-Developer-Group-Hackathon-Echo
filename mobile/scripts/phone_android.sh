#!/usr/bin/env bash
# Run the app on a USB Android phone against the local backends.
# Usage: mobile/scripts/phone_android.sh [device-serial] [extra flutter run args]
#   DEMO_EVENT_ID=<id> (default devfest) selects the seeded event.
# Needs the backends running (backend/maps, backend/echo, ... dev.sh).
set -euo pipefail
DIR="$(cd "$(dirname "$0")" && pwd)"
ADB="${ADB:-$(command -v adb || echo "$HOME/Library/Android/sdk/platform-tools/adb")}"

SERIAL=""
if [[ $# -gt 0 && "${1:0:1}" != "-" ]]; then SERIAL="$1"; shift; fi
if [[ -z "$SERIAL" ]]; then
  SERIAL="$("$ADB" devices | awk 'NR>1 && $2=="device" {print $1; exit}')"
  [[ -n "$SERIAL" ]] || { echo "no Android device connected (adb devices)" >&2; exit 1; }
fi

# Go APIs (8080-8083) + Firebase emulators (8081 Firestore, 9099 Auth, 9199 Storage).
PORTS=(8080 8081 8082 8083 9099 9199)
for p in "${PORTS[@]}"; do "$ADB" -s "$SERIAL" reverse "tcp:$p" "tcp:$p" >/dev/null; done
echo "adb reverse set for ${PORTS[*]} on $SERIAL"

# adb reverse reaches the Mac via ::1; the emulators listen on IPv4 only.
# fwd6.py skips ports that already answer on ::1 and exits if none are left.
python3 "$DIR/fwd6.py" 8081 9099 9199 &
FWD_PID=$!
trap 'kill "$FWD_PID" 2>/dev/null || true' EXIT
sleep 1

cd "$DIR/../app"
flutter run -d "$SERIAL" \
  --dart-define=EMULATOR_HOST=0.0.0.0 \
  --dart-define=DEMO_EVENT_ID="${DEMO_EVENT_ID:-devfest}" \
  "$@"
