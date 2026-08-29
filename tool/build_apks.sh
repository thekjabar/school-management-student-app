#!/usr/bin/env bash
# Build the role APKs.
#
# The splash clip is the reason this is a script rather than three commands.
# Flutter's asset bundle is not flavour-aware: every file under an `assets:`
# entry goes into every build, so declaring one clip per role put the teacher's
# animation inside the parent APK and vice versa — ten megabytes each way, for
# a file the app can never play. So the clips live OUTSIDE the bundle, and the
# one belonging to the role being built is copied into place first.
set -euo pipefail

cd "$(dirname "$0")/.."

OUT="${1:-../apk}"
ROLES=("${@:2}")
if [ ${#ROLES[@]} -eq 0 ]; then ROLES=(parent teacher driver); fi

mkdir -p assets/video "$OUT"

for role in "${ROLES[@]}"; do
  echo
  echo "── $role ─────────────────────────────────────────────"

  rm -f assets/video/splash.mp4
  if [ -f "design/splash/$role.mp4" ]; then
    cp "design/splash/$role.mp4" assets/video/splash.mp4
    echo "splash: design/splash/$role.mp4 ($(du -h "design/splash/$role.mp4" | cut -f1))"
  else
    # No clip for this role yet. The app opens straight onto the first screen
    # rather than onto somebody else's animation.
    echo "splash: none"
  fi

  # A stale incremental build is how a half-updated bundle ships; the whole
  # point of this script is that the assets differ between runs.
  flutter build apk --release \
    --flavor "$role" \
    --dart-define="APP_ROLE=$role" \
    --split-per-abi

  cp "build/app/outputs/flutter-apk/app-arm64-v8a-$role-release.apk" "$OUT/$role.apk"
  echo "→ $OUT/$role.apk  ($(du -h "$OUT/$role.apk" | cut -f1))"
done

rm -f assets/video/splash.mp4
echo
ls -la "$OUT"
