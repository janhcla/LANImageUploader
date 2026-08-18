#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
verifier="$repo_root/scripts/verify_build_channel_marker.sh"
fixtures="$repo_root/scripts/fixtures"
temp_dir="$(mktemp -d "${TMPDIR:-/tmp}/lensbridge-preflight-marker.XXXXXX")"
trap 'rm -rf "$temp_dir"' EXIT

production_app="$temp_dir/Production.app"
testflight_app="$temp_dir/TestFlight.app"
mkdir -p "$production_app" "$testflight_app"
cp "$fixtures/BuildChannelMarkerProductionInfo.plist" "$production_app/Info.plist"
cp "$fixtures/BuildChannelMarkerTestFlightInfo.plist" "$testflight_app/Info.plist"

"$verifier" "$production_app" production
"$verifier" "$testflight_app" testFlight

if "$verifier" "$production_app" testFlight >/dev/null 2>&1; then
    printf 'Production artifact unexpectedly passed TestFlight marker verification.\n' >&2
    exit 1
fi

if "$verifier" "$testflight_app" production >/dev/null 2>&1; then
    printf 'TestFlight artifact unexpectedly passed production marker verification.\n' >&2
    exit 1
fi

printf 'Release preflight build-channel marker behavior passed.\n'
