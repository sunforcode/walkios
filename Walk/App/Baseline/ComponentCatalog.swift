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
                    Text(ComponentPreviewFixtures.sheetTitle).font(.sectionTitle)
                    Text(WalkDesignSystem.ComponentPreviewFixtures.longSupportingText).font(.appBody)
                    PrimaryAction(title: ComponentPreviewFixtures.sheetAction, fillsWidth: true, action: {})
                }
            }
        },
        entry("Notice", .common) {
            NoticeView(message: WalkDesignSystem.ComponentPreviewFixtures.supportingText, title: "补充信息", tone: .info)
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
        entry("PrimaryTabBar", .common) {
            PrimaryTabBar(selectedTab: .home, onSelect: { _ in })
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
        entry("SelectInput", .common) {
            SelectInput(
                selection: .constant("moderate"),
                label: "难度",
                placeholder: "请选择难度",
                options: WalkDesignSystem.ComponentPreviewFixtures.selectOptions
            )
        },
        entry("SelectableOptionCard", .common) {
            SelectableOptionCard(isSelected: false, action: {}) {
                Text(WalkDesignSystem.ComponentPreviewFixtures.longSupportingText).font(.appBody)
            }
        },
        entry("SettingsListRow", .common) {
            SettingsListRow(id: "account", label: "账号与安全", onActivate: { _ in })
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
        entry("Timeline", .common) {
            Timeline(WalkDesignSystem.ComponentPreviewFixtures.timelineItems, optionalTime: { $0.time }) { item in
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text(item.title).font(.listTitle)
                    ForEach(item.details, id: \.self) { Text($0) }
                }
            }
        },
        entry("UnavailableState", .common) {
            UnavailableStateView(title: "天气暂不可用", message: WalkDesignSystem.ComponentPreviewFixtures.longSupportingText)
        },
        entry("UtilityNavigationHeader", .common) {
            UtilityNavigationHeader(
                title: ComponentPreviewFixtures.navigationTitle,
                leading: IconButtonConfiguration(systemName: "chevron.left", accessibilityLabel: "返回", action: {}),
                trailing: IconButtonConfiguration(systemName: "magnifyingglass", accessibilityLabel: "搜索路线", action: {})
            )
        },
        entry("UtilityPage", .common) {
            UtilityPage { Text("Content Slot").font(.label).padding(Spacing.lg) }
        },
    ]

    private static let businessEntries: [ComponentCatalogEntry] = [
        entry("AccountMenuSheet", .business) {
            AccountMenuSheet(
                profile: BusinessComponentPreviewFixtures.profileWithAvatar,
                avatarImage: Image(systemName: "person.crop.circle.fill"),
                onDismiss: {},
                onSelectSetting: { _ in },
                onLogout: {}
            )
        },
        entry("AuthPanel", .business) {
            AuthPanel(
                projection: BusinessComponentPreviewFixtures.authPhone,
                onClose: {},
                onChangePhone: { _ in },
                onSendCode: {},
                onChangeCode: { _ in },
                onVerifyCode: {},
                onResendCode: {},
                onRetryFocusTrip: {}
            )
        },
        entry("ChecklistItemRow", .business) {
            ChecklistItemRow(
                projection: BusinessComponentPreviewFixtures.checklistMemberKnown,
                onChangeQuantity: { _, _ in },
                onRemoveMember: { _ in }
            )
        },
        entry("ChecklistPanel", .business) {
            ChecklistPanel(
                summary: BusinessComponentPreviewFixtures.checklistSummary,
                isExpanded: false,
                members: BusinessComponentPreviewFixtures.checklistMembers,
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
            TripBusinessComponents.DailyWeatherCard(day: BusinessComponentPreviewFixtures.weatherDayDefault)
        },
        entry("ElevationProfile", .business) {
            RouteBusinessComponents.ElevationProfile(projection: BusinessComponentPreviewFixtures.elevationProfile)
        },
        entry("EquipmentDeletionImpact", .business) {
            EquipmentDeletionImpact(impact: BusinessComponentPreviewFixtures.deletionImpact)
        },
        entry("EquipmentListRow", .business) {
            EquipmentListRow(
                projection: BusinessComponentPreviewFixtures.personalEquipmentRow,
                onActivate: { _ in },
                onEdit: { _ in },
                onDelete: { _ in }
            )
        },
        entry("FocusTripSummary", .business) {
            FocusTripSummary(model: HomePreviewFixtures.focusComplete, onOpen: {})
                .frame(height: 700)
        },
        entry("GearRing", .business) {
            TripBusinessComponents.GearRing(
                projection: GearRingProjection(value: 6, total: 8, tone: .mint, label: "已有")
            )
        },
        entry("GenerationRouteSummaryCard", .business) {
            RouteBusinessComponents.GenerationRouteSummaryCard(
                projection: BusinessComponentPreviewFixtures.generationRouteDefault
            )
        },
        entry("GenerationWaitingView", .business) {
            RouteBusinessComponents.GenerationWaitingView(
                projection: BusinessComponentPreviewFixtures.generationWaiting,
                reduceMotionOverride: true
            )
            .frame(minHeight: 560)
        },
        entry("HeatmapCalendar", .business) {
            TripBusinessComponents.HeatmapCalendar(days: BusinessComponentPreviewFixtures.heatmapDefault)
        },
        entry("InlineEquipmentEditor", .business) {
            AccountEquipmentBusinessComponents.InlineEquipmentEditor(
                projection: BusinessComponentPreviewFixtures.inlineEquipmentDefault,
                onChangeField: { _, _ in },
                onChangeQuantity: { _ in },
                onCancel: {}
            )
        },
        entry("InlineListNameEditor", .business) {
            InlineListNameEditor(
                projection: BusinessComponentPreviewFixtures.inlineListDefault,
                onChangeName: { _ in },
                onCancel: {}
            )
        },
        entry("PersonalEquipmentForm", .business) {
            PersonalEquipmentForm(
                projection: BusinessComponentPreviewFixtures.personalEquipmentFormDefault,
                onChangeField: { _, _ in }
            )
        },
        entry("PersonalEquipmentSummaryCard", .business) {
            PersonalEquipmentSummaryCard(
                summary: BusinessComponentPreviewFixtures.personalEquipmentSummary,
                onActivate: {}
            )
        },
        entry("ProfileIdentityHeader", .business) {
            AccountEquipmentBusinessComponents.ProfileIdentityHeader(
                profile: BusinessComponentPreviewFixtures.profileDefault
            )
        },
        entry("RouteFactSection", .business) {
            RouteBusinessComponents.RouteFactSection(projection: BusinessComponentPreviewFixtures.routeSafetyFacts)
        },
        entry("RouteImageGallery", .business) {
            RouteBusinessComponents.RouteImageGallery(
                images: BusinessComponentPreviewFixtures.routeImages,
                onOpenImage: { _ in }
            ) { image in
                RouteDeterministicImageSurface(style: BusinessComponentPreviewFixtures.imageStyle(for: image.id))
            }
        },
        entry("RouteImageViewer", .business) {
            RouteBusinessComponents.RouteImageViewer(
                image: BusinessComponentPreviewFixtures.routeImages[0],
                onDismiss: {}
            ) {
                RouteDeterministicImageSurface(style: .ridge)
            }
        },
        entry("RouteIntroduction", .business) {
            RouteBusinessComponents.RouteIntroduction(projection: BusinessComponentPreviewFixtures.routeIntroduction)
        },
        entry("RouteListRow", .business) {
            RouteBusinessComponents.RouteListRow(
                projection: BusinessComponentPreviewFixtures.routeRowDefault,
                onSelect: { _ in }
            ) {
                RouteDeterministicImageSurface(style: .ridge)
            }
        },
        entry("RouteMap", .business) {
            RouteBusinessComponents.RouteMap(
                projection: BusinessComponentPreviewFixtures.routeMap,
                onSelectPoint: { _ in }
            )
            .frame(height: 700)
        },
        entry("RoutePointDetail", .business) {
            RouteBusinessComponents.RoutePointDetail(
                projection: BusinessComponentPreviewFixtures.routePointDetail,
                onDismiss: {}
            )
        },
        entry("RoutePointSection", .business) {
            RouteBusinessComponents.RoutePointSection(
                projection: BusinessComponentPreviewFixtures.routePointSection,
                onFocusPoint: { _ in }
            )
        },
        entry("RouteReferenceDayList", .business) {
            RouteBusinessComponents.RouteReferenceDayList(days: BusinessComponentPreviewFixtures.referenceDays)
        },
        entry("RouteScene", .business) {
            RouteBusinessComponents.RouteScene(
                projection: BusinessComponentPreviewFixtures.routeScene,
                onSelect: { _ in }
            ) {
                RouteDeterministicImageSurface(style: .ridge)
            }
            .frame(height: 700)
        },
        entry("RouteSegmentList", .business) {
            RouteBusinessComponents.RouteSegmentList(
                projection: BusinessComponentPreviewFixtures.routeSegments,
                onSelectSegment: { _ in }
            )
        },
        entry("RouteSummary", .business) {
            RouteBusinessComponents.RouteSummary(projection: BusinessComponentPreviewFixtures.routeSummary)
        },
        entry("TrekDayBadge", .business) {
            TripBusinessComponents.TrekDayBadge(
                projection: TrekDayBadgeProjection(trekDayNumber: 2, totalTrekDays: 3)
            )
        },
        entry("TripCalendarCard", .business) {
            TripBusinessComponents.TripCalendarCard(
                projection: BusinessComponentPreviewFixtures.tripCalendarDefault,
                onActivate: {}
            )
        },
        entry("TripCoverHeader", .business) {
            TripBusinessComponents.TripCoverHeader(
                projection: BusinessComponentPreviewFixtures.tripCoverDefault,
                onNavigateBack: {}
            ) {
                TripDeterministicCoverSurface()
            }
        },
        entry("TripDayArrangement", .business) {
            TripBusinessComponents.TripDayArrangement(
                projection: BusinessComponentPreviewFixtures.tripArrangementDefault
            )
            .frame(height: 700)
        },
        entry("TripDaySummaryCard", .business) {
            TripBusinessComponents.TripDaySummaryCard(
                day: BusinessComponentPreviewFixtures.tripDayDefault,
                onActivate: { _ in }
            )
        },
        entry("TripDayHikeSummary", .business) {
            TripBusinessComponents.TripDayHikeSummary(
                projection: BusinessComponentPreviewFixtures.tripDayDefault.hikeSummary
                    ?? TripDayHikeSummaryProjection(
                        segment: "徒步段",
                        distance: nil,
                        ascent: nil,
                        duration: nil,
                        nodes: []
                    )
            )
        },
        entry("TripDayTransportSummary", .business) {
            TripBusinessComponents.TripDayTransportSummary(
                projection: BusinessComponentPreviewFixtures.tripDayDefault.outboundTransport
                    ?? TripDayTransportSummaryProjection(
                        direction: .outbound,
                        title: "大交通与路线接驳",
                        timeRange: nil,
                        duration: nil,
                        path: nil,
                        modes: nil,
                        notice: nil
                    )
            )
        },
        entry("TripEquipmentSummaryCard", .business) {
            TripBusinessComponents.TripEquipmentSummaryCard(
                projection: BusinessComponentPreviewFixtures.tripEquipmentDefault,
                onActivate: {}
            )
        },
        entry("TripEquipmentGearRings", .business) {
            TripBusinessComponents.TripEquipmentGearRings(
                projection: BusinessComponentPreviewFixtures.tripEquipmentDefault.gearRings
            )
        },
        entry("TripListRow", .business) {
            TripBusinessComponents.TripListRow(
                projection: BusinessComponentPreviewFixtures.tripRowDefault,
                onActivate: { _ in }
            ) {
                TripDeterministicCoverSurface()
            }
        },
        entry("TripRouteSummaryCard", .business) {
            TripBusinessComponents.TripRouteSummaryCard(
                projection: BusinessComponentPreviewFixtures.tripRouteEntryDefault,
                onActivate: {}
            )
        },
        entry("TripStatusBadge", .business) {
            TripStatusBadge(status: .planned)
        },
        entry("TripWeatherSummaryCard", .business) {
            TripBusinessComponents.TripWeatherSummaryCard(
                projection: BusinessComponentPreviewFixtures.tripWeatherDefault,
                onActivate: {}
            )
        },
        entry("TripWeatherTrendChart", .business) {
            TripBusinessComponents.TripWeatherTrendChart(
                samples: BusinessComponentPreviewFixtures.tripWeatherDefault.samples
            )
        },
        entry("WeatherOverview", .business) {
            TripBusinessComponents.WeatherOverview(
                projection: BusinessComponentPreviewFixtures.weatherOverviewDefault
            )
        },
        entry("WeatherSummary", .business) {
            WeatherSummary(model: HomePreviewFixtures.weatherAvailable)
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
