# Walk iOS 平台规范

本目录是 Walk 总规范在 iOS 上的**唯一平台规范入口**，只记录承载方式与实现差距，不记录产品事实。

## 上游权威

按以下顺序读取根协调仓 `walk/` 中的总规范（相对本文件解析）：

1. [总规范入口](../../docs/README.md) 与 [PRD](../../docs/prd.md)；
2. [平台无关行为 Spec](../../openspec/specs/)；
3. [Data](../../docs/data/)、[API](../../docs/api/)、[UI](../../docs/ui/index.md)。

本目录不是独立产品事实来源。总规范与本目录冲突时，总规范优先。

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

## Page 映射

| 总 UI Page ID | SwiftUI 承载 | 源码 |
|---|---|---|
| `PAGE-LOGIN` | `LoginView` | `Walk/Features/Profile/LoginView.swift` |
| `PAGE-HOME` | `HomeView` | `Walk/Features/Home/HomeView.swift` |
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
| `page-shell` | `PageShell` | `Packages/WalkDesignSystem/Sources/WalkDesignSystem/Components/SharedPrimitives.swift` |
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
| `elevation-profile` | L2b 业务独立 | `ElevationProfile` | `Walk/Features/Routes/Components/ElevationProfile.swift` |
| `equipment-deletion-impact` | L2b 业务独立 | `EquipmentDeletionImpact` | `Walk/Features/Equipment/Components/EquipmentDeletionImpact.swift` |
| `equipment-list-row` | L2b 业务独立 | `EquipmentListRow` | `Walk/Features/Equipment/Components/EquipmentListRow.swift` |
| `focus-trip-summary` | L2b 业务独立 | `FocusTripSummary` | `Walk/Features/Home/Components/FocusTripSummary.swift` |
| `gear-ring` | L2a 业务原子 | `GearRing` | `Walk/Features/Trips/Components/GearRing.swift` |
| `generation-equipment-selection` | L2c 业务组合 | `GenerationEquipmentSelection` | `Walk/Features/Routes/Components/GenerationEquipmentSelection.swift` |
| `generation-route-summary-card` | L2b 业务独立 | `GenerationRouteSummaryCard` | `Walk/Features/Routes/Components/GenerationRouteSummaryCard.swift` |
| `generation-waiting-view` | L2b 业务独立 | `GenerationWaitingView` | `Walk/Features/Routes/Components/GenerationWaitingView.swift` |
| `inline-equipment-editor` | L2b 业务独立 | `InlineEquipmentEditor` | `Walk/Features/Trips/Components/InlineEquipmentEditor.swift` |
| `inline-list-name-editor` | L2b 业务独立 | `InlineListNameEditor` | `Walk/Features/Equipment/Components/InlineListNameEditor.swift` |
| `personal-equipment-form` | L2b 业务独立 | `PersonalEquipmentForm` | `Walk/Features/Equipment/Components/PersonalEquipmentForm.swift` |
| `personal-equipment-summary-card` | L2b 业务独立 | `PersonalEquipmentSummaryCard` | `Walk/Features/Profile/Components/PersonalEquipmentSummaryCard.swift` |
| `profile-identity-header` | L2b 业务独立 | `ProfileIdentityHeader` | `Walk/Features/Profile/Components/ProfileIdentityHeader.swift` |
| `route-fact-section` | L2b 业务独立 | `RouteFactSection` | `Walk/Features/Routes/Components/RouteFactSection.swift` |
| `route-image-gallery` | L2b 业务独立 | `RouteImageGallery` | `Walk/Features/Routes/Components/RouteImageGallery.swift` |
| `route-introduction` | L2b 业务独立 | `RouteIntroduction` | `Walk/Features/Routes/Components/RouteIntroduction.swift` |
| `route-list-row` | L2b 业务独立 | `RouteListRow` | `Packages/WalkDesignSystem/Sources/WalkDesignSystem/Components/SharedPrimitives.swift` |
| `route-map` | L2b 业务独立 | `RouteMap` | `Walk/Features/Routes/Components/RouteMap.swift` |
| `route-map-dock` | L2b 业务独立 | `RouteMapDock` | `Walk/Features/Routes/Components/RouteMapDock.swift` |
| `route-point-detail` | L2b 业务独立 | `RoutePointDetail` | `Walk/Features/Routes/Components/RoutePointDetail.swift` |
| `route-point-section` | L2b 业务独立 | `RoutePointSection` | `Walk/Features/Routes/Components/RoutePointSection.swift` |
| `route-reference-day-list` | L2b 业务独立 | `RouteReferenceDayList` | `Walk/Features/Routes/Components/RouteReferenceDayList.swift` |
| `route-scene` | L2b 业务独立 | `RouteScene` | `Walk/Features/Routes/Components/RouteScene.swift` |
| `route-segment-list` | L2b 业务独立 | `RouteSegmentList` | `Walk/Features/Routes/Components/RouteSegmentList.swift` |
| `route-span-card` | L2b 业务独立 | `RouteSpanCard` | `Walk/Features/Routes/Components/RouteSpanCard.swift` |
| `route-summary` | L2b 业务独立 | `RouteSummary` | `Walk/Features/Routes/Components/RouteSummary.swift` |
| `search-route-result-row` | L2b 业务独立 | `SearchRouteResultRow` | `Walk/Features/Routes/Components/SearchRouteResultRow.swift` |
| `transport-option-selection` | L2b 业务独立 | `TransportOptionSelection` | `Walk/Features/Routes/Components/TransportOptionSelection.swift` |
| `trek-day-badge` | L2a 业务原子 | `TrekDayBadge` | `Walk/Features/Trips/Components/TrekDayBadge.swift` |
| `trip-calendar-card` | L2b 业务独立 | `TripCalendarCard` | `Walk/Features/Trips/Components/TripCalendarCard.swift` |
| `trip-cover-header` | L2b 业务独立 | `TripCoverHeader` | `Walk/Features/Trips/Components/TripCoverHeader.swift` |
| `trip-day-arrangement` | L2c 业务组合 | `TripDayArrangement` | `Walk/Features/Trips/Components/TripDayArrangement.swift` |
| `trip-day-overview-entry` | L2b 业务独立 | `TripDayOverviewEntry` | `Walk/Features/Trips/Components/TripDayOverviewEntry.swift` |
| `trip-equipment-gear-rings` | L2c 业务组合 | `TripEquipmentGearRings` | `Walk/Features/Trips/Components/TripEquipmentGearRings.swift` |
| `trip-equipment-item-row` | L2b 业务独立 | `TripEquipmentItemRow` | `Walk/Features/Trips/Components/TripEquipmentItemRow.swift` |
| `trip-equipment-overview` | L2b 业务独立 | `TripEquipmentOverview` | `Walk/Features/Trips/Components/TripEquipmentOverview.swift` |
| `trip-equipment-summary-card` | L2c 业务组合 | `TripEquipmentSummaryCard` | `Walk/Features/Trips/Components/TripEquipmentSummaryCard.swift` |
| `trip-list-row` | L2b 业务独立 | `TripListRow` | `Walk/Features/Trips/Components/TripListRow.swift` |
| `trip-route-metrics-summary` | L2b 业务独立 | `TripRouteMetricsSummary` | `Walk/Features/Trips/Components/TripRouteMetricsSummary.swift` |
| `trip-route-summary-card` | L2b 业务独立 | `TripRouteSummaryCard` | `Walk/Features/Trips/Components/TripRouteSummaryCard.swift` |
| `trip-route-version-card` | L2b 业务独立 | `TripRouteVersionCard` | `Walk/Features/Trips/Components/TripRouteVersionCard.swift` |
| `trip-status-badge` | L2a 业务原子 | `TripStatusBadge` | `Walk/Features/Trips/TripStatusBadge.swift` |
| `trip-weather-summary-card` | L2c 业务组合 | `TripWeatherSummaryCard` | `Walk/Features/Trips/Components/TripWeatherSummaryCard.swift` |
| `trip-weather-trend-chart` | L2c 业务组合 | `TripWeatherTrendChart` | `Walk/Features/Trips/Components/TripWeatherTrendChart.swift` |
| `weather-overview` | L2b 业务独立 | `WeatherOverview` | `Packages/WalkData/Sources/WalkData/API/Trips/PersonalTripModels.swift` |
| `weather-summary` | L2a 业务原子 | `WeatherSummary` | `Walk/Features/Home/Components/WeatherSummary.swift` |

「层」对应根仓 `docs/ui/taxonomy.md` 的业务组件分层（L2a 业务原子 / L2b 业务独立 / L2c 业务组合），由总 UI 目录 `components/business/{atoms,components,composites}/` 的共置目录决定，本文件不另行归层。

## Token 映射

Token 承载家族位于 `Packages/WalkDesignSystem/Sources/WalkDesignSystem/Theme/`（`Color+App.swift`、`Font+App.swift`、`Spacing.swift`、`Radius.swift`、`Shadow.swift`）。

**已知缺口**：Token 尚未建立与总 UI Token 一一对应的逐项分区登记（历史版本的逐项表随旧规范结构一并移除）。逐项分区与配套测试列入后续平台符合性 Change，在此之前不得从近似颜色、字号或阴影推断符合。

## 变更流程

- 总规范变更：根仓 OpenSpec Change 批准后，本目录在 iOS 仓提交中引用该 Change ID 承接映射更新；
- 平台独有决策：直接修改本目录，只改「怎么承载」，不改「是什么」；
- 事实冲突：总规范优先；无法映射：停止端内扩展并回根仓立 Change。

## 验证

```bash
python3 scripts/tests/test_platform_spec_registry.py
```
