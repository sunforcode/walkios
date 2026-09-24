# 重构前现状调研

调研日期：2026-09-24；工作树快照记录时间为 17:49（Asia/Shanghai）。对象：当前工作树，分支 `main`，HEAD `d6654ec`。依据：[架构基准与重构规范](../specs/README.md#重构规范与约束)。本文是现状证据，不修改目标规范，也不表示已执行代码重构。

## 结论

App → Feature → Service → APIClient 的主干已实际存在。当前最集中的重构工作是数据策略、最终配置与身份装配、调试能力独立化；页面侧主要是少数合同与组件的归属整理。

实施起点还需要处理两类基线问题：部分本地构建输入被 Git 忽略，不能直接把本机工作树当作可复现代码基线；测试证据需要区分历史结果、当前脚本结果和未注册草稿。此次没有重新构建 App，没有修复这些问题。

## 1. 工作树与改动来源

调研开始时有 **17 个已跟踪文件修改、7 个未跟踪文件**。未跟踪不等于未加入 Xcode 工程：几个页面文件已经登记，而两个新测试文件尚未登记。

| 分类 | 当前文件范围 | 如何看待 |
|---|---|---|
| 调研前已有页面与工程改动 | ModalBottomSheet；路线分页和详情文件拆分；对应结构测试；手写 Debug 环境页面及 App/Profile 导航连接；project.yml 与生成工程 | 保留现场，后续整理不能覆盖。包括 iOS 最低版本调整至 18.0、Release 服务地址配置等既有修改。 |
| 此前未完成的数据层草稿 | APIClient、AlamofireRemoteAPIClient、AuthManager；AppEnvironmentTests 新增两例；AuthConfigurationTests 与 DebugDataAccessTests | 草稿接口存在，但新模式没有接入 App。不能算作三模式或身份隔离已完成。 |
| 已保存的架构材料 | README、specs/README、architecture-review-20260924.md | 是目标与调研记录，不是实现完成证据；新增规范表与旧登记脚本存在兼容问题，见第 5 节。 |

当前生产 App target 有 106 个 Swift 文件，均已登记在生成工程。五个业务域目录合计 87 个 Swift 文件，另有 1 个 Shared 文件；App 与 Feature 仍在同一个 target。两个本地基础 Package 为 WalkData、WalkDesignSystem。

## 2. 数据、配置与调试能力

| 方面 | 当前真实状态 | 对照规范的工作 |
|---|---|---|
| 数据装配 | [AppEnvironment](../Walk/App/AppEnvironment.swift) 按 `remote / local / mock` 创建客户端，注入五类 Service | 装配为 `mock / real / remoteOnly`；保持业务 Service 入口稳定。 |
| 远端与缓存 | remote 请求网络，按端点资格保存成功响应；[LocalAPIClient](../Packages/WalkData/Sources/WalkData/Sources/LocalAPIClient.swift) 独立读取快照 | 尚无真实客户端中的断网策略。独立 local 不是网络失败回退。 |
| 缓存保存资格 | APIRequest 显式 `.store` 共 17 处，均为 GET；其中 15 处在当前五域请求，2 处在旧请求类型 | 现有保存资格不能视为允许离线返回；逐项登记读取资格与规则。 |
| 策略与元数据 | [APIClient](../Packages/WalkData/Sources/WalkData/Network/APIClient.swift) 直接返回类型化 Response；存储为原始 Data | 没有 OfflinePolicy、有效期、离线资格、结果来源与保存时间等完整语义。 |
| 错误分类 | HTTP 状态码与业务错误部分类型化；传输错误最终压成 `.transport(String)` | 断网策略需要稳定的结构化原因，不能根据本地化文案或业务 `retryable` 判断是否返回缓存。 |
| remoteOnly 草稿 | 存在 `APIResponseCachePolicy.disabled` 和远端客户端禁缓存参数 | [AppEnvironment](../Walk/App/AppEnvironment.swift) 没有传入该参数；不能从 App 选择 remoteOnly。 |
| 配置解析 | [AppConfiguration](../Walk/App/AppConfiguration.swift) 仍识别旧参数；顺序是命令行 > 持久 Debug > 环境变量 > Info | 新规范需要独立的数据模式/服务器/执行上下文及新的优先级。`-WalkDataMode` 测试存在，解析尚未实现。 |
| 认证装配 | AppEnvironment 使用 `AuthManager.shared`；shared 自行从环境变量和 Info 再次选择 token 槽位 | 需要由最终配置统一注入；当前无法保证与命令行或 Debug 选择一致。显式命名空间初始化器仅是草稿能力。 |
| 缓存隔离 | [APIStorage](../Packages/WalkData/Sources/WalkData/Persistence/APIStorage.swift) 已有 schema、环境名、会话身份和请求键；有写入世代机制 | 缺少 baseURL 服务身份、完整缓存有效性及统一生命周期失效策略，不能因局部保护存在就认定已满足新规则。 |
| Debug | [DebugEnvironment](../Walk/App/DebugEnvironment.swift) 与 Profile 调试页提供 `mock / testServer / production`，重启生效 | 尚无 DebugSwift 或独立 DebugTools。两种服务器预设目前使用同一 URL；名称不证明存在两套部署。 |

已有可复用基础包括：类型化 APIRequest/APIClient、业务 Service、可注入的网络和存储、独立 Mock、原子文件存储、环境/身份分区及部分世代保护。后续应在这些基础上补齐，不需要全部替换。

当前落盘路径没有检查响应的 HTTP 缓存控制指令；写入世代主要保护缓存回填，尚无统一的修改后失效与旧结果发布拦截。这些属于 W1 需要完善的策略和生命周期边界。

## 3. 页面与基建的最小整理单位

| 位置 | 当前事实 | 最小整理方向 |
|---|---|---|
| [RootNavigation](../Walk/App/RootNavigation.swift) | 导航意图合同与根导航、UIKit 外观、部分页面样式同文件；Feature 消费这些合同 | 提取纯合同与页面专属样式，保留现有导航机制。使用导航合同本身不是违规。 |
| [DebugEnvironmentView](../Walk/Features/Profile/DebugEnvironmentView.swift) | 位于 Profile，直接读写 App 的 DebugEnvironment | 调试页面、状态和配置动作整体归 DebugTools，App 注入状态与回调。 |
| [CreateTripView](../Walk/Features/Trips/CreateTripView.swift) | 消费 Routes 下四个生成组件及路线 VM 文件中的资格展示类型 | 生成组件按实际生产消费者归 Trips；共享资格展示转换从具体 VM 文件独立出来。 |
| [ProfileView](../Walk/Features/Profile/ProfileView.swift) 与 [ProfileViewModel](../Walk/Features/Profile/ProfileViewModel.swift) | 消费 Trips 的日历组件；VM 读取具体日历 View 的常量 | 日历组件、投影及展示约束作为一组整理归属，解除 VM 对具体 View 常量的依赖。 |
| [SharedPrimitives](../Packages/WalkDesignSystem/Sources/WalkDesignSystem/Components/SharedPrimitives.swift) | 混有我的页专属背景构图 | 页面专属构图归 Feature，保留通用 Token 和 UI 能力。不能仅因名称含业务词就判定整个组件违规。 |
| [LocationService](../Walk/Support/LocationService.swift) | 有定位、轨迹采集实现，未发现生产源码中的外部消费者 | 登记为存在但未接入；本轮整理不自动新增定位流程。 |

WalkDesignSystem 当前没有 WalkData Package 依赖；Service 没有 UI 依赖。这些良好边界应保留。上表主要影响职责归属与以后独立编译，不代表页面当前一定存在运行故障。

## 4. 工程输入与测试注册

环境为 Xcode 26.5（17F42）、XcodeGen 2.46.0，工程当前最低 iOS 18.0。`Walk.xcodeproj/project.pbxproj` 的 plist 格式检查通过；本轮没有运行 XcodeGen。

### 本地构建输入与版本控制不一致

[.gitignore](../.gitignore) 第 38–40 行忽略整个 Packages、Package.resolved 和 .swiftpm-packages。已经跟踪的源码仍在 Git 中，但下列必要输入目前未被跟踪：

- [WalkData/Package.swift](../Packages/WalkData/Package.swift)、[WalkDesignSystem/Package.swift](../Packages/WalkDesignSystem/Package.swift)。
- [TripEquipmentModels.swift](../Packages/WalkData/Sources/WalkData/API/Trips/TripEquipmentModels.swift)。
- [ComponentPreviewFixtures.swift](../Packages/WalkDesignSystem/Sources/WalkDesignSystem/ComponentPreviewFixtures.swift)、[MetricPreviewFixtures.swift](../Packages/WalkDesignSystem/Sources/WalkDesignSystem/Components/MetricPreviewFixtures.swift)。

[project.yml](../project.yml) 还使用 `.swiftpm-packages/checkouts/Alamofire` 与 `lottie-ios` 本地路径，两者当前在磁盘存在但未被版本控制。所检查的 README 和 scripts 中未发现还原这些输入的流程。因此，本机历史构建成功不能证明仅检出当前受版本控制内容即可复现。此结论来自文件与配置对账，本轮没有执行干净检出构建。

### 文件是否登记必须单独判断

- Walk 的 106 个 Swift 源文件均已登记。
- WalkTests 已登记 15 个测试文件，缺少 [AuthConfigurationTests](../Walk/Tests/NetworkTests/AuthConfigurationTests.swift) 和 [DebugDataAccessTests](../Walk/Tests/NetworkTests/DebugDataAccessTests.swift)，各含 4 个测试。
- AppEnvironmentTests 已登记，其中新增的两个新模式用例仍是待实现草稿。
- DebugEnvironment、DebugEnvironmentView、RouteDetailViewSupport、RouteDiscoveryPagerStructureTests 虽是 Git 未跟踪文件，却已登记在 pbxproj。
- 另外四个测试 target 的源码登记未发现缺项。DebugSwift 不在当前 Package 或 target 依赖中；不能检查一个尚未接入 SDK 的 Release 产物来证明未来隔离方案已完成。

两份本地 Package manifest 目前没有独立 testTarget，数据层和设计系统的相关 XCTest 依赖 App 工程运行。

## 5. 新鲜检查与历史证据

| 检查 | 证据时间 | 结果与边界 |
|---|---|---|
| `git diff --check` | 本轮 | 通过；只检查变更格式。 |
| pbxproj plist 格式 | 本轮 | 通过；不等于编译成功。 |
| `test_compare_ui_baseline.py` | 本轮 | 9 项通过；这是对比工具测试，不是当前页面视觉验收。 |
| `test_platform_spec_registry.py` | 本轮 | 4 项中 2 项失败，失败首先来自架构表被误识别为 UI 登记。 |
| WalkTests xcresult | 2026-09-23 20:40:30–20:41:17 +0800 | 构建成功，330 项中 322 通过、7 失败、1 跳过；不是当前所有草稿修改后的新构建证据。 |
| 此前新模式红测日志 | 本轮检查文件是否存在 | `/tmp/walk-debug-modes-red.log` 已不存在，因此不把之前对话中的结果当作本轮可重新核验的证据。 |

历史 xcresult 位于 [build/status-check-20260923/WalkTests.xcresult](../build/status-check-20260923/WalkTests.xcresult)，测试设备为 iPhone 17 Pro / iOS 26.5。7 项历史失败集中在 RouteDetail 源码结构断言（DesignSystemTests 5 项、RouteDetailViewModelTests 2 项），应与真实行为回归区分。跳过的是需要显式开启的真实后端行程流程测试。该结果不覆盖 Release、Baseline/Component 测试组，或后来新增的模式、认证和禁缓存测试。

### 登记测试的两层问题

1. **本次会话此前新增文档造成的兼容问题**：测试扫描 specs/README 的所有表格，把 `mock / real / remoteOnly` 等架构条目当作 Page/Component ID，并把用途文案当成源码路径。因此当前首先出现重复 ID 和源码不存在失败。需要使登记解析范围与实际登记区一致；本轮只记录，没有修改测试或文档表格。
2. **原有映射问题**：只检查 Page/Component 登记区，或检查 HEAD 中的登记内容，仍可确认缺少 `daily-weather-summary-row`；`page-shell`、`trip-route-version-card` 已不在上游对象集合中，且登记的 TripRouteVersionCard.swift 不存在。这些与新模式表无关，不能被新的解析失败掩盖。

轻量检查日志保存于本机 `/private/tmp/walk-current-state-platform-20260924.log` 与 `/private/tmp/walk-current-state-baseline-tools-20260924.log`；它们是临时证据，不是长期归档。

## 6. 本轮边界与后续起点

调研开始时磁盘可用空间约 431 MiB。本轮未启动新的 Xcode 构建、模拟器测试或 SDK 下载，也未清理用户文件。仅运行两组轻量脚本测试，临时测试产物由测试自身清理。

当前先后关系建议为：

1. 保留并分类当前工作树，补齐构建输入、测试注册与文档登记检查之间的基线问题。
2. 在具备足够磁盘空间后获取当前工作树的新构建/测试结果，区分已有失败与新增失败；DebugSwift 构建隔离方案仍需单独验证。
3. 进入数据策略与最终配置装配，再接入 DebugTools。
4. 按上文列出的最小单位整理导航合同、组件与样式归属。

本轮只新增这份调查报告，既有源码、工程、测试和规范保持原样。完成的是现状调查与部分轻量基线核对，不能据此将 W0 的全部构建、运行与 SDK 隔离验证标记完成。
