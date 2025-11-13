#!/bin/zsh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
APPICONSET="${REPO_ROOT}/OpenCone/Assets.xcassets/AppIcon.appiconset"
SOURCE="${1:-${APPICONSET}/AppIcon-1024.png}"

if [[ ! -f "${SOURCE}" ]]; then
  print -- "error: Source image not found at ${SOURCE}" >&2
  exit 1
fi

if [[ ! -d "${APPICONSET}" ]]; then
  print -- "error: AppIcon set not found at ${APPICONSET}" >&2
  exit 1
fi

ICON_SPECS=(
  "40 AppIcon-20@2x.png"
  "60 AppIcon-20@3x.png"
  "58 AppIcon-29@2x.png"
  "87 AppIcon-29@3x.png"
  "80 AppIcon-40@2x.png"
  "120 AppIcon-40@3x.png"
  "120 AppIcon-60@2x.png"
  "180 AppIcon-60@3x.png"
  "20 AppIcon-20~ipad.png"
  "40 AppIcon-20@2x~ipad.png"
  "29 AppIcon-29~ipad.png"
  "58 AppIcon-29@2x~ipad.png"
  "40 AppIcon-40~ipad.png"
  "80 AppIcon-40@2x~ipad.png"
  "76 AppIcon-76~ipad.png"
  "152 AppIcon-76@2x~ipad.png"
  "167 AppIcon-83.5@2x~ipad.png"
)

for spec in "${ICON_SPECS[@]}"; do
  pixels="${spec%% *}"
  output="${spec#* }"
  sips -z "${pixels}" "${pixels}" "${SOURCE}" --out "${APPICONSET}/${output}" >/dev/null
  print -- "Generated ${output}"
done

print -- "Generated ${#ICON_SPECS[@]} app icon variants into ${APPICONSET}"
