#!/usr/bin/env bash
# 关键流程回归（specs/README.md R-VERIFY「业务与 UI」）：Mock 模式下五域主链路与登录。
#
# Keychain 在卸载 App 后仍保留登录态。为保证每次从未登录状态开始并显式登录，
# 运行前卸载 App 并重置目标模拟器的 Keychain。只作用于显式指定的测试模拟器。
#
# 用法：WALK_E2E_DESTINATION='platform=iOS Simulator,id=<UDID>' scripts/run_key_flow_regression.sh
set -euo pipefail

readonly ROOT="$(cd "$(dirname "$0")/.." && pwd)"
readonly DESTINATION="${WALK_E2E_DESTINATION:?Set WALK_E2E_DESTINATION to an explicit iOS Simulator destination}"
readonly UDID="$(sed -n 's/.*id=\([A-F0-9-]*\).*/\1/p' <<<"${DESTINATION}")"
[[ -n "${UDID}" ]] || { echo "destination 必须包含 id=<UDID>" >&2; exit 2; }

xcrun simctl uninstall "${UDID}" com.walk.app >/dev/null 2>&1 || true
xcrun simctl keychain "${UDID}" reset
exec python3 "${ROOT}/scripts/build.py" --mode debug --action test --scheme WalkKeyFlows \
  --destination "${DESTINATION}" --output "${ROOT}/build/key-flow-regression"
