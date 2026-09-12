import SwiftUI
import WalkData
import WalkDesignSystem

struct TripDetailView: View {
    @Environment(\.dismiss) private var dismiss
    let tripID: String
    let reloadRevision: String?
    @StateObject private var viewModel: TripDetailViewModel
    @State private var isCancelConfirmationPresented = false
    @State private var isMigrationConfirmationPresented = false
    @State private var showsVersionDifferences = false
    private let onOpenRoute: (String) -> Void
    private let onOpenEquipment: () -> Void
    private let onOpenDay: (String) -> Void
    private let onOpenWeather: () -> Void
    private let baselinePresentation: TripDetailBaselinePresentation?

    init(
        tripID: String,
        service: any PersonalTripServicing,
        reloadRevision: String? = nil,
        onOpenRoute: @escaping (String) -> Void,
        onOpenEquipment: @escaping () -> Void,
        onOpenDay: @escaping (String) -> Void,
        onOpenWeather: @escaping () -> Void
    ) {
        self.tripID = tripID
        self.reloadRevision = reloadRevision
        self.onOpenRoute = onOpenRoute
        self.onOpenEquipment = onOpenEquipment
        self.onOpenDay = onOpenDay
        self.onOpenWeather = onOpenWeather
        self.baselinePresentation = nil
        _viewModel = StateObject(wrappedValue: TripDetailViewModel(service: service))
    }

    init(
        tripID: String,
        viewModel: TripDetailViewModel,
        reloadRevision: String? = nil,
        onOpenRoute: @escaping (String) -> Void = { _ in },
        onOpenEquipment: @escaping () -> Void = {},
        onOpenDay: @escaping (String) -> Void = { _ in },
        onOpenWeather: @escaping () -> Void = {},
        baselinePresentation: TripDetailBaselinePresentation? = nil
    ) {
        self.tripID = tripID
        self.reloadRevision = reloadRevision
        self.onOpenRoute = onOpenRoute
        self.onOpenEquipment = onOpenEquipment
        self.onOpenDay = onOpenDay
        self.onOpenWeather = onOpenWeather
        self.baselinePresentation = baselinePresentation
        _viewModel = StateObject(wrappedValue: viewModel)
        _showsVersionDifferences = State(
            initialValue: baselinePresentation?.showsVersionDifferences == true
        )
    }

    var body: some View {
        ZStack {
            AppColors.pageBase.ignoresSafeArea()

            stateContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .toolbar(.hidden, for: .navigationBar)
        .overlay(alignment: .topLeading) {
            if viewModel.trip == nil {
                IconButton(
                    systemName: "chevron.left",
                    accessibilityLabel: "返回",
                    variant: .overlay,
                    action: { dismiss() }
                )
                .padding(.leading, Spacing.pageHorizontal)
                .padding(.top, Spacing.sm)
            }
        }
        .overlay(alignment: .topTrailing) {
            maintenanceMenuOverlay
        }
        .task { await viewModel.loadTrip(id: tripID) }
        .onChange(of: reloadRevision) { revision in
            guard let revision, revision != viewModel.trip?.revision else { return }
            Task { await viewModel.loadTrip(id: tripID) }
        }
        .confirmationDialog(
            "确认取消这趟行程？",
            isPresented: $isCancelConfirmationPresented,
            titleVisibility: .visible
        ) {
            Button("取消行程", role: .destructive) {
                Task { await viewModel.cancelTrip(id: tripID) }
            }
            Button("返回", role: .cancel) {}
        } message: {
            Text("取消后行程会保留，但只能只读查看。")
        }
        .confirmationDialog(
            "确认整体迁移到当前公开新版？",
            isPresented: $isMigrationConfirmationPresented,
            titleVisibility: .visible
        ) {
            Button("整体迁移") {
                Task { await viewModel.migrateTrip(id: tripID) }
            }
            Button("返回", role: .cancel) {}
        } message: {
            Text("路线依据、逐日安排、天气、点位和装备快照将作为一个完整结果切换。")
        }
        .alert("操作未完成", isPresented: mutationErrorBinding) {
            Button("知道了") { viewModel.errorMessage = nil }
        } message: {
            Text(viewModel.errorMessage ?? "请稍后重试")
        }
    }

    @ViewBuilder
    private var maintenanceMenuOverlay: some View {
        if let detail = viewModel.trip, detail.trip.status == .planned {
            Menu {
                Button("取消行程", role: .destructive) {
                    isCancelConfirmationPresented = true
                }
            } label: {
                IconButton(
                    systemName: "ellipsis.circle",
                    accessibilityLabel: "行程维护",
                    variant: .overlay,
                    action: {}
                )
            }
            .disabled(viewModel.isMutating)
            .padding(.trailing, Spacing.pageHorizontal)
            .padding(.top, Spacing.sm)
        }
    }

    @ViewBuilder
    private var stateContent: some View {
        if viewModel.errorMessage != nil, viewModel.trip == nil {
            ErrorView(
                message: "不会用其他行程或当前公开路线补齐。",
                title: "暂时无法加载行程",
                variant: .page,
                retry: { Task { await viewModel.loadTrip(id: tripID) } }
            )
        } else if let detail = viewModel.trip,
                  let days = viewModel.days {
            tripDetailContent(TripDetailPresentation(
                detail: detail,
                days: days,
                routeVersionStatus: viewModel.routeVersionStatus ?? detail.routeVersionStatus
            ))
        } else {
            LoadingView(message: "正在加载个人行程", variant: .page)
        }
    }

    private func tripDetailContent(_ presentation: TripDetailPresentation) -> some View {
        ImmersivePageContainer {
            VStack(spacing: 0) {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: Spacing.xl) {
                            TripBusinessComponents.TripCoverHeader(
                                projection: presentation.coverProjection,
                                onNavigateBack: { dismiss() }
                            ) {
                                TripDeterministicCoverSurface()
                            }
                            .id("baseline-trip-detail-top")

                            TripBusinessComponents.TripRouteVersionCard(
                                projection: routeVersionProjection(
                                    detail: presentation.detail,
                                    versionStatus: presentation.routeVersionStatus,
                                    differencesExpanded: showsVersionDifferences,
                                    isMigrating: viewModel.isMutating,
                                    migrationErrorMessage: viewModel.migrationErrorMessage
                                ),
                                onViewCurrentRoute: { onOpenRoute(presentation.detail.routeReference.routeID) },
                                onToggleDifferences: { showsVersionDifferences.toggle() },
                                onRequestMigration: { isMigrationConfirmationPresented = true }
                            )
                            .padding(.horizontal, Spacing.pageHorizontal)

                            TripBusinessComponents.TripRouteMetricsSummary(
                                projection: routeMetricsProjection(presentation.detail.trip.frozenRouteBasis)
                            )
                            .padding(.horizontal, Spacing.pageHorizontal)

                            daysSection(presentation.dayProjections)

                            TripBusinessComponents.TripRouteSummaryCard(
                                projection: routeEntryProjection(presentation.detail),
                                onActivate: { onOpenRoute(presentation.detail.routeReference.routeID) }
                            )
                            .padding(.horizontal, Spacing.pageHorizontal)
                            .id("baseline-trip-detail-bottom")

                            if let weatherSummaryProjection = presentation.weatherSummaryProjection {
                                TripBusinessComponents.TripWeatherSummaryCard(
                                    projection: weatherSummaryProjection,
                                    onActivate: onOpenWeather
                                )
                                .padding(.horizontal, Spacing.pageHorizontal)
                                .id("baseline-trip-detail-weather")
                            } else if viewModel.isWeatherUnavailable {
                                UnavailableStateView(
                                    title: "行程天气暂不可用",
                                    message: "天气关联尚未形成完整投影，其他行程内容不受影响。",
                                    icon: "cloud.sun",
                                    actionTitle: "重试",
                                    action: { Task { await viewModel.loadTrip(id: tripID) } },
                                    variant: .block
                                )
                                .padding(.horizontal, Spacing.pageHorizontal)
                                .id("baseline-trip-detail-weather")
                            }
                            TripBusinessComponents.TripEquipmentSummaryCard(
                                projection: presentation.equipmentSummaryProjection,
                                onActivate: onOpenEquipment
                            )
                            .padding(.horizontal, Spacing.pageHorizontal)
                            .id("baseline-trip-detail-equipment")
                            if !presentation.notices.isEmpty {
                                noticesSection(presentation.notices)
                            }
                        }
                        .frame(maxWidth: 600, alignment: .topLeading)
                        .frame(maxWidth: .infinity, alignment: .top)
                        .padding(.bottom, Spacing.xxl)
                    }
                    .accessibilityIdentifier("baseline.trip-detail.scroll")
                    .refreshable { await viewModel.loadTrip(id: tripID) }
                    .onChange(of: viewModel.trip?.revision) { revision in
                        guard revision != nil else { return }
                        scrollToBaselinePosition(using: proxy)
                    }
                }
            }
        }
    }

    private func daysSection(_ dayProjections: [TripDayProjection]) -> some View {
        ContentSection(title: "完整行程安排") {
            VStack(alignment: .leading, spacing: Spacing.md) {
                if dayProjections.isEmpty {
                    UnavailableStateView(
                        title: "逐日安排暂不可用",
                        message: "不会根据日期范围或默认模板补造自然日。",
                        icon: "calendar",
                        variant: .section
                    )
                } else {
                    ForEach(dayProjections, id: \.tripDayID) { day in
                        TripBusinessComponents.TripDaySummaryCard(
                            day: day,
                            onActivate: { _ in onOpenDay(day.tripDayID) }
                        )
                        .id("baseline-trip-detail-day-\(day.dayNumber)")
                        .accessibilityIdentifier("baseline.trip-detail.day.\(day.dayNumber)")
                    }
                }
            }
        }
        .padding(.horizontal, Spacing.pageHorizontal)
    }

    private func noticesSection(_ notices: [PersonalTripImportantNotice]) -> some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            ForEach(notices) { notice in
                if let content = notice.content.value {
                    NoticeView(
                        message: content,
                        title: "重要提醒",
                        icon: "exclamationmark.triangle",
                        tone: .warning
                    )
                }
            }
        }
        .padding(.horizontal, Spacing.pageHorizontal)
    }

    private var mutationErrorBinding: Binding<Bool> {
        Binding(
            get: {
                viewModel.trip != nil
                    && viewModel.errorMessage != nil
                    && viewModel.migrationErrorMessage == nil
            },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )
    }

    private func scrollToBaselinePosition(using proxy: ScrollViewProxy) {
        let target: String?
        switch baselinePresentation?.scrollPosition {
        case .middle:
            target = "baseline-trip-detail-day-2"
        case .bottom:
            target = "baseline-trip-detail-bottom"
        case .top, .none:
            target = nil
        }
        guard let target else { return }
        DispatchQueue.main.async {
            proxy.scrollTo(target, anchor: .top)
        }
    }

}

private func routeVersionProjection(
    detail: PersonalTripDetail,
    versionStatus: PersonalTripRouteVersionStatus,
    differencesExpanded: Bool,
    isMigrating: Bool,
    migrationErrorMessage: String?
) -> TripRouteVersionCardProjection {
    let route = detail.trip.frozenRouteBasis
    let adoptedVersionLabel = versionStatus.adoptedVersion.versionLabel
        ?? route.versionLabel
        ?? "采用版本"
    let currentVersionLabel = versionStatus.currentPublicVersion.flatMap { $0.versionLabel }
        ?? "当前公开版本"
    let relationship = versionRelationship(versionStatus.versionRelationship)
    let difference = versionStatus.difference
    let canViewCurrentRoute = relationship != .currentPublicVersionUnavailable
    let migrationEligible = detail.trip.status == .planned
        && versionStatus.currentPublicVersion != nil
        && relationship == .newerPublicVersionAvailable
    return TripRouteVersionCardProjection(
        adoptedVersionLabel: adoptedVersionLabel,
        currentPublicVersionLabel: versionStatus.currentPublicVersion.flatMap { $0.versionLabel },
        relationship: relationship,
        migrationEligible: migrationEligible,
        comparisonStatus: difference.map(comparisonStatusText),
        differences: difference?.differences.map(versionDifference) ?? [],
        unavailableCategories: difference?.unavailableCategories.map { $0.title } ?? [],
        otherRelevantChanges: difference?.otherRelevantChanges ?? [],
        otherRelevantChangeStatus: difference?.otherRelevantChangeStatus == .unknown
            ? "暂不可确认"
            : nil,
        differencesExpanded: differencesExpanded,
        canViewCurrentRoute: canViewCurrentRoute,
        isMigrating: isMigrating,
        migrationResult: migrationErrorMessage.map {
            TripNoticeProjection(
                id: "migration-error",
                title: "迁移未完成",
                message: $0,
                tone: .danger
            )
        }
    )
}

private func routeMetricsProjection(_ route: FrozenRouteBasis) -> TripRouteMetricsSummaryProjection {
    TripRouteMetricsSummaryProjection(
        distance: route.distance.map(tripDistanceText),
        ascent: route.ascent.map { "\(Int($0.meters.rounded())) m" },
        estimatedDuration: tripDurationText(route.estimatedDuration.seconds)
    )
}

private func routeEntryProjection(_ detail: PersonalTripDetail) -> TripRouteSummaryProjection {
    let route = detail.trip.frozenRouteBasis
    return TripRouteSummaryProjection(
        routeName: route.routeName,
        versionLabel: route.versionLabel,
        routeType: routeNonEmpty(route.routeType),
        region: route.region,
        start: route.start.name,
        end: route.end.name,
        direction: routeNonEmpty(route.direction),
        metrics: routeSummaryEntryMetrics(route)
    )
}

private func routeSummaryEntryMetrics(_ route: FrozenRouteBasis) -> [MetricItemModel] {
    var items: [MetricItemModel] = []
    if let distance = route.distance {
        items.append(MetricItemModel(id: "entry-distance", value: tripDistanceText(distance), unit: nil, label: "距离"))
    }
    if let ascent = route.ascent {
        items.append(MetricItemModel(id: "entry-ascent", value: "\(Int(ascent.meters.rounded()))", unit: "m", label: "累计爬升"))
    }
    items.append(MetricItemModel(id: "entry-duration", value: tripDurationText(route.estimatedDuration.seconds), unit: nil, label: "预计用时"))
    return items
}

private func versionRelationship(_ relationship: PersonalTripVersionRelationship) -> TripRouteVersionRelationship {
    switch relationship {
    case .current: .current
    case .newerPublicVersionAvailable: .newerPublicVersionAvailable
    case .currentPublicVersionUnavailable: .currentPublicVersionUnavailable
    }
}

private func comparisonStatusText(_ difference: PersonalTripRouteVersionDifference) -> String {
    switch difference.minimumComparisonStatus {
    case .unavailable:
        "五类最低差异整体不可用，不能据此判断无变化。"
    case .partial:
        "最低五类仅部分可比较；下方保留已确认变化与全部不可比较类别。"
    case .complete where !difference.differences.isEmpty:
        "最低五类比较完整；下方只列已确认的实际变化。"
    case .complete:
        "最低五类比较完整，未发现影响本次行程理解或准备的路线内容变化。"
    }
}

private func versionDifference(_ item: PersonalTripRouteVersionDifferenceItem) -> TripRouteDifferenceProjection {
    TripRouteDifferenceProjection(
        id: item.id,
        label: "\(item.category.title) · \(item.changeType.title)",
        changeType: differenceChangeType(item.changeType),
        summary: item.summary,
        before: item.before?.value,
        after: item.after?.value
    )
}

private func differenceChangeType(_ type: PersonalTripRouteDifferenceChangeType) -> TripRouteDifferenceChangeType {
    switch type {
    case .added: .added
    case .noLongerProvided: .noLongerProvided
    case .modified: .modified
    }
}

private func tripDistanceText(_ distance: RouteDistance) -> String {
    let meters = distance.meters
    return meters >= 1_000
        ? "\((meters / 1_000).formatted(.number.precision(.fractionLength(0...1)))) km"
        : "\(Int(meters.rounded())) m"
}

private func tripDurationText(_ seconds: Double) -> String {
    let hours = seconds / 3_600
    return hours >= 24
        ? "\((hours / 24).formatted(.number.precision(.fractionLength(0...1)))) 天"
        : "\(hours.formatted(.number.precision(.fractionLength(0...1)))) 小时"
}
