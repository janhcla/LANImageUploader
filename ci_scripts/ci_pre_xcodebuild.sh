#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source_file="${BUILD_CHANNEL_SOURCE_FILE:-$repo_root/LANImageUploader/PremiumAccess.swift}"
expected_workflow_id="37c9d62c-448d-4f60-8672-496a5c044c34"
expected_workflow_name="TestFlight - external beta test"

if [[ ! -f "$source_file" ]]; then
    printf 'Build distribution channel source is missing.\n' >&2
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
