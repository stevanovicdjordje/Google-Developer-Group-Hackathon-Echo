#!/bin/sh
# Screenshot routes of the Flutter web build (phone viewport, headless Chrome).
#   mobile/scripts/shots.sh <out-dir> start=/ agenda=/e/devfest/agenda echo=/e/devfest/session/s1/echo
# Builds the web app first unless SKIP_BUILD=1. SHOT_WAIT=<seconds> per route (default 10).
set -e
cd "$(dirname "$0")/../app"
out="$1"; shift
venv="${TMPDIR:-/tmp}/eho-shots-venv"
[ -x "$venv/bin/python" ] || { python3 -m venv "$venv" && "$venv/bin/pip" -q install websocket-client; }
[ "${SKIP_BUILD:-0}" = 1 ] || flutter build web --dart-define=DEMO_EVENT_ID="${DEMO_EVENT_ID:-devfest}" >/dev/null
"$venv/bin/python" ../scripts/shots.py build/web "$out" "$@" 2>&1 | grep -v -i "NotOpenSSL\|warnings.warn"
