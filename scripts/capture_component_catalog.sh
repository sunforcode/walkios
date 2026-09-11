#!/usr/bin/env bash
set -euo pipefail

readonly PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
readonly DESTINATION="${WALK_COMPONENT_DESTINATION:?Set WALK_COMPONENT_DESTINATION to an explicit iOS Simulator destination}"
readonly BUILD_DIR="${PROJECT_ROOT}/build/component-catalog"
readonly RESULT_BUNDLE="${BUILD_DIR}/WalkComponents.xcresult"
readonly EXPORTED_DIR="${BUILD_DIR}/exported"
readonly CANDIDATE_DIR="${BUILD_DIR}/candidate"
readonly CATALOG_SOURCE="${PROJECT_ROOT}/Walk/App/Baseline/ComponentCatalog.swift"

mkdir -p "${BUILD_DIR}"

for path in "${RESULT_BUNDLE}" "${EXPORTED_DIR}" "${CANDIDATE_DIR}"; do
    if [[ -e "${path}" ]]; then
        mv "${path}" "${path}.previous.$(date +%Y%m%d%H%M%S)"
    fi
done
mkdir -p "${CANDIDATE_DIR}"

xcodebuild test \
    -project "${PROJECT_ROOT}/Walk.xcodeproj" \
    -scheme WalkComponents \
    -destination "${DESTINATION}" \
    -resultBundlePath "${RESULT_BUNDLE}" \
    CODE_SIGNING_ALLOWED=NO

xcrun xcresulttool export attachments \
    --path "${RESULT_BUNDLE}" \
    --output-path "${EXPORTED_DIR}"

python3 - "${EXPORTED_DIR}" "${CANDIDATE_DIR}" "${CATALOG_SOURCE}" <<'PY'
import json
import re
import shutil
import sys
from pathlib import Path

exported = Path(sys.argv[1])
candidate = Path(sys.argv[2])
catalog_source = Path(sys.argv[3])

catalog_ids = re.findall(r'^\s*entry\("([^"]+)",\s*\.(?:common|business)\)', catalog_source.read_text(encoding="utf-8"), re.MULTILINE)
if len(catalog_ids) != 78 or len(set(catalog_ids)) != 78:
    raise SystemExit(f"Catalog must contain exactly 78 unique component IDs; got {len(catalog_ids)} / {len(set(catalog_ids))} unique")

manifest = json.loads((exported / "manifest.json").read_text(encoding="utf-8"))
runs = manifest if isinstance(manifest, list) else [manifest]
attachments = [
    attachment
    for run in runs
    if isinstance(run, dict)
    for attachment in run.get("attachments", [])
]

candidate.mkdir(parents=True, exist_ok=True)
exported_ids = []
for attachment in attachments:
    name = attachment.get("name") or attachment.get("suggestedHumanReadableName") or ""
    exported_name = attachment.get("exportedFileName") or attachment.get("filename")
    if not exported_name:
        continue
    stem = name.split("_0_", 1)[0]
    if stem.endswith(".png"):
        stem = stem[:-4]
    match = re.fullmatch(r"component-(.+)--default", stem)
    if not match:
        continue
    component_id = match.group(1)
    if component_id not in catalog_ids:
        raise SystemExit(f"Unexpected component screenshot attachment: {component_id}")
    if component_id in exported_ids:
        raise SystemExit(f"Duplicate component screenshot attachment: {component_id}")
    shutil.copyfile(exported / exported_name, candidate / f"{component_id}--default.png")
    exported_ids.append(component_id)

missing = sorted(set(catalog_ids) - set(exported_ids))
extra = sorted(set(exported_ids) - set(catalog_ids))
if len(exported_ids) != 78 or missing or extra:
    raise SystemExit(
        f"Expected 78 default component screenshots, exported {len(exported_ids)}; missing={missing}; extra={extra}"
    )

print(f"Exported {len(exported_ids)} component screenshots to {candidate}")
PY
