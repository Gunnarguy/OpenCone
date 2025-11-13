#!/bin/zsh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
INFO_PLIST="${REPO_ROOT}/OpenCone/Info.plist"

print -- "🔍 Running OpenCone preflight checks from ${REPO_ROOT}"

# 1. Secret scan
python3 "${SCRIPT_DIR}/secret_scan.py" "${REPO_ROOT}"

# 2. Ensure required usage descriptions exist
function ensure_plist_key() {
  local key="$1"
  if ! /usr/libexec/PlistBuddy -c "Print :${key}" "${INFO_PLIST}" >/dev/null 2>&1; then
    print -- "error: Missing Info.plist key '${key}'" >&2
    exit 1
  fi
  local value
  value=$(/usr/libexec/PlistBuddy -c "Print :${key}" "${INFO_PLIST}" 2>/dev/null || true)
  if [[ -z "${value}" ]]; then
    print -- "error: Info.plist key '${key}' is present but empty" >&2
    exit 1
  fi
}

ensure_plist_key "NSPhotoLibraryUsageDescription"
ensure_plist_key "NSDocumentsFolderUsageDescription"
ensure_plist_key "NSFileProviderPresenceUsageDescription"
ensure_plist_key "NSFileProviderDomainUsageDescription"

# 3. Validate privacy docs are present and up to date
function require_phrase() {
  local file="$1"
  local phrase="$2"
  if ! grep -q "$phrase" "$file"; then
    print -- "error: '${phrase}' missing from ${file}" >&2
    exit 1
  fi
}

require_phrase "${REPO_ROOT}/PRIVACY.md" "Last updated"
require_phrase "${REPO_ROOT}/AppReviewNotes.md" "Last updated"

# 4. Run unit tests unless explicitly skipped. Customize the destination via
#    OPEN_CONE_TEST_DESTINATION if your simulator list differs.
if [[ "${SKIP_TESTS:-0}" != "1" ]]; then
  DESTINATION=${OPEN_CONE_TEST_DESTINATION:-'platform=iOS Simulator,name=iPhone 17'}
  print -- "🧪 Running unit tests on ${DESTINATION}"
  xcodebuild test \
    -project "${REPO_ROOT}/OpenCone.xcodeproj" \
    -scheme OpenCone \
    -destination "${DESTINATION}"
else
  print -- "⚠️ Skipping unit tests (SKIP_TESTS=1)"
fi

print -- "✅ Preflight checks passed"
