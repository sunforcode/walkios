import SwiftUI
import WalkData
import WalkDesignSystem

struct TripDetailView: View {
    let tripID: String
    let reloadRevision: String?
    private let demoScenesEnabled: Bool
    @State private var viewModel: TripDetailViewModel
    @State private var selection = TripExpeditionSelection.overview
    @State private var isCancelConfirmationPresented = false
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private let onOpenRoute: (String) -> Void
    private let onOpenEquipment: () -> Void
    private let onOpenWeather: () -> Void
    private let onOpenBrowse: (Int) -> Void

    init(
        tripID: String,
        service: any PersonalTripServicing,
        reloadRevision: String? = nil,
        demoScenesEnabled: Bool = false,
        onOpenRoute: @escaping (String) -> Void,
        onOpenEquipment: @escaping () -> Void,
        onOpenWeather: @escaping () -> Void,
        onOpenBrowse: @escaping (Int) -> Void = { _ in }
    ) {
        self.tripID = tripID
        self.reloadRevision = reloadRevision
        self.demoScenesEnabled = demoScenesEnabled
        self.onOpenRoute = onOpenRoute
        self.onOpenEquipment = onOpenEquipment
        self.onOpenWeather = onOpenWeather
        self.onOpenBrowse = onOpenBrowse
        _viewModel = State(initialValue: TripDetailViewModel(service: service))
    }

    init(
        tripID: String,
        viewModel: TripDetailViewModel,
        reloadRevision: String? = nil,
        demoScenesEnabled: Bool = false,
        onOpenRoute: @escaping (String) -> Void = { _ in },
        onOpenEquipment: @escaping () -> Void = {},
        onOpenWeather: @escaping () -> Void = {},
        onOpenBrowse: @escaping (Int) -> Void = { _ in }
    ) {
        self.tripID = tripID
        self.reloadRevision = reloadRevision
        self.demoScenesEnabled = demoScenesEnabled
        self.onOpenRoute = onOpenRoute
        self.onOpenEquipment = onOpenEquipment
        self.onOpenWeather = onOpenWeather
        self.onOpenBrowse = onOpenBrowse
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                navOverlay
                    .frame(minHeight: dynamicTypeSize.isAccessibilitySize ? 80 : 56)
                stateContent(size: geometry.size)
                    .transformAnchorPreference(key: TripExpeditionSceneViewportKey.self, value: .bounds) { viewports, anchor in
                        viewports.content = anchor
                    }
            }
            .frame(width: geometry.size.width, height: geometry.size.height, alignment: .top)
            .shadow(color: AppColors.shadowOverlay, radius: 2, y: 1)
            .clipped()
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("trip-detail-safe-content")
            .backgroundPreferenceValue(TripExpeditionSceneViewportKey.self) { viewports in
                background(viewports: viewports)
            }
        }
        .background(AppColors.pageBase)
        .toolbar(.hidden, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .task(id: reloadRevision) {
            await viewModel.loadTrip(id: tripID)
        }
        .task(id: viewModel.sceneRequestID) {
            guard !demoScenesEnabled else { return }
            await viewModel.refreshScenes()
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
            Button("知道了") { viewModel.dismissError() }
        } message: {
            Text(viewModel.errorMessage ?? "请稍后重试")
        }
    }

    /// 仅艺术层测量完整屏幕；正文仍使用系统提供的内容安全区。
    private func background(viewports: TripExpeditionSceneViewportKey.Value) -> some View {
        GeometryReader { geometry in
            if let scene = resolvedScene {
                let sceneViewport = viewports.scene.map { geometry[$0] } ?? .zero
                let contentViewport = viewports.content.map { geometry[$0] } ?? .zero
                TripBusinessComponents.TripExpeditionScene.Artwork(
                    projection: TripExpeditionSceneProjection(presentation: scene),
                    landmarkViewport: sceneViewport.intersection(contentViewport)
                )
                .frame(width: geometry.size.width, height: geometry.size.height)
            } else {
                AppColors.pageBase
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private var navOverlay: some View {
        UtilityNavigationHeader(
            leading: IconButtonConfiguration(
                systemName: "chevron.left",
                accessibilityLabel: "返回",
                action: { dismiss() }
            )
        )
        .overlay(alignment: .trailing) {
            HStack(spacing: Spacing.sm) {
                if let presentation = resolvedPresentation {
                    TripBusinessComponents.TripEquipmentSummaryCard(
                        projection: presentation.equipmentSummaryProjection,
                        presentation: .icon,
                        onActivate: onOpenEquipment
                    )
                }
                maintenanceMenu
            }
            .padding(.trailing, Spacing.pageHorizontal)
        }
    }

    private var maintenanceMenu: some View {
        Menu {
            if let presentation = resolvedPresentation {
                Button("公共路线详情", systemImage: "map") {
                    onOpenRoute(presentation.detail.routeReference.routeID)
                }
                .accessibilityIdentifier("trip-public-route")
            }
            Button("刷新行程", systemImage: "arrow.clockwise") {
                Task { await viewModel.loadTrip(id: tripID) }
            }
            if resolvedPresentation?.showsPageLevelCancel == true {
                Button("取消行程", systemImage: "xmark.circle", role: .destructive) {
                    isCancelConfirmationPresented = true
                }
                .disabled(viewModel.isMutating)
            }
        } label: {
            Image(systemName: "ellipsis")
                .font(.action)
                .foregroundStyle(AppColors.textPrimary)
                .frame(width: Spacing.navBarHeight, height: Spacing.navBarHeight)
                .background(AppColors.surfaceControlOverlay, in: Circle())
        }
        .accessibilityLabel("更多行程操作")
        .accessibilityIdentifier("trip-detail-more")
    }

    private var resolvedPresentation: TripDetailPresentation? {
        guard let detail = viewModel.trip, let days = viewModel.days else { return nil }
        return TripDetailPresentation(
            detail: detail,
            days: days,
            routeVersionStatus: viewModel.routeVersionStatus ?? detail.routeVersionStatus
        )
    }

    private var resolvedScene: TripExpeditionPresentation? {
        resolvedPresentation.map {
            TripExpeditionPresentation(source: $0, selection: selection, demoScenesEnabled: demoScenesEnabled, remoteScenes: viewModel.scenes)
        }
    }

    @ViewBuilder
    private func stateContent(size: CGSize) -> some View {
        if viewModel.errorMessage != nil, viewModel.trip == nil {
            ErrorView(
                message: "不会用其他行程或当前公开路线补齐。",
                title: "暂时无法加载行程",
                variant: .page,
                retry: { Task { await viewModel.loadTrip(id: tripID) } }
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let scene = resolvedScene {
            if dynamicTypeSize.isAccessibilitySize || size.height < 720 || size.width < 350 {
                accessibleContent(scene, size: size)
            } else {
                fixedContent(scene, size: size)
            }
        } else {
            LoadingView(message: "正在加载个人行程", variant: .page)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    /// 上方内容固定，场景吸收剩余高度，左下摘要区独立滚动。
    private func fixedContent(_ scene: TripExpeditionPresentation, size: CGSize) -> some View {
        VStack(spacing: Spacing.xs) {
            identity(scene)
                .fixedSize(horizontal: false, vertical: true)
            dateAndWeather(scene)
                .padding(.horizontal, Spacing.pageHorizontal)
            expeditionScene(scene)
                .frame(maxHeight: .infinity)
            VStack(alignment: .leading, spacing: Spacing.sm) {
                timelineHeading(scene, availableWidth: size.width)
                ScrollView {
                    timelineContent(scene, availableWidth: size.width)
                        .padding(.bottom, Spacing.sm)
                }
                .scrollIndicators(.hidden)
                .refreshable { await viewModel.loadTrip(id: tripID) }
                .accessibilityIdentifier("trip-expedition-timeline")
                .id(selection)
                .clipped()
            }
            .frame(width: timelineWidth(availableWidth: size.width), alignment: .leading)
            .frame(height: 200, alignment: .topLeading)
            .clipped()
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("trip-timeline-region")
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.leading, Spacing.xl)
            .padding(.bottom, Spacing.sm)
        }
        .frame(maxWidth: 640, maxHeight: .infinity, alignment: .top)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    /// 大字号 / 紧凑高度只保留一个正文滚动容器，避免文字被固定高度裁切。
    private func accessibleContent(_ scene: TripExpeditionPresentation, size: CGSize) -> some View {
        ScrollView {
            LazyVStack(spacing: Spacing.lg, pinnedViews: [.sectionHeaders]) {
                identity(scene)
                dateAndWeather(scene)
                    .padding(.horizontal, Spacing.pageHorizontal)
                expeditionScene(scene)
                    .frame(height: dynamicTypeSize.isAccessibilitySize ? 480 : sceneHeight(for: size.width))
                Section {
                    timelineContent(scene, availableWidth: size.width)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, Spacing.xl)
                } header: {
                    timelineHeading(scene, availableWidth: size.width)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, Spacing.xl)
                        .padding(.vertical, Spacing.sm)
                        .shadow(color: AppColors.pageBase, radius: 4)
                }
            }
            .padding(.bottom, Spacing.xl)
            .frame(maxWidth: 640)
            .frame(maxWidth: .infinity)
        }
        .scrollIndicators(.hidden)
        .refreshable { await viewModel.loadTrip(id: tripID) }
        .accessibilityIdentifier("trip-expedition-timeline")
    }

    private func identity(_ scene: TripExpeditionPresentation) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            TripBusinessComponents.TripCoverHeader(
                projection: scene.source.coverProjection,
                presentation: .identity(headline: scene.title, eyebrow: scene.eyebrow)
            ) {
                EmptyView()
            }
            .accessibilityIdentifier("trip-expedition-identity")
            if !scene.metrics.isEmpty {
                MetricGroup(items: scene.metrics)
                    .accessibilityIdentifier("trip-expedition-metrics")
                if let qualification = scene.referenceQualification {
                    Text(qualification)
                        .font(.micro)
                        .foregroundStyle(AppColors.textSecondary)
                        .accessibilityLabel(scene.referenceInformationNotices.joined(separator: "，"))
                        .accessibilityIdentifier("trip-reference-qualification")
                }
            }
        }
        .padding(.horizontal, Spacing.xl)
    }

    private func sceneHeight(for width: CGFloat) -> CGFloat {
        min(390, max(280, min(width, 640) * 0.58 + 48))
    }

    @ViewBuilder
    private func dateAndWeather(_ scene: TripExpeditionPresentation) -> some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                dateSelection(scene)
                weatherEntry(scene)
            }
        } else {
            HStack(spacing: Spacing.sm) {
                dateSelection(scene)
                Rectangle()
                    .fill(AppColors.borderOverlay)
                    .frame(width: 1, height: 36)
                    .accessibilityHidden(true)
                weatherEntry(scene)
                    .frame(width: 100)
            }
        }
    }

    private func dateSelection(_ scene: TripExpeditionPresentation) -> some View {
        HStack(spacing: Spacing.sm) {
            Button {
                changeSelection { $0.showOverview() }
            } label: {
                VStack(spacing: Spacing.xs) {
                    Image(systemName: "mountain.2")
                        .font(.action)
                    Text("全程")
                        .font(.microStrong)
                }
                .frame(width: 46, height: 58)
                .foregroundStyle(scene.selectedDay == nil ? AppColors.interactionOnPrimary : AppColors.textSecondary)
                .background(scene.selectedDay == nil ? AppColors.interactionPrimary : AppColors.surfaceControlOverlay, in: RoundedRectangle(cornerRadius: Radius.md))
                .overlay {
                    RoundedRectangle(cornerRadius: Radius.md).stroke(AppColors.borderOverlay, lineWidth: 1)
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("全程安排")
            .accessibilityAddTraits(scene.selectedDay == nil ? .isSelected : [])
            .accessibilityIdentifier("trip-date-overview")

            ScrollViewReader { proxy in
                ScrollView(.horizontal) {
                    HStack(spacing: Spacing.sm) {
                        ForEach(scene.calendarDays) { day in
                            dateButton(day, scene: scene)
                                .id(day.dayNumber)
                        }
                    }
                }
                .scrollIndicators(.hidden)
                .onChange(of: selection) { _, _ in
                    if let number = scene.selectedDay?.dayNumber {
                        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.25)) {
                            proxy.scrollTo(number, anchor: .center)
                        }
                    }
                }
            }
            .frame(height: 60)
        }
    }

    private func dateButton(_ day: PersonalTripDay, scene: TripExpeditionPresentation) -> some View {
        let isSelected = scene.selectedDay?.dayNumber == day.dayNumber
        return Button {
            changeSelection { $0.selectDay(day.dayNumber, availableDays: scene.calendarDays) }
        } label: {
            VStack(spacing: Spacing.xs) {
                Text(String(day.date.day))
                    .font(.dateTitle)
                    .monospacedDigit()
                Text("\(day.date.month)月")
                    .font(.micro)
            }
            .frame(width: 46, height: 58)
            .foregroundStyle(isSelected ? AppColors.interactionOnPrimary : AppColors.textPrimary)
            .background(isSelected ? AppColors.interactionPrimary : AppColors.surfaceControlOverlay, in: RoundedRectangle(cornerRadius: Radius.md))
            .overlay {
                RoundedRectangle(cornerRadius: Radius.md).stroke(isSelected ? AppColors.interactionPrimary : AppColors.borderOverlay, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(day.date.month)月\(day.date.day)日，\(day.primaryStage)")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityIdentifier("trip-date-\(day.dayNumber)")
    }

    private func weatherEntry(_ scene: TripExpeditionPresentation) -> some View {
        Button(action: onOpenWeather) {
            Group {
                if let weather = scene.weather {
                    TripBusinessComponents.DailyWeatherSummaryRow(day: weather, presentation: .inline)
                } else {
                    HStack(spacing: Spacing.xs) {
                        Image(systemName: "cloud.sun")
                            .font(.action)
                            .foregroundStyle(AppColors.interactionPrimary)
                        VStack(alignment: .leading, spacing: Spacing.xs) {
                            Text("全程天气")
                                .font(.weatherConclusion)
                                .foregroundStyle(AppColors.textPrimary)
                            Text(scene.source.weatherSummaryProjection == nil ? "暂不可用" : "\(scene.calendarDays.count) 天预报")
                                .font(.weatherImpact)
                                .foregroundStyle(AppColors.textSecondary)
                        }
                        Image(systemName: "chevron.right")
                            .font(.micro)
                            .foregroundStyle(AppColors.textWeak)
                    }
                }
            }
            .frame(minHeight: 44, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        .accessibilityHint("进入行程天气")
        .accessibilityIdentifier("trip-weather-day-summary")
    }

    private func expeditionScene(_ scene: TripExpeditionPresentation) -> some View {
        ZStack {
            TripBusinessComponents.TripExpeditionScene(
                projection: TripExpeditionSceneProjection(presentation: scene),
                onActivate: {
                    if let day = scene.selectedDay {
                        onOpenBrowse(day.dayNumber)
                    } else {
                        changeSelection { $0.enterFirstDay(in: scene.calendarDays) }
                    }
                },
                onMove: { offset in
                    changeSelection { $0.move(by: offset, in: scene.calendarDays) }
                }
            )
            .id(selection)
            .transition(.opacity)
        }
        .clipped()
    }

    private func timelineWidth(availableWidth: CGFloat) -> CGFloat {
        let contentWidth = max(0, min(availableWidth, 640) - Spacing.xl * 2)
        return dynamicTypeSize.isAccessibilitySize ? contentWidth : min(contentWidth, availableWidth * 0.66)
    }

    private func timelineHeading(_ scene: TripExpeditionPresentation, availableWidth: CGFloat) -> some View {
        Text(scene.timelineTitle)
            .font(dynamicTypeSize.isAccessibilitySize ? .caption : .appCaption)
            .foregroundStyle(AppColors.textSecondary)
            .fixedSize(horizontal: false, vertical: true)
            .frame(width: timelineWidth(availableWidth: availableWidth), alignment: .leading)
            .accessibilityAddTraits(.isHeader)
            .accessibilityIdentifier("trip-timeline-heading")
    }

    private func timelineContent(_ scene: TripExpeditionPresentation, availableWidth: CGFloat) -> some View {
        let timeWidth: CGFloat = scene.selectedDay == nil ? 28
            : (scene.timeline.contains { scene.timelineColumnTime(for: $0) != nil } ? 52 : 0)
        return VStack(alignment: .leading, spacing: Spacing.md) {
            if scene.timeline.isEmpty {
                UnavailableStateView(title: "安排暂未提供", message: "已有日期与其他行程信息仍可查看。", icon: "calendar", variant: .inline)
            } else {
                Timeline(
                    scene.timeline,
                    optionalTime: { scene.timelineColumnTime(for: $0) },
                    presentation: .compact,
                    timeColumnWidth: timeWidth,
                    sectionLabel: { scene.timelineMonthLabel(for: $0) }
                ) { item in
                    timelineItem(item, scene: scene)
                }
            }
        }
        .frame(width: timelineWidth(availableWidth: availableWidth), alignment: .leading)
        .accessibilityIdentifier("trip-timeline-content")
        .padding(.top, Spacing.xs)
    }

    private func timelineItem(_ item: TripTimelineSummaryProjection, scene: TripExpeditionPresentation) -> some View {
        TimelineSummaryContent(title: item.title, subtitle: item.subtitle)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel([scene.timelineAccessibilityDate(for: item), item.time, item.title, item.subtitle]
                .compactMap { $0 }.joined(separator: "，"))
    }

    private func changeSelection(_ change: (inout TripExpeditionSelection) -> Bool) {
        var next = selection
        guard change(&next) else { return }
        withAnimation(reduceMotion ? .easeInOut(duration: 0.12) : .easeInOut(duration: 0.38)) {
            selection = next
        }
    }

    private var mutationErrorBinding: Binding<Bool> {
        Binding(
            get: {
                viewModel.trip != nil
                    && viewModel.errorMessage != nil
                    && viewModel.migrationErrorMessage == nil
            },
            set: { if !$0 { viewModel.dismissError() } }
        )
    }
}
