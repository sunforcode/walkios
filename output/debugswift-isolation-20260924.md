# W0：DebugSwift 接入与构建隔离验证

日期：2026-09-24。承接[架构规范 R-DEBUG](../specs/README.md#6-debugtools-与工程隔离)和[上一批 W0 记录](refactor-w0-results-20260924.md)。这是独立验证工程的证据，正式 Walk App 尚未接入 DebugSwift。

## 方案与验证范围

验证源码在 [scripts/fixtures/debugswift-isolation](../scripts/fixtures/debugswift-isolation/)。`base.yml` 共用宿主源码与设置；`debug.yml` 增加 WalkDebugTools → DebugSwift；`release.yml` 不声明这两个依赖。两套工程由 XcodeGen 生成到 `build/`，不手改 pbxproj，不复制 App 业务代码。

固定 DebugSwift **1.19.0**，实际 SwiftPM 锁定 revision **b85fd86581bc1b67710be82249d8aac2ef61b2f5**，解析生成的锁文件保存在 fixture 中。验证环境为 Xcode 26.5（17F42）、XcodeGen 2.46.0、iPhone 17 Pro / iOS 26.5，宿主最低 iOS 18、Swift 5.9 模式；SDK 自身使用 Swift 6 模式。

最小适配层在主线程单次初始化 SDK，关闭全部可选 swizzle/监控钩子，通过 `debugViewController()` 返回真实 SDK 面板，由 SwiftUI sheet 承载。注入一组自定义信息，验证 App 持有入口而 SDK 类型不扩散到宿主视图。没有启用网络观察、浮标或任何真实业务请求，也没有接入三模式配置、认证、缓存操作。

即便关闭钩子，SDK setup 仍会注册生命周期监听和初始化内部管理对象；本次不宣称 SDK 零副作用。W3 如需启用网络观察，仍须验证请求、缓存、认证和取消语义。

## 实测证据

| 检查 | 结果与证据 |
|---|---|
| Debug SDK 编译 | 成功；固定版本可由当前工具链编译，并经 WalkDebugTools 被宿主调用。 |
| 接入前失败用例 | 空适配层能编译；[Debug-red.xcresult](../build/debugswift-w0/Debug-red.xcresult) 的 UI 用例在 SDK 面板、自定义数据断言失败。 |
| 接通 SDK 面板及自定义详情 | 最终[构建入口 UI 用例](../build/debugswift-w0/Runs/debug-test-20260924T110807.559953Z/Tests.xcresult)通过，真实 SDK App tab、W0 Probe 分组和注入值均可见。 |
| Release 运行 | [Release.xcresult](../build/debugswift-w0/Release.xcresult) 的 UI 用例通过，生产标记可见，没有调试按钮或面板。 |
| 生产 iOS 归档 | 通过受限入口生成的[生产归档](../build/debugswift-w0/Runs/release-archive-20260924T110607.458742Z/WalkIsolationRelease.xcarchive)构建成功；`generic/platform=iOS`，关闭签名，不代表设备安装或 App Store 分发已验证。 |
| 开发 scheme 归档 | 原始 `xcodebuild archive` 返回配置错误，未发生 SDK 编译；[日志](../build/debugswift-w0/rejected-archive.log)。 |
| Debug 产物正向检查 | [verification-debug.json](../build/debugswift-w0/verification-debug.json) 全部通过：SDK 与适配层均实际编译、链接并有符号，SDK 资源 bundle 存在。 |
| 生产依赖图、编译输入、链接、符号与资源 | [verification-release-archive.json](../build/debugswift-w0/verification-release-archive.json) 全部通过：对应 SDK / 适配层输入、符号和资源均不存在。 |
| 把 Debug 产物当作 Release 检查 | [verification-reject-debug-as-release.json](../build/debugswift-w0/verification-reject-debug-as-release.json) 返回失败，准确识别依赖、编译、链接、符号与资源 5 类违规。 |
| 构建入口规则 | 9 项 Python 测试通过。两个[真实非法调用](../build/debugswift-w0/entry-rejections.json)均在创建输出目录前返回 2：开发入口强制 Release、开发入口 archive。 |

Debug 的依赖编译发生在红测阶段，接通适配器后的绿测复用相同 SDK。两个原始日志分别保留在 `debug-red.log`、`debug-green.log`；`debug-build.log` 明确标记并合并两段编译证据，没有隐藏红测结果。

最终入口验证还发现 SDK 将详情标题和值合并为一个无障碍标签。按实际 UI 层级将断言改为完整 `SDK\nDebugSwift 1.19.0` 后详情测试通过；此前失败记录保留在 `Runs/debug-test-20260924T110603.685834Z`。最终完整编译证据 `debug-final-build.log` 明确标记该次 SDK 全量编译与后续成功重链/测试两段来源。

验证宿主关闭 `ENABLE_DEBUG_DYLIB`，使主程序 link map 直接记录 SDK。Xcode 默认的启动 stub link map 不能证明 `.debug.dylib` 的完整链接内容；正式 App 若保留该结构，W3 的检查必须覆盖实际承载 SDK 的二进制及对应链接记录，不能只检查启动 stub。

## 可重复执行

[构建入口](../scripts/build_debugswift_probe.py)在执行工具前校验参数，按 Debug / Release 分目录生成工程和 DerivedData，日志与结果使用独立时间戳目录。Debug 从 fixture 锁文件恢复固定版本；Release 不创建开发工程或 SDK 下载目录。它不接受任意 xcodebuild 参数透传。

```bash
python3 scripts/tests/test_debugswift_probe_entry.py
python3 scripts/build_debugswift_probe.py --mode debug --action test \
  --destination 'platform=iOS Simulator,id=D48F449A-B85E-4E73-BE25-C8BF6A4BDE44'
python3 scripts/build_debugswift_probe.py --mode release --action archive
```

测试时按本机已安装模拟器替换 destination。新的日志和结果路径由入口输出；归档是无签名验证产物。

[产物检查](../scripts/check_debugswift_isolation.py)读取生成工程、构建日志、link map、全部 App Mach-O 的符号/动态依赖及资源，并输出带文件摘要的 JSON；缺输入或缺链接证据即失败。它不启动构建，也不替代 UI 测试。

```bash
python3 scripts/check_debugswift_isolation.py --mode release \
  --project build/debugswift-w0/Release/WalkIsolationRelease.xcodeproj \
  --derived-data build/debugswift-w0/Release/DerivedData \
  --app 'build/debugswift-w0/Runs/<本次归档目录>/WalkIsolationRelease.xcarchive/Products/Applications/WalkIsolationProbe.app' \
  --build-log 'build/debugswift-w0/Runs/<本次归档目录>/archive.log' \
  --output build/debugswift-w0/verification-release-archive.json
```

示例中的 `<本次归档目录>` 需要替换为入口输出的目录。Debug 模式还要求 SDK、适配层编译与链接的正向证据；增量构建需提供来源明确的完整本轮日志。产物门禁在失败时返回 1，不能仅依据 App 中没有动态 framework 就判隔离通过。

## 发现并处理的构建陷阱

1. XcodeGen 2.46 的单配置工程需要给 scheme 的 run / test / profile / analyze / archive 五种 action 显式指定已有配置，缺省 action 可能使工程生成器崩溃。fixture 已明确配置。
2. **删除开发工程的 Release configuration 不会阻止命令行强行传入 Release。** 实验中，只有 Debug 配置的工程接受了 `xcodebuild -configuration Release`，并开始编译 SDK。发现后主动终止该构建，证据为 [rejected-release.log](../build/debugswift-w0/rejected-release.log)。不能把这个实验标为成功拒绝。
3. 因此，受支持构建入口必须在调用 XcodeGen / xcodebuild 前校验工程模式、configuration 和 action；开发入口拒绝 Release 与 archive，正式 Release / archive 仅使用无 SDK 依赖的生产图。原始 xcodebuild 绕过入口并强行覆盖配置仍有风险，不能宣称生成工程能够阻止所有任意命令。
4. App 的 `#if DEBUG`、编译报错或 target 内拒绝脚本都不能单独证明 SDK 没有被依赖任务提前编译。最终验收必须检查生产依赖图、构建任务、link map、二进制符号/动态依赖和资源。

## 正式接入的边界

W0 的接入方案验证完成。W3 采用本次验证的共用模板、分离依赖图、入口校验和产物检查方式；根 `project.yml` 与正式 App 在本批保持原样。正式接入后仍需重新验证 Walk 的 Debug/Release 与发布产物，不能用最小宿主的结果代替 App 的最终验收。

三模式与缓存策略分别归 W1 / W2；现有两项新模式配置红测继续保留。SDK 的真实配置动作应连接 App 的统一配置与数据能力，不能在 SDK 适配层另建客户端或第二份有效配置。
