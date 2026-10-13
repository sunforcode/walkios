#if DEBUG
import SwiftUI
import WalkData
import WalkDesignSystem

struct ComponentPreviewRequest: Equatable {
    let componentID: String
    let stateID: String

    init(componentID: String, stateID: String = "default") {
        self.componentID = componentID
        self.stateID = stateID
    }

    init?(arguments: [String]) {
        guard let flagIndex = arguments.firstIndex(of: "--component-preview"),
              arguments.indices.contains(flagIndex + 1) else {
            return nil
        }
        componentID = arguments[flagIndex + 1]
        let stateIndex = flagIndex + 2
        if arguments.indices.contains(stateIndex), !arguments[stateIndex].hasPrefix("-") {
            stateID = arguments[stateIndex]
        } else {
            stateID = "default"
        }
    }
}

enum ComponentCategory: String, Equatable {
    case common
    case business
}

struct ComponentCatalogEntry {
    let id: String
    let category: ComponentCategory
    let stateIDs: [String]
    let makeView: (String) -> AnyView?

    var isUnsupported: Bool {
        makeView("default") == nil
    }
}

enum ComponentCatalog {
    static let entries: [ComponentCatalogEntry] = commonEntries + businessEntries

    static func entry(id: String) -> ComponentCatalogEntry? {
        entries.first { $0.id == id }
    }

    private static let commonEntries: [ComponentCatalogEntry] = [
        entry("AvatarButton", .common) {
            AvatarButton(avatarLabel: "林", accessibilityLabel: "个人与设置", action: {})
        },
        entry("Card", .common) {
            WalkCard {
                Text(WalkDesignSystem.ComponentPreviewFixtures.longSupportingText)
                    .font(.appBody)
                    .foregroundStyle(AppColors.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        },
        entry("ConfirmationDialog", .common) {
            ConfirmationDialog(
                title: WalkDesignSystem.ComponentPreviewFixtures.confirmationTitle,
                message: WalkDesignSystem.ComponentPreviewFixtures.confirmationMessage,
                confirmationTitle: "确认",
                onCancel: {},
                onConfirm: {}
            )
            .padding(.vertical, Spacing.xxl)
        },
        entry("ContentSection", .common) {
            ContentSection(
                title: WalkDesignSystem.ComponentPreviewFixtures.sectionTitle,
                subtitle: WalkDesignSystem.ComponentPreviewFixtures.supportingText
            ) {
                WalkCard { Text(WalkDesignSystem.ComponentPreviewFixtures.longSupportingText) }
            }
        },
        entry("DangerAction", .common) {
            DangerAction(title: "删除", systemImage: "trash", action: {})
        },
        entry("DateInput", .common) {
            DateInput(value: .constant(WalkDesignSystem.ComponentPreviewFixtures.fixedDate), label: "出发日期")
        },
        entry("EmptyState", .common) {
            EmptyStateView(title: "暂无内容", message: WalkDesignSystem.ComponentPreviewFixtures.supportingText, icon: "tray")
        },
        entry("ErrorView", .common) {
            ErrorView(message: WalkDesignSystem.ComponentPreviewFixtures.errorMessage, retry: {})
        },
        entry("FixedActionArea", .common) {
            FixedActionArea { PrimaryAction(title: "继续", fillsWidth: true, action: {}) }
        },
        entry("FormField", .common) {
            FormField(label: WalkDesignSystem.ComponentPreviewFixtures.formLabel, requirement: .required) {
                TextField(WalkDesignSystem.ComponentPreviewFixtures.formPlaceholder, text: .constant(""))
            }
        },
        entry("IconButton", .common) {
            IconButton(systemName: "chevron.left", accessibilityLabel: "返回", action: {})
        },
        entry("InfoTag", .common) {
            InfoTag(title: "适中", tone: .neutral)
        },
        entry("ListRow", .common) {
            ListRow {
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text(WalkDesignSystem.ComponentPreviewFixtures.shortTitle).font(.listTitle)
                    Text(WalkDesignSystem.ComponentPreviewFixtures.supportingText).font(.appCaption)
                }
            }
        },
        entry("LoadingState", .common) {
            LoadingView(message: "正在加载", variant: .page)
        },
        entry("MetricGroup", .common) {
            MetricGroup(items: WalkDesignSystem.MetricPreviewFixtures.completeMetrics)
        },
        entry("MetricItem", .common) {
            MetricItem(model: WalkDesignSystem.MetricPreviewFixtures.completeMetrics[0])
        },
        entry("MixedPageShell", .common) {
            MixedPageShell {
                Text("Content Slot")
                    .font(.label)
                    .padding(Spacing.lg)
            }
        },
        entry("ModalBottomSheet", .common) {
            ModalBottomSheet(onDismiss: {}) {
                VStack(alignment: .leading, spacing: Spacing.lg) {
                    Text("底部模态任务").font(.sectionTitle)
                    Text(WalkDesignSystem.ComponentPreviewFixtures.longSupportingText).font(.appBody)
                    PrimaryAction(title: "完成", fillsWidth: true, action: {})
                }
            }
        },
        ComponentCatalogEntry(id: "Notice", category: .common, stateIDs: ["default", "inline"]) { state in
            guard ["default", "inline"].contains(state) else { return nil }
            return AnyView(NoticeView(
                message: state == "inline"
                    ? WalkDesignSystem.ComponentPreviewFixtures.longSupportingText
                    : WalkDesignSystem.ComponentPreviewFixtures.supportingText,
                title: state == "inline" ? "出发前核验" : "补充信息",
                icon: state == "inline" ? "exclamationmark.triangle" : "info.circle",
                tone: state == "inline" ? .warning : .info,
                presentation: state == "inline" ? .inline : .standard
            ))
        },
        entry("PageTitleBlock", .common) {
            PageTitleBlock(
                title: WalkDesignSystem.ComponentPreviewFixtures.longTitle,
                kicker: "准备出发",
                description: WalkDesignSystem.ComponentPreviewFixtures.longSupportingText
            )
        },
        entry("Panel", .common) {
            WalkPanel(variant: .default) { Text("Content Slot") }
        },
        entry("PrimaryAction", .common) {
            PrimaryAction(title: "继续", fillsWidth: true, action: {})
        },
        entry("QuantityStepper", .common) {
            QuantityStepper(value: .constant(2), minimum: 1, maximum: 5)
        },
        entry("SearchField", .common) {
            SearchField(
                text: .constant(WalkDesignSystem.ComponentPreviewFixtures.searchQuery),
                placeholder: WalkDesignSystem.ComponentPreviewFixtures.searchPlaceholder,
                onSubmit: {}
            )
        },
        entry("SecondaryAction", .common) {
            SecondaryAction(title: "稍后处理", action: {})
        },
        entry("SectionHeader", .common) {
            SectionHeader(
                title: WalkDesignSystem.ComponentPreviewFixtures.longTitle,
                subtitle: WalkDesignSystem.ComponentPreviewFixtures.longSupportingText
            )
        },
        entry("SegmentedControl", .common) {
            SegmentedControl(options: WalkDesignSystem.ComponentPreviewFixtures.segmentOptions, selection: .constant("overview"))
        },
        ComponentCatalogEntry(
            id: "SelectInput", category: .common,
            stateIDs: ["default", "empty", "selected", "disabled", "error"]
        ) { stateID in
            guard ["default", "empty", "selected", "disabled", "error"].contains(stateID) else { return nil }
            let selection: String? = stateID == "empty" || stateID == "error" ? nil : "moderate"
            return AnyView(SelectInput(
                selection: .constant(selection),
                label: "难度",
                placeholder: "请选择难度",
                options: WalkDesignSystem.ComponentPreviewFixtures.selectOptions,
                error: stateID == "error" ? "请选择一个选项" : nil,
                isDisabled: stateID == "disabled"
            ))
        },
        entry("SelectableOptionCard", .common) {
            SelectableOptionCard(isSelected: false, action: {}) {
                Text(WalkDesignSystem.ComponentPreviewFixtures.longSupportingText).font(.appBody)
            }
        },
        entry("SettingsListRow", .common) {
            SettingsListRow(id: "notifications", label: "通知设置", onActivate: { _ in })
        },
        entry("SheetHandle", .common) {
            SheetHandle()
        },
        entry("SourceNote", .common) {
            SourceNote(source: WalkDesignSystem.ComponentPreviewFixtures.source, updatedAt: WalkDesignSystem.ComponentPreviewFixtures.updatedAt)
        },
        entry("TextInput", .common) {
            TextInput(text: .constant("云岭环线"), label: "路线名称", placeholder: "输入路线名称")
        },
        ComponentCatalogEntry(
            id: "Timeline", category: .common,
            stateIDs: ["default", "compact", "compactCrossMonth", "compactTime", "compactTitleOnly", "compactWithoutTime", "compactLongTitle", "compactQualified", "compactAccessible"]
        ) { state in
            guard ["default", "compact", "compactCrossMonth", "compactTime", "compactTitleOnly", "compactWithoutTime", "compactLongTitle", "compactQualified", "compactAccessible"].contains(state) else { return nil }
            let isDate = state == "compact" || state == "compactCrossMonth"
            let items: [TimelinePreviewItem]
            switch state {
            case "compact": items = Array(TimelinePreviewItem.compactDays.prefix(2))
            case "compactCrossMonth": items = TimelinePreviewItem.compactDays
            case "compactTitleOnly": items = TimelinePreviewItem.titleOnly
            case "compactWithoutTime": items = TimelinePreviewItem.withoutTime
            case "compactLongTitle": items = TimelinePreviewItem.longTitle
            case "compactQualified", "compactAccessible": items = TimelinePreviewItem.qualified
            default: items = WalkDesignSystem.ComponentPreviewFixtures.timelineItems
            }
            return AnyView(Timeline(
                items,
                optionalTime: { $0.time },
                presentation: state == "default" ? .standard : .compact,
                timeColumnWidth: isDate ? 28 : (items.contains { $0.time != nil } ? 52 : 0),
                sectionLabel: { isDate ? TimelinePreviewItem.compactSectionLabel(for: $0) : nil }
            ) { item in
                if state == "default" {
                    VStack(alignment: .leading, spacing: Spacing.xs) {
                        Text(item.title).font(.listTitle)
                        ForEach(item.details, id: \.self) { Text($0) }
                    }
                } else {
                    TimelineSummaryContent(title: item.title, subtitle: item.subtitle)
                }
            }
            .environment(\.dynamicTypeSize, state == "compactAccessible" ? .accessibility2 : .large))
        },
        entry("UnavailableState", .common) {
            UnavailableStateView(title: "天气暂不可用", message: WalkDesignSystem.ComponentPreviewFixtures.longSupportingText)
        },
        entry("UtilityNavigationHeader", .common) {
            UtilityNavigationHeader(
                title: "全部路线",
                leading: IconButtonConfiguration(systemName: "chevron.left", accessibilityLabel: "返回", action: {}),
                trailing: IconButtonConfiguration(systemName: "magnifyingglass", accessibilityLabel: "搜索路线", action: {})
            )
        },
        entry("UtilityPage", .common) {
            UtilityPage { Text("Content Slot").font(.label).padding(Spacing.lg) }
        },
    ]

    private static let businessEntries: [ComponentCatalogEntry] = [
        entry("AuthPanel", .business) {
            AuthPanel(
                projection: AuthPanelProjection.phone,
                onClose: {},
                onChangePhone: { _ in },
                onSendCode: {},
                onChangeCode: { _ in },
                onVerifyCode: {},
                onResendCode: {}
            )
        },
        entry("ChecklistItemRow", .business) {
            ChecklistItemRow(
                projection: ChecklistItemRowProjection.knownWeight,
                onChangeQuantity: { _, _ in },
                onRemoveMember: { _ in }
            )
        },
        entry("ChecklistPanel", .business) {
            ChecklistPanel(
                summary: EquipmentListSummaryProjection.default,
                isExpanded: false,
                members: ChecklistItemRowProjection.samples,
                onToggle: { _ in },
                onRename: { _ in },
                onRequestDelete: { _ in },
                onChangeQuantity: { _, _ in },
                onRemoveMember: { _ in }
            ) {
                SecondaryAction(title: "添加个人装备", variant: .inline, action: {})
            }
        },
        entry("DailyWeatherCard", .business) {
            TripBusinessComponents.DailyWeatherCard(day: TripWeatherDayProjection.default)
        },
        ComponentCatalogEntry(
            id: "DailyWeatherSummaryRow", category: .business,
            stateIDs: ["default", "compact", "compactUnavailable", "inline", "inlineUnavailable"]
        ) { state in
            guard ["default", "compact", "compactUnavailable", "inline", "inlineUnavailable"].contains(state) else { return nil }
            let isInline = state == "inline" || state == "inlineUnavailable"
            let isUnavailable = state == "compactUnavailable" || state == "inlineUnavailable"
            return AnyView(
                TripBusinessComponents.DailyWeatherSummaryRow(
                    day: isUnavailable ? .unavailable : .knownWithPlace,
                    presentation: isInline ? .inline : .standard
                )
                .frame(width: state == "default" ? nil : (isInline ? 98 : 178))
            )
        },
        entry("ElevationProfile", .business) {
            RouteBusinessComponents.ElevationProfile(projection: ElevationProfileProjection.default)
        },
        entry("EquipmentDeletionImpact", .business) {
            EquipmentDeletionImpact(impact: PersonalEquipmentDeletionImpact.referenced)
        },
        entry("EquipmentListRow", .business) {
            EquipmentListRow(
                projection: EquipmentListRowProjection.sample,
                onActivate: { _ in },
                onEdit: { _ in },
                onDelete: { _ in }
            )
        },
        entry("FocusTripSummary", .business) {
            FocusTripSummary(model: FocusTripSummaryModel.complete, onOpen: {})
                .frame(height: 700)
        },
        entry("GearRing", .business) {
            TripBusinessComponents.GearRing(
                projection: GearRingProjection(value: 6, total: 8, tone: .mint, label: "已有")
            )
        },
        entry("GenerationRouteSummaryCard", .business) {
            SharedBusinessComponents.GenerationRouteSummaryCard(
                projection: GenerationRouteSummaryProjection.default
            )
        },
        entry("GenerationWaitingView", .business) {
            SharedBusinessComponents.GenerationWaitingView(
                projection: GenerationWaitingProjection.default,
                reduceMotionOverride: true
            )
            .frame(minHeight: 560)
        },
        entry("HeatmapCalendar", .business) {
            SharedBusinessComponents.HeatmapCalendar(days: TripHeatmapDayProjection.sampleYear)
        },
        entry("InlineEquipmentEditor", .business) {
            SharedBusinessComponents.InlineEquipmentEditor(
                projection: InlineEquipmentEditorProjection.default,
                onChangeField: { _, _ in },
                onChangeQuantity: { _ in },
                onCancel: {}
            )
        },
        entry("InlineListNameEditor", .business) {
            InlineListNameEditor(
                projection: InlineListNameEditorProjection.default,
                onChangeName: { _ in },
                onCancel: {}
            )
        },
        ComponentCatalogEntry(
            id: "PersonalEquipmentForm", category: .business,
            stateIDs: PersonalEquipmentFormProjection.previewStates.map { $0.0 }
        ) { stateID in
            guard let projection = PersonalEquipmentFormProjection.previewStates.first(where: { $0.0 == stateID })?.1 else { return nil }
            return AnyView(PersonalEquipmentForm(projection: projection, onChangeField: { _, _ in }))
        },
        entry("PersonalEquipmentSummaryCard", .business) {
            PersonalEquipmentSummaryCard(
                summary: PersonalEquipmentSummary.default,
                onActivate: {}
            )
        },
        entry("ProfileIdentityHeader", .business) {
            AccountEquipmentBusinessComponents.ProfileIdentityHeader(
                profile: ProfileProjection.default,
                onSelectAvatar: {}
            )
        },
        entry("RouteFactSection", .business) {
            RouteBusinessComponents.RouteFactSection(projection: RouteFactSectionProjection.safety)
        },
        entry("RouteImageGallery", .business) {
            RouteBusinessComponents.RouteImageGallery(
                images: RouteImageProjection.samples
            ) { image in
                RouteDeterministicImageSurface(style: RouteImageProjection.sampleStyle(for: image.id))
            }
        },
        entry("RouteIntroduction", .business) {
            RouteBusinessComponents.RouteIntroduction(projection: RouteIntroductionProjection.default)
        },
        entry("RouteListRow", .business) {
            RouteBusinessComponents.RouteListRow(
                projection: RouteListRowProjection.default,
                onSelect: { _ in }
            ) {
                RouteDeterministicImageSurface(style: .ridge)
            }
        },
        entry("RouteMap", .business) {
            RouteBusinessComponents.RouteMap(
                projection: RouteMapProjection.default,
                onSelectPoint: { _ in }
            )
            .frame(height: 700)
        },
        entry("RoutePointDetail", .business) {
            RouteBusinessComponents.RoutePointDetail(
                projection: RoutePointDetailProjection.default,
                onDismiss: {}
            )
        },
        entry("RoutePointSection", .business) {
            RouteBusinessComponents.RoutePointSection(
                projection: RoutePointSectionProjection.keyPoints,
                onFocusPoint: { _ in }
            )
        },
        entry("RouteReferenceDayList", .business) {
            RouteBusinessComponents.RouteReferenceDayList(days: RouteReferenceDayProjection.samples)
        },
        entry("RouteScene", .business) {
            RouteBusinessComponents.RouteScene(
                projection: RouteSceneProjection.default,
                onSelect: { _ in }
            ) {
                RouteDeterministicImageSurface(style: .ridge)
            }
            .frame(height: 700)
        },
        entry("RouteSegmentList", .business) {
            RouteBusinessComponents.RouteSegmentList(
                projection: RouteSegmentListProjection.default,
                onSelectSegment: { _ in }
            )
        },
        entry("RouteSummary", .business) {
            RouteBusinessComponents.RouteSummary(projection: RouteSummaryProjection.default)
        },
        entry("TrekDayBadge", .business) {
            TripBusinessComponents.TrekDayBadge(
                projection: TrekDayBadgeProjection(trekDayNumber: 2, totalTrekDays: 3)
            )
        },
        entry("TripCalendarCard", .business) {
            SharedBusinessComponents.TripCalendarCard(
                projection: TripCalendarCardProjection.default,
                onActivate: {}
            )
        },
        ComponentCatalogEntry(
            id: "TripExpeditionScene", category: .business,
            stateIDs: ["default", "overview", "hikingDay", "arrival", "unavailable", "noticesLong", "accessible"]
        ) { state in
            let projection: TripExpeditionSceneProjection
            switch state {
            case "default", "overview": projection = .overview
            case "hikingDay": projection = .hikingDay
            case "arrival": projection = .arrival
            case "unavailable": projection = .unavailable
            case "noticesLong": projection = .noticesLong
            case "accessible": projection = .accessible
            default: return nil
            }
            return AnyView(
                TripBusinessComponents.TripExpeditionScene(projection: projection)
                    .frame(maxWidth: 430)
                    .frame(height: state == "accessible" ? 440 : 395)
                    .background { TripBusinessComponents.TripExpeditionScene.Artwork(projection: projection) }
                    .environment(\.dynamicTypeSize, state == "accessible" ? .accessibility2 : .large)
            )
        },
        ComponentCatalogEntry(
            id: "TripCoverHeader", category: .business,
            stateIDs: ["default", "longName", "largeText", "identity", "identityWithoutSubtitle", "identityOverviewDate", "identityDayEndpoints"]
        ) { state in
            guard ["default", "longName", "largeText", "identity", "identityWithoutSubtitle", "identityOverviewDate", "identityDayEndpoints"].contains(state) else { return nil }
            let isIdentity = state.hasPrefix("identity")
            let headerPresentation: TripBusinessComponents.TripCoverHeader<TripExpeditionCoverSurface>.Presentation
            switch state {
            case "identity":
                headerPresentation = .identity(headline: "贡嘎环线", eyebrow: "全程总览", subtitle: "9月7日 — 9月10日")
            case "identityWithoutSubtitle":
                headerPresentation = .identity(headline: "山脊穿行", eyebrow: "DAY 02")
            case "identityOverviewDate":
                headerPresentation = .identity(headline: "贡嘎环线", eyebrow: "8月25–8月27日")
            case "identityDayEndpoints":
                headerPresentation = .identity(headline: "河谷入山", eyebrow: "老榆林 → 下日乌且营地")
            default:
                headerPresentation = .cover
            }
            return AnyView(
                TripBusinessComponents.TripCoverHeader(
                    projection: state == "default" || isIdentity ? .default : .longName,
                    presentation: headerPresentation
                ) { TripExpeditionCoverSurface() }
                .environment(\.dynamicTypeSize, state == "largeText" ? .accessibility2 : .large)
            )
        },
        ComponentCatalogEntry(
            id: "TripDayArrangement", category: .business,
            stateIDs: ["default", "referenceGuide", "referenceGuideLong", "hikeSectionUnavailable"]
        ) { state in
            if state == "default" {
                return AnyView(TripBusinessComponents.TripDayArrangement(projection: .default).frame(height: 700))
            }
            let projection: TripDayArrangementProjection
            switch state {
            case "referenceGuide": projection = .referenceGuide
            case "referenceGuideLong": projection = .referenceGuideLong
            case "hikeSectionUnavailable": projection = .hikeSectionUnavailable
            default: return nil
            }
            return AnyView(ScrollView {
                TripBusinessComponents.TripDayArrangement(projection: projection)
                    .padding(.horizontal, Spacing.pageHorizontal)
                    .padding(.vertical, Spacing.md)
            }
            .frame(height: 760)
            .environment(\.dynamicTypeSize, state == "referenceGuideLong" ? .accessibility2 : .large))
        },
        entry("TripDayOverviewEntry", .business) {
            TripBusinessComponents.TripDayOverviewEntry(
                projection: TripDayOverviewEntryProjection.default,
                onActivate: {}
            )
        },
        entry("TripEquipmentSourcePicker", .business) {
            TripBusinessComponents.TripEquipmentSourcePicker.preview(.equipment)
        },
        ComponentCatalogEntry(
            id: "TripEquipmentSummaryCard", category: .business,
            stateIDs: [
                "default", "compact", "compactPartialWeight", "compactReadonly",
                "dashboard", "dashboardPartialWeight", "dashboardReadonly",
                "icon", "iconPartialWeight", "iconReadonly",
            ]
        ) { state in
            let projection: TripEquipmentSummaryProjection
            let presentation: TripBusinessComponents.TripEquipmentSummaryCard.Presentation
            let width: CGFloat?
            switch state {
            case "default":
                projection = .default
                presentation = .standard
                width = nil
            case "compact", "compactPartialWeight", "compactReadonly":
                projection = state == "compactPartialWeight" ? .partialWeight : (state == "compactReadonly" ? .readonly : .default)
                presentation = .compact
                width = 140
            case "dashboard", "dashboardPartialWeight", "dashboardReadonly":
                projection = state == "dashboardPartialWeight" ? .partialWeight : (state == "dashboardReadonly" ? .readonly : .default)
                presentation = .dashboard
                width = 108
            case "icon", "iconPartialWeight", "iconReadonly":
                projection = state == "iconPartialWeight" ? .partialWeight : (state == "iconReadonly" ? .readonly : .default)
                presentation = .icon
                width = Spacing.navBarHeight
            default:
                return nil
            }
            return AnyView(
                TripBusinessComponents.TripEquipmentSummaryCard(
                    projection: projection,
                    presentation: presentation,
                    onActivate: {}
                )
                .frame(width: width)
            )
        },
        entry("TripEquipmentGearRings", .business) {
            TripBusinessComponents.TripEquipmentGearRings(
                projection: TripEquipmentSummaryProjection.default.gearRings
            )
        },
        entry("TripListRow", .business) {
            TripBusinessComponents.TripListRow(
                projection: TripListRowProjection.default,
                onActivate: { _ in }
            )
        },
        entry("TripRouteSummaryCard", .business) {
            TripBusinessComponents.TripRouteSummaryCard(
                projection: TripRouteSummaryProjection.default,
                onActivate: {}
            )
        },
        entry("TripStatusBadge", .business) {
            TripStatusBadge(status: .planned)
        },
        entry("TripWeatherSummaryCard", .business) {
            TripBusinessComponents.TripWeatherSummaryCard(
                projection: TripWeatherSummaryProjection.default,
                onActivate: {}
            )
        },
        entry("TripWeatherTrendChart", .business) {
            TripBusinessComponents.TripWeatherTrendChart(
                samples: TripWeatherSummaryProjection.default.samples
            )
        },
        entry("WeatherOverview", .business) {
            TripBusinessComponents.WeatherOverview(
                projection: WeatherOverviewProjection.default
            )
        },
        entry("WeatherSummary", .business) {
            WeatherSummary(model: WeatherSummaryModel.available)
        },
    ]

    private static func entry<Content: View>(
        _ id: String,
        _ category: ComponentCategory,
        stateIDs: [String] = ["default"],
        @ViewBuilder makeDefaultView: @escaping () -> Content
    ) -> ComponentCatalogEntry {
        ComponentCatalogEntry(id: id, category: category, stateIDs: stateIDs) { stateID in
            guard stateID == "default" else { return nil }
            return AnyView(makeDefaultView())
        }
    }
}
#endif
