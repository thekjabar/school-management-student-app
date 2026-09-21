#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

ALL_ROLES=(parent teacher driver student)

role_api() {
  case "$1" in
    parent)  echo "https://parent-api.krsprotection.com"  ;;
    teacher) echo "https://teacher-api.krsprotection.com" ;;
    driver)  echo "https://driver-api.krsprotection.com"  ;;
    student) echo "https://student-api.krsprotection.com" ;;
  esac
}

role_title() {
  case "$1" in
    parent)  echo "KSP Parent"  ;;
    teacher) echo "KSP Teacher" ;;
    driver)  echo "KSP Driver"  ;;
    student) echo "KSP Student" ;;
  esac
}

OUT="${1:-../apk}"
ROLES=("${@:2}")
if [ ${#ROLES[@]} -eq 0 ]; then ROLES=("${ALL_ROLES[@]}"); fi

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

APP_VERSION="$(awk '/^version:/ {print $2}' pubspec.yaml | cut -d+ -f1)"
echo "version: ${APP_VERSION:-unknown}"

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

  api="$(role_api "$role")"
  if [ -z "$api" ]; then
    echo
    echo "FAILED: there is no API for the role \"$role\"."
    echo "  Every audience answers on its own host and refuses the others, so a"
    echo "  build for a role with no host would ship an app that cannot sign"
    echo "  anybody in. The roles are ${ALL_ROLES[*]}."
    exit 1
  fi
  echo "api: $api"

  STATUS_KEY=""
  if [ -f "tool/status.$role.key" ]; then
    STATUS_KEY="$(tr -d "[:space:]" < "tool/status.$role.key")"
  fi
  if [ -z "$STATUS_KEY" ]; then
    echo
    echo "FAILED: tool/status.$role.key is missing or empty."
    echo "  Without it the $role app cannot ask the status service, so a family"
    echo "  or a driver sees a dead app with no explanation while the platform"
    echo "  is down. Copy the key from STATUS_KEY_$(echo "$role" | tr 'a-z' 'A-Z') in"
    echo "  /var/www/school/ksp-status-api/.env on the server."
    exit 1
  fi
  echo "status: tool/status.$role.key (${#STATUS_KEY} characters)"

  flutter build apk --release \
    --flavor "$role" \
    --dart-define="APP_ROLE=$role" \
    --dart-define="API_BASE=$api" \
    --dart-define="APP_VERSION=$APP_VERSION" \
    --dart-define="STATUS_KEY=$STATUS_KEY" \
    --dart-define="MAPBOX_TOKEN=$MAPBOX_TOKEN" \
    --dart-define="MAPBOX_STYLE=$MAPBOX_STYLE" \
    --split-per-abi

  title="$(role_title "$role")"
  name="${title// /-}"

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
    wrong=""
    for other in "${ALL_ROLES[@]}"; do
      [ "$other" = "$role" ] && continue
      otherName="$(role_title "$other")"
      if grep -aq "$otherName" "$tmp"; then wrong="$wrong $otherName"; fi
    done
    if ! grep -aq "$title" "$tmp" || [ -n "$wrong" ]; then
      rm -f "$tmp"
      echo
      echo "FAILED: $name.apk is not the $role app."
      echo "  APP_ROLE did not reach the Dart side, so the binary is somebody"
      echo "  else's app wearing this role's package name, label and icon."
      [ -n "$wrong" ] && echo "  found instead:$wrong"
      exit 1
    fi
    if ! grep -aqF "$STATUS_KEY" "$tmp"; then
      rm -f "$tmp"
      echo
      echo "FAILED: $name.apk does not carry the $role status key."
      echo "  STATUS_KEY did not reach the Dart side, so this app can never ask"
      echo "  the status service and would show a family or a driver a dead app"
      echo "  with no explanation while the platform is down."
      exit 1
    fi
    strayKey=""
    for other in "${ALL_ROLES[@]}"; do
      [ "$other" = "$role" ] && continue
      if [ -f "tool/status.$other.key" ]; then
        otherKey="$(tr -d "[:space:]" < "tool/status.$other.key")"
        if [ -n "$otherKey" ] && grep -aqF "$otherKey" "$tmp"; then
          strayKey="$strayKey $other"
        fi
      fi
    done
    if [ -n "$strayKey" ]; then
      rm -f "$tmp"
      echo
      echo "FAILED: $name.apk carries another app's status key:$strayKey"
      echo "  The service refuses a key used with another app's name, so every"
      echo "  status check from this build would be answered 403 and no notice"
      echo "  or maintenance screen would ever be shown."
      exit 1
    fi
    rm -f "$tmp"
    echo "role verified: binary is the $role app, with the $role status key"
  fi

  echo "→ $OUT/$name.apk  ($(du -h "$OUT/$name.apk" | cut -f1))"
done

rm -f assets/video/splash.mp4
echo
ls -la "$OUT"
