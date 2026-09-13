import SwiftUI
import WalkData
import WalkDesignSystem

struct TripDetailView: View {
    let tripID: String
    let reloadRevision: String?
    @StateObject private var viewModel: TripDetailViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var isCancelConfirmationPresented = false
    private let onOpenRoute: (String) -> Void
    private let onOpenEquipment: () -> Void
    private let onOpenWeather: () -> Void
    private let onOpenBrowse: (Int) -> Void
    private let baselinePresentation: TripDetailBaselinePresentation?

    init(
        tripID: String,
        service: any PersonalTripServicing,
        reloadRevision: String? = nil,
        onOpenRoute: @escaping (String) -> Void,
        onOpenEquipment: @escaping () -> Void,
        onOpenWeather: @escaping () -> Void,
        onOpenBrowse: @escaping (Int) -> Void = { _ in }
    ) {
        self.tripID = tripID
        self.reloadRevision = reloadRevision
        self.onOpenRoute = onOpenRoute
        self.onOpenEquipment = onOpenEquipment
        self.onOpenWeather = onOpenWeather
        self.onOpenBrowse = onOpenBrowse
        self.baselinePresentation = nil
        _viewModel = StateObject(wrappedValue: TripDetailViewModel(service: service))
    }

    init(
        tripID: String,
        viewModel: TripDetailViewModel,
        reloadRevision: String? = nil,
        onOpenRoute: @escaping (String) -> Void = { _ in },
        onOpenEquipment: @escaping () -> Void = {},
        onOpenWeather: @escaping () -> Void = {},
        onOpenBrowse: @escaping (Int) -> Void = { _ in },
        baselinePresentation: TripDetailBaselinePresentation? = nil
    ) {
        self.tripID = tripID
        self.reloadRevision = reloadRevision
        self.onOpenRoute = onOpenRoute
        self.onOpenEquipment = onOpenEquipment
        self.onOpenWeather = onOpenWeather
        self.onOpenBrowse = onOpenBrowse
        self.baselinePresentation = baselinePresentation
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        // PAGE-TRIP-DETAIL 自定义承载（不经统一二级页壳）：
        // 沉浸封面通到屏顶并随正文在同一滚动流内整体上滑，返回入口悬浮于封面顶部，
        // 标题由封面身份区唯一承载。
        ZStack(alignment: .top) {
            AppColors.pageBase
                .ignoresSafeArea()

            ScrollView {
                stateContent
            }
            .ignoresSafeArea(edges: .top)
            // 下拉刷新由本页自有滚动容器承担。
            .refreshable { await viewModel.loadTrip(id: tripID) }

            navOverlay
        }
        // 自定义悬浮导航承载系统返回：隐藏 NavigationStack 系统导航栏与 tab 栏，
        // 否则系统返回钮与本页 navOverlay 双钮并存，且安全区被导航栏下推、封面无法通到屏顶。
        .toolbar(.hidden, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .task {
            await viewModel.loadTrip(id: tripID)
        }
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
        .alert("操作未完成", isPresented: mutationErrorBinding) {
            Button("知道了") { viewModel.errorMessage = nil }
        } message: {
            Text(viewModel.errorMessage ?? "请稍后重试")
        }
    }

    /// 悬浮导航承载：返回入口悬浮于封面顶部（顶部安全区下方统一位置）；
    /// planned 行程的取消行程入口同在导航行右侧，不随内容滚动。
    private var navOverlay: some View {
        UtilityNavigationHeader(
            leading: IconButtonConfiguration(
                systemName: "chevron.left",
                accessibilityLabel: "返回",
                action: { dismiss() }
            )
        )
        .overlay(alignment: .trailing) {
            maintenanceMenuOverlay
        }
    }

    @ViewBuilder
    private var maintenanceMenuOverlay: some View {
        if let detail = viewModel.trip, detail.trip.status == .planned {
            Button {
                isCancelConfirmationPresented = true
            } label: {
                Text("取消行程")
                    .font(.listTitle)
                    .foregroundStyle(AppColors.danger)
            }
            .disabled(viewModel.isMutating)
        }
    }

    /// 封面投影：行程与自然日就绪后可用；加载/错误态无封面，封面身份区即页面主标题。
    private var resolvedPresentation: TripDetailPresentation? {
        guard let detail = viewModel.trip, let days = viewModel.days else { return nil }
        return TripDetailPresentation(
            detail: detail,
            days: days,
            routeVersionStatus: viewModel.routeVersionStatus ?? detail.routeVersionStatus
        )
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
            .padding(.top, Spacing.navBarHeight)
            .frame(maxWidth: .infinity, minHeight: 420, alignment: .center)
        } else if let presentation = resolvedPresentation {
            tripDetailContent(presentation)
        } else {
            LoadingView(message: "正在加载个人行程", variant: .page)
                .padding(.top, Spacing.navBarHeight)
                .frame(maxWidth: .infinity, minHeight: 420, alignment: .center)
        }
    }

    private func tripDetailContent(_ presentation: TripDetailPresentation) -> some View {
        ScrollViewReader { proxy in
            LazyVStack(alignment: .leading, spacing: 0) {
                TripBusinessComponents.TripCoverHeader(projection: presentation.coverProjection) {
                    TripDeterministicCoverSurface()
                }
                // 封面通到屏顶整幅出血，随正文在同一滚动流内整体上滑。
                .ignoresSafeArea(edges: .top)
                .id("baseline-trip-detail-cover")

                // 页面自定义承载自持水平边距与最大宽度（原由统一壳持有）。
                VStack(alignment: .leading, spacing: Spacing.xl) {
                    overviewSection(presentation)

                routeSection(presentation)

                if !presentation.weatherDayProjections.isEmpty {
                    weatherSection(presentation.weatherDayProjections)
                } else if viewModel.isWeatherUnavailable {
                    UnavailableStateView(
                        title: "行程天气暂不可用",
                        message: "天气关联尚未形成完整投影，其他行程内容不受影响。",
                        icon: "cloud.sun",
                        actionTitle: "重试",
                        action: { Task { await viewModel.loadTrip(id: tripID) } },
                        variant: .block
                    )
                    .id("baseline-trip-detail-weather")
                }
                TripBusinessComponents.TripEquipmentSummaryCard(
                    projection: presentation.equipmentSummaryProjection,
                    onActivate: onOpenEquipment
                )
                .id("baseline-trip-detail-equipment")
                if !presentation.notices.isEmpty {
                    noticesSection(presentation.notices)
                }
                    Spacer(minLength: 0)
                        .frame(height: 1)
                        .id("baseline-trip-detail-bottom")
                }
                .padding(.horizontal, Spacing.pageHorizontal)
                .padding(.top, Spacing.lg)
                .padding(.bottom, Spacing.xxl)
                .frame(maxWidth: 600)
                .frame(maxWidth: .infinity, alignment: .top)
            }
            .onChange(of: viewModel.trip?.revision) { revision in
                guard revision != nil else { return }
                scrollToBaselinePosition(using: proxy)
            }
        }
    }

    /// 行程概览区：整体色块（标题 + 冻结概述 + 自然日入口分块），逐日进入逐日阅读页。
    private func overviewSection(_ presentation: TripDetailPresentation) -> some View {
        WalkCard {
            VStack(alignment: .leading, spacing: Spacing.md) {
                Text("行程概览")
                    .font(.sectionTitle)
                    .foregroundStyle(AppColors.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)

                if let introduction = tripNonEmpty(presentation.detail.trip.frozenRouteBasis.introduction) {
                    Text(introduction)
                        .font(.appBody)
                        .foregroundStyle(AppColors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if presentation.dayOverviewEntries.isEmpty {
                    UnavailableStateView(
                        title: "逐日安排暂不可用",
                        message: "不会根据日期范围或默认模板补造自然日。",
                        icon: "calendar",
                        variant: .section
                    )
                } else {
                    ForEach(Array(presentation.dayOverviewEntries.enumerated()), id: \.element.id) { index, entry in
                        if index > 0 {
                            Divider()
                        }
                        TripBusinessComponents.TripDayOverviewEntry(
                            projection: entry,
                            onActivate: { onOpenBrowse(entry.dayNumber) }
                        )
                        .id("baseline-trip-detail-overview-day-\(entry.dayNumber)")
                        .accessibilityIdentifier("baseline.trip-detail.overview.day.\(entry.dayNumber)")
                    }
                }
            }
        }
        // 页面水平边距由统一壳持有。
        .id("baseline-trip-detail-overview")
    }

    /// 路线介绍区：整体色块（标题 + 走向文字卡 + 冻结指标摘要分块）。
    private func routeSection(_ presentation: TripDetailPresentation) -> some View {
        WalkCard {
            VStack(alignment: .leading, spacing: Spacing.md) {
                Text("路线介绍")
                    .font(.sectionTitle)
                    .foregroundStyle(AppColors.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)

                TripBusinessComponents.TripRouteSummaryCard(
                    projection: routeEntryProjection(presentation),
                    onActivate: {
                        onOpenRoute(presentation.detail.routeReference.routeID)
                    }
                )
                .id("baseline-trip-detail-route-entry")
            }
        }
        // 页面自定义承载自持水平边距。
        .id("baseline-trip-detail-route")
    }

    /// 走向文字卡投影：只消费冻结事实（路线名、走向摘要、冻结指标、冻结海拔剖面）。
    private func routeEntryProjection(_ presentation: TripDetailPresentation) -> TripRouteSummaryProjection {
        let basis = presentation.detail.trip.frozenRouteBasis
        return TripRouteSummaryProjection(
            routeName: basis.routeName,
            versionLabel: tripNonEmpty(basis.versionLabel),
            routeOrientation: tripNonEmpty(basis.routeOrientation),
            elevationSamples: basis.elevationProfile?.samples,
            metrics: TripRouteMetricsSummaryProjection(
                distance: basis.distance.map { tripDistanceText($0) },
                ascent: basis.ascent.map { "\(Int($0.meters.rounded())) m" },
                descent: basis.descent.map { "\(Int($0.meters.rounded())) m" },
                maxElevation: basis.maxElevation.map { "\(Int($0.meters.rounded())) m" }
            )
        )
    }

    /// 行程天气区：整体色块（标题 + 每日摘要行，D 序 + 日期 + 冻结天气地点｜状况 + 温度），
    /// 点按任一日进入天气页查看四字段明细；摘要行间用分隔线，对齐概览入口节奏。
    private func weatherSection(_ days: [TripWeatherDayProjection]) -> some View {
        WalkCard {
            VStack(alignment: .leading, spacing: Spacing.md) {
                Text("行程天气")
                    .font(.sectionTitle)
                    .foregroundStyle(AppColors.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)

                ForEach(days) { day in
                    Button(action: onOpenWeather) {
                        TripBusinessComponents.DailyWeatherSummaryRow(day: day)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint("进入行程天气")

                    if day.id != days.last?.id {
                        Divider()
                    }
                }
            }
        }
        .id("baseline-trip-detail-weather")
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
            target = "baseline-trip-detail-overview"
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

private func tripDistanceText(_ distance: RouteDistance) -> String {
    let meters = distance.meters
    return meters >= 1_000
        ? "\((meters / 1_000).formatted(.number.precision(.fractionLength(0...1)))) km"
        : "\(Int(meters.rounded())) m"
}
