#!/usr/bin/env bash
# Build the Flutter admin web app and publish it to a Cloud Storage bucket.
# Usage: API_URL=https://api.example.com/api/v1 WEB_BUCKET=my-bucket ./infra/deploy-web.sh
set -euo pipefail
API_URL=${API_URL:?set API_URL}
WEB_BUCKET=${WEB_BUCKET:?set WEB_BUCKET}
cd "$(dirname "$0")/../apps/admin_web"
flutter pub get
flutter build web --release --dart-define=API_BASE_URL="$API_URL"
gsutil -m rsync -r -d build/web "gs://$WEB_BUCKET"
gsutil -m setmeta -h 'Cache-Control:no-cache' "gs://$WEB_BUCKET/index.html" "gs://$WEB_BUCKET/flutter_service_worker.js" "gs://$WEB_BUCKET/main.dart.js" || true
echo "Published to https://storage.googleapis.com/$WEB_BUCKET/index.html"
