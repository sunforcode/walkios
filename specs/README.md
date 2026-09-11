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
| `avatar-button` | `AvatarButton` | `Walk/DesignSystem/Components/SharedPrimitives.swift` |
| `card` | `WalkCard` | `Walk/DesignSystem/Components/SharedPrimitives.swift` |
| `confirmation-dialog` | `ConfirmationDialog` | `Walk/DesignSystem/Components/ConfirmationDialog.swift` |
| `content-section` | `ContentSection` | `Walk/DesignSystem/Components/ContentSection.swift` |
| `danger-action` | `DangerAction` | `Walk/DesignSystem/Components/SharedPrimitives.swift` |
| `date-input` | `DateInput` | `Walk/DesignSystem/Components/Foundation/DateInput.swift` |
| `empty-state` | `EmptyStateView` | `Walk/DesignSystem/Components/EmptyStateView.swift` |
| `error-view` | `ErrorView` | `Walk/DesignSystem/Components/ErrorView.swift` |
| `fixed-action-area` | `FixedActionArea` | `Walk/DesignSystem/Components/SharedPrimitives.swift` |
| `form-field` | `FormField` | `Walk/DesignSystem/Components/FormField.swift` |
| `icon-button` | `IconButton` | `Walk/DesignSystem/Components/SharedPrimitives.swift` |
| `info-tag` | `InfoTag` | `Walk/DesignSystem/Components/SharedPrimitives.swift` |
| `list-row` | `ListRow` | `Walk/DesignSystem/Components/SharedPrimitives.swift` |
| `loading-state` | `LoadingView` | `Walk/DesignSystem/Components/LoadingView.swift` |
| `metric-group` | `MetricGroup` | `Walk/DesignSystem/Components/MetricGroup.swift` |
| `metric-item` | `MetricItem` | `Walk/DesignSystem/Components/MetricItem.swift` |
| `mixed-page-shell` | `MixedPageShell` | `Walk/DesignSystem/Components/Foundation/MixedPageShell.swift` |
| `modal-bottom-sheet` | `ModalBottomSheet` | `Walk/DesignSystem/Components/ModalBottomSheet.swift` |
| `notice` | `NoticeView` | `Walk/DesignSystem/Components/SharedPrimitives.swift` |
| `page-title-block` | `PageTitleBlock` | `Walk/DesignSystem/Components/SharedPrimitives.swift` |
| `panel` | `WalkPanel` | `Walk/DesignSystem/Components/SharedPrimitives.swift` |
| `primary-action` | `PrimaryAction` | `Walk/DesignSystem/Components/SharedPrimitives.swift` |
| `primary-tab-bar` | `PrimaryTabBar` | `Walk/DesignSystem/Components/PrimaryTabBar.swift` |
| `quantity-stepper` | `QuantityStepper` | `Walk/DesignSystem/Components/SharedPrimitives.swift` |
| `search-field` | `SearchField` | `Walk/DesignSystem/Components/SearchField.swift` |
| `secondary-action` | `SecondaryAction` | `Walk/DesignSystem/Components/SharedPrimitives.swift` |
| `section-header` | `SectionHeader` | `Walk/DesignSystem/Components/SharedPrimitives.swift` |
| `segmented-control` | `SegmentedControl` | `Walk/DesignSystem/Components/SharedPrimitives.swift` |
| `select-input` | `SelectInput` | `Walk/DesignSystem/Components/Foundation/SelectInput.swift` |
| `selectable-option-card` | `SelectableOptionCard` | `Walk/DesignSystem/Components/SharedPrimitives.swift` |
| `settings-list-row` | `SettingsListRow` | `Walk/DesignSystem/Components/Foundation/SettingsListRow.swift` |
| `sheet-handle` | `SheetHandle` | `Walk/DesignSystem/Components/SharedPrimitives.swift` |
| `source-note` | `SourceNote` | `Walk/DesignSystem/Components/SharedPrimitives.swift` |
| `text-input` | `TextInput` | `Walk/DesignSystem/Components/Foundation/TextInput.swift` |
| `timeline` | `Timeline` | `Walk/DesignSystem/Components/SharedPrimitives.swift` |
| `unavailable-state` | `UnavailableStateView` | `Walk/DesignSystem/Components/SharedPrimitives.swift` |
| `utility-navigation-header` | `UtilityNavigationHeader` | `Walk/DesignSystem/Components/UtilityNavigationHeader.swift` |
| `utility-page` | `UtilityPage` | `Walk/DesignSystem/Components/SharedPrimitives.swift` |

### 业务组件

| 总 UI Component ID | SwiftUI 承载 | 源码 |
|---|---|---|
| `account-menu-sheet` | `AccountMenuSheet` | `Walk/DesignSystem/BusinessComponents/AccountEquipment/AccountMenuSheet.swift` |
| `auth-panel` | `AuthPanel` | `Walk/DesignSystem/BusinessComponents/AccountEquipment/AuthPanel.swift` |
| `checklist-item-row` | `ChecklistItemRow` | `Walk/DesignSystem/BusinessComponents/AccountEquipment/ChecklistItemRow.swift` |
| `checklist-panel` | `ChecklistPanel` | `Walk/DesignSystem/BusinessComponents/AccountEquipment/ChecklistPanel.swift` |
| `daily-weather-card` | `DailyWeatherCard` | `Walk/DesignSystem/BusinessComponents/Trip/DailyWeatherCard.swift` |
| `elevation-profile` | `ElevationProfile` | `Walk/DesignSystem/BusinessComponents/Route/ElevationProfile.swift` |
| `equipment-deletion-impact` | `EquipmentDeletionImpact` | `Walk/DesignSystem/BusinessComponents/AccountEquipment/EquipmentDeletionImpact.swift` |
| `equipment-list-row` | `EquipmentListRow` | `Walk/DesignSystem/BusinessComponents/AccountEquipment/EquipmentListRow.swift` |
| `focus-trip-summary` | `FocusTripSummary` | `Walk/Features/Home/Components/FocusTripSummary.swift` |
| `generation-equipment-selection` | `GenerationEquipmentSelection` | `Walk/DesignSystem/BusinessComponents/Route/GenerationEquipmentSelection.swift` |
| `generation-route-summary-card` | `GenerationRouteSummaryCard` | `Walk/DesignSystem/BusinessComponents/Route/GenerationRouteSummaryCard.swift` |
| `generation-waiting-view` | `GenerationWaitingView` | `Walk/DesignSystem/BusinessComponents/Route/GenerationWaitingView.swift` |
| `inline-equipment-editor` | `InlineEquipmentEditor` | `Walk/DesignSystem/BusinessComponents/AccountEquipment/InlineEquipmentEditor.swift` |
| `inline-list-name-editor` | `InlineListNameEditor` | `Walk/DesignSystem/BusinessComponents/AccountEquipment/InlineListNameEditor.swift` |
| `personal-equipment-form` | `PersonalEquipmentForm` | `Walk/DesignSystem/BusinessComponents/AccountEquipment/PersonalEquipmentForm.swift` |
| `personal-equipment-summary-card` | `PersonalEquipmentSummaryCard` | `Walk/DesignSystem/BusinessComponents/AccountEquipment/PersonalEquipmentSummaryCard.swift` |
| `profile-identity-header` | `ProfileIdentityHeader` | `Walk/DesignSystem/BusinessComponents/AccountEquipment/ProfileIdentityHeader.swift` |
| `route-fact-section` | `RouteFactSection` | `Walk/DesignSystem/BusinessComponents/Route/RouteFactSection.swift` |
| `route-image-gallery` | `RouteImageGallery` | `Walk/DesignSystem/BusinessComponents/Route/RouteImageGallery.swift` |
| `route-introduction` | `RouteIntroduction` | `Walk/DesignSystem/BusinessComponents/Route/RouteIntroduction.swift` |
| `route-list-row` | `RouteListRow` | `Walk/DesignSystem/BusinessComponents/Route/RouteListRow.swift` |
| `route-map` | `RouteMap` | `Walk/DesignSystem/BusinessComponents/Route/RouteMap.swift` |
| `route-point-detail` | `RoutePointDetail` | `Walk/DesignSystem/BusinessComponents/Route/RoutePointDetail.swift` |
| `route-point-section` | `RoutePointSection` | `Walk/DesignSystem/BusinessComponents/Route/RoutePointSection.swift` |
| `route-reference-day-list` | `RouteReferenceDayList` | `Walk/DesignSystem/BusinessComponents/Route/RouteReferenceDayList.swift` |
| `route-scene` | `RouteScene` | `Walk/DesignSystem/BusinessComponents/Route/RouteScene.swift` |
| `route-segment-list` | `RouteSegmentList` | `Walk/DesignSystem/BusinessComponents/Route/RouteSegmentList.swift` |
| `route-summary` | `RouteSummary` | `Walk/DesignSystem/BusinessComponents/Route/RouteSummary.swift` |
| `search-route-result-row` | `SearchRouteResultRow` | `Walk/DesignSystem/BusinessComponents/Route/SearchRouteResultRow.swift` |
| `transport-option-selection` | `TransportOptionSelection` | `Walk/DesignSystem/BusinessComponents/Route/TransportOptionSelection.swift` |
| `trip-calendar-card` | `TripCalendarCard` | `Walk/DesignSystem/BusinessComponents/Trip/TripCalendarCard.swift` |
| `trip-cover-header` | `TripCoverHeader` | `Walk/DesignSystem/BusinessComponents/Trip/TripCoverHeader.swift` |
| `trip-day-arrangement` | `TripDayArrangement` | `Walk/DesignSystem/BusinessComponents/Trip/TripDayArrangement.swift` |
| `trip-day-summary-card` | `TripDaySummaryCard` | `Walk/DesignSystem/BusinessComponents/Trip/TripDaySummaryCard.swift` |
| `trip-equipment-item-row` | `TripEquipmentItemRow` | `Walk/DesignSystem/BusinessComponents/Trip/TripEquipmentItemRow.swift` |
| `trip-equipment-overview` | `TripEquipmentOverview` | `Walk/DesignSystem/BusinessComponents/Trip/TripEquipmentOverview.swift` |
| `trip-equipment-summary-card` | `TripEquipmentSummaryCard` | `Walk/DesignSystem/BusinessComponents/Trip/TripEquipmentSummaryCard.swift` |
| `trip-list-row` | `TripListRow` | `Walk/DesignSystem/BusinessComponents/Trip/TripListRow.swift` |
| `trip-route-metrics-summary` | `TripRouteMetricsSummary` | `Walk/DesignSystem/BusinessComponents/Trip/TripRouteMetricsSummary.swift` |
| `trip-route-summary-card` | `TripRouteSummaryCard` | `Walk/DesignSystem/BusinessComponents/Trip/TripRouteSummaryCard.swift` |
| `trip-route-version-card` | `TripRouteVersionCard` | `Walk/DesignSystem/BusinessComponents/Trip/TripRouteVersionCard.swift` |
| `trip-status-badge` | `TripStatusBadge` | `Walk/Features/Trips/TripStatusBadge.swift` |
| `trip-weather-summary-card` | `TripWeatherSummaryCard` | `Walk/DesignSystem/BusinessComponents/Trip/TripWeatherSummaryCard.swift` |
| `weather-overview` | `WeatherOverview` | `Walk/Core/Network/APIModels.swift` |
| `weather-summary` | `WeatherSummary` | `Walk/Features/Home/Components/WeatherSummary.swift` |

## Token 映射

Token 承载家族位于 `Walk/DesignSystem/Theme/`（`Color+App.swift`、`Font+App.swift`、`Spacing.swift`、`Radius.swift`、`Shadow.swift`）。

**已知缺口**：Token 尚未建立与总 UI Token 一一对应的逐项分区登记（历史版本的逐项表随旧规范结构一并移除）。逐项分区与配套测试列入后续平台符合性 Change，在此之前不得从近似颜色、字号或阴影推断符合。

## 变更流程

- 总规范变更：根仓 OpenSpec Change 批准后，本目录在 iOS 仓提交中引用该 Change ID 承接映射更新；
- 平台独有决策：直接修改本目录，只改「怎么承载」，不改「是什么」；
- 事实冲突：总规范优先；无法映射：停止端内扩展并回根仓立 Change。

## 验证

```bash
python3 scripts/tests/test_platform_spec_registry.py
```
