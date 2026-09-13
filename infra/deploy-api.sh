#!/usr/bin/env bash
# Build & deploy only the API to Cloud Run from your machine.
# Usage: PROJECT_ID=my-project REGION=asia-south1 ./infra/deploy-api.sh
set -euo pipefail
PROJECT_ID=${PROJECT_ID:?set PROJECT_ID}
REGION=${REGION:-asia-south1}
REPO=${REPO:-gamya}
IMAGE="$REGION-docker.pkg.dev/$PROJECT_ID/$REPO/gamya-api:$(git rev-parse --short HEAD)"
cd "$(dirname "$0")/.."
gcloud builds submit backend --tag "$IMAGE" --project "$PROJECT_ID"
gcloud run deploy gamya-api --image "$IMAGE" --region "$REGION" --project "$PROJECT_ID" --platform managed --allow-unauthenticated --port 8080
gcloud run services describe gamya-api --region "$REGION" --project "$PROJECT_ID" --format 'value(status.url)'
