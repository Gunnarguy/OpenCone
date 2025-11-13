#!/bin/zsh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
DEST_DIR="${1:-${REPO_ROOT}/Screenshots}"
SIMULATOR_NAME="${OPEN_CONE_SCREENSHOT_DEVICE:-iPhone 17}"
SHOT_LIST=(
  "welcome Onboarding flow ready (WelcomeView)"
  "documents Documents tab after import (Document list)"
  "processing Processing Logs tab during ingestion"
  "search Search tab showing streaming answer"
)

mkdir -p "${DEST_DIR}"

print -- "📸 Using simulator '${SIMULATOR_NAME}'"

if ! xcrun simctl list devices | grep -q "${SIMULATOR_NAME}"; then
  print -- "error: Simulator '${SIMULATOR_NAME}' not found. Use xcodebuild -showsdks to inspect available devices." >&2
  exit 1
fi

print -- "➡️  Booting simulator (if needed)"
xcrun simctl bootstatus "${SIMULATOR_NAME}" -b >/dev/null

print -- "When prompted, stage the described screen in the simulator, then press Return to capture."

for shot in "${SHOT_LIST[@]}"; do
  file_key="${shot%% *}"
  description="${shot#* }"
  output_path="${DEST_DIR}/${file_key}.png"
  print -- "\n🖼  Ready to capture: ${description}"
  read -s "?Press Return when staged..."
  xcrun simctl io "${SIMULATOR_NAME}" screenshot "${output_path}"
  print -- "Saved ${output_path}"
done

print -- "✅ Captured ${#SHOT_LIST[@]} screenshots to ${DEST_DIR}"
