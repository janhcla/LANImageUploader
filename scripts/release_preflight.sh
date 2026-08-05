#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

app_id="${APP_ID:-6742799620}"
version_id="${VERSION_ID:-6be1a88a-633a-43e2-b7a7-1d7e3d636c5a}"
marketing_version="${MARKETING_VERSION:-1.58}"
production_build_id="${PRODUCTION_BUILD_ID:-7d58096f-cd10-478e-a974-051c0eac5f89}"
testflight_build_id="${TESTFLIGHT_BUILD_ID:-1ca50bac-0890-4e5d-a3de-9d1a802b6a88}"
production_build_number="${PRODUCTION_BUILD_NUMBER:-65}"
testflight_build_number="${TESTFLIGHT_BUILD_NUMBER:-64}"
testflight_marketing_version="${TESTFLIGHT_MARKETING_VERSION:-1.57}"
production_ipa="${PRODUCTION_IPA:-.asc/artifacts/LensBridge-1.58-65-export/LANImageUploader.ipa}"
testflight_ipa="${TESTFLIGHT_IPA:-.asc/artifacts/LensBridge-1.57-64-testflight.ipa}"
skip_asc="${SKIP_ASC:-0}"

failures=0

pass() { printf 'PASS  %s\n' "$1"; }
fail() {
    printf 'FAIL  %s\n' "$1"
    failures=$((failures + 1))
}
note() { printf 'INFO  %s\n' "$1"; }

require_command() {
    if command -v "$1" >/dev/null 2>&1; then
        pass "tool available: $1"
    else
        fail "tool missing: $1"
    fi
}

require_command jq
require_command plutil
require_command codesign
require_command unzip

if git diff --check; then
    pass "git diff --check"
else
    fail "git diff --check"
fi

if [[ -x "$repo_root/scripts/release_preflight.sh" ]]; then
    pass "release preflight script is executable"
else
    fail "release preflight script is not executable"
fi

if metadata_json="$(asc metadata validate --dir docs/app-store-metadata --output json 2>/dev/null)" \
    && [[ "$(jq -r '.valid' <<<"$metadata_json")" == "true" ]]; then
    pass "canonical App Store metadata validates"
else
    fail "canonical App Store metadata validation"
fi

if screenshots_json="$(asc screenshots validate \
    --path docs/app-store-screenshots/asc-6.9/en-US \
    --device-type IPHONE_67 \
    --output json 2>/dev/null)" \
    && [[ "$(jq -r '.errorCount' <<<"$screenshots_json")" == "0" ]] \
    && [[ "$(jq -r '.warningCount' <<<"$screenshots_json")" == "0" ]]; then
    pass "App Store screenshot dimensions and files validate"
else
    fail "App Store screenshot validation"
fi

check_ipa() {
    local label="$1"
    local ipa="$2"
    local expected_marketing_version="$3"
    local expected_build="$4"
    local expected_premium_string="$5"
    local extraction_dir
    local app
    local binary
    local display_name
    local short_version
    local build_number

    if [[ ! -f "$ipa" ]]; then
        fail "$label IPA exists: $ipa"
        return
    fi

    extraction_dir="$(mktemp -d "${TMPDIR:-/tmp}/lensbridge-preflight.XXXXXX")"
    unzip -qq "$ipa" -d "$extraction_dir"
    app="$(find "$extraction_dir/Payload" -maxdepth 1 -name '*.app' -type d -print -quit)"

    if [[ -z "$app" ]]; then
        fail "$label IPA contains an app bundle"
        rm -rf "$extraction_dir"
        return
    fi

    binary="$app/$(basename "$app" .app)"
    display_name="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleDisplayName' "$app/Info.plist")"
    short_version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$app/Info.plist")"
    build_number="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$app/Info.plist")"

    [[ "$display_name" == "LensBridge" ]] \
        && pass "$label display name is LensBridge" \
        || fail "$label display name is LensBridge"
    [[ "$short_version" == "$expected_marketing_version" ]] \
        && pass "$label marketing version is $expected_marketing_version" \
        || fail "$label marketing version is $expected_marketing_version"
    [[ "$build_number" == "$expected_build" ]] \
        && pass "$label build number is $expected_build" \
        || fail "$label build number is $expected_build"
    [[ -f "$app/PrivacyInfo.xcprivacy" ]] \
        && pass "$label contains PrivacyInfo.xcprivacy" \
        || fail "$label contains PrivacyInfo.xcprivacy"
    [[ "$(/usr/libexec/PlistBuddy -c 'Print :ITSAppUsesNonExemptEncryption' "$app/Info.plist")" == "false" ]] \
        && pass "$label declares exempt encryption" \
        || fail "$label declares exempt encryption"

    if codesign --verify --deep --strict "$app" >/dev/null 2>&1; then
        pass "$label strict code signature"
    else
        fail "$label strict code signature"
    fi

    if [[ "$expected_premium_string" == "present" ]]; then
        if strings "$binary" | rg -q 'Premium override'; then
            pass "$label contains TestFlight Premium override"
        else
            fail "$label contains TestFlight Premium override"
        fi
    else
        if strings "$binary" | rg -q 'Premium override'; then
            fail "$label excludes production Premium override"
        else
            pass "$label excludes production Premium override"
        fi
    fi

    rm -rf "$extraction_dir"
}

check_ipa "production" "$production_ipa" "$marketing_version" "$production_build_number" "absent"
check_ipa "TestFlight" "$testflight_ipa" "$testflight_marketing_version" "$testflight_build_number" "present"

if [[ "$skip_asc" == "1" ]]; then
    note "ASC checks skipped because SKIP_ASC=1"
else
    require_command asc
    status_ok=0
    for attempt in 1 2 3; do
        if asc status --app "$app_id" --output json >/dev/null 2>&1; then
            status_ok=1
            break
        fi
        sleep 1
    done
    if (( status_ok == 1 )); then
        pass "ASC authentication and app status"
    else
        fail "ASC authentication and app status"
    fi

    if testflight_json="$(asc validate testflight \
        --app "$app_id" \
        --build "$testflight_build_id" \
        --output json 2>/dev/null)" \
        && [[ "$(jq -r '.summary.errors' <<<"$testflight_json")" == "0" ]] \
        && [[ "$(jq -r '.summary.warnings' <<<"$testflight_json")" == "0" ]]; then
        pass "ASC TestFlight build validation"
    else
        fail "ASC TestFlight build validation"
    fi

    if version_json="$(asc versions view \
        --version-id "$version_id" \
        --include-build \
        --output json 2>/dev/null)" \
        && [[ "$(jq -r '.versionString' <<<"$version_json")" == "$marketing_version" ]] \
        && [[ "$(jq -r '.buildId' <<<"$version_json")" == "$production_build_id" ]] \
        && [[ "$(jq -r '.buildVersion' <<<"$version_json")" == "$production_build_number" ]]; then
        pass "ASC version $marketing_version has production build $production_build_number attached"
    else
        fail "ASC version $marketing_version production build attachment"
    fi

    if app_price_json="$(asc pricing current --app "$app_id" --output json 2>/dev/null)" \
        && [[ "$(jq -r '.isFree' <<<"$app_price_json")" == "true" ]] \
        && [[ "$(jq -r '.customerPrice' <<<"$app_price_json")" == "0.0" ]]; then
        pass "ASC app price is free"
    else
        fail "ASC app price is free"
    fi

    if iap_json="$(asc iap list --app "$app_id" --output json 2>/dev/null)" \
        && [[ "$(jq -r '.data[] | select(.attributes.productId == "com.janhagenclausen.LANImageUploader.fullunlock") | .attributes.inAppPurchaseType' <<<"$iap_json")" == "NON_CONSUMABLE" ]]; then
        pass "ASC Full App Unlock is non-consumable"
    else
        fail "ASC Full App Unlock is non-consumable"
    fi

    if iap_price_json="$(asc iap pricing summary --app "$app_id" --output json 2>/dev/null)" \
        && [[ "$(jq -r '.iaps[] | select(.productId == "com.janhagenclausen.LANImageUploader.fullunlock") | .currentPrice.amount' <<<"$iap_price_json")" == "1.99" ]] \
        && [[ "$(jq -r '.iaps[] | select(.productId == "com.janhagenclausen.LANImageUploader.fullunlock") | .currentPrice.currency' <<<"$iap_price_json")" == "USD" ]]; then
        pass "ASC Full App Unlock price is USD 1.99"
    else
        fail "ASC Full App Unlock price is USD 1.99"
    fi

    if app_info_json="$(asc localizations list \
        --app "$app_id" \
        --type app-info \
        --output json 2>/dev/null)" \
        && [[ "$(jq -r '[.data[] | select(.attributes.locale == "en-US" and .attributes.name == "LensBridge" and .attributes.subtitle == "Private Photo \u0026 Scan Transfer")] | length' <<<"$app_info_json")" == "1" ]] \
        && [[ "$(jq -r '[.data[] | select(.attributes.locale == "da" and .attributes.name == "LensBridge" and .attributes.subtitle == "Private Photo \u0026 Scan Transfer")] | length' <<<"$app_info_json")" == "1" ]]; then
        pass "ASC en-US/da name and subtitle are LensBridge"
    else
        fail "ASC en-US/da name and subtitle are LensBridge"
    fi

    if availability_json="$(asc pricing availability view \
        --app "$app_id" \
        --output json 2>/dev/null)" \
        && [[ "$(jq -r '.data.attributes.availableInNewTerritories' <<<"$availability_json")" == "true" ]]; then
        pass "ASC availability includes new territories"
    else
        fail "ASC availability includes new territories"
    fi

    if review_json="$(asc review doctor --app "$app_id" --output json 2>/dev/null)" \
        && [[ "$(jq -r '.summary.errors' <<<"$review_json")" == "0" ]] \
        && [[ "$(jq -r '.summary.warnings' <<<"$review_json")" == "0" ]]; then
        pass "ASC review doctor has no errors or warnings"
    else
        fail "ASC review doctor has unresolved release gates"
        if [[ -n "${review_json:-}" ]]; then
            note "ASC review summary: $(jq -c '.summary' <<<"$review_json")"
        fi
    fi
fi

if (( failures > 0 )); then
    printf 'RESULT  NOT READY (%d failed checks)\n' "$failures"
    exit 1
fi

printf 'RESULT  READY\n'
