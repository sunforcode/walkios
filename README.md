# Walk iOS 架构与目录

本仓是 Walk 的 SwiftUI 原生 iOS 实现。产品定位、范围与行为规范不在本仓，权威入口见根仓 `docs/README.md` 与 `docs/prd.md`。

## 架构设计

已确认的架构图、职责边界和 Debug 三模式设计统一保存在 [平台规范：App 架构基准](specs/README.md#app-架构基准)。

重构目的、已认可的目标与分批工作安排见 [重构目标与工作拆分](specs/README.md#重构目标与工作拆分)。

实施规则统一见 [重构规范与约束](specs/README.md#重构规范与约束)，包括依赖、配置、断网策略、会话隔离、调试工具与验收要求。

当前源码的真实组成见 [架构调研记录（2026-09-24）](output/architecture-review-20260924.md)：App → Feature → Service → 统一 APIClient 的主干已实际使用；物理基础模块为 WalkData 与 WalkDesignSystem。数据客户端当前仍按 `remote / local / mock` 装配，DebugSwift 与独立 DebugTools 尚未接入。目标设计与实现现状在上述两处分别记录。

工程与测试基线的修复范围、当前验证证据和保留问题见 [W0 执行记录](output/refactor-w0-results-20260924.md)。

DebugSwift 已在 W3 接入正式 App，只存在于开发依赖图；Release 产物的隔离证据见 [W3 执行记录](output/refactor-w3-results-20260925.md)。W0 的最小宿主验证见 [W0 SDK 验证记录](output/debugswift-isolation-20260924.md)。

## 目录地图

```text
project-base.yml             # XcodeGen 共用模板（不直接生成工程）
project.yml                  # 开发依赖图：仅 Debug，含 WalkDebugTools；生成仓内 Walk.xcodeproj
project-release.yml          # 生产依赖图：仅 Release，无调试依赖；只经 scripts/build.py 生成
Packages/                    # 本地 Swift Package（独立编译，只暴露 public API）
  WalkData/                  # 数据层：Network / API / Persistence / Repositories / Sources(Mock)；不依赖 Features 与 WalkDesignSystem
  WalkDesignSystem/          # 设计系统：Theme(Token) / Components / 通用 fixture；不引用业务模型
  WalkDebugTools/            # 调试适配层（DebugSwift 1.19.0）；仅开发依赖图声明
Walk/                        # 主 target 源码
  App/                       # App 入口、根导航、环境配置
    Baseline/                # 视觉基线与组件目录基建（基线场景、截图目录、组件清单）
    Debug/                   # Debug 设置、调试面板模型与摇一摇入口（仅 DEBUG 编译）
  Features/                  # 页面按业务域组织（Home/Routes/Trips/Equipment/Profile），另有 Shared
    <域>/Components/         # 业务组件沉淀在所属域内，由组件目录与基线体系治理
  Support/                   # 跨域工具（LocationService）
  Preview Content/           # SwiftUI Preview 与业务 Mock 数据（通用 fixture 委托给 WalkDesignSystem）
  Resources/                 # Info.plist、本地化、MockAPI 资源
  Tests/                     # 主 target 的单元测试与 Fixtures
Tests/                       # 独立测试 target
  BaselineTests/  BaselineUITests/  ComponentTests/  ComponentUITests/  DebugToolsUITests/
scripts/                     # 构建入口 build.py、产物隔离检查、UI 基线与组件目录脚本
output/                      # 调研记录与其他产物；不作为规范来源
specs/                       # 平台规范：只承接总规范，不新增产品事实（见 specs/README.md）
```

依赖规则：App → Features → WalkData / WalkDesignSystem；WalkData 不依赖 Features 与 WalkDesignSystem，Features 之间禁止横向依赖，WalkDesignSystem 不 import 业务模型。只有 App 的 `Walk/App/Debug/` 使用 WalkDebugTools，Feature、WalkData、WalkDesignSystem 不得依赖它，由 `DebugToolsBoundaryTests` 强制。

## 约定

- 本地包的 `Package.swift`、源码与 fixture 属于仓库输入，不忽略整个 `Packages/`。第三方依赖由 SwiftPM 按固定版本恢复，App 的 `Package.resolved` 随工程保留；不依赖 `.swiftpm-packages/` 下的手工下载内容。
- 工程由 XcodeGen 生成：修改 `project-base.yml`、`project.yml` 或源码目录结构后运行 `xcodegen generate`，不直接编辑 `Walk.xcodeproj`。
- 仓内 `Walk.xcodeproj` 只有 Debug 配置。出包与 Release 验证只走 `scripts/build.py --mode release`，它每次重新生成生产工程并自动执行产物隔离检查；不要在 Xcode 中对开发工程选择 Release 或 Archive。
- 页面组件归 `Features/<域>/`，跨页面通用组件归 `DesignSystem/Components/`，绑定业务对象的组件沉淀到 `Features/<域>/Components/`；分类标准见根仓 `docs/ui/`。
- 视觉基线证据与脚本输出进入 `build/`（gitignored），已批准的基线资产目录由 `scripts/compare_ui_baseline.py` 定义。

## 恢复工程与验证

安装匹配的 Xcode 与 XcodeGen 后，在仓库根目录执行。平台登记检查还要求本仓位于 Walk 协调工作区中，父目录包含对应版本的 `docs/ui/` 与 `openspec/specs/`；仅检出 iOS 仓不能运行这项跨仓检查。

```bash
xcodegen generate
xcodebuild -resolvePackageDependencies -project Walk.xcodeproj -scheme Walk
python3 scripts/tests/test_platform_spec_registry.py
python3 scripts/tests/test_compare_ui_baseline.py
xcodebuild test -project Walk.xcodeproj -scheme Walk -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' CODE_SIGNING_ALLOWED=YES CODE_SIGN_IDENTITY=-
```

## 调试工具

Debug 构建中摇一摇设备（模拟器：Device → Shake）打开 DebugSwift 面板，在 App 分组查看「当前生效」「重启后生效」，并通过自定义动作切换数据模式、服务器、断网策略，或清除响应缓存、恢复构建默认值。设置只在重启后生效。Baseline 与组件预览不挂载该入口。

## 出包

```bash
python3 scripts/build.py --mode release --action archive
```

输出目录中的 `isolation-report.json` 是 Release 不含 DebugSwift 的证据；检查失败时入口返回非零。归档不签名，签名与分发尚未纳入本入口。

首次恢复第三方依赖需要访问其 Git 仓库。模拟器名称与系统版本按本机已安装设备选择；上述模拟器测试使用本地临时签名，认证用例需要有效的 Keychain 访问权限，不能用 `CODE_SIGNING_ALLOWED=NO` 替代。UI 对比工具测试需要 Python 的 Pillow 和 NumPy。当前固定 Alamofire 5.9.1、Lottie 4.4.3、DebugSwift 1.19.0，升级版本应单独验证并更新锁文件。
