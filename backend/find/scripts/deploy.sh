#!/usr/bin/env bash
# Deploys a Go service of this repo (backend/events or backend/find) to Cloud Run.
# The Firestore rules, indexes and the web app are deployed by backend/maps/scripts/deploy.sh.
#
# Usage: backend/<service>/scripts/deploy.sh <project-id> [region]
#   EXTRA_ORIGINS   more CORS origins, comma-separated (default: the project's Hosting domains)
#   GEMINI_API_KEY  taken from the environment or the service's .env; stored in Secret Manager as
#                   `gemini-api-key` (shared by Echo, Find and Events) and mounted as an env var.
#                   Without it the service runs offline (no AI).
#
# Needs: gcloud (`gcloud auth login`) and a Blaze (billing) plan. Never needs a key file.
set -euo pipefail
cd "$(dirname "$0")/.."

PROJECT="${1:-}"
REGION="${2:-europe-west1}"
NAME="$(basename "$PWD")"            # events | find
SERVICE="eho-$NAME-api"
[[ -n "$PROJECT" ]] || { sed -n '2,12p' "$0"; exit 2; }
[[ "$PROJECT" != demo-* ]] || { echo "demo-* projects exist only in the emulators" >&2; exit 2; }
command -v gcloud >/dev/null || { echo "gcloud not found: https://cloud.google.com/sdk/docs/install" >&2; exit 1; }

if [[ -z "${GEMINI_API_KEY:-}" && -f .env ]]; then
  GEMINI_API_KEY="$(sed -n 's/^GEMINI_API_KEY=//p' .env | tail -1)"
fi
ORIGINS="https://$PROJECT.web.app,https://$PROJECT.firebaseapp.com${EXTRA_ORIGINS:+,$EXTRA_ORIGINS}"

ENV_FILE="$(mktemp)"
trap 'rm -f "$ENV_FILE"' EXIT
cat >"$ENV_FILE" <<ENV
FIREBASE_PROJECT_ID: "$PROJECT"
ALLOWED_ORIGINS: "$ORIGINS"
LOG_LEVEL: "info"
ENV
SECRETS=()
if [[ -n "${GEMINI_API_KEY:-}" ]]; then
  gcloud services enable secretmanager.googleapis.com --project "$PROJECT" --quiet
  if gcloud secrets describe gemini-api-key --project "$PROJECT" >/dev/null 2>&1; then
    printf %s "$GEMINI_API_KEY" | gcloud secrets versions add gemini-api-key --project "$PROJECT" --data-file=- >/dev/null
  else
    printf %s "$GEMINI_API_KEY" | gcloud secrets create gemini-api-key --project "$PROJECT" --data-file=- >/dev/null
  fi
  NUMBER="$(gcloud projects describe "$PROJECT" --format 'value(projectNumber)')"
  gcloud secrets add-iam-policy-binding gemini-api-key --project "$PROJECT" --quiet >/dev/null \
    --member "serviceAccount:$NUMBER-compute@developer.gserviceaccount.com" --role roles/secretmanager.secretAccessor
  SECRETS=(--set-secrets "GEMINI_API_KEY=gemini-api-key:latest")
else
  echo "GEMINI_API_KEY not set: $SERVICE will run offline (no AI)" >&2
fi

echo "== $NAME → Cloud Run $SERVICE ($REGION)"
# min 1 avoids a cold start in the middle of the demo.
gcloud run deploy "$SERVICE" --project "$PROJECT" --region "$REGION" --source . \
  --allow-unauthenticated --env-vars-file "$ENV_FILE" "${SECRETS[@]}" \
  --min-instances 1 --max-instances 2 --memory 512Mi --cpu 1 --timeout 120 --quiet
URL="$(gcloud run services describe "$SERVICE" --project "$PROJECT" --region "$REGION" --format 'value(status.url)')"
echo "$NAME API: $URL"
curl -fsS "$URL/healthz" && echo
