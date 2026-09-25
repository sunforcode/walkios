# W3 DebugTools 接入：实施结果

日期：2026-09-25
范围：`specs/README.md` 重构工作拆分 W3（DebugTools 接入）
承接：W0（DebugSwift 最小宿主与隔离验证）、W2（App 配置与依赖装配）

## 结论

DebugSwift 1.19.0 已接入正式 App，只存在于开发依赖图中。Debug 构建中摇一摇即可打开面板，面板里查看和修改配置都通过 W2 建立的同一套配置入口。Release 走独立的生产依赖图出包，产物隔离检查的 13 项全部通过；另外做了一次反向校验，把 Debug 产物当作 Release 送检，检查准确报出了 6 项违规。

用户对本批的三项决定：用摇一摇打开面板；Release 不出现任何调试能力；网络观察这一批先关闭。

## 工程结构

`project.yml` 拆成三个文件：

| 文件 | 作用 |
| --- | --- |
| `project-base.yml` | 共用模板，包含全部 target 与共用设置，不直接生成工程 |
| `project.yml` | 开发依赖图。只有 Debug 配置，为 `Walk` 和 `WalkTests` 增加 `WalkDebugTools` 依赖，新增 `WalkDebugToolsUITests` target 和 `WalkDebugTools` scheme。生成仓内的 `Walk.xcodeproj` |
| `project-release.yml` | 生产依赖图。只有 Release 配置，不声明任何调试依赖；关闭 `ENABLE_DEBUG_DYLIB` 并生成 link map，让检查覆盖真正承载代码的二进制。只经 `scripts/build.py` 生成 `WalkRelease.xcodeproj`，该工程已加入 gitignore |

开发图中所有 scheme 的 run、test、profile、analyze、archive 五个 action 都显式指定为 Debug，避开 W0 发现的 XcodeGen 缺省 action 问题。

依赖锁定：`Package.resolved` 新增 DebugSwift 1.19.0，revision 为 `b85fd86581bc1b67710be82249d8aac2ef61b2f5`，与 W0 验证的版本一致。解析时 github.com 曾暂时连不上，于是先按 W0 的已验证 pin 写入锁文件，再用 `-onlyUsePackageVersionsFromResolvedFile` 解析，最终 6 个包全部解析到锁定版本。生产锁文件由入口从开发锁文件派生，去掉 DebugSwift。

## 切片与证据

### 1. WalkDebugTools 适配层

新增 `Packages/WalkDebugTools`，是唯一 import DebugSwift 的地方。它对外只提供 `DebugInfoSection`、`DebugActionSection`、`configure(info:actions:)` 和 `makeViewController()`；不依赖 WalkData、WalkDesignSystem 或 App，也不持有配置。信息和动作每次打开面板时由 App 注入的闭包重新生成。SDK 的 network、performance、interface、resources 四个分组全部隐藏，所有 swizzle 钩子关闭，只保留 App 分组。

### 2. 调试面板模型

`Walk/App/Debug/DebugPanelModel.swift`：

- **信息**：「当前生效」显示本次启动的数据模式、服务器和断网策略；「重启后生效」只列出保存值与生效值不同的维度。选择 `useCache` 时会注明「当前无端点登记离线资格，行为同 fail」。
- **动作**：数据模式、服务器、断网策略三组动作各自只改自己那个维度，其余维度保留已保存的值。维护组提供清除响应缓存（交给数据层执行）和恢复构建默认值（清空设置记录）。
- 所有动作都只写 `DebugSettingsStore`，不改变本次启动的有效配置（R-SWITCH）。

`DebugPanelModelTests` 9 项通过。

### 3. 摇一摇入口

`Walk/App/Debug/DebugShakeEntry.swift`：覆写 `UIWindow.motionEnded`，把摇动事件转成通知，由挂在 App 根部的 modifier 以 sheet 呈现 SDK 面板。入口只挂在正常运行的 `RootView` 分支上，Baseline 和组件预览不加载调试 SDK，截图结果保持确定。不需要登录。

删除了 Feature 侧的旧入口：`DebugEnvironmentView`、账户菜单里的「开发者」分组，以及 `AppDestination.debugEnvironment`。

新增 `DebugToolsBoundaryTests`（5 项）强制以下边界：Feature 不得 import 调试工具；WalkData 和 WalkDesignSystem 的源码与 manifest 不得引用调试工具；App 只能经 WalkDebugTools 使用 SDK；调试入口不得作为 Feature 目的地；生产图和共用模板不得声明调试依赖。红测按预期在 `AccountMenuView` 和 `AppDestination` 两处失败。

**UI 链路验证**：`WalkDebugToolsUITests` 通过。XCUITest 没法合成摇动事件，所以用启动参数 `-WalkSimulateShake` 发出和 `motionEnded` 相同的通知，只替换事件来源。用例覆盖的链路是：面板出现 → App 分组 →「当前生效」显示 `mock` → 执行「数据模式 / remoteOnly」动作 → 刷新 →「重启后生效」显示 `remoteOnly` → 恢复构建默认值。截图保存在 `build/w1-20260925/DebugToolsUI-3.xcresult`。

过程中碰到两个 SDK 的实际行为：App 分组以每个自定义分组的标题作为一行，而不是一个叫「Custom Info」的入口；App 列表不会在返回时自动刷新，要点导航栏的刷新按钮。这两点都是先读 SDK 源码确认后才改的用例，没有继续靠猜。

### 4. 断网策略接入配置

`DebugSettings` 增加可选的 `offlinePolicy` 字段，没有这个字段的旧记录仍然能读。`AppConfiguration` 新增启动参数 `-WalkOfflinePolicy` 和环境变量 `WALK_OFFLINE_POLICY`，优先级与其他维度一致；构建配置不承载这一项。自动化上下文忽略个人设置，Release 固定为 `fail`。`OfflinePolicy` 改为带字符串原始值。

`OfflinePolicyConfigurationTests` 7 项通过。

### 5. 受限构建入口与产物检查

`scripts/build.py` 在创建目录、写文件或启动任何工具之前完成全部参数校验：

- debug 模式拒绝 archive，也拒绝 `--configuration Release`；
- release 模式拒绝 test，也不能自选 scheme；
- test 必须提供 destination，archive 只接受 `generic/platform=iOS`；
- 不接受任意 xcodebuild 参数透传。

release 模式每次都会删掉并重新生成 `WalkRelease.xcodeproj`，派生生产锁文件，构建完成后自动运行 `check_debugswift_isolation.py`；检查失败时入口返回非零。

`test_build_entry.py` 5 项通过，其中一项覆盖 12 种非法调用，确认它们都在任何文件或子进程操作之前以返回码 2 退出。

入口第一次 archive 失败了，原因是 XcodeGen 的 `--project-root` 让 `Info.plist` 的路径按输出目录去解析。改为在仓库根目录生成生产工程（已加入 gitignore）后通过。

## Release 隔离证据

生产归档：`build/walk-build/Runs/release-archive-20260925T064305.256332Z/`，报告为 `isolation-report.json`。

| 检查 | 结果 |
| --- | --- |
| 工程依赖引用 | 无 |
| DebugSwift / WalkDebugTools 编译任务 | 0 / 0 |
| 链接记录 | 覆盖主可执行文件 `Walk`，不含两个模块 |
| 二进制符号 | 0 / 0 |
| 动态依赖 | 无 |
| 资源 bundle | 无 |
| Info.plist | `WalkDataMode=real`、`WalkEnvironment=production` |
| App 调试字符串 | `walkDeviceDidShake`、`WalkSimulateShake`、`walk.debug.settings`、`DebugPanelModel` 均为 0 |

**反向校验**：把入口生成的全新 Debug 构建当作 Release 送检，检查失败并报出 6 项：工程依赖引用、编译任务（DebugSwift 612 个、WalkDebugTools 8 个）、链接记录、link map 内容、符号（DebugSwift 66265 个、WalkDebugTools 366 个）、资源 bundle。Debug 产物中 SDK 实际链接在 `Walk.debug.dylib` 里，这正是 W0 提醒过的结构；生产图关闭 `ENABLE_DEBUG_DYLIB` 后，检查覆盖的就是真正承载代码的二进制。报告保存在 `build/w3-reject-debug-as-release.json`。

## 验证汇总

环境：iPhone 17 Pro 模拟器 `D48F449A-B85E-4E73-BE25-C8BF6A4BDE44`。

| 项目 | 结果 |
| --- | --- |
| WalkTests（经 build.py） | 435 项，0 失败，1 跳过（需要真实后端，与此前各批一致） |
| WalkBaseline（经 build.py） | 通过 |
| WalkDebugToolsUITests | 通过 |
| 生产归档与隔离检查 | 13 项全部通过 |
| 反向校验 | 按预期失败，报出 6 项违规 |
| `test_build_entry.py` | 5 项通过 |
| `test_debugswift_probe_entry.py`、`test_compare_ui_baseline.py` | 通过 |
| `test_platform_spec_registry.py` | 通过（本记录写入后复跑） |

WalkComponents 组本批没有重跑。W1 记录的 `DailyWeatherSummaryRow` UI 登记缺口仍然存在，与本批无关。

## 使用方式的变化

- **Xcode 中不能再对仓内工程选 Release 或 Archive**，开发工程只有 Debug 配置。出包使用 `python3 scripts/build.py --mode release --action archive`。归档不签名，签名和分发尚未纳入入口。
- **调试入口从账户菜单移到了摇一摇**，不需要登录。模拟器上使用 Device → Shake。
- 仍然无法阻止有人绕过入口直接对开发工程执行 `xcodebuild -configuration Release`，W0 已经证明单配置工程拦不住这种调用。发布产物以入口生成的隔离报告为准。

## 未决与后续

- SDK 网络观察保持关闭。开启前需要按 R-DEBUG 证明它不改变请求、缓存、认证和取消的行为。
- 离线返回能力仍然没有任何生产端点启用。
- 签名、TestFlight 和 App Store 分发不在入口范围内。
- `DailyWeatherSummaryRow` 的 UI 登记缺口需要走根仓 Change。

## 下一批

W4 整理 App / Feature / Service：RootView、RootNavigation、五个 Feature 以及业务 Service 的职责连接，按代表链路逐个业务域整理并验证。
