# Walk iOS 平台规范

本目录是 Walk 总规范在 iOS 上的**唯一平台规范入口**，只记录承载方式与实现差距，不记录产品事实。

## 上游权威

按以下顺序读取根协调仓 `walk/` 中的总规范（相对本文件解析）：

1. [总规范入口](../../docs/README.md) 与 [PRD](../../docs/prd.md)；
2. [平台无关行为 Spec](../../openspec/specs/)；
3. [Data](../../docs/data/)、[API](../../docs/api/)、[UI](../../docs/ui/index.md)。

本目录不是独立产品事实来源。总规范与本目录冲突时，总规范优先。

## 平台编写标准

[SwiftUI 编写标准](./swiftui-coding.md)定义 View／State 职责拆分、状态所有权与修改入口、文件共置及公共基础层复用方式，细化本文件的 R-DEP。该标准已批准；存量代码迁移需另行批准和验证，不代表现有实现已全部符合。本文件继续作为唯一平台规范入口。

## 可以定义

- Data 到 Swift Model、API 到客户端请求/响应/错误模型的映射规则；
- Page、Component、Token 到 SwiftUI 的承载映射；
- iOS 导航承载、生命周期、系统权限与平台适配（Dynamic Type、VoiceOver、安全区）；
- fixture、测试入口、验证方法和当前实现差距。

## 不得定义

- 新的产品范围、业务行为、数据事实、枚举或 API 字段；
- 总 UI 中不存在的页面、组件、文案或可见状态；
- 与总规范不同的资格、状态流转或错误语义；
- 用默认值、Mock、兼容分支或现有代码反向补齐总规范。

总规范缺少 iOS 实现所需决策时，停止端内扩展，回到根仓 `docs/` 或 `openspec/` 的正确权威层提出变更。

## 登记规则

- 每个总 UI Page ID 和 Component ID 在本文件中有且仅有两种状态：**已映射**（指向当前生产承载源码）或**缺口**（登记为后续 Change 的输入）；
- 已映射只表示源码存在可确认的命名承载，不表示已通过内容符合性验收；近似实现不得冒充符合；
- 登记完整性由 [scripts/tests/test_platform_spec_registry.py](../scripts/tests/test_platform_spec_registry.py) 强制，不依赖手工维护的诚实；
- 缺口只能通过总规范批准的 Change 补齐，不得在本文件中把差距改写成总规范。

## 装备 Data 层承接

本批承接总仓已批准 Change `define-equipment-catalog`、`define-equipment-classification-standard`、`extend-equipment-preparation-api`，消费者为 `WalkData`。上游行为引用 [equipment-catalog](../../openspec/specs/equipment-catalog/spec.md)、[personal-equipment](../../openspec/specs/personal-equipment/spec.md)、[trip-equipment](../../openspec/specs/trip-equipment/spec.md)，值与关系引用 [equipment-schema](../../docs/data/equipment-schema.md) 和 [equipment-relations](../../docs/data/equipment-relations.md)。

| 上游 API 权威 | Swift 承载 |
|---|---|
| [equipment-catalog-api](../../docs/api/equipment-catalog-api.md) | `EquipmentCatalogModels.swift`、`EquipmentCatalogAPI`、`EquipmentCatalogService` |
| [personal-equipment-api](../../docs/api/personal-equipment-api.md) | `EquipmentModels.swift`、`PersonalEquipmentAPI`、`EquipmentListAPI`、`EquipmentService` |
| [trip-equipment-api](../../docs/api/trip-equipment-api.md) | `TripEquipmentModels.swift`、`TripEquipmentPreparationModels.swift`、`TripEquipmentAPI`、`TripEquipmentService` |

- 重量承载使用 `Double`，旧整数 convenience initializer / Service 入口保留；完整配置写入通过类型化 request DTO。已有组件 Projection 仅作数值类型兼容。
- nullable PATCH 使用 `.unchanged / .value / .clear` 表达省略、写入与清空；目录详情按装备类型解码具体规格。
- 请求复用 `APIRequest → APIClient`。动态身份由 `APIPathSegment` 编码；`pathIsPercentEncoded` 防止 HTTP 层重复转义。装备查询的字面加号使用 `%2B`。
- 本次调用的版本头由请求对象携带，远端成功响应由端点 `validateResponse` 校验；不保留全局“最后 ETag”，不在重试时重建幂等键。
- 新接口无离线返回资格，准备结果保留服务器投影。页面新功能与表单完整配置接线不属于本批 Data 层交付。

独立接口测试入口：`swift test --package-path Packages/WalkData`。Package 的 macOS 最低版本声明用于本机运行数据层测试，不新增 App 平台。`Packages/WalkData/Tests/WalkDataTests` 覆盖 DTO、请求合同及注入 `URLProtocol` 的真实 HTTP 客户端；不依赖真实账号或后端在线状态。既有 App 回归继续使用本文件规定的 iOS 模拟器入口。

2026-09-28 验证：先确认小数重量解码、准备字段丢失、身份重复编码及响应版本校验的失败测试，再完成修复。隔离本任务提交树后，WalkData 独立测试 58 项全部通过；`Walk` scheme 在 `iPhone 17 Pro / iOS 26.5` 上的装备 Service、ViewModel、Profile、APIClient 与 TripDataAccess 相关回归执行 88 项，87 项通过、1 项因未启用 `-walkLiveBackendTest` 跳过。该证据覆盖客户端单测与编译，不作为真实后端联调或新增页面验收证据。

## 公共路线详情地图接入

本批承接总仓 Change `replace-route-detail-map-with-mapbox`。行为引用 [route-detail-map-mode](../../openspec/specs/route-detail-map-mode/spec.md)，UI 引用 [RouteMap](../../docs/ui/components/business/components/route-map/spec.md) 与 [PAGE-ROUTE-DETAIL](../../docs/ui/pages/PAGE-ROUTE-DETAIL/spec.md)，坐标引用 [GeoPosition](../../docs/data/domain-value-schema.md)。消费者仅公共路线详情，不修改个人行程图片场景。

- `Packages/MapComponentCore` 承载无 SDK 的地理显示输入；`Packages/OutdoorMap` 承载真实 Mapbox 地图，官方依赖固定 Maps 11.16.0。包不依赖 WalkData、业务 Feature 或 output/Vendor。
- `RouteMapView` 是生产业务地图适配，复用共享 renderer；`RouteMapSceneAdapter` 保留轨迹区间、点位类别和对象身份；`RouteMapCoordinateAdapter` 在 DTO 仍保留参考系时验证，不认识的主路径整体不绘制，不改变服务器资格。海拔 cursor 不是用户 GPS。
- `RouteDetailView` 持有显示选项，继续编排信息面、纯地图、点位详情与曲线。组件目录与共置 Preview 使用同一 `RouteMapView`，合成样例明确标识；原归一化示意 renderer 退役。
- `MapAccessConfiguration` 由 App 一次解析 Bundle 的 `MBXAccessToken` 并调用组件 SDK 配置，Feature 只消费 `routeMapAccessAvailable`。构建设置 `MAPBOX_ACCESS_TOKEN` 由部署方/本地配置提供；源代码与工程只保存占位符，未配置时不创建 SDK 地图。地图瓦片网络独立于 Walk 业务数据模式。
- 验证沿用本文件的构建入口与已批准 iPhone 17 Pro / iOS 26.5 模拟器。Debug 工程使用公开 `Config/MapAccess.xcconfig` 的空值占位与可选、被忽略的 `MapAccess.local.xcconfig`；本机在该 ignored 文件独立保存既有 Mapbox 开发访问配置，不依赖实验目录。Release 由部署方提供同名构建设置，不消费本地 Debug 文件；生产依赖图同样声明共享包，签名、分发和生产配置不属于本批。

2026-10-14 验证：先建立坐标、业务适配及真实 SDK 失败测试，迁入共享实现后，MapComponentCore 35 项通过；独立宿主首次完整回归 22 项通过，离屏点位可访问性修复后的最终 SDK / 定位控制器回归 17 项通过。正式 `Walk` 工程在上述模拟器编译成功；最终单测执行 712 项，711 通过、1 项真实后端用例按配置跳过、0 失败，明确排除以下两个未改动代码中的既有失败：`AppEnvironmentTests/testMockEnvironmentLoadsDefaultPublicRouteFixtures` 的行程 fixture 数量预期，以及 `SecondaryPageShellStructureTests/testEveryPageNamedFileIsRegistered` 的 RouteArtworkView 登记。首轮未排除的完整结果与上述失败均保留在 `build/route-mapbox/Runs/debug-test-20261014T082522.064416Z/Tests.xcresult`；最终结果为 `build/route-mapbox/Unit-final.xcresult`。

正式页面定向 UI 测试 `YadingMockUITests/testRouteDetailTerrainModesKeepMapAndInformationLinks` 通过，覆盖二维、普通/增强三维、卫星往返、纯地图、曲线临时定位、可见点位详情及返回信息面。报告为 `build/route-mapbox/RouteDetailUI-final.xcresult`，已检查的截图位于 `output/verification/route-map-mapbox/`。平台登记 8 项、构建入口 5 项检查通过。业务资料使用 Mock，底图、DEM 与等高线使用在线真实 Mapbox 资源；不作为真实后端、真机 GPS、离线、性能或 Release 分发验证证据。

随后按用户要求退役独立地图 Demo App：删除根仓 `output/NavigationCompare/` 的比较宿主、MapComponentLab、工程及缓存，并卸载已批准模拟器上的对应 App 与测试 runner。共享包源码及测试继续由本仓管理，独立组件体验仍从 DebugPanel 的组件目录进入。实验最终结果、日志与截图迁至 `output/verification/route-map-mapbox/demo-retirement/`，不作为当前可运行宿主。

清理后的正式 Debug 工程增量构建通过（`build/route-mapbox/demo-retirement-build.log`），已确认产物读取独立的本地 Mapbox 配置；平台登记与构建入口共 13 项检查再次通过。

## 四个一级区域承接

本批承接根仓 Change `promote-equipment-and-trips-tabs`，并按纠正 Change `restore-trip-tab-home` 恢复行程根的原首页承载。页面范围与行为引用 [app-flow](../../openspec/specs/app-flow/spec.md)、[account-access](../../openspec/specs/account-access/spec.md) 和 [App Structure](../../docs/ui/app-structure.md)。

- `AppTab` 映射四个区域；`AppShellState` 持有独立 NavigationStack 路径。`RootView` 装配个人区域的游客/会话分支；身份变化时销毁旧个人模型并清除个人导航与版本缓存；被动重认证只暂存当前目标路径，重新授权读取，取消或退出则丢弃。
- `HomeView` 承载 `PAGE-HOME`，由 `AppTab.trips` 作为根页装配；`Home` 是 Feature 代码域，不增加第五个一级区域。`TripListView` 以 UtilityPage 承载二级 `PAGE-TRIPS`，日历由 App 层在来源任务栈推入；列表查找路线继续在当前栈推入。
- 行程根的焦点读取由注入 `PersonalTripServicing` 的 `HomeViewModel` 承载；会话变化交由 App 装配重建或重置。普通认证完成先恢复来源页，焦点加载与重试留在 Home，不进入登录完成流程。
- `EquipmentListView` 的 `.root` 使用 PageShell、根页滚动与 FixedActionArea；`.stack` 使用 UtilityPage 同一生产内容。行程生成与行程装备中的管理往返留在各自来源栈，不切换 Tab。
- 装备概况生产组件 `PersonalEquipmentSummaryCard` 位于 Shared；`ProfileViewModel` 只加载本页账户与日历。登录普通承接不依赖焦点查询。
- `TripEquipmentSession` 在本次认证会话中按 trip ID 复用行程装备模型，页面返回后未确认的选入命令仍可用同一标识重试；普通再进入重新读取，身份变化清空缓存。
- 行程装备写入的版本通知由该会话转发，即使已返回详情仍刷新摘要；会话清空后丢弃旧响应通知。页面少量分区使用普通 VStack，避免延迟分区在滚动与自适应操作区交界反复估算高度。
- `PageShell` 顶部仍固定窗口安全区以抑制转场尖峰；底部由外层 GeometryReader 读取实际系统安全区，固定操作避让 Tab，不写死系统栏高度。
- `TripEquipmentSourcePicker` 通过不可变 Projection 和事件承载个人装备/清单选择；VM 通过 `TripEquipmentPreparing` 使用请求版本与固定幂等键消费完整服务端快照。重量输入保留 Double；只改名称不覆盖参考重量。
- `FocusTripSummary` 与 `WeatherSummary` 恢复在 Home 域的生产组件承载；Page、共置 Preview 与 Debug 组件目录使用同一实现。共享焦点 DTO、API 与业务算法保持原合同。

2026-09-28 `promote-equipment-and-trips-tabs` 验证：`Walk` scheme 在 `iPhone 17 Pro / iOS 26.5` 上执行 571 项，570 通过、1 项因未启用真实后端测试跳过；包含导航、认证、装备基础管理、26 项行程选入测试及 3 项会话延迟完成测试。WalkData 独立测试 70 项通过，平台映射结构测试 8 项通过。`WalkKeyFlows/FourTabEquipmentUITests` 的游客导航与取消登录、装备新增/选入/追加/管理往返、生产来源选择组件独立展示共 3 项通过；截图经人工检查，UI 使用默认 Mock 场景和同一生产页面，不作为真实后端联调证据。

2026-09-28 `restore-trip-tab-home` 验证：`Walk` scheme 在上述模拟器执行 594 项，593 通过、1 项真实后端用例按配置跳过；包含 Home 的 19 项状态、取消与身份隔离测试。平台映射结构检查 8 项通过。四 Tab UI 的装备准备往返、游客导航、来源选择组件、两个首页组件独立展示通过；首页登录/焦点详情/我的日历二级列表往返首轮暴露整页手势合并游客按钮点击区域的问题，限定手势仅在焦点态启用后，该用例重跑通过且全量单测再次通过。原首页游客/焦点、二级列表、独立组件截图已检查。UI 使用默认 Mock 和生产实现，不作为真实后端联调证据；日志为 `/tmp/walk-restore-home-unit-final.log`、`/tmp/walk-restore-home-ui.log` 与 `/tmp/walk-restore-home-navigation-green.log`。

同批 `WalkComponents/WalkComponentTests` 4 项通过，校验当前 81 项组件目录、分类、default 构造和预览参数；日志 `/tmp/walk-restore-home-components.log`。

2026-09-28 装备新增入口修复：承接 `PAGE-MY-EQUIPMENT` 的固定新增操作与 `personal-equipment` 的个人装备管理合同，修复初次列表读取中或失败时错误隐藏新增入口的映射。可见性由 `EquipmentListState` 统一计算，装备分段不依赖集合读取；清单分段与游客承载保持既有规则。最小回归先复现两个失败，修复后装备状态、编辑与页面结构相关单测 41 项通过，平台映射 8 项通过；模拟器生产页面的新增保存/行程选入/追加清单/管理往返及游客登录取消共 2 项 UI 测试通过。加载和失败状态的入口条件由单测验证，UI 新增链路使用默认 Mock；未作真实后端写入。日志 `/tmp/walk-equipment-add-entry-red.log`、`/tmp/walk-equipment-add-entry-green.log`、`/tmp/walk-equipment-add-entry-ui.log`。不改 Data/API 或共享页面壳。

同日补测 `FourTabEquipmentUITests/testEquipmentListCanRenameAndEditMembers` 通过：生产装备页的清单重命名、添加成员、修改数量、移除成员，以及折叠后重新展开读取结果；默认 Mock 数据、上述模拟器，日志 `/tmp/walk-equipment-list-edit-ui.log`。此次只补 UI 回归证据，清单仍按既有合同页内编辑。

本批承接根仓 Change `add-equipment-classification-selectors`，按 [PersonalEquipmentForm](../../docs/ui/components/business/components/personal-equipment-form/spec.md) 与 [PAGE-EQUIPMENT-EDIT](../../docs/ui/pages/PAGE-EQUIPMENT-EDIT/spec.md) 接入分类/类型选择。`EquipmentClassificationOptions` 将 [EquipmentCategory / CatalogEquipmentType](../../docs/data/equipment-schema.md) 登记映射为已有 WalkData 枚举的中文显示与候选；Page 向表单 Projection 传入选择和候选，生产 `SelectInput` 承载菜单单选。`EquipmentEditDraft` 保存选择，ViewModel 处理联动、dirty、请求映射和参考重量确认；现有 Service/DTO 承接字段，不新增数据访问分支。组件共置样例与 Debug 目录登记选择及参考重量提示状态，页面与独立展示复用生产实现。

2026-09-28 本批先确认缺少分类选择框的 UI 失败，再完成实现。既定 iPhone 17 Pro / iOS 26.5 上 `Walk` 单测 615 项（614 通过、1 在线 opt-in 跳过），`WalkComponents` 6 项、定向 `WalkKeyFlows` 3 项全部通过；`WalkData` 装备 API 合同 29 项、平台登记检查 8 项通过。UI 覆盖背包/睡袋新增保存与编辑回显、表单独立状态、重量小数输入及行程选入回归，截图已查看。证据为 `/tmp/walk-equipment-selectors-{unit,api,ui-green,component}.log` 与 `/tmp/walk-equipment-selectors-attachments/`；红测试为 `/tmp/walk-equipment-selectors-ui-red.log`。未验证真实后端写入或其他设备。

## 行程详情 AIGC 视觉承接

### 紧凑 Timeline 与场景叠层精简

2026-10-08 承接根仓 `define-compact-timeline-hierarchy` 与 `simplify-trip-detail-overlays`。权威为 [Timeline](../../docs/ui/components/common/timeline/spec.md)、[PAGE-TRIP-DETAIL](../../docs/ui/pages/PAGE-TRIP-DETAIL/spec.md)、[TripExpeditionScene](../../docs/ui/components/business/components/trip-expedition-scene/spec.md) 与 [app-flow](../../openspec/specs/app-flow/spec.md) 对应 Requirement。`TimelineSummaryContent` 是通用Timeline内部两层内容承载，不新增Component ID；Page只传标题与可选副标题并拥有区域尺寸。摘要投影与完整每日投影分离，不改原DTO或来源。场景不绘制角标/提醒，但保留可访问艺术语义和已有非空提醒样例作为反证。图片、安全区与日期导航沿用单图批次。

本轮先记录界面精简结构测试失败，再实施；独立复核发现端点同名和交通地点的限定遗漏，补2项失败回归并修正。最终在iPhone17Pro/iOS26.5模拟器上66项定向单测、4项UITest通过，涵盖正式全程/五日、切日与每日详情返回、Timeline七态和场景六态。证据位于 `output/compact-trip-timeline/UnitFinal.xcresult`、`Component.xcresult`、`UIFinal.xcresult`、`final-shots/` 与 `component-shots/`，截图已查看。66%宽按正式页实际frame验证，约200pt含标题按结构与实际截图核验，不以AX联合内容范围代替可见裁切范围。保留输入真实长名称，不截取攻略造短名；来源数据不变。该证据不代表真实服务、真机、全仓回归或发布通过。

### 单张满屏场景承接

2026-10-07 承接根仓 Change `use-single-fullscreen-trip-artwork`，UI 权威引用 [PAGE-TRIP-DETAIL](../../docs/ui/pages/PAGE-TRIP-DETAIL/spec.md) 与 [TripExpeditionScene](../../docs/ui/components/business/components/trip-expedition-scene/spec.md)。平台将同一生产 Scene 的艺术子层用于全屏背景，前景继续承载海拔、提醒和既有手势；`TripDetailView` 不自行复制图片加载与坐标映射。仅艺术背景忽略系统安全区，安全内容沿用现有 SwiftUI 承载并按实际内容画布裁切；Debug 目录与共置 Preview 不再额外绘制森林图。图片资源与数据投影不变，本地/远程图片共用 aspect-fill 几何，人工标注限于场景与正文可视范围交集。

本轮 iPhone 17 Pro / iOS 26.5 定向回归58项通过；正式行程六态UITest与独立组件六态UITest各1项通过，截图已检查。证据位于 `output/single-fullscreen-trip-artwork/UnitFinal.xcresult`、`UIVerified.xcresult`、`Component.xcresult` 与 `verified-shots/`。底部截图与源图差分核实所采样区域没有前景字形残留，AX滚动容器的逻辑范围不作为裁切后的可见范围。该证据限定本机模拟器和Mock样例，不代表真实服务、其他机型、全仓回归或发布验证；下方历史记录不充当本次验收。

### 亚丁五日 Mock 素材与样例

2026-09-29 按用户要求增加本地亚丁五日样例，承接下述既有行程/路线合同与场景组件，不改变共享 DTO 或真实服务。`route-yading-5d` / `route-yading-5d-v1` 与 `trip-yading-5d` 使用独立样例身份；既有贡嘎与长海子样例保留。样例来源为已核对的亚丁 KMZ、主轨迹与五日分段，出行日期为演示条件，天气缺失不补造预报。

`YadingMockScene` 在显式 Mock 上下文、路线版本、行程和五个自然日身份均匹配时选择 `YadingSceneOverview` 与 `YadingSceneDay1…5`。每天的徒步路径必须是冻结主路径的完整连续子序列，海拔样本与主路径逐点对应后才切片归零；首日曲线从圣水门后的徒步段开始，不把前段电瓶车接驳算作徒步。艺术图没有地理标定。按根仓 `annotate-yading-offline-mock` 与 `TripExpeditionScene` 合同，亚丁新增独立人工画面节点，沿用贡嘎同一生产叠加渲染器，节点文字源于该样例已有起讫与关键点；不复用贡嘎节点或宣称地理精度。完整冻结轨迹指纹、分日路径和所展示关键点匹配后才启用，失配时不套用。Mock跳过独立远程场景读取，本地底图和矢量叠加可离线显示；不改变真实服务数据模式。无可信对应时保持原缺失表达。

路线图片由 `RouteArtworkView` 解析六个明确的 `asset://` 本地素材引用；发现、全部、搜索与图库复用同一加载节点，远程图片继续使用 HTTP(S)。本地素材是场景插画，真实路线仍通过主轨迹和参考分日地图显示。验证入口为 `YadingMockPresentationTests`、`RouteArtworkSourceTests`、WalkData 的 `YadingMockFixtureTests` 与 `YadingMockUITests`。

本批验证：WalkData 82 项通过；iOS 定向单测 190 项，189 通过、1 项真实后端 opt-in 跳过；平台登记检查 8 项通过。iPhone 17 Pro / iOS 26.5 的亚丁 UI 全链路通过，覆盖路线入口、地图、五日场景、重复选日、滑动、日详情返回、天气及装备；最终截图已检查。证据见 `output/verification/yading-mock/README.md`。未执行真实后端写入。

2026-09-30 `annotate-yading-offline-mock` 验证：先复现旧亚丁缺少标注及来源失配仍复用的问题；新增映射后，亚丁、贡嘎投影及remote隔离定向50项单测通过。上述模拟器的 `YadingMockUITests/testYadingOverviewAndFiveDaysLocalOverlayVisualReview` 经正式我的/日历入口及无效API域名Mock配置完成六态，1项UITest通过，六张截图已查看。现有六张底图hash未变，使用同一生产节点导出六张1448×1086合成PNG及ZIP，见 `output/yading-offline-scenes/verification.json`。该证据仅覆盖本地Mock场景与标注，无真实服务缓存、整App离线或新TestFlight发布声明。

### 独立远程场景承接

本批承接根仓 Change `serve-route-artwork`，共享形状与匹配不变量引用 [scene-artwork-schema](../../docs/data/scene-artwork-schema.md)，请求与鉴权引用 [scene-artwork-api](../../docs/api/scene-artwork-api.md)；页面与组件继续使用本入口既有 `PAGE-TRIP-DETAIL`、`PAGE-ROUTE-DETAIL`、`TripExpeditionScene` 和 `RouteImageGallery` 映射。

- `WalkData/SceneArtworkModels.swift` 承载独立场景 DTO 与上下文验证，`SceneArtworkAPI.swift` 经现有 APIClient 发起独立读取；`RouteService`、`PersonalTripService` 不把艺术字段混入原有路线/个人行程事实 DTO。场景请求本轮无业务离线返回资格。
- Route / Trip 的主投影先完成发布，场景由页面独立 `.task(id:)` 读取。ViewModel 以主投影读取批次和请求生命周期拒绝取消、重试、变更或离页后的迟到结果；个人页面继续由既有会话装配在身份变化时销毁。场景失败和旧服务 404 只使艺术区域降级，不替换主页面 loading/error。
- `TripExpeditionPresentation` 以明确实际日身份选图，保留显式 Mock 资源映射；真实模式缺图使用中性渐变占位。`TripExpeditionScene` 通过 `AsyncImage` 装载远程图，URL 变化重建图片节点；当前图片裁切承载以 `use-single-fullscreen-trip-artwork` 为准，日期/滑动/深入交互保留。图片关联不授予海拔、地标或示意线映射。此实现不承诺预加载或离线图片缓存。
- `RouteDetailPresentation.sceneImages` 与原事实 `images` 分离，`RouteDetailViewSupport` 复用正式 `RouteImageGallery` 承载独立“场景示意”组；组名和参考日关联标签来自投影上下文，不作为图片自带 caption。场景图片在原图库空间内等比完整显示。

2026-09-30 验证：先建立独立 API/DTO 与 iOS 投影失败测试，WalkData 89 项通过；上述模拟器的 iOS 定向 192 项执行，191 项通过、1 项既有真实后端 opt-in 跳过。`RemoteSceneArtworkUITests` 使用 `remoteOnly` 连接本机真实 Spring Boot 服务，从公开亚丁路线进入独立图库，六张 HTTP 图片均已截图检查，1 项 UI 用例通过。该结果不代表线上部署或个人行程 UI 的真实服务验收；个人场景关联由请求合同与生命周期单测覆盖。可复核证据见 [remote-scenes/README.md](../output/verification/remote-scenes/README.md)。

### 已采纳参考日攻略承接

本批承接根仓 Change `preserve-reference-itinerary-content`；日级值与未知徒步区段引用 [trip-schema](../../docs/data/trip-schema.md)，明确采纳关系引用 [trip-composition-relations](../../docs/data/trip-composition-relations.md)，交换形状引用 [personal-trip-api](../../docs/api/personal-trip-api.md)。页面继续由既有 `PAGE-TRIP-BROWSE` 与 `TripDayArrangement` 承载，不增加组件或生成入口。

- `PersonalTripRouteGuideModels.swift` 承载独立冻结参考资料，`PersonalTripDay` 与 `PersonalTripAction` 增量解码上游可选值。旧响应没有攻略时保持缺失；iOS 不生成参考日关系、不重写日序/日期/行动、不在读取时查询当前公共路线补资料。
- `TripRouteGuideProjection` 只格式化同一天已有的文字、置信、来源和参考统计；`TripBrowsePagePlan` 在行动与点位之后、天气之前加入日级 `.routeGuide` 内容块。实际徒步摘要仍只读取实际行动，参考数值与路径不参与实际指标或海拔计算。
- `TripDayArrangement` 复用既有 Panel、正文和 warning 颜色承载“路线参考”，状态没有已知值时仍可见；参考指标附活动口径说明，未知徒步段通过原徒步块局部表达。长正文完整换行，不设 lineLimit 或固定内容高度。`DayPageCell` 继续由内层 UICollectionView 的自适应 UIHostingConfiguration 承接超屏内容，一个自然日仍为一页。
- 校准样例与组件共置，Debug 目录登记 `referenceGuide`、`referenceGuideLong`、`hikeSectionUnavailable`；长文校准同时验证可访问字号。新增攻略块在可访问字号下使用 iOS 语义字体放大，普通字号继续消费既有字体 Token，不修改全局字号系统或主图布局。

2026-09-30 验证：最小 DTO 与投影 RED 后完成实现，WalkData 94 项通过，包含显式输入本次真实 HTTP 五日生成响应的解码回归；iOS 定向 144 项执行，143 项通过、1 项既有 live opt-in 跳过。长日内容通过真实 SwiftUI 测高验证超屏可增长；同一生产组件的普通/长文可访问字号/未知徒步区段三状态通过 2 项 UI 用例，最终截图已检查，参考口径提示与长文末尾来源完整可达。平台登记结构 8 项通过。证据见 [reference-guide/README.md](../output/verification/reference-guide/README.md)；组件校准截图不作为真实个人账号行程 UI 或线上部署证据。

### 既有场景承接

本批承接根仓 Change `polish-trip-detail-aigc`；上游引用 [app-flow](../../openspec/specs/app-flow/spec.md) 的「App 提供四个公开一级区域」「个人行程根页面承接从属任务」「自然日详情按自然日逐页阅读」、[PAGE-TRIP-DETAIL](../../docs/ui/pages/PAGE-TRIP-DETAIL/spec.md)、[PAGE-TRIP-BROWSE](../../docs/ui/pages/PAGE-TRIP-BROWSE/spec.md)、[TripExpeditionScene](../../docs/ui/components/business/components/trip-expedition-scene/spec.md)、[TripCoverHeader](../../docs/ui/components/business/components/trip-cover-header/spec.md)、[DailyWeatherSummaryRow](../../docs/ui/components/business/components/daily-weather-summary-row/spec.md)、[TripEquipmentSummaryCard](../../docs/ui/components/business/components/trip-equipment-summary-card/spec.md) 与 [Token](../../docs/ui/tokens.md)。

- `AppTab`、`AppShellState` 与 `RootView` 继续使用系统 `TabView` 和来源 `NavigationStack`；Home 保持原生产焦点与数据路径。
- `TripDetailView` 使用自定义固定构图与悬浮导航；本页选择状态由纯展示逻辑承载，原 `TripDetailViewModel` 请求编排与真实 DTO 保留。通常宽度的纵向内容滚动归底部 Timeline 区；日期横向滚动和场景横划分别拥有自己的手势范围。可访问字号的适配不得裁掉操作。
- `TripCoverHeader.identity` 承载顶部身份；`TripExpeditionScene` 使用 Asset Catalog 的无字图片、独立矢量路径/地标示意与海拔数据层。`coverAvailable` 仍表达真实路线媒体是否可用，艺术资源不会将其置为 true。字体由 `AppTypography.editorialTitle` / `Font.editorialTitle` 映射既有 Token。
- `DailyWeatherSummaryRow.inline` 与装备入口是显式外观；日天气与装备分别转发既有导航回调，装备读取仍来自本次详情快照，不新增按日装备请求。
- 演示场景配置由明确的 mock 上下文注入，业务 DTO、网络 Service 与后端事实不变；展示投影负责验证适用条件并切分演示剖面。真实数据没有可信日界时不沿用该分段。样例资源配置不承担普通行程路线推导。
- 新组件在 `Walk/Features/Trips/Components/TripExpeditionScene.swift` 共置生产实现、Projection 与 DEBUG 校准样例；`ComponentCatalog` 登记 default、overview、hikingDay、arrival、unavailable；default 映射 overview，独立 Preview 使用其余四个同名状态。Page、SwiftUI Preview 与目录都使用这一生产实现。
- 日期选择、边界与演示数据隔离由单元测试，页面两次场景激活、幂等日期、返回恢复、固定滚动与独立入口由适用 UI 测试承接；登记检查仍使用本入口下方命令。此处是映射决策，不是本轮验证完成证明。

同日承接 `refine-trip-detail-timeline-hierarchy`，按上述 Page 和 [Timeline](../../docs/ui/components/common/timeline/spec.md)、[Notice](../../docs/ui/components/common/notice/spec.md) 合同，`TripDetailView` 消费 `Timeline.compact`、`Notice.inline`、`TripEquipmentSummaryCard.icon`；默认外观继续服务其他消费者。日号、月份边界、完整可访问日期与关键时间由 `TripExpeditionPresentation` 投影，关键时间独立于可截短的普通说明。页面负责窄栏宽度与大字号适配，公共路线回调移入系统 `Menu`。现有图片、轨迹和海拔组件保持原生产实现。组件校准状态通过共置 Preview 与同一 `ComponentCatalog` 承载。

同日后续承接 `reorganize-trip-detail-scene-information`，以同一 Page / Scene / Cover 合同为权威：`TripExpeditionPresentation` 提供上下文眉题与指标投影，Page 将 `MetricGroup.inline` 组合在 `TripCoverHeader.identity` 下。Scene 的独立叠层承载海拔与提醒滚动窗口，和场景激活 Button 分开接收手势；提醒不再由 Page 底部重复组合。常规布局将 Timeline 标题置于滚动容器外，紧凑及可访问字号使用 `LazyVStack` 的 pinned Section header。Scene 与 Cover 的新增校准样例仍共置于原生产组件文件并登记到 `ComponentCatalog`。

随后承接 `blend-trip-detail-artwork`：Page 用独立 `GeometryReader` 将 `TripAtmosphere` 装饰背景铺到系统安全区边缘，正文仍遵守安全区。Scene 消费同一 Asset Catalog 中的新版场景，图片与矢量层通过统一等比坐标转换适配可用区域；投影与业务数据保持原来源。`expand-timeline-offline-demo` 按后续用户确认移除图片外围代码蒙版，不修改原素材。提醒正文消费既有 warning Token，Page 扩大 Timeline 的 SwiftUI 内容约束；可用高度不足时切换正文滚动，保留常驻/吸顶安排标题。生成资源及提示词验证入口为本轮 `output/imagegen/blend-trip-detail-artwork/`，生产图片保存于 Asset Catalog。

2026-09-30 `expand-timeline-offline-demo`：Timeline布局收紧顶部间隔并减少场景占用，保留比首轮230pt更大的底图，页面标题/正文提高既有字体Token档位，取消正文232pt上限。27项配置与55项场景/几何回归共82项通过；实际release优化的OfflineDemo六态UITest通过并逐图检查，证据 `output/timeline-offline-demo/ui-final`。宽度按截图核验，AX短标题字形不作为容器尺寸证据。独立device DerivedData最终归档的13项DebugSwift隔离通过，生产Release参数仍real/production，与Mock演示分发配置分开。TestFlight结果以同目录发布回执为准，不以归档代替可安装。

## App 架构基准

确认日期：2026-09-24。本节保存本轮讨论确定的 iOS **目标逻辑架构**。W0–W6 完成后的实际落地见下文「当前架构」。

### 架构图

```mermaid
flowchart TB
    Debug["DebugTools · 仅 Debug<br/>DebugSwift + 自定义调试能力<br/>Mock / 真实＋缓存 / 仅远端"]
    App["App 层<br/>系统入口 · 生命周期 · 全局导航 · 依赖组装"]
    Features["Feature 层<br/>行程首页 · 路线 · 行程任务 · 装备 · 账户<br/>展示 · 交互 · 页面状态"]
    Service["Service<br/>业务数据操作"]

    subgraph Data["数据访问能力"]
        Protocol["统一数据请求协议"]
        Mock["Mock 实现<br/>预设数据 / 模拟返回"]
        Real["真实数据实现<br/>协调远端请求与缓存策略"]
        Protocol --> Mock
        Protocol --> Real
    end

    subgraph Infrastructure["独立基建"]
        HTTP["HTTP 网络层"]
        Cache["缓存能力"]
        Storage["持久化存储"]
        UI["通用 UI 组件"]
        Theme["Theme / Design Token"]
        System["认证 · 定位 · 系统适配"]
        Cache --> Storage
        UI --> Theme
    end

    Backend["后端服务"]
    Debug -. "提供调试配置" .-> App
    App --> Features
    App -. "选择实现与策略，组装依赖" .-> Protocol
    App --> System
    Features --> Service
    Features --> UI
    Service --> Protocol
    Real --> HTTP
    Real --> Cache
    HTTP --> Backend
```

实线表示主要访问或组成关系，虚线表示配置与组装。协议连接 Mock / 真实实现，表示两种可替换的数据能力；协议本身不要求再增加一个运行时路由对象。

### 职责与依赖

| 层 / 能力 | 职责与边界 |
|---|---|
| App | 系统入口、生命周期、全局导航、最终配置解析和依赖组装；决定注入哪一种数据实现及策略。 |
| Feature | 按业务域组织展示、交互、页面状态与任务流程；通过 Service 请求业务数据。 |
| Service | 对页面提供类型化业务数据操作，经统一请求协议访问数据；不负责选择调试模式。后端业务事实仍由上游规范与后端拥有。 |
| 统一请求协议 | 为 Service 提供稳定入口，使业务调用不随 Mock / 真实实现切换而改变。 |
| Mock 实现 | 返回预设数据或模拟结果，与真实远端及其响应缓存分开。 |
| 真实数据实现 | 组合 HTTP 与缓存能力，根据配置和接口策略决定是否使用响应缓存。 |
| 缓存 / 持久化 | 缓存能力管理响应数据的复用，持久化承载数据读写；不属于 Mock，也不决定业务事实。 |
| Theme / 通用 UI | Theme 定义视觉 Token，通用 UI 组合可复用界面能力，供 Feature 消费。 |
| 认证 / 系统适配 | 承载认证会话以及系统权限、定位等平台能力，按需要提供给 App 或 Feature。 |
| DebugTools | 仅在 Debug 中接入 DebugSwift，并承载本 App 的自定义调试能力；向 App 提供配置，不进入业务请求链。 |

这些是逻辑职责边界，不要求每个方框都成为独立 Swift Package。Feature 与业务 Service 不依赖 DebugTools；调试配置由 App 转换为具体依赖和策略。

### Debug 数据运行模式

| 模式 | 数据能力 | 用途 |
|---|---|---|
| `mock` | Mock 实现返回预设或模拟数据 | 页面开发、场景复现 |
| `real` | 真实远端 + 本地响应缓存 | 真实数据链路，按策略使用缓存 |
| `remoteOnly` | 真实远端，绕过响应缓存读写 | 便于 E2E 验证真实请求链路 |

三种模式是调试配置；数据能力仍归为 Mock 与真实两类。`real` 和 `remoteOnly` 使用同一类真实请求能力，以缓存策略区分。这里的缓存开关针对请求响应缓存，不等于关闭登录态、调试设置等其他持久化。

缓存行为由独立策略决定，首版采用网络优先，并提供断网失败与断网尝试返回缓存两种策略；具体约束见下文「重构规范与约束」。DebugSwift 是选定的接入方案，不表示已经完成 SDK 接入或模式改造。

### 重构目标与工作拆分

阶段状态：第 1–3 步（目的与目标、工作拆分、规范与约束）已确定；第 4 步的 W0–W6 均已完成，当前架构与验收入口见本节「当前架构」，已知问题与未验证范围见「当前架构」末尾。各批次过程记录不入库，从 git 历史追溯。SDK 网络观察仍关闭，开启前需按 R-DEBUG 补齐请求、缓存、认证与取消语义的证据。W1 建立的离线返回能力目前没有任何生产端点启用。

**重构目的**：把现有逻辑架构落实为职责明确、依赖清晰、容易修改和验证的代码结构，降低后续开发、问题定位和测试成本。衡量效果时关注修改位置是否明确、影响范围是否可控、结果是否可验证。

已认可的目标与完成标准：

| 目标 | 完成标准 |
|---|---|
| 各层职责明确 | App 承担入口、生命周期、全局导航与组装；Feature 承担展示、交互、页面状态与流程；Service 提供业务数据操作。 |
| 数据访问边界稳定 | Feature 通过 Service 获取业务数据；Service 使用统一请求协议，不自行判断运行模式。 |
| 真实数据能力统一 | Mock 与真实实现分开；真实实现组合 HTTP 与缓存，策略有统一归属，存储提供独立读写能力。 |
| 调试配置统一 | 支持三种数据模式；数据模式与服务器环境分开，由 App 根据最终配置组装依赖。 |
| 调试工具独立 | DebugSwift 与自定义能力由 DebugTools 承载，业务模块不依赖调试工具；Release 构建不引入调试能力。 |
| 基建职责明确 | Theme、通用 UI、网络、存储、认证具有清晰职责和使用入口，减少重复实现。 |
| 架构可以验证 | 能检查依赖方向，验证数据模式与缓存策略，并提供关键业务流程的回归证据。 |

工作分为保持已有业务行为的结构整理，以及三种数据模式、真实数据与缓存组合、DebugSwift 接入的能力补齐。产品功能、页面视觉、后端业务规则按现有上游约定承接；拆包粒度根据实际依赖与验证需要决定。

以下 W0–W6 是第 4 步的建议执行批次。每批包含自身验证，W6 汇总跨模块验收；第 3 步先确定共用规则，避免实施过程中分别补充隐含约定。

| 批次 | 工作范围与承载 | 交付物 / 验收点 | 依赖 |
|---|---|---|---|
| W0 现状与验证基线 | 盘点现有工作树、未完成草稿、工程依赖、测试与关键流程入口 | 记录实施前的构建/测试结果、已有失败、既有改动边界及回归清单；验证 DebugSwift 接入与 Debug/Release 隔离方案的可行性 | 第 3 步规范确定后开始执行 |
| W1 数据能力与缓存 | WalkData 的请求协议、HTTP、Mock、响应缓存、存储与认证接口边界 | 形成可组合的 Mock / 真实实现；按既定策略验证缓存行为、关闭响应缓存的真实请求，以及会话变化与在途请求的缓存行为；业务 Service 的调用面保持稳定 | W0；缓存、认证隔离及旧 local 路径迁移规则已确定 |
| W2 App 配置与依赖装配 | AppConfiguration、AppEnvironment 及旧 DebugEnvironment 的配置映射 | 数据模式与服务器环境分别解析；最终配置统一生成客户端、缓存与认证依赖；启动参数可确定性选择模式 | W1；配置优先级与生效方式已确定 |
| W3 DebugTools 接入 | DebugSwift 封装、App 调试入口、现有手写调试页与设置迁移、工程依赖 | 调试 UI 使用 W2 的同一配置入口；业务层不依赖 SDK；分别验证 Debug 可用与 Release 隔离；验证观察工具不改变 remoteOnly 的缓存语义 | W2；W0 接入方案验证完成 |
| W4 App / Feature / Service 整理 | RootView、RootNavigation、五个 Feature 及业务 Service 的职责连接 | 全局导航与依赖组装归 App，页面流程与状态归所属 Feature；按代表链路逐域整理并验证，不以文件长度作为拆分依据 | W2；可与 W3 并行，调试入口相关文件由 W3 统一修改 |
| W5 共用基建归属整理 | WalkDesignSystem、Feature 共用组件、Support 及认证/系统适配入口 | 根据实际复用和职责整理归属与可见接口，保持视觉及业务语义；只处理有明确收益的重复或越界，不为每个概念强制新增 Package | W4 梳理清楚使用关系；不重复改写 W1 已确定的数据基础设施 |
| W6 整体验收与记录 | 架构边界检查、模式集成验证、关键流程回归、文档与遗留入口 | 五域主链路、三模式、服务器环境切换与 Debug/Release 分别有适用证据；明确新旧入口迁移结果、已有问题与本轮新增问题；更新当前架构记录 | W1–W5 的批次验证完成 |

W1 与 W2 共享第 3 步确定的配置合同：WalkData 只接收所需策略与依赖，不读取 App 配置或引用 App 类型；App 负责将最终配置映射为这些参数。实施时可以按 Mock、真实＋缓存、仅远端逐条完成能力与接线验证。W3 通过回调或独立接口与 App 连接，不产生 DebugTools 对 App 实现的反向依赖。

第 2 步识别的规范议题：

- 各层允许的依赖方向、接口所有权、目录归属与拆包条件。
- 数据模式与服务器环境的定义、配置优先级、默认值、生效时机；旧参数、设置与 local 回放能力如何迁移。
- 缓存资格、读取/刷新/过期/失效规则，错误处理与回退范围；服务器环境、用户和 Mock/真实认证会话的隔离规则；退出登录、认证失效及环境切换时对旧请求、响应和页面状态的处理。
- DebugSwift 的能力边界、构建隔离与配置接入方式；remoteOnly 的验证范围覆盖应用响应缓存和 HTTP 客户端缓存。
- 分批修改与验证约束：保护已有改动、区分存量失败、为新增行为建立针对性测试；测试验证可观察行为和依赖边界，减少对文件名与源码字符串的绑定。

这些议题的首版规则统一记录在下节。SDK 版本及工程隔离方案的可行性由 W0 验证，接口级离线资格及有效期需要逐项登记，不能从现有 `.store` 标记推导。

### 当前架构

W0–W6 完成后的实际结构，是上文架构图与「职责与依赖」的落地：

| 逻辑层 | 承载 | 依赖约束的强制 |
|---|---|---|
| App | `Walk/App/`：`WalkApp` 入口、`AppConfiguration` 解析、`AppEnvironment` 唯一生产装配、`AuthenticationFlow` 认证编排、`RootView`/`RootNavigation` 全局导航；`Walk/App/Debug/` 仅 DEBUG 编译 | `ArchitectureDependencyTests`（生产依赖只由 `AppEnvironment` 装配） |
| Feature | `Walk/Features/<Home/Routes/Trips/Equipment/Profile>`；跨域合同在 `Features/Shared/`（Navigation、跨域业务组件） | `FeatureBoundaryTests`（不跨域、不引用 App）、`ArchitectureDependencyTests`（不装配依赖、不读配置） |
| Service / 数据 | `Packages/WalkData`：Service 协议、统一请求协议、Mock 与真实实现、`OfflinePolicy`、缓存记录、认证 | `ArchitectureDependencyTests`（只依赖 Foundation 族与 Alamofire） |
| Theme / 通用 UI | `Packages/WalkDesignSystem` | `ArchitectureDependencyTests`（只依赖 UI 框架）、`DesignSystemBoundaryTests`（不以业务命名）、`DesignSystemTests`（Token 取值与 Feature 裸值守卫） |
| DebugTools | `Packages/WalkDebugTools` → DebugSwift 1.19.0，仅开发依赖图 | `DebugToolsBoundaryTests`；Release 由 `scripts/build.py` 产物隔离检查 |

验收入口：

| 验收面 | 入口 |
|---|---|
| 单元与结构 | `python3 scripts/build.py --mode debug --action test --scheme Walk --destination '<destination>'` |
| 三种数据模式 E2E | `WALK_E2E_DESTINATION='<destination>' scripts/run_data_mode_e2e.sh [局域网 IP]` |
| 关键流程回归 | `WALK_E2E_DESTINATION='<destination>' scripts/run_key_flow_regression.sh`（会重置该模拟器 Keychain） |
| 组件 UITest / 调试面板 | scheme `WalkComponents` / `WalkDebugTools`；手动组件预览仅从 DebugPanel 进入 |
| Release 产物隔离 | `python3 scripts/build.py --mode release --action archive` |

已知问题（截至 W6 收尾）：

- 独立 iOS Baseline 链路已批准退役；组件验证保留 UITest 的断言与截图证据，不宣称具备已批准 Golden 的像素对比验收。
- `color.map.overnight` 为暂定取值（冻结原型未定义），待设计确认后只改取值。
- `TripWeatherTrendChart` 借用 `color.map.waypoint` 表示降水，属于语义借用。

未验证范围：真实后端联调（需要真实后端的用例始终跳过）；正式 App 中的断网回退（无端点登记离线资格）；SDK 网络观察；签名、真机与分发。

验证中需知的陷阱：

- 模拟器 Keychain 在卸载 App 后仍保留登录态；依赖未登录起点的 UI 测试须先重置 Keychain（`run_key_flow_regression.sh` 已处理）。
- 真实网络模式拒绝 localhost / 127.0.0.1，受控服务须使用局域网地址。
- 模拟器测试须用 `CODE_SIGN_IDENTITY=-` 本地临时签名；`CODE_SIGNING_ALLOWED=NO` 会使 Keychain 返回 -34018，认证用例假失败。
- 单配置开发工程不能阻止原始 `xcodebuild -configuration Release`；发布产物以 `scripts/build.py` 的隔离报告为准。

### 重构规范与约束

本节是第 3 步形成的首版实施约束，供 W0–W6 使用，不代表当前实现已符合。用户明确要求将「断网失败 / 断网返回缓存」建模为策略，因此缓存回退不固定在真实客户端内部。其余工程规则以保持已有业务行为和可验证性为原则制定。

#### 1. 范围与模块边界

**R-SCOPE**：结构整理保持现有业务、导航和视觉合同；三模式与 DebugTools 属于本轮能力补齐。涉及离线页面语义、业务资格、错误语义或 API 合同的新决定，归相应上游规范，不能通过移动代码、Mock 或缓存策略暗中改变。

**R-DEP**：依赖遵守下表。逻辑独立不强制逐项拆包；只有编译隔离、独立验证或复用确有需要时新增物理模块。

| 所有者 | 承担与允许依赖 | 边界 |
|---|---|---|
| App | 最终配置、实例生命周期、依赖装配、全局导航、系统事件连接 | 页面内部流程归 Feature；App 是业务客户端、存储与认证实例的生产装配入口。 |
| Feature | 展示、交互、页面状态、任务编排；消费业务 Service 合同、设计系统、必要系统适配及导航动作合同 | 不创建具体 APIClient、HTTP Session 或响应存储；不读取运行模式；不引用其他 Feature 的页面/VM 或 App 根实现。 |
| Service | 类型化业务数据操作与必要结果转换，消费 APIClient 等数据合同 | 不决定运行模式、不呈现 UI、不自行创建全局客户端；不得补造后端业务事实。 |
| WalkData | 请求/响应/错误合同、Service、Mock、真实客户端、缓存、存储与认证能力 | 不依赖 App、Features、WalkDesignSystem、DebugTools；不重新读取 App 配置源来选择模式。 |
| WalkDesignSystem | Theme、通用 UI 和通用展示值 | 不依赖业务数据模型、Service 或调试工具；绑定业务对象的组件留在所属 Feature。 |
| DebugTools | 调试展示、诊断、配置动作意图 | 通过 App 注入的状态与回调连接，不反向引用 App 实现、不创建业务依赖、不持有第二份有效配置。 |

导航意图可放在明确的共享合同位置，跨域流程由 App 或共享业务 Service 协调。Feature 内部具体页面和 VM 不作为跨域复用接口。Preview、组件体验与生产页面消费同一组件实现。

#### 2. 配置、默认值与切换

**R-CONFIG**：以下三个维度独立，统一由 App 解析、校验并冻结为一次启动的有效配置：

- 数据模式：`mock / real / remoteOnly`。
- 服务器身份：稳定环境标识与规范化 baseURL；标识相同但地址不同也视为不同服务。
- 执行上下文：正常运行、测试、组件预览，以及 Debug / Release 构建类型。不能仅凭服务器名为 `test` 判断当前一定处于自动化测试。

模式只选择数据能力；切换服务器不隐式改变模式。`mock` 不请求业务服务器。真实模式必须有有效服务地址；不得因地址配置错误自动改用 Mock 或其他服务器。Debug 构建默认沿用 Mock，普通Release固定使用构建配置的生产服务与 `real`，采用默认断网失败策略；显式开发配置可覆盖 Debug 默认值。经 `expand-timeline-offline-demo` 批准的 `OfflineDemo` 是独立release优化构建，包内 `WalkDistribution=offline-demo`、`WalkDataMode=mock`、`WalkEnvironment=offline-demo` 和 `https://offline.walk.invalid/api/v1` 必须精确一致，显示名为“Walk演示”；不匹配拒绝启动，不自动转为真实服务。生产Release保持原值和原拒绝规则。两种分发模式都不读取运行时参数、进程环境或历史Debug设置；Mock认证/缓存沿现有服务身份命名空间隔离。

Debug 配置的优先级统一为：**显式启动参数 > 进程环境变量 > 已保存的 Debug 设置 > 构建配置 > 代码默认值**。来源以可注入输入传入解析器；测试与组件定向预览忽略个人 Debug 设置并显式注入场景配置；从 DebugPanel 打开组件预览不改变宿主的有效配置、会话或缓存。未知、空白或同一来源内相互冲突的显式配置报错，不静默降级。Release 不读取 Debug 偏好，也不接受开发模式切换入口。

**R-SWITCH**：首版保留重启生效。DebugTools 展示当前有效值与待生效值；保存配置只影响下一次启动，不热替换某个 Service、缓存或认证实例，也不立即删除当前会话。启动时统一创建依赖，避免一个 App 同时使用新旧服务。待生效提示根据两份配置是否不同计算。

#### 3. 数据模式与缓存策略

**R-MODE**：统一业务访问入口保持类型化，具体数据能力分为 Mock 与真实两类。`real / remoteOnly` 使用同一类真实实现，通过策略装配区分。

| 模式 | 真实业务网络 | 响应缓存 | 断网行为 |
|---|---|---|---|
| `mock` | 不调用 | 不访问真实响应缓存 | 由模拟场景定义结果，不回退真实请求 |
| `real` | 网络优先 | 根据端点资格和策略读写 | 按 `OfflinePolicy` 执行 |
| `remoteOnly` | 发起真实请求 | 绕过应用响应缓存及 HTTP 客户端缓存，不读取验证器、不保存响应 | 返回网络错误；任何缓存策略都不能覆盖该模式 |

`remoteOnly` 针对业务请求响应链，不关闭 Keychain、调试配置等其他持久化，也不宣称绕过后端/CDN内部缓存。E2E 需要通过受控服务或请求日志证明真实请求到达；仅有页面显示成功不算证据。

**R-CACHE-POLICY**：首版读取顺序为网络优先，失败处理独立建模：

| 策略 | 明确断网 / 连接中断后的行为 |
|---|---|
| `fail` | 返回本次连接错误，不以缓存替代结果；这是未配置时的默认值。 |
| `useCache` | 对允许离线读取的只读端点，尝试返回同服务、同身份、未失效且符合有效期的缓存；没有合格缓存时仍返回原始连接错误。 |

策略由数据层执行，App 注入默认策略，端点声明允许范围与所需规则；DebugTools 可选择已允许的策略。优先级是 **模式硬约束 → 端点资格/上游合同 → 所选策略 → 缓存有效性**。全局选择 `useCache` 不会让所有接口自动具备离线返回资格。

断网原因来自结构化传输错误，不解析错误文案，也不单靠网络可达性预判。首版仅明确的未连接网络、连接中断触发 `useCache`；超时、401/403、其他 HTTP 错误、业务错误、解码错误和取消保持原语义，不自动回退。修改命令始终等待远端结果，不缓存回放成功，也不在离线时排队提交。

**R-CACHE-VALIDITY**：允许保存与允许离线读取分别声明，现有 `.store` 只能证明保存资格。离线资格至少登记上游依据、有效期、失效事件及调用方如何处理缓存来源；缺少任何一项时默认不允许离线返回。不自行统一指定“所有数据缓存若干分钟”，不借业务日期、revision 或天气可信状态推导有效期；首版不返回过期缓存。

**R-RESULT**：启用 `useCache` 的调用链必须携带结果来源与保存时间，必要时携带本次回退原因；Service 与页面能够区分本次远端结果和本地缓存结果。这是客户端结果上下文，不增加后端 DTO 字段；不通过共享的“最后一次请求来源”记录并发请求信息。W1 决定具体类型承载，保留兼容入口时不得丢弃此语义。

缓存来源标记不自动授权新的离线页面行为。[个人行程读取失败](../../openspec/specs/trip-lifecycle/spec.md)、[路线事实完整性](../../openspec/specs/public-route/spec.md) 与 [API 错误合同](../../docs/api/api-common-contract.md) 继续有效。本轮可以实现并验证 `useCache` 策略能力；具体生产端点是否启用，按上述资格登记，不把整个 App 一次性切成离线成功。

#### 4. 缓存、存储与一致性

**R-STORAGE**：首版仅缓存明确允许的只读 GET 成功响应。登录、验证码、令牌响应和修改命令不缓存；个人资源读取按端点资格和身份隔离。HTTP 缓存指令仍须遵守：`no-store` 不保存；`no-cache` 的复用需要成功验证，不能当作离线返回许可。条件验证及变体匹配遵循 [RFC 9111](https://www.rfc-editor.org/rfc/rfc9111.html#section-4.3)，不假设当前后端已经支持验证器或 304。HTTP 客户端不得另外绕过所选策略返回缓存。

缓存记录包含业务响应及必要的请求匹配、来源时间和缓存控制元数据；命名空间至少隔离服务身份、模型版本、会话/用户、请求及影响响应的表示差异。存储只负责读写，不负责端点资格、回退选择或业务规则。旧的纯 JSON 快照缺少策略所需元数据时，不能直接升级为可离线返回的缓存。

缓存缺失、损坏、身份不匹配、已失效或过期都视为缓存不可用。网络成功后的缓存写入失败不抹掉已取得的有效远端结果；网络失败且缓存不可用时保留原始失败，不转换为空集合、无焦点或不存在。

**R-INVALIDATION**：首版采用保守失效范围，成功修改或修改结果不确定后使当前服务与会话的响应缓存失效；涉及公开资源的变更也覆盖对应公开缓存。失效过程必须阻止旧在途读取重新写回缓存或覆盖新的页面结果。不能将修改响应直接写入形状不同的 GET 缓存。

退出、认证失效、切换身份会推进会话有效性并清理或隔离个人响应；旧响应不能恢复认证、回填新身份缓存或继续向新会话发布个人数据。[退出登录语义](../../openspec/specs/account-access/spec.md) 保持不变。`remoteOnly` 请求不访问响应缓存；再次进入 `real` 时需使此前缓存失效，避免忽略 `remoteOnly` 期间的修改，该失效属于启动生命周期管理。

#### 5. 认证与配置迁移

**R-AUTH**：客户端、Service 与页面使用 App 注入的同一认证实例；认证管理器不重新读取启动参数、Info.plist 或 Debug 偏好选择模式。认证命名空间以最终服务身份为基础，再区分 Mock 与真实：Mock 独立；同一服务下 `real / remoteOnly` 共用真实会话；不同环境标识或不同 baseURL 隔离。服务地址的身份包括协议、主机、有效端口和 API 基路径，不能仅比较显示名称。

**R-MIGRATION**：内部统一新模型，迁移覆盖脚本、scheme、UI 测试与调试入口。用户已确认现有登录态、Debug 设置与启动键均为临时状态，因此 W2 不保留兼容别名，也不迁移旧数据。旧键显式报错，防止被静默忽略。

| 旧入口 | 首版迁移规则 |
|---|---|
| `remote / mock` | 分别解析为 `real / mock`；`remote` 不隐式授予离线读取资格。 |
| `local` App 模式 | 没有等价新模式，显式报不支持；缓存回放需要在测试中直接注入，不能映射为真实网络或 remoteOnly。 |
| `-DataSourceMode` / `WALK_DATA_SOURCE_MODE` / `WalkDataSourceMode` | 已退役，传入即报 `retiredKey`。规范键为 `-WalkDataMode` / `WALK_DATA_MODE` / `WalkDataMode`，取值 `mock / real / remoteOnly`（大小写不敏感）；旧值 `remote` 不再被接受。仓内 scheme、`project.yml` 与测试启动参数已全部改用新键。 |
| 服务器参数与构建默认值 | 保留现有 `-APIBaseURL`、`-WalkEnvironment` 及对应环境/Info 键的承载，拆开服务器身份与测试执行上下文。不得凭旧 `testServer` 名称推断已有独立测试部署。 |
| 旧 Debug 环境预设 | 不迁移。`walk.debug.environment` 不再被读取；Debug 设置保存为带版本的单一记录 `walk.debug.settings`，数据模式与服务器分别可选，未设置的维度回落到下一级来源；无法读取或版本更高的记录被忽略，不猜测。 |
| 旧认证槽位 | 不迁移。旧 `auth_token` / `auth_token_mock` 没有服务来源记录，且被多个环境共用，按本规则不能复制到任何当前地址。认证命名空间改为由 Mock/真实与服务身份组成的新键，升级后需重新登录一次。 |

#### 6. DebugTools 与工程隔离

**R-DEBUG**：DebugSwift 放在独立调试适配层，App 注入只读配置快照与设置、清缓存等动作回调，数据模块执行实际操作。调试能力不成为业务链路的运行前提，也不在 Feature 中留下 SDK 调用。

Release 的编译/链接输入与最终产物不得包含 DebugSwift 及其资源。仅在调用处使用 `#if DEBUG` 不构成完成证据；W0 验证可行的 target/依赖组织，W3 在实际接入后提供产物检查。SDK 网络观察不得改变请求、缓存、认证和取消语义；无法保证时关闭相关拦截并使用受控诊断入口。诊断信息不输出 Token 等凭据。

工程结构以 `project.yml` 为源，新增目录/target 后通过 XcodeGen 生成；固定并记录验证过的依赖版本。各模块依赖只声明实际需要的内容，不为文件搬迁引入新的框架或架构模式。

**W0 已验证的 W3 工程方案**：共用 XcodeGen 模板，分别生成开发与生产依赖图；仅开发图引入 DebugTools → DebugSwift，生产图不声明二者。候选版本固定为已经实测的 DebugSwift 1.19.0。正式构建入口在启动工具前校验模式、configuration 和 action，开发入口拒绝 Release 与 archive；发布入口只生成生产图，并执行依赖、编译、link map、符号/动态依赖和资源检查。

单配置工程不能阻止原始 `xcodebuild -configuration Release` 强行覆盖，因此不能把「开发工程没有 Release 配置」视为隔离保证；受支持入口及发布检查必须一并落地。最小宿主已验证面板和自定义信息展示，默认禁用网络等自动监控钩子；正式 App 接入与配置回调已在 W3 完成并由 `WalkDebugToolsUITests` 验证；监控语义仍未验证（网络观察保持关闭）。

#### 7. 实施与验收

**R-VERIFY**：W0 记录工作树、已有草稿与失败；每批修改都包含针对其行为的验证。新增行为先建立最小失败测试；纯文件归属调整复用已有检查，不为实现细节编造测试。不能把已存在失败算作本轮引入，也不能通过删除断言掩盖新增失败。

| 验收面 | 最小证据 |
|---|---|
| 架构依赖 | 包/target 依赖图与生产装配路径；边界检查聚焦禁止依赖，不绑定局部函数名或完整 SwiftUI 源码字符串。 |
| 配置 | 来源优先级、非法值、新旧键、执行上下文隔离、待生效配置不影响当前实例；同名不同地址按不同服务隔离。 |
| 数据模式 | Mock 真实业务 HTTP 为零；real 按资格和策略读写；remoteOnly 在预置应用及 HTTP 缓存情况下仍发真实请求且响应缓存读写为零。 |
| 断网策略 | 同一端点分别验证 fail 返回连接错误、useCache 返回合格缓存及来源；缺失/过期/损坏/身份不匹配时保留错误；不合格端点及非断网错误不回退。 |
| 生命周期 | Mock 与真实认证隔离、real/remoteOnly 共用会话、不同服务隔离；修改/退出后的旧响应不写回、不覆盖新结果。 |
| Debug / Release | Debug 配置动作实际连接 App；SDK 接入后的 Release 编译/链接记录与产物隔离；网络诊断开启时重复验证缓存规则。 |
| 业务与 UI | 受影响的导航、登录、五域加载与操作回归；公共组件在独立体验与消费页面保持一致。 |
| E2E 与证据 | 明确 scheme、destination、测试身份与存储；remoteOnly 真实到达受控服务的证据；最终报告区分存量失败、新增失败与未验证范围。 |

单元测试使用注入的网络、存储、时钟与身份，不依赖真实账号或个人 Debug 设置；E2E 显式选择服务器与模式。W6 汇总各批的新鲜证据并更新架构记录。已认可的目标是上述规则的验收依据，本节本身不是实现完成证明。

## 组件测试与手动预览

本轮用户批准的平台调整是移除独立 iOS Baseline，组件自动化验证由 `WalkComponents` 中的 UITest 承担，手动预览统一从现有 DebugPanel 的「组件预览」进入。它是开发工具，不建立产品 Page，不改变上游 UI 对象、状态、Data 或 API 合同，也不删除根仓冻结原型。

DebugPanel 提供现有组件目录与已登记状态的选择、预览、返回和关闭；目录与 UITest 定向启动共用 `Walk/App/Debug/ComponentCatalog.swift` 及 `ComponentPreviewRootView.swift`，组件与样例仍使用对象共置的生产实现。UITest 的 `--component-preview` 只用于定向自动化，不作为另一套手动预览入口。未知组件或状态明确显示 unsupported，不回退 default；手动预览不覆盖宿主数据模式、服务器、会话或缓存，关闭后返回原调试面板。旧 `-WalkBaselineScenario` 与 `WALK_BASELINE_SCENARIO` 在 Debug 中显式报 `retiredKey`，不再解析场景或提供兼容宿主。

实施顺序为：先增加面板入口与退役构建入口的失败测试；迁出组件目录和普通业务测试所需数据；删除 Baseline 配置、场景宿主、专用 target/scheme、截图对比脚本及生产页面中的专用注入；接入面板入口；由 XcodeGen 更新工程；验证组件定向 UITest、面板预览往返、普通业务测试与平台结构。业务 fixture 只编入测试 target，不能通过删除业务断言代替解除依赖。保留当前未提交的组件样例共置改动。

本节是已批准的承载方案，不是验证通过证明；结果由本轮实际测试记录确认。

## Page 映射

| 总 UI Page ID | SwiftUI 承载 | 源码 |
|---|---|---|
| `PAGE-HOME` | `HomeView` | `Walk/Features/Home/HomeView.swift` |
| `PAGE-LOGIN` | `LoginView` | `Walk/Features/Profile/LoginView.swift` |
| `PAGE-ROUTES` | `RouteDiscoveryView` | `Walk/Features/Routes/RouteDiscoveryView.swift` |
| `PAGE-ROUTE-LIST` | `RouteCollectionView` | `Walk/Features/Routes/RouteDiscoveryView.swift` |
| `PAGE-SEARCH` | `RouteSearchView` | `Walk/Features/Routes/RouteDiscoveryView.swift` |
| `PAGE-ROUTE-DETAIL` | `RouteDetailView` | `Walk/Features/Routes/RouteDetailView.swift` |
| `PAGE-TRIP-CREATE` | `CreateTripView` | `Walk/Features/Trips/CreateTripView.swift` |
| `PAGE-TRIP-DETAIL` | `TripDetailView` | `Walk/Features/Trips/TripDetailView.swift` |
| `PAGE-TRIP-BROWSE` | `TripBrowseView` | `Walk/Features/Trips/TripBrowseView.swift` |
| `PAGE-TRIP-WEATHER` | `TripWeatherView` | `Walk/Features/Trips/TripDayWeatherViews.swift` |
| `PAGE-TRIP-EQUIPMENT` | `TripEquipmentView` | `Walk/Features/Trips/TripEquipment.swift` |
| `PAGE-TRIPS` | `TripListView` | `Walk/Features/Trips/TripListView.swift` |
| `PAGE-ME` | `ProfileView` | `Walk/Features/Profile/ProfileView.swift` |
| `PAGE-ACCOUNT-MENU` | `AccountMenuView` | `Walk/Features/Profile/AccountMenuView.swift` |
| `PAGE-MY-EQUIPMENT` | `EquipmentListView` | `Walk/Features/Equipment/EquipmentListView.swift` |
| `PAGE-EQUIPMENT-EDIT` | `EquipmentEditView` | `Walk/Features/Equipment/AddEquipmentView.swift` |

`PAGE-ROUTES` 与 `PAGE-ROUTE-LIST` 的空态路线图标在 iOS 映射为 SF Symbol `map`；平台无关语义名 `route` 不直接传入 `Image(systemName:)`。

`PAGE-ROUTES` 沉浸式分页承接根仓 Change `route-discovery-immersive-paging`：`RouteDiscoveryView` 以 SwiftUI 纵向 `ScrollView` 的原生 paging 承载整屏 RouteScene，页头作为固定覆盖层；分页内容延伸到系统 tab bar 之后。系统区域读取集中在 WalkDesignSystem 的 `immersiveSystemAreaContext`，RouteScene 只通过 `immersiveBottomContentPadding` 声明底部内容避让，不读取或接收物理 inset。结构验证入口为 `RouteDiscoveryPagerStructureTests` 与 `DesignSystemTests.testSafeAreaInsetHandlingLivesInSharedPageContainers`。

导航承载与 Page ID 转换位于 `Walk/App/RootNavigation.swift` 和 `Walk/App/RootView.swift`。它们只负责 iOS 导航，不拥有页面范围或跨页面业务结果。

二级导航行为统一（任务栈推入、唯一返回入口及其可见性、覆盖层边界）由根仓 Change `unify-navigation-behavior` 定义；iOS 承载决策：全部二级页复用根仓 `AppDestination` 路径推入，返回入口统一由 `dismiss` 语义承载，`routeListShowsBackEntry` 等返回可见性状态归入路径来源语义，不在各 Feature 页内自行决定返回行为。例外：`PAGE-LOGIN` 为 Modal 任务，由 `AppShellState.isLoginPresented` 驱动的 `fullScreenCover` 全屏承载，不进入任务栈。

二级页统一悬浮导航承载（承接根仓 Change `unify-secondary-page-navigation-and-titles`）：`UtilityNavigationHeader` 以悬浮形态承载（无固定底色与下边界线、`IconButton.overlay` 圆形返回、可选标题），全部任务栈二级页与 `PAGE-TRIP-DETAIL` 封面返回使用同一形态与顶部左上角统一位置；`PAGE-ROUTE-LIST` 返回可见性由到达方式决定（复用 `routeListShowsBackEntry`）；任务栈二级页不再输出宣传性 kicker（`PageTitleBlock` 不传 kicker），`PAGE-TRIPS` 正文不再重复页面标题块，页面标题只呈现一次。

### PAGE-ACCOUNT-MENU 承载登记（承接根仓 Change `revamp-account-settings-modal`）

- 模态承载：`AccountMenuView` 由 `AppShellState.isAccountMenuPresented` 驱动，在 `RootView` 以 overlay 呈现 `ModalBottomSheet`，不进入任何任务栈；不启用 Sheet 右上角 CloseAction。
- 关闭边界：`ModalBottomSheet` 支持向下拖拽跟手、超过关闭距离/速度关闭、未达阈值回位，且仅内容处于滚动顶部时接管拖动手势；遮罩点击与拖拽关闭共用同一 `onDismiss`。
- 设置项承接：设置主页 `AccountMenuView` 只承载入口；选择任一设置项（个人资料/通知/隐私/帮助与反馈/关于 Walk）由 `RootView.onNavigate` 先关闭菜单再推入我的页任务栈（`AppDestination.profileDetails/.notificationSettings/.privacySettings/.helpAndFeedback/.about` 均映射 `PAGE-ME`），返回经 `dismiss` 回到我的页；不新增 Page ID，二级内容合同由根仓 `PAGE-ACCOUNT-MENU/spec.md` 定义。
- 二级页壳：`SettingsDetailPage`（悬浮 `IconButton` 返回 + 内容区标题）与 `SurfaceElevated` / `EntrySettingsRow`（左右行 + `AppColors.surfaceDivider` 横线）位于 `Walk/Features/Profile/ProfileEntryPages.swift`；五个设置二级页共享同一生产内容实现。
- 头像更新：`ProfileViewModel.updateAvatar(data:contentType:)` 先上传头像媒体取得 `mediaReference` 再写入 Profile，成功刷新共享 `account.profile`；照片来源为系统相册（`photosPicker(isPresented:)`）。

## Component 映射

### 通用组件

| 总 UI Component ID | SwiftUI 承载 | 源码 |
|---|---|---|
| `avatar-button` | `AvatarButton` | `Packages/WalkDesignSystem/Sources/WalkDesignSystem/Components/SharedPrimitives.swift` |
| `card` | `WalkCard` | `Packages/WalkDesignSystem/Sources/WalkDesignSystem/Components/SharedPrimitives.swift` |
| `confirmation-dialog` | `ConfirmationDialog` | `Packages/WalkDesignSystem/Sources/WalkDesignSystem/Components/ConfirmationDialog.swift` |
| `content-section` | `ContentSection` | `Packages/WalkDesignSystem/Sources/WalkDesignSystem/Components/ContentSection.swift` |
| `danger-action` | `DangerAction` | `Packages/WalkDesignSystem/Sources/WalkDesignSystem/Components/SharedPrimitives.swift` |
| `date-input` | `DateInput` | `Packages/WalkDesignSystem/Sources/WalkDesignSystem/Components/DateInput.swift` |
| `empty-state` | `EmptyStateView` | `Packages/WalkDesignSystem/Sources/WalkDesignSystem/Components/EmptyStateView.swift` |
| `error-view` | `ErrorView` | `Packages/WalkDesignSystem/Sources/WalkDesignSystem/Components/ErrorView.swift` |
| `fixed-action-area` | `FixedActionArea` | `Packages/WalkDesignSystem/Sources/WalkDesignSystem/Components/SharedPrimitives.swift` |
| `form-field` | `FormField` | `Packages/WalkDesignSystem/Sources/WalkDesignSystem/Components/FormField.swift` |
| `icon-button` | `IconButton` | `Packages/WalkDesignSystem/Sources/WalkDesignSystem/Components/SharedPrimitives.swift` |
| `info-tag` | `InfoTag` | `Packages/WalkDesignSystem/Sources/WalkDesignSystem/Components/SharedPrimitives.swift` |
| `list-row` | `ListRow` | `Packages/WalkDesignSystem/Sources/WalkDesignSystem/Components/SharedPrimitives.swift` |
| `loading-state` | `LoadingView` | `Packages/WalkDesignSystem/Sources/WalkDesignSystem/Components/LoadingView.swift` |
| `metric-group` | `MetricGroup` | `Packages/WalkDesignSystem/Sources/WalkDesignSystem/Components/MetricGroup.swift` |
| `metric-item` | `MetricItem` | `Packages/WalkDesignSystem/Sources/WalkDesignSystem/Components/MetricItem.swift` |
| `mixed-page-shell` | `MixedPageShell` | `Packages/WalkDesignSystem/Sources/WalkDesignSystem/Components/MixedPageShell.swift` |
| `modal-bottom-sheet` | `ModalBottomSheet` | `Packages/WalkDesignSystem/Sources/WalkDesignSystem/Components/ModalBottomSheet.swift` |
| `notice` | `NoticeView` | `Packages/WalkDesignSystem/Sources/WalkDesignSystem/Components/SharedPrimitives.swift` |
| `page-title-block` | `PageTitleBlock` | `Packages/WalkDesignSystem/Sources/WalkDesignSystem/Components/SharedPrimitives.swift` |
| `panel` | `WalkPanel` | `Packages/WalkDesignSystem/Sources/WalkDesignSystem/Components/SharedPrimitives.swift` |
| `primary-action` | `PrimaryAction` | `Packages/WalkDesignSystem/Sources/WalkDesignSystem/Components/SharedPrimitives.swift` |
| `quantity-stepper` | `QuantityStepper` | `Packages/WalkDesignSystem/Sources/WalkDesignSystem/Components/SharedPrimitives.swift` |
| `search-field` | `SearchField` | `Packages/WalkDesignSystem/Sources/WalkDesignSystem/Components/SearchField.swift` |
| `secondary-action` | `SecondaryAction` | `Packages/WalkDesignSystem/Sources/WalkDesignSystem/Components/SharedPrimitives.swift` |
| `section-header` | `SectionHeader` | `Packages/WalkDesignSystem/Sources/WalkDesignSystem/Components/SharedPrimitives.swift` |
| `segmented-control` | `SegmentedControl` | `Packages/WalkDesignSystem/Sources/WalkDesignSystem/Components/SharedPrimitives.swift` |
| `select-input` | `SelectInput` | `Packages/WalkDesignSystem/Sources/WalkDesignSystem/Components/SelectInput.swift` |
| `selectable-option-card` | `SelectableOptionCard` | `Packages/WalkDesignSystem/Sources/WalkDesignSystem/Components/SharedPrimitives.swift` |
| `settings-list-row` | `SettingsListRow` | `Packages/WalkDesignSystem/Sources/WalkDesignSystem/Components/SettingsListRow.swift` |
| `sheet-handle` | `SheetHandle` | `Packages/WalkDesignSystem/Sources/WalkDesignSystem/Components/SharedPrimitives.swift` |
| `source-note` | `SourceNote` | `Packages/WalkDesignSystem/Sources/WalkDesignSystem/Components/SharedPrimitives.swift` |
| `text-input` | `TextInput` | `Packages/WalkDesignSystem/Sources/WalkDesignSystem/Components/TextInput.swift` |
| `timeline` | `Timeline` | `Packages/WalkDesignSystem/Sources/WalkDesignSystem/Components/SharedPrimitives.swift` |
| `unavailable-state` | `UnavailableStateView` | `Packages/WalkDesignSystem/Sources/WalkDesignSystem/Components/SharedPrimitives.swift` |
| `utility-navigation-header` | `UtilityNavigationHeader` | `Packages/WalkDesignSystem/Sources/WalkDesignSystem/Components/UtilityNavigationHeader.swift` |
| `utility-page` | `UtilityPage` | `Packages/WalkDesignSystem/Sources/WalkDesignSystem/Components/SharedPrimitives.swift` |

### 业务组件

| 总 UI Component ID | 层 | SwiftUI 承载 | 源码 |
|---|---|---|---|
| `auth-panel` | L2b 业务独立 | `AuthPanel` | `Walk/Features/Profile/Components/AuthPanel.swift` |
| `checklist-item-row` | L2b 业务独立 | `ChecklistItemRow` | `Walk/Features/Equipment/Components/ChecklistItemRow.swift` |
| `checklist-panel` | L2c 业务组合 | `ChecklistPanel` | `Walk/Features/Equipment/Components/ChecklistPanel.swift` |
| `daily-weather-card` | L2b 业务独立 | `DailyWeatherCard` | `Walk/Features/Trips/Components/DailyWeatherCard.swift` |
| `daily-weather-summary-row` | L2b 业务独立 | `DailyWeatherSummaryRow` | `Walk/Features/Trips/Components/DailyWeatherSummaryRow.swift` |
| `elevation-profile` | L2b 业务独立 | `ElevationProfile` | `Walk/Features/Routes/Components/ElevationProfile.swift` |
| `equipment-deletion-impact` | L2b 业务独立 | `EquipmentDeletionImpact` | `Walk/Features/Equipment/Components/EquipmentDeletionImpact.swift` |
| `equipment-list-row` | L2b 业务独立 | `EquipmentListRow` | `Walk/Features/Equipment/Components/EquipmentListRow.swift` |
| `focus-trip-summary` | L2b 业务独立 | `FocusTripSummary` | `Walk/Features/Home/Components/FocusTripSummary.swift` |
| `gear-ring` | L2a 业务原子 | `GearRing` | `Walk/Features/Trips/Components/GearRing.swift` |
| `generation-equipment-selection` | L2c 业务组合 | `GenerationEquipmentSelection` | `Walk/Features/Shared/Components/GenerationEquipmentSelection.swift` |
| `generation-route-summary-card` | L2b 业务独立 | `GenerationRouteSummaryCard` | `Walk/Features/Shared/Components/GenerationRouteSummaryCard.swift` |
| `generation-waiting-view` | L2b 业务独立 | `GenerationWaitingView` | `Walk/Features/Shared/Components/GenerationWaitingView.swift` |
| `inline-equipment-editor` | L2b 业务独立 | `InlineEquipmentEditor` | `Walk/Features/Shared/Components/InlineEquipmentEditor.swift` |
| `inline-list-name-editor` | L2b 业务独立 | `InlineListNameEditor` | `Walk/Features/Equipment/Components/InlineListNameEditor.swift` |
| `personal-equipment-form` | L2b 业务独立 | `PersonalEquipmentForm` | `Walk/Features/Equipment/Components/PersonalEquipmentForm.swift` |
| `personal-equipment-summary-card` | L2b 业务独立 | `PersonalEquipmentSummaryCard` | `Walk/Features/Shared/Components/PersonalEquipmentSummaryCard.swift` |
| `profile-identity-header` | L2b 业务独立 | `ProfileIdentityHeader` | `Walk/Features/Profile/Components/ProfileIdentityHeader.swift` |
| `route-fact-section` | L2b 业务独立 | `RouteFactSection` | `Walk/Features/Routes/Components/RouteFactSection.swift` |
| `route-image-gallery` | L2b 业务独立 | `RouteImageGallery` | `Walk/Features/Routes/Components/RouteImageGallery.swift` |
| `route-introduction` | L2b 业务独立 | `RouteIntroduction` | `Walk/Features/Routes/Components/RouteIntroduction.swift` |
| `route-list-row` | L2b 业务独立 | `RouteListRow` | `Walk/Features/Routes/Components/RouteListRow.swift` |
| `route-map` | L2b 业务独立 | `RouteMapView` | `Walk/Features/Routes/RouteMapView.swift` |
| `route-map-dock` | L2b 业务独立 | `RouteMapDock` | `Walk/Features/Routes/Components/RouteMapDock.swift` |
| `route-point-detail` | L2b 业务独立 | `RoutePointDetail` | `Walk/Features/Routes/Components/RoutePointDetail.swift` |
| `route-point-section` | L2b 业务独立 | `RoutePointSection` | `Walk/Features/Routes/Components/RoutePointSection.swift` |
| `route-reference-day-list` | L2b 业务独立 | `RouteReferenceDayList` | `Walk/Features/Routes/Components/RouteReferenceDayList.swift` |
| `route-scene` | L2b 业务独立 | `RouteScene` | `Walk/Features/Routes/Components/RouteScene.swift` |
| `route-segment-list` | L2b 业务独立 | `RouteSegmentList` | `Walk/Features/Routes/Components/RouteSegmentList.swift` |
| `route-span-card` | L2b 业务独立 | `RouteSpanCard` | `Walk/Features/Routes/Components/RouteSpanCard.swift` |
| `route-summary` | L2b 业务独立 | `RouteSummary` | `Walk/Features/Routes/Components/RouteSummary.swift` |
| `search-route-result-row` | L2b 业务独立 | `SearchRouteResultRow` | `Walk/Features/Routes/Components/SearchRouteResultRow.swift` |
| `transport-option-selection` | L2b 业务独立 | `TransportOptionSelection` | `Walk/Features/Shared/Components/TransportOptionSelection.swift` |
| `trek-day-badge` | L2a 业务原子 | `TrekDayBadge` | `Walk/Features/Trips/Components/TrekDayBadge.swift` |
| `trip-calendar-card` | L2b 业务独立 | `TripCalendarCard` | `Walk/Features/Shared/Components/TripCalendarCard.swift` |
| `trip-cover-header` | L2b 业务独立 | `TripCoverHeader` | `Walk/Features/Trips/Components/TripCoverHeader.swift` |
| `trip-expedition-scene` | L2b 业务独立 | `TripExpeditionScene` | `Walk/Features/Trips/Components/TripExpeditionScene.swift` |
| `trip-day-arrangement` | L2c 业务组合 | `TripDayArrangement` | `Walk/Features/Trips/Components/TripDayArrangement.swift` |
| `trip-day-overview-entry` | L2b 业务独立 | `TripDayOverviewEntry` | `Walk/Features/Trips/Components/TripDayOverviewEntry.swift` |
| `trip-equipment-gear-rings` | L2c 业务组合 | `TripEquipmentGearRings` | `Walk/Features/Trips/Components/TripEquipmentGearRings.swift` |
| `trip-equipment-item-row` | L2b 业务独立 | `TripEquipmentItemRow` | `Walk/Features/Trips/Components/TripEquipmentItemRow.swift` |
| `trip-equipment-overview` | L2b 业务独立 | `TripEquipmentOverview` | `Walk/Features/Trips/Components/TripEquipmentOverview.swift` |
| `trip-equipment-source-picker` | L2b 业务独立 | `TripEquipmentSourcePicker` | `Walk/Features/Trips/Components/TripEquipmentSourcePicker.swift` |
| `trip-equipment-summary-card` | L2c 业务组合 | `TripEquipmentSummaryCard` | `Walk/Features/Trips/Components/TripEquipmentSummaryCard.swift` |
| `trip-list-row` | L2b 业务独立 | `TripListRow` | `Walk/Features/Trips/Components/TripListRow.swift` |
| `trip-route-metrics-summary` | L2b 业务独立 | `TripRouteMetricsSummary` | `Walk/Features/Trips/Components/TripRouteMetricsSummary.swift` |
| `trip-route-summary-card` | L2b 业务独立 | `TripRouteSummaryCard` | `Walk/Features/Trips/Components/TripRouteSummaryCard.swift` |
| `trip-status-badge` | L2a 业务原子 | `TripStatusBadge` | `Walk/Features/Trips/TripStatusBadge.swift` |
| `trip-weather-summary-card` | L2c 业务组合 | `TripWeatherSummaryCard` | `Walk/Features/Trips/Components/TripWeatherSummaryCard.swift` |
| `trip-weather-trend-chart` | L2c 业务组合 | `TripWeatherTrendChart` | `Walk/Features/Trips/Components/TripWeatherTrendChart.swift` |
| `weather-overview` | L2b 业务独立 | `WeatherOverview` | `Packages/WalkData/Sources/WalkData/API/Trips/PersonalTripModels.swift` |
| `weather-summary` | L2a 业务原子 | `WeatherSummary` | `Walk/Features/Home/Components/WeatherSummary.swift` |

「层」对应根仓 `docs/ui/taxonomy.md` 的业务组件分层（L2a 业务原子 / L2b 业务独立 / L2c 业务组合），由总 UI 目录 `components/business/{atoms,components,composites}/` 的共置目录决定，本文件不另行归层。

## Token 映射

Token 承载家族位于 `Packages/WalkDesignSystem/Sources/WalkDesignSystem/Theme/`（`Color+App.swift`、`Font+App.swift`、`Spacing.swift`、`Radius.swift`、`Shadow.swift`）。

地图点位类别 Token（`mapKeyPoint`、`mapInterest`、`mapCamp`、`mapOvernight`、`mapWater`、`mapSupply`）与 `mapStart` 承接根仓 Change `add-map-point-category-tokens`，取值由 `DesignSystemTests` 逐项断言。Feature 源码（含业务组件目录）不得出现数值字面量颜色或裸字号，由 `DesignSystemTests` 强制。

**已知缺口**：其余 Token 尚未建立与总 UI Token 一一对应的逐项分区登记（历史版本的逐项表随旧规范结构一并移除）。逐项分区与配套测试列入后续平台符合性 Change，在此之前不得从近似颜色、字号或阴影推断符合。

## 变更流程

- 总规范变更：根仓 OpenSpec Change 批准后，本目录在 iOS 仓提交中引用该 Change ID 承接映射更新；
- 平台独有决策：直接修改本目录，只改「怎么承载」，不改「是什么」；
- 事实冲突：总规范优先；无法映射：停止端内扩展并回根仓立 Change。

## 验证

```bash
python3 scripts/tests/test_platform_spec_registry.py
```

平台实现的完整验收入口见「当前架构」。
