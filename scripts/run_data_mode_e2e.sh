#!/usr/bin/env bash
# 三种数据模式的 E2E 验收（specs/README.md R-VERIFY「remoteOnly 真实到达受控服务的证据」）。
#
# 在宿主局域网地址启动受控服务，依次以 mock → real → real → remoteOnly 启动正式 App，
# 每一步记录：UI 测试结果、页面实际展示的路线（OCR）、受控服务新增请求数、应用响应缓存文件数。
# 真实网络模式拒绝 localhost / 127.0.0.1 占位地址（R-CONFIG），所以受控服务绑定局域网地址，
# 仅在本次运行期间监听，结束即停止。
#
# 用法：WALK_E2E_DESTINATION='platform=iOS Simulator,id=<UDID>' scripts/run_data_mode_e2e.sh [局域网 IP]
set -euo pipefail

readonly ROOT="$(cd "$(dirname "$0")/.." && pwd)"
readonly FIXTURE="${ROOT}/scripts/fixtures/data-mode-e2e"
readonly DESTINATION="${WALK_E2E_DESTINATION:?Set WALK_E2E_DESTINATION to an explicit iOS Simulator destination}"
readonly UDID="$(sed -n 's/.*id=\([A-F0-9-]*\).*/\1/p' <<<"${DESTINATION}")"
readonly IP="${1:-$(ipconfig getifaddr en0)}"
readonly PORT=18765
readonly OUT="${ROOT}/build/data-mode-e2e/$(date +%Y%m%dT%H%M%S)"
readonly DERIVED="${ROOT}/build/data-mode-e2e/DerivedData"
[[ -n "${UDID}" && -n "${IP}" ]] || { echo "需要带 id= 的 destination 与局域网 IP" >&2; exit 2; }
mkdir -p "${OUT}"

swiftc -O "${FIXTURE}/ocr.swift" -o "${OUT}/ocr"
cd "${ROOT}" && xcodegen generate >/dev/null
export SIMCTL_CHILD_WALK_E2E_BASE_URL="http://${IP}:${PORT}/walkbg/api/v1"
xcodebuild build-for-testing -project Walk.xcodeproj -scheme WalkDataModeE2E -destination "${DESTINATION}" \
  -derivedDataPath "${DERIVED}" CODE_SIGNING_ALLOWED=YES CODE_SIGN_IDENTITY=- > "${OUT}/build.log" 2>&1

xcrun simctl uninstall "${UDID}" com.walk.app >/dev/null 2>&1 || true
: > "${OUT}/requests.log"
python3 "${FIXTURE}/server.py" "${PORT}" "${OUT}/requests.log" "${IP}" > "${OUT}/server.log" 2>&1 &
readonly SERVER=$!
trap 'kill ${SERVER} 2>/dev/null || true' EXIT
sleep 1

app_cache() {
  local container; container="$(xcrun simctl get_app_container "${UDID}" com.walk.app data 2>/dev/null || true)"
  local dir="${container}/Library/Caches/APIResponses"
  if [[ -d "${dir}" ]]; then find "${dir}" -type f | wc -l | tr -d ' '; else echo 0; fi
}
requests() { wc -l < "${OUT}/requests.log" | tr -d ' '; }

{
  echo "| 步骤 | UI 测试 | 页面路线（OCR） | 受控服务新增请求 | 应用响应缓存文件 |"
  echo "|---|---|---|---|---|"
  index=0
  for step in Mock Real Real RemoteOnly RemoteOnlyFromEmpty; do
    index=$((index + 1))
    test_name="${step%FromEmpty}"
    if [[ "${step}" == *FromEmpty ]]; then
      # 清空应用响应缓存后单独运行，证明 remoteOnly 不写缓存（而不仅是「数量未变」）。
      container="$(xcrun simctl get_app_container "${UDID}" com.walk.app data 2>/dev/null || true)"
      [[ -n "${container}" ]] && rm -rf "${container}/Library/Caches/APIResponses"
    fi
    before_requests=$(requests); before_cache=$(app_cache)
    result="${OUT}/${index}-${step}.xcresult"
    xcodebuild test-without-building -project Walk.xcodeproj -scheme WalkDataModeE2E -destination "${DESTINATION}" \
      -derivedDataPath "${DERIVED}" -only-testing:"WalkDataModeE2EUITests/DataModeE2EUITests/test${test_name}" \
      -resultBundlePath "${result}" > "${OUT}/${index}-${step}.log" 2>&1 || true
    xcrun xcresulttool export attachments --path "${result}" --output-path "${OUT}/${index}-attachments" >/dev/null 2>&1
    shot="$(python3 -c "import json,sys;m=json.load(open(sys.argv[1]));print(next((a['exportedFileName'] for t in m for a in t.get('attachments',[]) if a.get('suggestedHumanReadableName','').startswith('mode-')),''))" "${OUT}/${index}-attachments/manifest.json")"
    route="$("${OUT}/ocr" "${OUT}/${index}-attachments/${shot}" 2>/dev/null | grep -E 'W6 受控服务路线|长海子' | head -1 || true)"
    status="$(grep -oE "Test Case '.*' (passed|failed)" "${OUT}/${index}-${step}.log" | grep -oE 'passed|failed' | tail -1 || echo unknown)"
    echo "| ${step} | ${status} | ${route:-（未识别）} | +$(( $(requests) - before_requests )) | ${before_cache} → $(app_cache) |"
  done
} | tee "${OUT}/summary.md"

echo "期望：Mock 展示「长海子」且请求 +0、缓存不变；Real 两次都 +1（网络优先，不被 HTTP 缓存截走）且写入应用缓存；"
echo "      RemoteOnly 展示受控服务路线且请求 +1，应用缓存数量不变；RemoteOnlyFromEmpty 从空缓存开始仍为 0。"
echo "结果目录：${OUT}"
