#!/bin/sh
# Screenshot routes of the Flutter web build (phone viewport, headless Chrome).
#   mobile/scripts/shots.sh <out-dir> start=/ agenda=/e/devfest/agenda echo=/e/devfest/session/s1/echo
# Builds the web app first unless SKIP_BUILD=1. SHOT_WAIT=<seconds> per route (default 10).
# LINK_BASE=<url> is forwarded as a dart-define (join-link base on non-web).
# Echo uses demo data unless you export USE_ECHO_API=true.
set -e
cd "$(dirname "$0")/../app"
out="$1"; shift
venv="${TMPDIR:-/tmp}/eho-shots-venv"
[ -x "$venv/bin/python" ] || { python3 -m venv "$venv" && "$venv/bin/pip" -q install websocket-client; }
[ "${SKIP_BUILD:-0}" = 1 ] || flutter build web --dart-define=DEMO_EVENT_ID="${DEMO_EVENT_ID:-devfest}" --dart-define=USE_ECHO_API="${USE_ECHO_API:-false}" ${LINK_BASE:+--dart-define=LINK_BASE="$LINK_BASE"} >/dev/null
"$venv/bin/python" ../scripts/shots.py build/web "$out" "$@" 2>&1 | grep -v -i "NotOpenSSL\|warnings.warn"
