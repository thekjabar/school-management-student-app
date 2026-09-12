#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

OUT="${1:-../apk}"
ROLES=("${@:2}")
if [ ${#ROLES[@]} -eq 0 ]; then ROLES=(parent teacher driver); fi

mkdir -p assets/video "$OUT"

MAPBOX_TOKEN=""
if [ -f tool/mapbox.token ]; then
  MAPBOX_TOKEN="$(tr -d "[:space:]" < tool/mapbox.token)"
fi
if [ -z "$MAPBOX_TOKEN" ]; then
  echo "note: tool/mapbox.token is missing - maps will be blank in these builds"
fi

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
    echo "splash: none"
  fi

  rm -rf .dart_tool/flutter_build
  rm -rf build/flutter_assets
  rm -rf build/app/intermediates/merged_assets
  rm -rf build/app/intermediates/assets

  case "$role" in
    parent)  api="https://parent-api.krsprotection.com" ;;
    teacher) api="https://teacher-api.krsprotection.com" ;;
    *)      api="https://api.krsprotection.com" ;;
  esac
  echo "api: $api"

  flutter build apk --release \
    --flavor "$role" \
    --dart-define="APP_ROLE=$role" \
    --dart-define="API_BASE=$api" \
    --dart-define="MAPBOX_TOKEN=$MAPBOX_TOKEN" \
    --dart-define="MAPBOX_STYLE=$MAPBOX_STYLE" \
    --split-per-abi

  case "$role" in
    parent)  name="KSP-Parent"  ;;
    teacher) name="KSP-Teacher" ;;
    driver)  name="KSP-Driver"  ;;
    *)       name="KSP-${role}" ;;
  esac

  cp "build/app/outputs/flutter-apk/app-arm64-v8a-$role-release.apk" "$OUT/$name.apk"

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

  lib=$(unzip -p "$OUT/$name.apk" lib/arm64-v8a/libapp.so 2>/dev/null | wc -c)
  if [ "${lib:-0}" -gt 0 ]; then
    tmp=$(mktemp)
    unzip -p "$OUT/$name.apk" lib/arm64-v8a/libapp.so > "$tmp"
    case "$role" in
      parent)  wantTitle="KSP Parent"  ;;
      teacher) wantTitle="KSP Teacher" ;;
      driver)  wantTitle="KSP Driver"  ;;
    esac
    wrong=""
    for other in parent teacher driver; do
      [ "$other" = "$role" ] && continue
      case "$other" in
        parent)  otherName="KSP Parent"  ;;
        teacher) otherName="KSP Teacher" ;;
        driver)  otherName="KSP Driver"  ;;
      esac
      if grep -aq "$otherName" "$tmp"; then wrong="$wrong $otherName"; fi
    done
    if ! grep -aq "$wantTitle" "$tmp" || [ -n "$wrong" ]; then
      rm -f "$tmp"
      echo
      echo "FAILED: $name.apk is not the $role app."
      echo "  APP_ROLE did not reach the Dart side, so the binary is somebody"
      echo "  else's app wearing this role's package name, label and icon."
      [ -n "$wrong" ] && echo "  found instead:$wrong"
      exit 1
    fi
    rm -f "$tmp"
    echo "role verified: binary is the $role app"
  fi

  echo "→ $OUT/$name.apk  ($(du -h "$OUT/$name.apk" | cut -f1))"
done

rm -f assets/video/splash.mp4
echo
ls -la "$OUT"
