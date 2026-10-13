# Walk iOS 架构与目录

本仓是 Walk 的 SwiftUI 原生 iOS 实现。产品定位、范围与行为规范不在本仓，权威入口见根仓 `docs/README.md` 与 `docs/prd.md`。

## 架构设计

已确认的架构图、职责边界和 Debug 三模式设计统一保存在 [平台规范：App 架构基准](specs/README.md#app-架构基准)。

重构目的、已认可的目标与分批工作安排见 [重构目标与工作拆分](specs/README.md#重构目标与工作拆分)。

实施规则统一见 [重构规范与约束](specs/README.md#重构规范与约束)，包括依赖、配置、断网策略、会话隔离、调试工具与验收要求。

重构 W0–W6 已完成。当前实际架构、各层依赖约束的强制测试与全部验收入口见 [当前架构](specs/README.md#当前架构)；各批次的过程记录不入库，需要时从 git 历史追溯（W6 收尾提交 `2a0fc14` 及之前）。

DebugSwift 只存在于开发依赖图，Release 产物由 `scripts/build.py --mode release` 执行隔离检查。

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
    Debug/                   # Debug 设置、调试面板、组件目录与预览（仅 DEBUG 编译）
  Features/                  # 页面按业务域组织（Home/Routes/Trips/Equipment/Profile），另有 Shared
    <域>/Components/         # 只被本域使用的业务组件
    Shared/                  # 跨域合同：Navigation/（导航意图、触控下限）与 Components/（被两个及以上域使用的业务组件与投影）
  Support/                   # 跨域工具（LocationService）
  Resources/                 # Info.plist、本地化、MockAPI 资源
  Tests/                     # 主 target 的单元测试与 Fixtures
Tests/                       # 独立测试 target
  ComponentTests/  ComponentUITests/  DebugToolsUITests/
  DataModeE2EUITests/  KeyFlowUITests/
scripts/                     # 构建入口 build.py、Release 产物隔离检查、E2E 与关键流程回归
specs/                       # 平台规范：只承接总规范，不新增产品事实（见 specs/README.md）
```

依赖规则：App → Features → WalkData / WalkDesignSystem；WalkData 不依赖 Features 与 WalkDesignSystem，WalkDesignSystem 不 import 业务模型。Feature 只能引用本域与 `Features/Shared/` 的类型，不引用 App 根实现；Shared 不依赖任何业务域，只放组件、投影与格式化工具，不放页面与 ViewModel。以上由 `FeatureBoundaryTests` 强制。WalkDesignSystem 的公开类型不得以业务域或具体页面命名，由 `DesignSystemBoundaryTests` 强制。Preview 样例数据与其对象共置：组件或页面在自身文件的 `#if DEBUG` 段内以所属类型 extension 提供样例，Preview 与 `ComponentCatalog` 共用同一份，不设集中式 fixture 目录或文件，由 `PreviewFixtureColocationTests` 强制。只有 App 的 `Walk/App/Debug/` 使用 WalkDebugTools，Feature、WalkData、WalkDesignSystem 不得依赖它，由 `DebugToolsBoundaryTests` 强制。

## 约定

- 本地包的 `Package.swift`、源码与 fixture 属于仓库输入，不忽略整个 `Packages/`。第三方依赖由 SwiftPM 按固定版本恢复，App 的 `Package.resolved` 随工程保留。
- 工程由 XcodeGen 生成：修改 `project-base.yml`、`project.yml` 或源码目录结构后运行 `xcodegen generate`，不直接编辑 `Walk.xcodeproj`。
- 仓内 `Walk.xcodeproj` 只有 Debug 配置。出包与 Release 验证只走 `scripts/build.py --mode release`，它每次重新生成生产工程并自动执行产物隔离检查；不要在 Xcode 中对开发工程选择 Release 或 Archive。
- 页面组件归 `Features/<域>/`，跨页面通用组件归 `DesignSystem/Components/`，绑定业务对象的组件沉淀到 `Features/<域>/Components/`；分类标准见根仓 `docs/ui/`。
- UITest 截图随测试结果保存，构建与脚本输出进入 `build/`（gitignored）；不维护独立 Baseline 或 Golden 图片对比链路。

## 恢复工程与验证

安装匹配的 Xcode 与 XcodeGen 后，在仓库根目录执行。平台登记检查还要求本仓位于 Walk 协调工作区中，父目录包含对应版本的 `docs/ui/` 与 `openspec/specs/`；仅检出 iOS 仓不能运行这项跨仓检查。

```bash
xcodegen generate
xcodebuild -resolvePackageDependencies -project Walk.xcodeproj -scheme Walk
python3 scripts/tests/test_platform_spec_registry.py
xcodebuild test -project Walk.xcodeproj -scheme Walk -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' CODE_SIGNING_ALLOWED=YES CODE_SIGN_IDENTITY=-
```

## 调试工具

Debug 构建中摇一摇设备（模拟器：Device → Shake）打开 DebugSwift 面板，在 App 分组查看「当前生效」「重启后生效」，并通过自定义动作切换数据模式、服务器、断网策略，或清除响应缓存、恢复构建默认值。设置只在重启后生效。

手动组件预览从面板 App 分组的「组件预览 → 打开组件目录」进入，选择组件和已登记状态后查看生产组件；可返回状态列表，关闭后回到原调试面板。预览不改变宿主配置、会话或缓存。自动化使用 `WalkComponents` 的组件 UITest，与面板复用同一目录和 renderer；`--component-preview` 定向启动仅供 UITest，不挂载调试面板。未知组件或状态显示 unsupported，不回退默认状态。

## 端到端验收

```bash
# 三种数据模式：在局域网地址启动受控服务，核对请求到达与应用响应缓存
WALK_E2E_DESTINATION='platform=iOS Simulator,id=<UDID>' scripts/run_data_mode_e2e.sh [局域网 IP]
# 关键流程：Mock 模式五域主链路与登录（运行前卸载 App 并重置该模拟器 Keychain）
WALK_E2E_DESTINATION='platform=iOS Simulator,id=<UDID>' scripts/run_key_flow_regression.sh
```

真实网络模式拒绝 localhost / 127.0.0.1 占位地址，受控服务因此使用局域网地址，只在运行期间监听。

## 出包

```bash
python3 scripts/build.py --mode release --action archive
```

输出目录中的 `isolation-report.json` 是 Release 不含 DebugSwift 的证据；检查失败时入口返回非零。归档不签名，签名与分发尚未纳入本入口。

首次恢复第三方依赖需要访问其 Git 仓库。模拟器名称与系统版本按本机已安装设备选择；上述模拟器测试使用本地临时签名，认证用例需要有效的 Keychain 访问权限，不能用 `CODE_SIGNING_ALLOWED=NO` 替代。当前固定 Alamofire 5.9.1、Lottie 4.4.3、DebugSwift 1.19.0，升级版本应单独验证并更新锁文件。
