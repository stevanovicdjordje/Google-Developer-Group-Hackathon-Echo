#!/usr/bin/env bash
# Deploys the venue map to a real Firebase / Google Cloud project:
#   1. Firestore + Storage security rules and indexes (firebase/),
#   2. the API to Cloud Run (built from the Dockerfile by Cloud Build),
#   3. optionally the web app to Firebase Hosting (WEB_BUILD=<dir with index.html>).
#
# Usage: backend/maps/scripts/deploy.sh <project-id> [region]
#   STORAGE_BUCKET   default <project>.firebasestorage.app (older projects: <project>.appspot.com)
#   EXTRA_ORIGINS    more CORS origins, comma-separated (default: the project's Hosting domains)
#   WEB_BUILD        e.g. ../../mobile/app/build/web; Hosting is skipped when unset
#   SKIP_RULES=1 / SKIP_API=1  skip a step
#
# Needs: firebase CLI (`firebase login`), gcloud (`gcloud auth login`), a Blaze (billing) plan
# for Cloud Run, and the Firestore database + Storage bucket created in the console.
# Never needs a key file: Cloud Run uses its service account (Application Default Credentials).
set -euo pipefail
cd "$(dirname "$0")/.."

PROJECT="${1:-}"
REGION="${2:-europe-west1}"
SERVICE=eho-maps-api
[[ -n "$PROJECT" ]] || { sed -n '2,15p' "$0"; exit 2; }
[[ "$PROJECT" != demo-* ]] || { echo "demo-* projects exist only in the emulators" >&2; exit 2; }

BUCKET="${STORAGE_BUCKET:-$PROJECT.firebasestorage.app}"
ORIGINS="https://$PROJECT.web.app,https://$PROJECT.firebaseapp.com${EXTRA_ORIGINS:+,$EXTRA_ORIGINS}"

need() { command -v "$1" >/dev/null || { echo "$1 not found: $2" >&2; exit 1; }; }
need firebase "npm i -g firebase-tools"
[[ -n "${SKIP_API:-}" ]] || need gcloud "https://cloud.google.com/sdk/docs/install"

if [[ -z "${SKIP_RULES:-}" ]]; then
  echo "== rules and indexes → $PROJECT"
  (cd firebase && firebase deploy --project "$PROJECT" --only firestore:rules,firestore:indexes,storage)
fi

if [[ -z "${SKIP_API:-}" ]]; then
  echo "== API → Cloud Run $SERVICE ($REGION)"
  ENV_FILE="$(mktemp)"
  trap 'rm -f "$ENV_FILE"' EXIT
  cat >"$ENV_FILE" <<EOF
FIREBASE_PROJECT_ID: "$PROJECT"
STORAGE_BUCKET: "$BUCKET"
ALLOWED_ORIGINS: "$ORIGINS"
LOG_LEVEL: "info"
EOF
  # One instance is enough for a demo and keeps the in-memory stats buffer and graph
  # cache in one place; min 1 avoids a cold start in the middle of the demo.
  gcloud run deploy "$SERVICE" --project "$PROJECT" --region "$REGION" --source . \
    --allow-unauthenticated --env-vars-file "$ENV_FILE" \
    --min-instances 1 --max-instances 1 --memory 512Mi --cpu 1 --quiet
  API_URL="$(gcloud run services describe "$SERVICE" --project "$PROJECT" --region "$REGION" --format 'value(status.url)')"
  echo "API: $API_URL"
  curl -fsS "$API_URL/healthz" && echo
fi

if [[ -n "${WEB_BUILD:-}" ]]; then
  [[ -f "$WEB_BUILD/index.html" ]] || { echo "WEB_BUILD=$WEB_BUILD has no index.html" >&2; exit 1; }
  echo "== web app → Firebase Hosting (https://$PROJECT.web.app)"
  rm -rf firebase/.hosting && cp -r "$WEB_BUILD" firebase/.hosting
  (cd firebase && firebase deploy --project "$PROJECT" --config firebase.hosting.json --only hosting)
fi
