#!/usr/bin/env bash
# Build the release APK / App Bundle for the Gamya Mobility Android app.
# Usage: API_URL=https://api.example.com/api/v1 ./infra/build-android.sh [apk|appbundle]
set -euo pipefail
API_URL=${API_URL:?set API_URL}
KIND=${1:-apk}
cd "$(dirname "$0")/../apps/mobile"
flutter pub get
flutter build "$KIND" --release --dart-define=API_BASE_URL="$API_URL" $( [ "$KIND" = apk ] && echo --split-per-abi )
ls -la build/app/outputs/flutter-apk/*.apk 2>/dev/null || ls -la build/app/outputs/bundle/release/*.aab
