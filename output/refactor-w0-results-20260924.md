# W0 工程与验证基线修复

日期：2026-09-24。对象为 `main` / `d6654ec` 上的当前工作树。本记录承接[实施前调研](refactor-current-state-20260924.md)，不改写历史检查结果；范围依据[分批计划](../specs/README.md#重构目标与工作拆分)。

后续进展：本批之后已完成 [DebugSwift 最小接入与构建隔离验证](debugswift-isolation-20260924.md)，W0 可进入下一批。本文下方的 SDK「尚未验证」描述保留为本批结束时的状态；正式 Walk App 的 SDK 接入仍在 W3。

## 本批修改

1. 解除 `Packages/` 和 `Package.resolved` 的整体忽略，继续忽略第三方下载目录与 SwiftPM 生成目录。两个本地包清单及三个既有必要源码文件现在可被版本控制识别；本轮没有暂存、提交或推送。
2. `project.yml` 与 WalkData manifest 改为从官方 URL 恢复固定的 Alamofire 5.9.1、Lottie 4.4.3，替代不可重建的本机 checkout 路径。README 补充恢复步骤和跨仓规范检查的工作区前提。
3. 运行 XcodeGen 重新生成工程，把 `AuthConfigurationTests`、`DebugDataAccessTests` 共 8 项既有草稿测试纳入 WalkTests。
4. 平台登记解析只读取 Page / Component 映射区，避免架构表被误识别；本地链接存在性检查排除 URL fragment。补充 4 项解析回归测试，仍检查未知 ID、重复登记和文件缺失。
5. 删除已退役的 `page-shell`、`trip-route-version-card` 映射，补上现有生产承载 `daily-weather-summary-row`。登记存在不等于 UI 符合性验收通过。
6. 修复 RouteDetail 拆分文件后失效的 7 项结构断言：联合检查主页面与其 Support，验证页面确实消费被检查结构，并保留组件、顺序与禁止旧实现的约束。顶部留白检查改为当前滚动内容边距接线，验证只有一个滚动拥有者。

本批修改与开始前文件摘要对账，生产业务与 UI 源码、此前的数据层草稿均未改动；Package manifest、工程定义、测试和文档属于本批范围。测试仍有源码字符串依赖，减少这类耦合留待后续按行为逐步调整。

## 新鲜验证

环境：Xcode 26.5（17F42）、XcodeGen 2.46.0、iPhone 17 Pro / iOS 26.5。构建使用新的 `build/w0-20260924/DerivedData` 与 `SourcePackages`，不复用旧的手工依赖目录。

| 检查 | 结果 |
|---|---|
| `xcodegen generate`、pbxproj 格式 | 通过；两个新增测试文件均在 Sources 中。 |
| 平台登记与解析测试 | 8 项通过；此前是 4 项中 2 项失败。 |
| UI 基线对比工具测试 | 9 项通过；这不是页面视觉验收。 |
| 官方依赖恢复与锁文件 | 通过；锁定 Alamofire 5.9.1 / `f455c2975872ccd2d9c81594c658af65716e9b9a`、Lottie 4.4.3 / `769b88d83a42ca8d5572b020c96f47e3690b3796`。 |
| WalkTests | 编译成功；340 项中 337 通过、2 失败、1 跳过。7 项旧结构失败均已消除，新增登记的认证 / 禁缓存 8 项全部通过。 |
| Release 模拟器构建 | 通过；生成 arm64 / x86_64 通用模拟器产物。未进行设备签名与归档。 |
| 变更格式 | `git diff --check` 通过。 |

主测试证据为 [WalkTests-signed.xcresult](../build/w0-20260924/WalkTests-signed.xcresult)，`xcresulttool` 汇总确认上述数量。两项失败均位于 AppEnvironmentTests：`testDebugMockLaunchModeOverridesRemoteEnvironment`、`testDebugRemoteOnlyLaunchModeOverridesMockEnvironment`。唯一跳过项仍为需显式开启的真实后端行程流程测试；本轮没有请求真实后端。

首轮使用 `CODE_SIGNING_ALLOWED=NO` 时，认证 4 个用例还产生 9 个失败断言，日志明确 Keychain 返回 `-34018`（`errSecMissingEntitlement`）。仅将测试命令改为 `CODE_SIGNING_ALLOWED=YES CODE_SIGN_IDENTITY=-` 后全量重跑，这 4 例全部通过；没有修改生产认证逻辑、跳过测试或弱化断言。README 已修正测试前提。首轮 [WalkTests.xcresult](../build/w0-20260924/WalkTests.xcresult) 保留作为环境问题证据。

本次没有运行独立 Baseline / Component 测试组、真实后端 E2E、设备归档、页面视觉验收或尚未接入 SDK 的功能测试，不能用本轮结果代替这些验收。

下载后的源码逐文件 SHA-256 对照：Alamofire `Source/` 44 个文件、Lottie `Sources/` 285 个文件，与旧本地目录完全一致。Lottie 旧本地 manifest 曾移除开发依赖，现使用官方 manifest；应用运行源码没有差异。锁文件由 SwiftPM 实际解析生成，保存在 `Walk.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved`。这证明当前工作树可从官方依赖构建，不等于已经执行仅包含已提交文件的干净检出验证。

恢复、首轮测试、签名重跑与 Release 构建日志保留于 [build/w0-20260924](../build/w0-20260924/) 下的 `resolve.log`、`tests.log`、`tests-signed.log`、`release.log`。构建产物目录被 Git 忽略；这份报告及锁文件可纳入后续提交。

本轮主要命令（省略日志重定向）：

```bash
xcodegen generate
xcodebuild -resolvePackageDependencies -project Walk.xcodeproj -scheme Walk \
  -derivedDataPath build/w0-20260924/DerivedData \
  -clonedSourcePackagesDirPath build/w0-20260924/SourcePackages
xcodebuild test -project Walk.xcodeproj -scheme Walk \
  -destination 'platform=iOS Simulator,id=D48F449A-B85E-4E73-BE25-C8BF6A4BDE44' \
  -derivedDataPath build/w0-20260924/DerivedData \
  -clonedSourcePackagesDirPath build/w0-20260924/SourcePackages \
  -disableAutomaticPackageResolution -parallel-testing-enabled NO \
  -resultBundlePath build/w0-20260924/WalkTests-signed.xcresult \
  CODE_SIGNING_ALLOWED=YES CODE_SIGN_IDENTITY=-
xcodebuild build -project Walk.xcodeproj -scheme Walk -configuration Release \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath build/w0-20260924/DerivedData \
  -clonedSourcePackagesDirPath build/w0-20260924/SourcePackages \
  -disableAutomaticPackageResolution CODE_SIGNING_ALLOWED=NO
```

再次执行时需选择本机模拟器和新的 resultBundlePath，避免覆盖已有证据。

## DebugSwift 可行性调研

只读调研候选为官方稳定版 [1.19.0](https://github.com/DebugSwift/DebugSwift/releases/tag/1.19.0)。其 [Package.swift](https://raw.githubusercontent.com/DebugSwift/DebugSwift/1.19.0/Package.swift) 声明 iOS 13、Swift tools 6.0 / Swift 6 模式，单一 `DebugSwift` 产品，无外部包依赖，包含资源。当前工程的部署目标与工具链满足声明门槛，但尚未编译、启动该 SDK，不能据此确认所有 API 与并发调用兼容。

仅给 App 调用加 `#if DEBUG` 不能满足“不编译、不链接 SDK”的要求。XcodeGen 2.46.0 的 [Dependency 定义](https://raw.githubusercontent.com/yonaskolb/XcodeGen/2.46.0/Sources/ProjectSpec/Dependency.swift) 没有按构建配置过滤包依赖的能力；`link: false` 也不能据此证明依赖不被构建。

可验证的候选方案是共用 target template、开发与生产 App target 分离，仅开发 target 引入 DebugTools → DebugSwift，生产 Release / Archive scheme 选择无此依赖链的 target。若要禁止开发 target 被误用于 Release，还需明确生成与构建入口约束。此处是根据 [XcodeGen 2.46.0 工程规范](https://raw.githubusercontent.com/yonaskolb/XcodeGen/2.46.0/Docs/ProjectSpec.md) 得出的方案，尚未实施。

后续独立验证至少包括：Debug 编译和入口运行；生产 Release 的构建日志、链接记录和最终产物中没有 SDK 及资源；静态链接时检查 link map / 符号。不能用当前尚未接入 SDK 的 Release 产物证明将来的隔离方案。

## 保留问题与批次边界

- `AppEnvironmentTests` 中两项 `-WalkDataMode` 新模式草稿测试保持原样；当前 App 仍解析旧配置入口，它们属于 W2 未实现项，不通过删除、跳过或弱化断言消除。
- `mock / real / remoteOnly`、独立 `OfflinePolicy`、缓存元数据与会话装配仍在 W1 / W2；DebugSwift 实际接入在 W3。
- 上游路线详情规范要求海拔曲线靠前，现有实现和原有结构测试要求置底。本批未改变 UI 或原有顺序断言，该存量差距不计作本轮修复，也不能被结构测试通过掩盖。
- 编译仍有弃用 API、Sendable 等既存警告；认证异步测试还暴露后台发布 SwiftUI 状态警告。AuthManager 的全局通知会被宿主 RootView 消费，事件来源隔离与主线程交付在后续认证边界整理中处理，本批不修改生产事件逻辑。
- 本轮已完成工程基线修复与可行性资料调查，W0 仍需 SDK 隔离方案的实际构建证明；不把 W0 全部或后续架构重构标记完成。
