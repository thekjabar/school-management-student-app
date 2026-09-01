#!/usr/bin/env bash
# Build the KSP role APKs.
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

# The Mapbox token, from a file this repository does not carry.
#
# A public token is meant to ship inside a client and can be read out of any
# APK, so this is not secrecy. It keeps the token out of a PUBLIC repository,
# where anyone who cloned the code could spend the quota without ever
# touching the app. Absent, the build still succeeds and every map says it is
# not set up rather than showing a grey rectangle.
MAPBOX_TOKEN=""
if [ -f tool/mapbox.token ]; then
  MAPBOX_TOKEN="$(tr -d "[:space:]" < tool/mapbox.token)"
fi
if [ -z "$MAPBOX_TOKEN" ]; then
  echo "note: tool/mapbox.token is missing - maps will be blank in these builds"
fi

# The Mapbox style, if the school has one of its own.
#
# It MUST be a classic style (Streets, Light, Outdoors, or one built on those).
# A Mapbox Standard style draws NOTHING through the raster endpoint: 200 OK,
# 235 bytes, a transparent tile, because it holds no layers of its own -- only
# an import the raster renderer does not resolve. See lib/ui/map_tiles.dart.
#
# Empty falls back to the classic default compiled into the app.
MAPBOX_STYLE=""
if [ -f tool/mapbox.style ]; then
  MAPBOX_STYLE="$(tr -d "[:space:]" < tool/mapbox.style)"
fi
if [ -n "$MAPBOX_STYLE" ]; then
  echo "style: $MAPBOX_STYLE"
fi

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

  # Drop the cached asset bundle before every build.
  #
  # This is not belt and braces, it is the actual bug: the staged path
  # assets/video/splash.mp4 is IDENTICAL for all three roles and only its
  # contents differ, so Flutter's build cache and Gradle's merged-assets task
  # will both happily reuse the previous role's bundle. That is how the parent
  # APK once shipped carrying the teacher's clip.
  rm -rf .dart_tool/flutter_build
  rm -rf build/flutter_assets
  rm -rf build/app/intermediates/merged_assets
  rm -rf build/app/intermediates/assets

  flutter build apk --release \
    --flavor "$role" \
    --dart-define="APP_ROLE=$role" \
    --dart-define="MAPBOX_TOKEN=$MAPBOX_TOKEN" \
    --dart-define="MAPBOX_STYLE=$MAPBOX_STYLE" \
    --split-per-abi

  # Named as the app is named, so the file somebody is handed over Telegram
  # says what it installs.
  case "$role" in
    parent)  name="KSP-Parent"  ;;
    teacher) name="KSP-Teacher" ;;
    driver)  name="KSP-Driver"  ;;
    *)       name="KSP-${role}" ;;
  esac

  cp "build/app/outputs/flutter-apk/app-arm64-v8a-$role-release.apk" "$OUT/$name.apk"

  # Prove the APK carries THIS role's clip.
  #
  # The failure this catches was completely silent: the build reported success,
  # the package name and the label were both correct, and the wrong video was
  # inside. Byte size is enough to tell three clips apart and needs no tools
  # beyond unzip.
  if [ -f "design/splash/$role.mp4" ]; then
    want=$(wc -c < "design/splash/$role.mp4" | tr -d ' ')
    got=$(unzip -l "$OUT/$name.apk" | awk '/assets\/flutter_assets\/assets\/video\/splash.mp4/ {print $1}')
    if [ "$want" != "$got" ]; then
      echo
      echo "FAILED: $name.apk carries the wrong splash clip."
      echo "  expected $want bytes (design/splash/$role.mp4)"
      echo "  found    ${got:-no splash at all}"
      echo "  The staged assets/video/splash.mp4 is shared by every flavour, so a"
      echo "  stale bundle or a second build running alongside this one will do"
      echo "  exactly this. Never run two of these at once."
      exit 1
    fi
    echo "splash verified: $got bytes"
  fi
  echo "→ $OUT/$name.apk  ($(du -h "$OUT/$name.apk" | cut -f1))"
done

rm -f assets/video/splash.mp4
echo
ls -la "$OUT"
