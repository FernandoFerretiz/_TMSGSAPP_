#!/usr/bin/env bash
# APK de STAGING (se instala junto con la app de producción: id ".staging").
# Uso: scripts/build_staging_apk.sh [staff|operators]   (por defecto: staff)
# Para correr (hot reload) contra staging, sin script:
#   flutter run --flavor staff --dart-define=ENV=staging
set -euo pipefail

FLAVOR="${1:-staff}"
OUT_DIR="${OUT_DIR:-$HOME/Developer/claude temporary files/SultanX TMS}"

cd "$(dirname "$0")/.."

flutter build apk --release --flavor "$FLAVOR" --dart-define=ENV=staging

mkdir -p "$OUT_DIR"
cp "build/app/outputs/flutter-apk/app-$FLAVOR-release.apk" "$OUT_DIR/sultanx-$FLAVOR-staging.apk"
echo "APK: $OUT_DIR/sultanx-$FLAVOR-staging.apk"
