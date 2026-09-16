#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

PARENT_SUITES=(
  test/parent_api_test.dart
  test/parent_payments_live_test.dart
  test/home_payload_live_test.dart
  test/language_flows_test.dart
)
TEACHER_SUITES=(
  test/register_photo_test.dart
  test/teacher_announcements_test.dart
)
DRIVER_SUITES=(
  test/crew_api_test.dart
)

echo "Each API only answers its own audience: a teacher phone is 401 on"
echo "parent-api. So every live suite is compiled for the role it signs in as,"
echo "and picks up that role's host from kApiBase - the same mapping"
echo "tool/build_apks.sh gives a release build."

failed=()

run() {
  local role="$1"; shift
  echo
  echo "── $role ─────────────────────────────────────────────"
  if ! flutter test --dart-define="APP_ROLE=$role" "$@"; then
    failed+=("$role")
  fi
}

run parent  "${PARENT_SUITES[@]}"
run teacher "${TEACHER_SUITES[@]}"
run driver  "${DRIVER_SUITES[@]}"

echo
if [ ${#failed[@]} -ne 0 ]; then
  echo "FAILED:${failed[*]/#/ }"
  exit 1
fi
echo "every live suite passed against the live platform"
