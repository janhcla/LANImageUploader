#!/usr/bin/env bash

set -euo pipefail

if [[ "$#" != "2" ]]; then
    printf 'Usage: %s <app-bundle> <production|testFlight>\n' "$0" >&2
    exit 2
fi

app_bundle="$1"
expected_channel="$2"
info_plist="$app_bundle/Info.plist"
marker_key='LensBridgeBuildChannelMarker'
testflight_marker='external-testflight-v1'

if [[ ! -f "$info_plist" ]]; then
    printf 'Build-channel marker verification requires an app Info.plist.\n' >&2
    exit 1
fi

case "$expected_channel" in
    production)
        if /usr/libexec/PlistBuddy -c "Print :$marker_key" "$info_plist" >/dev/null 2>&1; then
            printf 'Production artifact contains a build-channel marker.\n' >&2
            exit 1
        fi
        ;;
    testFlight)
        marker_value="$(/usr/libexec/PlistBuddy -c "Print :$marker_key" "$info_plist" 2>/dev/null || true)"
        if [[ "$marker_value" != "$testflight_marker" ]]; then
            printf 'TestFlight artifact is missing the expected build-channel marker.\n' >&2
            exit 1
        fi
        ;;
    *)
        printf 'Build-channel marker verification requires production or testFlight.\n' >&2
        exit 2
        ;;
esac
