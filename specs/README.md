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
| `PAGE-TRIP-DAY` | `TripDayView` | `Walk/Features/Trips/TripDayWeatherViews.swift` |
| `PAGE-TRIP-WEATHER` | `TripWeatherView` | `Walk/Features/Trips/TripDayWeatherViews.swift` |
| `PAGE-TRIP-EQUIPMENT` | `TripEquipmentView` | `Walk/Features/Trips/TripEquipment.swift` |
| `PAGE-TRIPS` | `TripListView` | `Walk/Features/Trips/TripListView.swift` |
| `PAGE-ME` | `ProfileView` | `Walk/Features/Profile/ProfileView.swift` |
| `PAGE-MY-EQUIPMENT` | `EquipmentListView` | `Walk/Features/Equipment/EquipmentListView.swift` |
| `PAGE-EQUIPMENT-EDIT` | `EquipmentEditView` | `Walk/Features/Equipment/AddEquipmentView.swift` |

导航承载与 Page ID 转换位于 `Walk/App/RootNavigation.swift` 和 `Walk/App/RootView.swift`。它们只负责 iOS 导航，不拥有页面范围或跨页面业务结果。

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
| `primary-tab-bar` | `PrimaryTabBar` | `Packages/WalkDesignSystem/Sources/WalkDesignSystem/Components/PrimaryTabBar.swift` |
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
| `account-menu-sheet` | L2b 业务独立 | `AccountMenuSheet` | `Walk/Features/Profile/Components/AccountMenuSheet.swift` |
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
| `route-point-detail` | L2b 业务独立 | `RoutePointDetail` | `Walk/Features/Routes/Components/RoutePointDetail.swift` |
| `route-point-section` | L2b 业务独立 | `RoutePointSection` | `Walk/Features/Routes/Components/RoutePointSection.swift` |
| `route-reference-day-list` | L2b 业务独立 | `RouteReferenceDayList` | `Walk/Features/Routes/Components/RouteReferenceDayList.swift` |
| `route-scene` | L2b 业务独立 | `RouteScene` | `Walk/Features/Routes/Components/RouteScene.swift` |
| `route-segment-list` | L2b 业务独立 | `RouteSegmentList` | `Walk/Features/Routes/Components/RouteSegmentList.swift` |
| `route-summary` | L2b 业务独立 | `RouteSummary` | `Walk/Features/Routes/Components/RouteSummary.swift` |
| `search-route-result-row` | L2b 业务独立 | `SearchRouteResultRow` | `Walk/Features/Routes/Components/SearchRouteResultRow.swift` |
| `transport-option-selection` | L2b 业务独立 | `TransportOptionSelection` | `Walk/Features/Routes/Components/TransportOptionSelection.swift` |
| `trek-day-badge` | L2a 业务原子 | `TrekDayBadge` | `Walk/Features/Trips/Components/TrekDayBadge.swift` |
| `trip-calendar-card` | L2b 业务独立 | `TripCalendarCard` | `Walk/Features/Trips/Components/TripCalendarCard.swift` |
| `trip-cover-header` | L2b 业务独立 | `TripCoverHeader` | `Walk/Features/Trips/Components/TripCoverHeader.swift` |
| `trip-day-arrangement` | L2c 业务组合 | `TripDayArrangement` | `Walk/Features/Trips/Components/TripDayArrangement.swift` |
| `trip-day-hike-summary` | L2c 业务组合 | `TripDayHikeSummary` | `Walk/Features/Trips/Components/TripDayHikeSummary.swift` |
| `trip-day-summary-card` | L2c 业务组合 | `TripDaySummaryCard` | `Walk/Features/Trips/Components/TripDaySummaryCard.swift` |
| `trip-day-transport-summary` | L2c 业务组合 | `TripDayTransportSummary` | `Walk/Features/Trips/Components/TripDayTransportSummary.swift` |
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
