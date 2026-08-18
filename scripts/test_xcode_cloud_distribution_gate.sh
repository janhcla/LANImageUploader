#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
gate_script="$repo_root/ci_scripts/ci_pre_xcodebuild.sh"
marker_verifier="$repo_root/scripts/verify_build_channel_marker.sh"
fixture="$repo_root/scripts/fixtures/BuildDistributionChannelFixture.swift"
info_plist_fixture="$repo_root/scripts/fixtures/BuildChannelMarkerProductionInfo.plist"
temp_dir="$(mktemp -d "${TMPDIR:-/tmp}/lensbridge-build-channel.XXXXXX")"
trap 'rm -rf "$temp_dir"' EXIT

run_case() {
    local expected_channel="$1"
    local workflow_id="$2"
    local workflow_name="$3"
    local source_file="$temp_dir/BuildDistributionChannel.swift"
    local info_plist="$temp_dir/Info.plist"
    local actual_channel

    cp "$fixture" "$source_file"
    cp "$info_plist_fixture" "$info_plist"
    CI_WORKFLOW_ID="$workflow_id" \
    CI_WORKFLOW="$workflow_name" \
    BUILD_CHANNEL_SOURCE_FILE="$source_file" \
    BUILD_CHANNEL_INFO_PLIST="$info_plist" \
    "$gate_script"
    "$marker_verifier" "$temp_dir" "$expected_channel"
    actual_channel="$(swift "$source_file")"

    if [[ "$actual_channel" != "$expected_channel" ]]; then
        printf 'Expected %s channel, got %s.\n' "$expected_channel" "$actual_channel" >&2
        exit 1
    fi
}

run_case production '' ''
run_case testFlight '37c9d62c-448d-4f60-8672-496a5c044c34' 'TestFlight - external beta test'
run_case production '37c9d62c-448d-4f60-8672-496a5c044c34' 'TestFlight - renamed workflow'

run_malformed_case() {
    local source_file="$temp_dir/MalformedBuildDistributionChannel.swift"
    local info_plist="$temp_dir/MalformedInfo.plist"

    cp "$fixture" "$source_file"
    cp "$info_plist_fixture" "$info_plist"
    /usr/bin/sed -i '' \
        's/static let current: AppBuildChannel = \.production/static let selected: AppBuildChannel = .production/' \
        "$source_file"

    if CI_WORKFLOW_ID='37c9d62c-448d-4f60-8672-496a5c044c34' \
        CI_WORKFLOW='TestFlight - external beta test' \
        BUILD_CHANNEL_SOURCE_FILE="$source_file" \
        BUILD_CHANNEL_INFO_PLIST="$info_plist" \
        "$gate_script" >/dev/null 2>&1; then
        printf 'Malformed build-channel source unexpectedly succeeded.\n' >&2
        exit 1
    fi
}

run_malformed_case

run_test_without_building_case() {
    local missing_source="$temp_dir/UnavailableBuildDistributionChannel.swift"
    local missing_info_plist="$temp_dir/UnavailableInfo.plist"

    CI_XCODEBUILD_ACTION='test-without-building' \
    BUILD_CHANNEL_SOURCE_FILE="$missing_source" \
    BUILD_CHANNEL_INFO_PLIST="$missing_info_plist" \
    "$gate_script"
}

run_test_without_building_case

printf 'Xcode Cloud distribution gate behavior passed.\n'
