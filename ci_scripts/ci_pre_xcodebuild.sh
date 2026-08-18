#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source_file="${BUILD_CHANNEL_SOURCE_FILE:-$repo_root/LANImageUploader/PremiumAccess.swift}"
info_plist="${BUILD_CHANNEL_INFO_PLIST:-$repo_root/LANImageUploader/Info.plist}"
expected_workflow_id="37c9d62c-448d-4f60-8672-496a5c044c34"
expected_workflow_name="TestFlight - external beta test"
marker_key='LensBridgeBuildChannelMarker'
testflight_marker='external-testflight-v1'

if [[ ! -f "$source_file" ]]; then
    printf 'Build distribution channel source is missing.\n' >&2
    exit 1
fi
if [[ ! -f "$info_plist" ]]; then
    printf 'Build distribution channel Info.plist is missing.\n' >&2
    exit 1
fi

declaration_count="$(/usr/bin/awk '
    /^[[:space:]]*static let current: AppBuildChannel = \.(production|testFlight)[[:space:]]*$/ {
        count += 1
    }
    END { print count + 0 }
' "$source_file")"
if [[ "$declaration_count" != "1" ]]; then
    printf 'Build distribution channel declaration must appear exactly once.\n' >&2
    exit 1
fi

# Reset the channel for every Cloud action. Only the one locked external-beta
# workflow can repopulate it, so missing or mismatched CI metadata fails closed
# to production.
channel_source='.production'
if [[ "${CI_WORKFLOW_ID:-}" == "$expected_workflow_id" \
    && "${CI_WORKFLOW:-}" == "$expected_workflow_name" ]]; then
    channel_source='.testFlight'
fi

/usr/bin/sed -i '' -E \
    "s#static let current: AppBuildChannel = \\.(production|testFlight)#static let current: AppBuildChannel = $channel_source#" \
    "$source_file"

rewritten_count="$(/usr/bin/awk -v expected="static let current: AppBuildChannel = $channel_source" '
    function trim(value) {
        sub(/^[[:space:]]+/, "", value)
        sub(/[[:space:]]+$/, "", value)
        return value
    }
    trim($0) == expected { count += 1 }
    END { print count + 0 }
' "$source_file")"
if [[ "$rewritten_count" != "1" ]]; then
    printf 'Build distribution channel rewrite verification failed.\n' >&2
    exit 1
fi

/usr/libexec/PlistBuddy -c "Delete :$marker_key" "$info_plist" >/dev/null 2>&1 || true
if [[ "$channel_source" == '.testFlight' ]]; then
    /usr/libexec/PlistBuddy -c "Add :$marker_key string $testflight_marker" "$info_plist"
fi

if [[ "$channel_source" == '.testFlight' ]]; then
    marker_value="$(/usr/libexec/PlistBuddy -c "Print :$marker_key" "$info_plist" 2>/dev/null || true)"
    if [[ "$marker_value" != "$testflight_marker" ]]; then
        printf 'TestFlight build-channel marker verification failed.\n' >&2
        exit 1
    fi
elif /usr/libexec/PlistBuddy -c "Print :$marker_key" "$info_plist" >/dev/null 2>&1; then
    printf 'Production build-channel marker removal failed.\n' >&2
    exit 1
fi
