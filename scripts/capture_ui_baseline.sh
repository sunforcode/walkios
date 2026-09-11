#!/usr/bin/env bash
set -euo pipefail

readonly PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
readonly WORKSPACE_ROOT="$(dirname "${PROJECT_ROOT}")"
readonly RESULT_BUNDLE="${PROJECT_ROOT}/build/ui-baseline/WalkBaseline.xcresult"
readonly OUTPUT_DIR="${1:-${WORKSPACE_ROOT}/prototypes/hiking-loop-validation-v1/ui-evidence/ios/page-trips-v1}"
readonly DESTINATION="${WALK_BASELINE_DESTINATION:-platform=iOS Simulator,name=iPhone 17,OS=26.5}"

cd "${PROJECT_ROOT}"
xcodegen generate

mkdir -p "$(dirname "${RESULT_BUNDLE}")"
mkdir -p "${OUTPUT_DIR}"
if [[ -e "${RESULT_BUNDLE}" ]]; then
    mv "${RESULT_BUNDLE}" "${RESULT_BUNDLE}.previous.$(date +%Y%m%d%H%M%S)"
fi

xcodebuild test \
    -project Walk.xcodeproj \
    -scheme WalkBaseline \
    -destination "${DESTINATION}" \
    -resultBundlePath "${RESULT_BUNDLE}" \
    CODE_SIGNING_ALLOWED=NO

readonly EXPORTED_DIR="${PROJECT_ROOT}/build/ui-baseline/exported"
if [[ -d "${EXPORTED_DIR}" ]]; then
    mv "${EXPORTED_DIR}" "${EXPORTED_DIR}.previous.$(date +%Y%m%d%H%M%S)"
fi
xcrun xcresulttool export attachments \
    --path "${RESULT_BUNDLE}" \
    --output-path "${EXPORTED_DIR}"

python3 - "${EXPORTED_DIR}" "${OUTPUT_DIR}" <<'PY'
import json
import shutil
import sys
from pathlib import Path

exported = Path(sys.argv[1])
output = Path(sys.argv[2])
manifest = json.loads((exported / "manifest.json").read_text(encoding="utf-8"))
runs = manifest if isinstance(manifest, list) else [manifest]
attachments = [
    attachment
    for run in runs
    if isinstance(run, dict)
    for attachment in run.get("attachments", [])
]
copied = 0
for attachment in attachments:
    name = attachment.get("name") or attachment.get("suggestedHumanReadableName") or ""
    exported_name = attachment.get("exportedFileName") or attachment.get("filename")
    if not name.startswith("page-trips--") or not exported_name:
        continue
    # suggestedHumanReadableName 形如 "<scenario>_0_<UUID>.png"，规整为 "<scenario>.png"
    stem = name.split("_0_")[0]
    if stem.endswith(".png"):
        stem = stem[: -len(".png")]
    target_name = f"{stem}.png"
    shutil.copyfile(exported / exported_name, output / target_name)
    copied += 1
if copied != 6:
    raise SystemExit(f"Expected 6 PAGE-TRIPS screenshots, exported {copied}")
print(f"Exported {copied} screenshots to {output}")
PY
