#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
gate_script="$repo_root/ci_scripts/ci_pre_xcodebuild.sh"
fixture="$repo_root/scripts/fixtures/BuildDistributionChannelFixture.swift"
temp_dir="$(mktemp -d "${TMPDIR:-/tmp}/lensbridge-build-channel.XXXXXX")"
trap 'rm -rf "$temp_dir"' EXIT

run_case() {
    local expected_channel="$1"
    local workflow_id="$2"
    local workflow_name="$3"
    local source_file="$temp_dir/BuildDistributionChannel.swift"
    local actual_channel

    cp "$fixture" "$source_file"
    CI_WORKFLOW_ID="$workflow_id" \
    CI_WORKFLOW="$workflow_name" \
    BUILD_CHANNEL_SOURCE_FILE="$source_file" \
    "$gate_script"
    actual_channel="$(swift "$source_file")"

    if [[ "$actual_channel" != "$expected_channel" ]]; then
        printf 'Expected %s channel, got %s.\n' "$expected_channel" "$actual_channel" >&2
        exit 1
    fi
}

run_case production '' ''
run_case testFlight '37c9d62c-448d-4f60-8672-496a5c044c34' 'TestFlight - external beta test'
run_case production '37c9d62c-448d-4f60-8672-496a5c044c34' 'TestFlight - renamed workflow'

printf 'Xcode Cloud distribution gate behavior passed.\n'
