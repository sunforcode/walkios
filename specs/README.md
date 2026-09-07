# Walk iOS 平台规范

本目录只记录 Walk 总规范在 iOS 上的映射、平台约束和验证方式。

## 上游权威

按以下顺序读取根协调仓中的总规范：

1. `../../app/prd.md`
2. `../../app/specs/`
3. `../../app/data/`
4. `../../app/api/`
5. `../../app/ui/`

本目录不是独立产品事实来源。总规范与 iOS 规范冲突时，总规范优先。

## 可以定义

- Data 到 Swift Model 的映射；
- API 到客户端请求、响应和错误模型的映射；
- Page、Component、Token 到 SwiftUI 的映射；
- iOS 导航承载、生命周期、系统权限和平台适配；
- Dynamic Type、VoiceOver、安全区等平台要求；
- fixture、测试入口、验证方法和当前实现差距。

## 不得定义

- 新的产品范围或业务行为；
- 新的数据事实、枚举或 API 字段；
- 总 UI 中不存在的页面、组件、文案或可见状态；
- 与总规范不同的资格、状态流转或错误语义；
- 用默认值、Mock、兼容分支或现有代码反向补齐总规范。

如果总规范缺少 iOS 实现所需决策，应停止端内扩展并回到根 `app/` 的正确权威层提出变更。

## 当前 Page 映射

下表只登记当前 Page ID 到实际 SwiftUI 承载类型与源码文件的映射，不改变页面合同。一个 Swift 文件可以承载多个相关 Page，但每个 Page ID 只能在本表出现一次。

| Page ID | SwiftUI 承载 | 源码 |
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

## 当前共享 Component 映射

下表只登记已经能从当前源码确认的共享组件实现。每个总 UI Component ID 只登记一次；无法确认独立承载的 ID 放入后续“映射缺口”，不得把近似实现冒充为已符合。

| 总 UI Component ID | SwiftUI 承载 | 源码 |
|---|---|---|
| `UtilityPage.default` | `UtilityPage` | `Walk/DesignSystem/Components/SharedPrimitives.swift` |
| `UtilityNavigationHeader.default` | `UtilityNavigationHeader` | `Walk/DesignSystem/Components/SharedPrimitives.swift` |
| `PageTitleBlock.default` | `PageTitleBlock` | `Walk/DesignSystem/Components/SharedPrimitives.swift` |
| `IconButton.default` | `IconButton(.default)` | `Walk/DesignSystem/Components/SharedPrimitives.swift` |
| `IconButton.overlay` | `IconButton(.overlay)`、`GlassIconButton` | `Walk/DesignSystem/Components/SharedPrimitives.swift` |
| `IconButton.compactClose` | `IconButton(.compactClose)` | `Walk/DesignSystem/Components/SharedPrimitives.swift` |
| `PrimaryAction.default` | `PrimaryAction(.default)` | `Walk/DesignSystem/Components/SharedPrimitives.swift` |
| `PrimaryAction.compact` | `PrimaryAction(.compact)` | `Walk/DesignSystem/Components/SharedPrimitives.swift` |
| `SecondaryAction.default` | `SecondaryAction(.default)` | `Walk/DesignSystem/Components/SharedPrimitives.swift` |
| `SecondaryAction.inline` | `SecondaryAction(.inline)` | `Walk/DesignSystem/Components/SharedPrimitives.swift` |
| `SecondaryAction.overlayCompact` | `SecondaryAction(.overlayCompact)` | `Walk/DesignSystem/Components/SharedPrimitives.swift` |
| `DangerAction.default` | `DangerAction` | `Walk/DesignSystem/Components/SharedPrimitives.swift` |
| `Panel.default` | `WalkPanel(.default)` | `Walk/DesignSystem/Components/SharedPrimitives.swift` |
| `Panel.glass` | `WalkPanel(.glass)` | `Walk/DesignSystem/Components/SharedPrimitives.swift` |
| `Panel.edgeAttached` | `WalkPanel(.edgeAttached)` | `Walk/DesignSystem/Components/SharedPrimitives.swift` |
| `Panel.section` | `WalkPanel(.section)` | `Walk/DesignSystem/Components/SharedPrimitives.swift` |
| `Panel.bottomOverlay` | `WalkPanel(.bottomOverlay)` | `Walk/DesignSystem/Components/SharedPrimitives.swift` |
| `Card.readonly` | `WalkCard(.default)` | `Walk/DesignSystem/Components/SharedPrimitives.swift` |
| `Card.navigation` | `WalkCard(.default)` + 外层单一导航动作 | `Walk/DesignSystem/Components/SharedPrimitives.swift` |
| `Card.selectable` | `WalkCard(.selectable)` | `Walk/DesignSystem/Components/SharedPrimitives.swift` |
| `SelectableOptionCard.default` | `SelectableOptionCard` | `Walk/DesignSystem/Components/SharedPrimitives.swift` |
| `ContentSection.default` | `ContentSection` | `Walk/DesignSystem/Components/SharedPrimitives.swift` |
| `SectionHeader.default` | `SectionHeader` | `Walk/DesignSystem/Components/SharedPrimitives.swift` |
| `FixedActionArea.default` | `FixedActionArea` | `Walk/DesignSystem/Components/SharedPrimitives.swift` |
| `ListRow.default` | `ListRow` | `Walk/DesignSystem/Components/SharedPrimitives.swift` |
| `RouteListRow.compact` | `RouteListRow` | `Walk/DesignSystem/Components/SharedPrimitives.swift` |
| `FormField.default` | `FormField` | `Walk/DesignSystem/Components/SharedPrimitives.swift` |
| `SearchField.default` | `SearchField` | `Walk/DesignSystem/Components/SharedPrimitives.swift` |
| `SegmentedControl.default` | `SegmentedControl` | `Walk/DesignSystem/Components/SharedPrimitives.swift` |
| `InfoTag.neutral` | `InfoTag(.neutral)` | `Walk/DesignSystem/Components/SharedPrimitives.swift` |
| `InfoTag.info` | `InfoTag(.info)` | `Walk/DesignSystem/Components/SharedPrimitives.swift` |
| `InfoTag.warning` | `InfoTag(.warning)` | `Walk/DesignSystem/Components/SharedPrimitives.swift` |
| `InfoTag.overlay` | `InfoTag(.overlay)` | `Walk/DesignSystem/Components/SharedPrimitives.swift` |
| `Notice.info` | `NoticeView(.info)` | `Walk/DesignSystem/Components/SharedPrimitives.swift` |
| `Notice.warning` | `NoticeView(.warning)` | `Walk/DesignSystem/Components/SharedPrimitives.swift` |
| `Notice.stale` | `NoticeView(.stale)` | `Walk/DesignSystem/Components/SharedPrimitives.swift` |
| `Notice.danger` | `NoticeView(.danger)` | `Walk/DesignSystem/Components/SharedPrimitives.swift` |
| `Notice.readonly` | `NoticeView(.readonly)` | `Walk/DesignSystem/Components/SharedPrimitives.swift` |
| `UnavailableState.page` | `UnavailableStateView(.page)` | `Walk/DesignSystem/Components/SharedPrimitives.swift` |
| `UnavailableState.inline` | `UnavailableStateView(.section)` | `Walk/DesignSystem/Components/SharedPrimitives.swift` |
| `Timeline.default` | `Timeline`、`TimelineItem` | `Walk/DesignSystem/Components/SharedPrimitives.swift` |
| `DailyWeatherCard.readonly` | `DailyWeatherCard` | `Walk/DesignSystem/Components/SharedPrimitives.swift` |
| `SourceNote.default` | `SourceNote` | `Walk/DesignSystem/Components/SharedPrimitives.swift` |
| `SheetHandle.default` | `SheetHandle` | `Walk/DesignSystem/Components/SharedPrimitives.swift` |
| `ModalBottomSheet.default` | `ProfileSheet` | `Walk/DesignSystem/Components/SharedPrimitives.swift` |
| `AvatarButton.pageHeader` | `AvatarButton(.pageHeader)` | `Walk/DesignSystem/Components/SharedPrimitives.swift` |
| `AvatarButton.panelHeader` | `AvatarButton(.panelHeader)` | `Walk/DesignSystem/Components/SharedPrimitives.swift` |
| `ProfileIdentityHeader.default` | `ProfileIdentityHeader` | `Walk/DesignSystem/Components/SharedPrimitives.swift` |
| `HeatmapCalendar.default` | `HeatmapCalendar` | `Walk/DesignSystem/Components/SharedPrimitives.swift` |
| `ChecklistPanel.default` | `Checklist` | `Walk/DesignSystem/Components/SharedPrimitives.swift` |
| `QuantityStepper.default` | `QuantityStepper` | `Walk/DesignSystem/Components/SharedPrimitives.swift` |
| `ConfirmationDialog.normal` | `ConfirmationDialog(.normal)` | `Walk/DesignSystem/Components/SharedPrimitives.swift` |
| `ConfirmationDialog.discard` | `ConfirmationDialog(.discard)` | `Walk/DesignSystem/Components/SharedPrimitives.swift` |
| `ConfirmationDialog.danger` | `ConfirmationDialog(.danger)` | `Walk/DesignSystem/Components/SharedPrimitives.swift` |
| `EmptyState.default` | `EmptyStateView(.default)` | `Walk/DesignSystem/Components/EmptyStateView.swift` |
| `EmptyState.compactText` | `EmptyStateView(.compactText)` | `Walk/DesignSystem/Components/EmptyStateView.swift` |
| `EmptyState.section` | `EmptyStateView(.section)` | `Walk/DesignSystem/Components/EmptyStateView.swift` |
| `LoadingState.page` | `LoadingView(.page)` | `Walk/DesignSystem/Components/LoadingView.swift` |
| `LoadingState.section` | `LoadingView(.section)` | `Walk/DesignSystem/Components/LoadingView.swift` |
| `LoadingState.rowSkeleton` | `LoadingView(.rowSkeleton)` | `Walk/DesignSystem/Components/LoadingView.swift` |
| `ErrorView.page` | `ErrorView(.page)` | `Walk/DesignSystem/Components/ErrorView.swift` |
| `ErrorView.section` | `ErrorView(.section)` | `Walk/DesignSystem/Components/ErrorView.swift` |
| `ErrorView.form` | `ErrorView(.form)`、`LocalErrorView` | `Walk/DesignSystem/Components/ErrorView.swift` |
| `MetricGroup.inline` | `MetricGroup` | `Walk/Features/Home/HomeView.swift` |
| `MetricGroup.grid` | `MetricGroup` | `Walk/Features/Home/HomeView.swift` |
| `MetricItem.inlineCompact` | `MetricItem(.inlineCompact)` | `Walk/Features/Home/HomeView.swift` |
| `MetricItem.gridCompact` | `MetricItem(.gridCompact)` | `Walk/Features/Home/HomeView.swift` |
| `MetricItem.default` | `MetricItem(.default)` | `Walk/Features/Home/HomeView.swift` |
| `WeatherSummary.compact` | `WeatherSummary` | `Walk/Features/Home/HomeView.swift` |
| `TripStatusBadge.planning` | `TripStatusBadge(.planned)` | `Walk/Features/Trips/TripStatusBadge.swift` |
| `TripStatusBadge.progress` | `TripStatusBadge(.inProgress)` | `Walk/Features/Trips/TripStatusBadge.swift` |
| `TripStatusBadge.completed` | `TripStatusBadge(.completed)` | `Walk/Features/Trips/TripStatusBadge.swift` |
| `TripStatusBadge.cancelled` | `TripStatusBadge(.cancelled)` | `Walk/Features/Trips/TripStatusBadge.swift` |
| `EquipmentListRow.personalAsset` | `PersonalEquipmentRow` | `Walk/Features/Equipment/EquipmentListView.swift` |
| `ChecklistItemRow.default` | `EquipmentListMemberRow` | `Walk/Features/Equipment/EquipmentListView.swift` |

### 映射缺口

以下 Component ID 尚未能从当前源码确认独立且完整的 SwiftUI 承载；它们是后续内容或平台符合性 Change 的输入，不在本次结构 Change 中补实现：

- `PrimaryTabBar.default`
- `MixedPageShell.default`
- `TripListRow.summary`
- `EquipmentListRow.tripSnapshot`
- `SettingsListRow.default`
- `TextInput.default`
- `DateInput.default`
- `SelectInput.default`
- `SceneLoadingState.default`
- `SceneErrorState.default`

## Token 映射

Token 采用逐项分区：每个总 UI Token 必须且只能出现在“已映射 Token”或“Token 映射缺口”之一。已映射只表示当前源码存在可确认的命名承载，不表示页面和组件已经通过内容符合性验收；近似颜色、字号或阴影不得冒充符合。

### 已映射 Token

| 类别 | 总 UI Token | iOS 承载 | 源码 |
|---|---|---|---|
| Color | `color.page.base` | `AppColors.pageBase` | `Walk/DesignSystem/Theme/Color+App.swift` |
| Color | `color.page.mid` | `AppColors.pageMiddle` | `Walk/DesignSystem/Theme/Color+App.swift` |
| Color | `color.page.outer` | `AppColors.pageOuter` | `Walk/DesignSystem/Theme/Color+App.swift` |
| Color | `color.surface.primary` | `AppColors.surfacePrimary` | `Walk/DesignSystem/Theme/Color+App.swift` |
| Color | `color.surface.elevated` | `AppColors.surfaceElevated` | `Walk/DesignSystem/Theme/Color+App.swift` |
| Color | `color.surface.clear` | `Color.clear` | `Walk/DesignSystem/Theme/Color+App.swift` |
| Color | `color.surface.glass` | `AppColors.surfaceGlass` | `Walk/DesignSystem/Theme/Color+App.swift` |
| Color | `color.surface.input` | `AppColors.surfaceInput` | `Walk/DesignSystem/Theme/Color+App.swift` |
| Color | `color.surface.divider` | `AppColors.surfaceDivider` | `Walk/DesignSystem/Theme/Color+App.swift` |
| Color | `color.surface.overlay` | `AppColors.surfaceOverlay` | `Walk/DesignSystem/Theme/Color+App.swift` |
| Color | `color.surface.toast` | `AppColors.surfaceToast` | `Walk/DesignSystem/Theme/Color+App.swift` |
| Color | `color.border.primary` | `AppColors.borderPrimary` | `Walk/DesignSystem/Theme/Color+App.swift` |
| Color | `color.border.strong` | `AppColors.borderStrong` | `Walk/DesignSystem/Theme/Color+App.swift` |
| Color | `color.text.primary` | `AppColors.textPrimary` | `Walk/DesignSystem/Theme/Color+App.swift` |
| Color | `color.text.secondary` | `AppColors.textSecondary` | `Walk/DesignSystem/Theme/Color+App.swift` |
| Color | `color.text.weak` | `AppColors.textWeak` | `Walk/DesignSystem/Theme/Color+App.swift` |
| Color | `color.interaction.primary` | `AppColors.interactionPrimary` | `Walk/DesignSystem/Theme/Color+App.swift` |
| Color | `color.interaction.background` | `AppColors.interactionBackground` | `Walk/DesignSystem/Theme/Color+App.swift` |
| Color | `color.interaction.focus` | `AppColors.interactionFocus` | `Walk/DesignSystem/Theme/Color+App.swift` |
| Color | `color.status.planning` | `AppColors.statusPlanning` | `Walk/DesignSystem/Theme/Color+App.swift` |
| Color | `color.status.planning.background` | `AppColors.statusPlanningBackground` | `Walk/DesignSystem/Theme/Color+App.swift` |
| Color | `color.status.progress` | `AppColors.statusProgress` | `Walk/DesignSystem/Theme/Color+App.swift` |
| Color | `color.status.progress.background` | `AppColors.statusProgressBackground` | `Walk/DesignSystem/Theme/Color+App.swift` |
| Color | `color.status.completed` | `AppColors.statusCompleted` | `Walk/DesignSystem/Theme/Color+App.swift` |
| Color | `color.status.completed.background` | `AppColors.statusCompletedBackground` | `Walk/DesignSystem/Theme/Color+App.swift` |
| Color | `color.status.cancelled` | `AppColors.statusCancelled` | `Walk/DesignSystem/Theme/Color+App.swift` |
| Color | `color.status.cancelled.background` | `AppColors.statusCancelledBackground` | `Walk/DesignSystem/Theme/Color+App.swift` |
| Color | `color.info` | `AppColors.info` | `Walk/DesignSystem/Theme/Color+App.swift` |
| Color | `color.info.background` | `AppColors.infoBackground` | `Walk/DesignSystem/Theme/Color+App.swift` |
| Color | `color.warning` | `AppColors.warning` | `Walk/DesignSystem/Theme/Color+App.swift` |
| Color | `color.warning.background` | `AppColors.warningBackground` | `Walk/DesignSystem/Theme/Color+App.swift` |
| Color | `color.danger` | `AppColors.danger` | `Walk/DesignSystem/Theme/Color+App.swift` |
| Color | `color.danger.background` | `AppColors.dangerBackground` | `Walk/DesignSystem/Theme/Color+App.swift` |
| Color | `color.map.route` | `AppColors.mapRoute` | `Walk/DesignSystem/Theme/Color+App.swift` |
| Color | `color.map.start` | `AppColors.mapStart` | `Walk/DesignSystem/Theme/Color+App.swift` |
| Color | `color.map.end` | `AppColors.mapEnd` | `Walk/DesignSystem/Theme/Color+App.swift` |
| Color | `color.map.waypoint` | `AppColors.mapWaypoint` | `Walk/DesignSystem/Theme/Color+App.swift` |
| Color | `color.map.poi` | `AppColors.mapPOI` | `Walk/DesignSystem/Theme/Color+App.swift` |
| Typography | `font.hero.title` | `AppTypography.heroTitle` | `Walk/DesignSystem/Theme/Font+App.swift` |
| Typography | `font.hero.subtitle` | `AppTypography.heroSubtitle` | `Walk/DesignSystem/Theme/Font+App.swift` |
| Typography | `font.display.title` | `AppTypography.displayTitle` | `Walk/DesignSystem/Theme/Font+App.swift` |
| Typography | `font.page.title` | `AppTypography.pageTitle` | `Walk/DesignSystem/Theme/Font+App.swift` |
| Typography | `font.nav.title` | `AppTypography.navTitle` | `Walk/DesignSystem/Theme/Font+App.swift` |
| Typography | `font.section.title` | `AppTypography.sectionTitle` | `Walk/DesignSystem/Theme/Font+App.swift` |
| Typography | `font.card.title` | `AppTypography.cardTitle` | `Walk/DesignSystem/Theme/Font+App.swift` |
| Typography | `font.body.large` | `AppTypography.bodyLarge` | `Walk/DesignSystem/Theme/Font+App.swift` |
| Typography | `font.body` | `AppTypography.appBody` | `Walk/DesignSystem/Theme/Font+App.swift` |
| Typography | `font.action` | `AppTypography.action` | `Walk/DesignSystem/Theme/Font+App.swift` |
| Typography | `font.body.small` | `AppTypography.bodySmall` | `Walk/DesignSystem/Theme/Font+App.swift` |
| Typography | `font.caption` | `AppTypography.appCaption` | `Walk/DesignSystem/Theme/Font+App.swift` |
| Typography | `font.label` | `AppTypography.label` | `Walk/DesignSystem/Theme/Font+App.swift` |
| Typography | `font.metric.value` | `AppTypography.metricValue` | `Walk/DesignSystem/Theme/Font+App.swift` |
| Typography | `font.metric.unit` | `AppTypography.metricUnit` | `Walk/DesignSystem/Theme/Font+App.swift` |
| Typography | `font.micro` | `AppTypography.micro` | `Walk/DesignSystem/Theme/Font+App.swift` |
| Spacing | `lg` | `Spacing.lg` | `Walk/DesignSystem/Theme/Spacing.swift` |
| Spacing | `md` | `Spacing.md` | `Walk/DesignSystem/Theme/Spacing.swift` |
| Spacing | `page.horizontal` | `Spacing.pageHorizontal` | `Walk/DesignSystem/Theme/Spacing.swift` |
| Spacing | `sm` | `Spacing.sm` | `Walk/DesignSystem/Theme/Spacing.swift` |
| Spacing | `xl` | `Spacing.xl` | `Walk/DesignSystem/Theme/Spacing.swift` |
| Spacing | `xs` | `Spacing.xs` | `Walk/DesignSystem/Theme/Spacing.swift` |
| Spacing | `xxl` | `Spacing.xxl` | `Walk/DesignSystem/Theme/Spacing.swift` |
| Spacing | `xxxl` | `Spacing.xxxl` | `Walk/DesignSystem/Theme/Spacing.swift` |
| Radius | `lg` | `Radius.lg` | `Walk/DesignSystem/Theme/Radius.swift` |
| Radius | `md` | `Radius.md` | `Walk/DesignSystem/Theme/Radius.swift` |
| Radius | `none` | `Radius.none` | `Walk/DesignSystem/Theme/Radius.swift` |
| Radius | `pill` | `Radius.full` | `Walk/DesignSystem/Theme/Radius.swift` |
| Radius | `sm` | `Radius.sm` | `Walk/DesignSystem/Theme/Radius.swift` |
| Radius | `xl` | `Radius.xl` | `Walk/DesignSystem/Theme/Radius.swift` |
| Shadow | `shadow.floating` | `AppShadow.floating` | `Walk/DesignSystem/Theme/Shadow.swift` |
| Shadow | `shadow.panel` | `AppShadow.panel` | `Walk/DesignSystem/Theme/Shadow.swift` |
| Shadow | `shadow.overlay` | `AppShadow.overlay` | `Walk/DesignSystem/Theme/Shadow.swift` |

### Token 映射缺口

下表是后续 Token / 平台符合性 Change 的输入。本次结构 Change 只登记缺口，不修改 Theme 实现，也不从近似值推断符合。

| 类别 | 总 UI Token | 目标源码 | 当前缺口 |
|---|---|---|---|
| Color | `color.scene.forest.highlight` | `Walk/DesignSystem/Theme/Color+App.swift` | 未找到与总 Token 语义和取值均一致的独立承载 |
| Color | `color.scene.forest.mid` | `Walk/DesignSystem/Theme/Color+App.swift` | 未找到与总 Token 语义和取值均一致的独立承载 |
| Color | `color.scene.mountain.front` | `Walk/DesignSystem/Theme/Color+App.swift` | 未找到与总 Token 语义和取值均一致的独立承载 |
| Color | `color.scene.mountain.middle` | `Walk/DesignSystem/Theme/Color+App.swift` | 未找到与总 Token 语义和取值均一致的独立承载 |
| Color | `color.surface.panelGlass` | `Walk/DesignSystem/Theme/Color+App.swift` | 未找到与总 Token 语义和取值均一致的独立承载 |
| Color | `color.surface.subtle` | `Walk/DesignSystem/Theme/Color+App.swift` | 未找到与总 Token 语义和取值均一致的独立承载 |
| Color | `color.surface.muted` | `Walk/DesignSystem/Theme/Color+App.swift` | 未找到与总 Token 语义和取值均一致的独立承载 |
| Color | `color.surface.handle` | `Walk/DesignSystem/Theme/Color+App.swift` | 未找到与总 Token 语义和取值均一致的独立承载 |
| Color | `color.surface.modalScrim` | `Walk/DesignSystem/Theme/Color+App.swift` | 未找到与总 Token 语义和取值均一致的独立承载 |
| Color | `color.surface.controlOverlay` | `Walk/DesignSystem/Theme/Color+App.swift` | 未找到与总 Token 语义和取值均一致的独立承载 |
| Color | `color.surface.header` | `Walk/DesignSystem/Theme/Color+App.swift` | 未找到与总 Token 语义和取值均一致的独立承载 |
| Color | `color.surface.navigation` | `Walk/DesignSystem/Theme/Color+App.swift` | 未找到与总 Token 语义和取值均一致的独立承载 |
| Color | `color.border.navigation` | `Walk/DesignSystem/Theme/Color+App.swift` | 未找到与总 Token 语义和取值均一致的独立承载 |
| Color | `color.border.subtle` | `Walk/DesignSystem/Theme/Color+App.swift` | 未找到与总 Token 语义和取值均一致的独立承载 |
| Color | `color.border.overlay` | `Walk/DesignSystem/Theme/Color+App.swift` | 未找到与总 Token 语义和取值均一致的独立承载 |
| Color | `color.text.disabled` | `Walk/DesignSystem/Theme/Color+App.swift` | 未找到与总 Token 语义和取值均一致的独立承载 |
| Color | `color.interaction.onPrimary` | `Walk/DesignSystem/Theme/Color+App.swift` | 未找到与总 Token 语义和取值均一致的独立承载 |
| Color | `color.info.border` | `Walk/DesignSystem/Theme/Color+App.swift` | 未找到与总 Token 语义和取值均一致的独立承载 |
| Color | `color.warning.border` | `Walk/DesignSystem/Theme/Color+App.swift` | 未找到与总 Token 语义和取值均一致的独立承载 |
| Color | `color.danger.border` | `Walk/DesignSystem/Theme/Color+App.swift` | 未找到与总 Token 语义和取值均一致的独立承载 |
| Color | `color.data.heatmap.empty` | `Walk/DesignSystem/Theme/Color+App.swift` | 未找到与总 Token 语义和取值均一致的独立承载 |
| Color | `color.data.heatmap.low` | `Walk/DesignSystem/Theme/Color+App.swift` | 未找到与总 Token 语义和取值均一致的独立承载 |
| Color | `color.data.heatmap.medium` | `Walk/DesignSystem/Theme/Color+App.swift` | 未找到与总 Token 语义和取值均一致的独立承载 |
| Color | `color.data.heatmap.high` | `Walk/DesignSystem/Theme/Color+App.swift` | 未找到与总 Token 语义和取值均一致的独立承载 |
| Typography | `font.scene.title` | `Walk/DesignSystem/Theme/Font+App.swift` | 未找到与总 Token 语义和取值均一致的独立承载 |
| Typography | `font.detail.title` | `Walk/DesignSystem/Theme/Font+App.swift` | 未找到与总 Token 语义和取值均一致的独立承载 |
| Typography | `font.day.date` | `Walk/DesignSystem/Theme/Font+App.swift` | 未找到与总 Token 语义和取值均一致的独立承载 |
| Typography | `font.state.title` | `Walk/DesignSystem/Theme/Font+App.swift` | 未找到与总 Token 语义和取值均一致的独立承载 |
| Typography | `font.identity.title` | `Walk/DesignSystem/Theme/Font+App.swift` | 未找到与总 Token 语义和取值均一致的独立承载 |
| Typography | `font.date.title` | `Walk/DesignSystem/Theme/Font+App.swift` | 未找到与总 Token 语义和取值均一致的独立承载 |
| Typography | `font.body.emphasis` | `Walk/DesignSystem/Theme/Font+App.swift` | 未找到与总 Token 语义和取值均一致的独立承载 |
| Typography | `font.list.title` | `Walk/DesignSystem/Theme/Font+App.swift` | 未找到与总 Token 语义和取值均一致的独立承载 |
| Typography | `font.context.title` | `Walk/DesignSystem/Theme/Font+App.swift` | 未找到与总 Token 语义和取值均一致的独立承载 |
| Typography | `font.sequence` | `Walk/DesignSystem/Theme/Font+App.swift` | 未找到与总 Token 语义和取值均一致的独立承载 |
| Typography | `font.sequence.compact` | `Walk/DesignSystem/Theme/Font+App.swift` | 未找到与总 Token 语义和取值均一致的独立承载 |
| Typography | `font.timeline.time` | `Walk/DesignSystem/Theme/Font+App.swift` | 未找到与总 Token 语义和取值均一致的独立承载 |
| Typography | `font.tab.label` | `Walk/DesignSystem/Theme/Font+App.swift` | 未找到与总 Token 语义和取值均一致的独立承载 |
| Typography | `font.micro.strong` | `Walk/DesignSystem/Theme/Font+App.swift` | 未找到与总 Token 语义和取值均一致的独立承载 |
| Typography | `font.metric.compact.value` | `Walk/DesignSystem/Theme/Font+App.swift` | 未找到与总 Token 语义和取值均一致的独立承载 |
| Typography | `font.metric.compact.label` | `Walk/DesignSystem/Theme/Font+App.swift` | 未找到与总 Token 语义和取值均一致的独立承载 |
| Typography | `font.metric.grid.value` | `Walk/DesignSystem/Theme/Font+App.swift` | 未找到与总 Token 语义和取值均一致的独立承载 |
| Typography | `font.metric.grid.label` | `Walk/DesignSystem/Theme/Font+App.swift` | 未找到与总 Token 语义和取值均一致的独立承载 |
| Typography | `font.weather.conclusion` | `Walk/DesignSystem/Theme/Font+App.swift` | 未找到与总 Token 语义和取值均一致的独立承载 |
| Typography | `font.weather.impact` | `Walk/DesignSystem/Theme/Font+App.swift` | 未找到与总 Token 语义和取值均一致的独立承载 |
| Typography | `font.brand.mark` | `Walk/DesignSystem/Theme/Font+App.swift` | 未找到与总 Token 语义和取值均一致的独立承载 |
| Shadow | `shadow.navigation` | `Walk/DesignSystem/Theme/Shadow.swift` | 未找到与总 Token 语义和取值均一致的独立承载 |
| Shadow | `shadow.action.compact` | `Walk/DesignSystem/Theme/Shadow.swift` | 未找到与总 Token 语义和取值均一致的独立承载 |
| Shadow | `shadow.interaction.glow` | `Walk/DesignSystem/Theme/Shadow.swift` | 未找到与总 Token 语义和取值均一致的独立承载 |

## 映射状态

映射表表示当前源码中可确认的承载关系，不表示实现已经通过内容符合性验收。缺少独立组件类型、Variant 不完整、页面内重复实现或视觉不一致，均作为后续内容对齐或平台符合性 Change 的输入；不得在本文件中把差距改写成总规范。
