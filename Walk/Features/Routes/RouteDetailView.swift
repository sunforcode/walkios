import SwiftUI
import MapKit
import WalkData
import WalkDesignSystem
import OutdoorMap

enum RouteDetailLayout {
    static let toolbarTop: CGFloat = 54
    static let bottomDetailMinimumHeight: CGFloat = 355
    /// 首屏信息区固定高度（分区式：屏幕分为地图区 + 信息区，信息区只装下标题/描述/标签/指标，剩余全给地图）。
    static let summarySectionHeight: CGFloat = 380
    /// section 间距（设计系统 token：`Spacing.md`）。
    static let sectionSpacing = Spacing.md
    /// section 卡片左右边距（悬浮卡样式，设计系统 token：`Spacing.md`）。
    static let sectionHorizontalMargin = Spacing.md
    /// 纯地图底部 dock 的估算高度，用于地图镜头底部避让。
    static let pureMapDockHeight: CGFloat = 216
    /// 纯地图下选中区间信息卡的估算高度，用于定位按钮避让。
    static let spanCardEstimatedHeight: CGFloat = 216
}

@MainActor
struct RouteDetailView: View {
    let routeId: String
    @State private var viewModel: RouteDetailViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.routeMapAccessAvailable) private var mapAccessAvailable
    @State private var selectedMapDetail: RouteMapDetailPresentation?
    private let onGenerateTrip: (String) -> Void

    // 纯地图模式页面内状态：不持久化，离开页面即重置。
    @State private var isPureMapActive = false
    @State private var activeDivision: RouteDivisionKind = .day
    @State private var activeSpanID: String?
    @State private var scrubPosition: PublicRoutePathPosition?
    @State private var showsGenerationNotice = false
    @State private var recenterRequest = 0
    @State private var mapDisplayOptions = MapDisplayOptions()
    @State private var mapResourceNotice: String?
    @State private var mapHasLoaded = false
    /// 信息面是否滚动在顶部：控制全屏按钮显隐。
    @State private var isPanelScrolledToTop = true
    /// 信息面顶部下拽的跟手偏移：收起时保持不归零，随收起动画一起滑出。
    @State private var panelDragOffset: CGFloat = 0
    /// push 首帧只渲染占位底色，地图引擎启动不与转场动画抢主线程。
    @State private var isMapLayerActive = false

    init(
        routeId: String,
        service: any RouteDetailServicing,
        onGenerateTrip: @escaping (String) -> Void
    ) {
        self.init(
            routeId: routeId,
            viewModel: RouteDetailViewModel(service: service),
            onGenerateTrip: onGenerateTrip
        )
    }

    init(
        routeId: String,
        viewModel: RouteDetailViewModel,
        onGenerateTrip: @escaping (String) -> Void
    ) {
        self.routeId = routeId
        _viewModel = State(initialValue: viewModel)
        self.onGenerateTrip = onGenerateTrip
    }

    var body: some View {
        GeometryReader { geometry in
            // 分区式首屏：信息区固定高度，地图区吸收剩余空间。
            // firstSectionHeight 为含内边距的 section 外高，panelSections 调用处再减内边距得内容高。
            // 滚动内容延伸到物理屏幕底，topSpacer 补偿底部Home指示器区域，让下一 section 顶边刚好落在物理底之外。
            let topSpacerHeight = geometry.size.height + Spacing.safeAreaBottom
                - RouteDetailLayout.summarySectionHeight
                - RouteDetailLayout.sectionSpacing
            let firstSectionHeight = RouteDetailLayout.summarySectionHeight

            ZStack(alignment: .bottom) {
                // 占位常驻底层，地图就绪后淡入其上。
                mapPlaceholder
                    .onAppear { scheduleMapLayerActivation() }

                if isMapLayerActive {
                    mapLayer(viewportHeight: geometry.size.height)
                        .transition(.opacity)
                }

                detailContent(topSpacerHeight: topSpacerHeight, firstSectionHeight: firstSectionHeight)
                    .offset(y: isPureMapActive ? geometry.size.height : 0)
                    .allowsHitTesting(!isPureMapActive)
                    .accessibilityHidden(isPureMapActive)

                mapToolbar

                // 定位与划分切换：纯地图下共用右下控制区。
                if isPureMapActive {
                    if viewModel.pureMapAvailable, viewModel.pureMapDockProjection.hasBothDivisions {
                        pureMapControls
                            .padding(.trailing, Spacing.pageHorizontal)
                            .padding(.bottom, pureMapControlsBottomPadding)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                            .zIndex(11)
                    } else {
                        locateButton
                            .position(
                                x: geometry.size.width - Spacing.pageHorizontal - 22,
                                y: geometry.size.height - 64
                            )
                    }
                } else {
                    fullscreenButton
                        .position(
                            x: geometry.size.width - Spacing.pageHorizontal - 22,
                            y: topSpacerHeight - 60
                        )
                        // 全屏按钮只在信息面停在首屏时可见，上推滚动淡出，下拉回顶淡入。
                        .opacity(isPanelScrolledToTop ? 1 : 0)
                        .allowsHitTesting(isPanelScrolledToTop)
                        .animation(.easeInOut(duration: 0.2), value: isPanelScrolledToTop)
                }

                if viewModel.hasUnavailableTrack {
                    NoticeView(message: trackUnavailableText)
                        .frame(maxWidth: 320)
                        .position(x: geometry.size.width / 2, y: 124)
                        .zIndex(9)
                }

                if let message = mapNotice {
                    NoticeView(message: message)
                        .frame(maxWidth: 320)
                        .position(x: geometry.size.width / 2, y: 180)
                        .allowsHitTesting(false)
                        .zIndex(9)
                }

                if let selectedMapDetail {
                    RouteBusinessComponents.RoutePointDetail(
                        projection: selectedMapDetail.pointDetailProjection
                    ) {
                        self.selectedMapDetail = nil
                    }
                    .zIndex(20)
                }

                // 纯地图状态：信息面移出屏幕，贴底 dock（可选信息卡悬浮其上）。
                if isPureMapActive, viewModel.pureMapAvailable, let presentation = viewModel.presentation {
                    pureMapOverlay(presentation: presentation)
                        .zIndex(10)
                }

                if showsGenerationNotice {
                    NoticeView(
                        message: generationUnavailableMessage,
                        title: "路线资料不足",
                        icon: "exclamationmark.triangle",
                        tone: .warning
                    )
                    .frame(maxWidth: 320)
                    .position(x: geometry.size.width / 2, y: 124)
                    .zIndex(9)
                    .onTapGesture { showsGenerationNotice = false }
                    .task(id: showsGenerationNotice) {
                        try? await Task.sleep(nanoseconds: 2_600_000_000)
                        showsGenerationNotice = false
                    }
                }
            }
            .background {
                ImmersivePageContainer { AppColors.surfacePrimary.opacity(0) }
            }
        }
        .ignoresSafeArea(edges: [.top, .horizontal])
        .toolbar(.hidden, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .task(id: routeId) { await viewModel.loadRoute(id: routeId) }
        .task(id: viewModel.sceneRequestID) { await viewModel.refreshScenes() }
    }

    /// 纯地图贴底层：选中区间信息卡悬浮在 dock 之上，不遮挡唤回把手。
    @ViewBuilder
    private func pureMapOverlay(presentation: RouteDetailPresentation) -> some View {
        VStack(spacing: Spacing.md) {
            if let spanID = activeSpanID,
               let card = viewModel.spanCardProjection(spanID: spanID, division: activeDivision) {
                RouteBusinessComponents.RouteSpanCard(projection: card)
                    .padding(.horizontal, Spacing.pageHorizontal)
                    .transition(.opacity)
            }

            RouteBusinessComponents.RouteMapDock(
                projection: viewModel.pureMapDockProjection,
                activeDivision: activeDivision,
                activeSpanID: activeSpanID,
                onRestore: { restoreInfoPanel() },
                onSelectSpan: { toggleSpan($0) },
                onScrub: { position in scrubPosition = position }
            )
        }
        .allowsHitTesting(selectedMapDetail == nil)
    }

    private func toggleSpan(_ spanID: String) {
        guard selectedMapDetail == nil else { return }
        withAnimation(.easeInOut(duration: 0.2)) {
            activeSpanID = activeSpanID == spanID ? nil : spanID
        }
    }

    private func enterPureMap() {
        guard selectedMapDetail == nil, viewModel.pureMapAvailable else { return }
        withAnimation(.easeInOut(duration: 0.32)) { isPureMapActive = true }
    }

    private func restoreInfoPanel() {
        guard selectedMapDetail == nil else { return }
        // 面板在屏外，此刻归零下拽偏移不产生可见跳变。
        withAnimation(.easeInOut(duration: 0.32)) {
            isPureMapActive = false
            panelDragOffset = 0
        }
    }

    private var locateButton: some View {
        IconButton(
            systemName: "location.fill",
            accessibilityLabel: "回到路线中心",
            variant: .overlay,
            action: { recenterRequest += 1 }
        )
    }

    /// 信息面首屏右侧的全屏入口：点击进入纯地图，与下拽手势同链路。
    private var fullscreenButton: some View {
        IconButton(
            systemName: "arrow.up.left.and.arrow.down.right",
            accessibilityLabel: "进入全屏地图",
            variant: .overlay,
            action: { enterPureMap() }
        )
    }

    /// 小按钮切换划分口径：显示另一口径名，点击即切换并清除选中。
    private var divisionToggleButton: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.28)) {
                activeDivision = activeDivision == .day ? .segment : .day
                activeSpanID = nil
            }
        } label: {
            HStack(spacing: Spacing.xs) {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.microStrong)
                Text(activeDivision == .day ? "分段" : "分日")
                    .font(.microStrong)
            }
            .foregroundStyle(AppColors.textPrimary)
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.xs)
            .background(AppColors.surfaceControlOverlay, in: Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("切换划分口径")
        .accessibilityValue(activeDivision == .day ? "当前分日，点击切换分段" : "当前分段，点击切换分日")
    }

    private var pureMapControls: some View {
        HStack(spacing: Spacing.sm) {
            divisionToggleButton
            locateButton
        }
    }

    private var pureMapControlsBottomPadding: CGFloat {
        RouteDetailLayout.pureMapDockHeight
            + (activeSpanID != nil ? RouteDetailLayout.spanCardEstimatedHeight : 0)
            + Spacing.lg
    }

    private var generationUnavailableMessage: String {
        viewModel.presentation?.generationAction.unavailableMessage ?? "路线资料不足，暂不可生成"
    }

    @ViewBuilder
    private func detailContent(topSpacerHeight: CGFloat, firstSectionHeight: CGFloat) -> some View {
        if viewModel.isLoading && viewModel.presentation == nil {
            RouteDetailStateOverlay {
                LoadingView(message: "正在加载路线完整资料", variant: .page)
            }
        } else if let message = viewModel.errorMessage, viewModel.presentation == nil {
            RouteDetailStateOverlay {
                ErrorView(message: message, title: "暂时无法加载路线详情", variant: .page) {
                    Task { await viewModel.retry() }
                }
            }
        } else if let presentation = viewModel.presentation {
            RouteDetailScrollOverlay(
                presentation: presentation,
                elevationProfile: viewModel.elevationProfileProjection,
                topSpacerHeight: topSpacerHeight,
                firstSectionHeight: firstSectionHeight,
                panelDragOffset: $panelDragOffset,
                selectedSegmentID: viewModel.selectedSegmentID,
                highlightedPointIdentity: viewModel.highlightedPointIdentity,
                onSelectSegment: viewModel.selectSegment,
                onSelectItem: viewModel.togglePointHighlight,
                onFocusPoint: viewModel.togglePointHighlight,
                onCollapse: { enterPureMap() },
                onScrolledTopChange: { isPanelScrolledToTop = $0 }
            )
        }
    }

    /// 延迟创建 MKMapView：等 push 转场过半后再启动 MapKit 引擎，避免首帧同步创建撞上转场。
    private func scheduleMapLayerActivation() {
        guard !isMapLayerActive else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            withAnimation(.easeIn(duration: 0.2)) {
                isMapLayerActive = true
            }
        }
    }

    /// 地图占位：与 RouteMap 瓦片加载前的底色一致。
    private var mapPlaceholder: some View {
        AppColors.pageBase
            .ignoresSafeArea()
            .accessibilityHidden(true)
    }

    private func mapLayer(viewportHeight: CGFloat) -> some View {
        let mapRevealHeight = viewportHeight
            - RouteDetailLayout.summarySectionHeight
            - RouteDetailLayout.sectionSpacing
        return RouteMapView(
            coordinates: viewModel.mapCoordinates,
            segments: isPureMapActive
                ? viewModel.divisionMapSegments(for: activeDivision)
                : viewModel.mapSegments,
            baseCoordinates: isPureMapActive ? viewModel.mapCoordinates : [],
            selectedSegmentID: isPureMapActive ? activeSpanID : viewModel.selectedSegmentID,
            divisionBadges: isPureMapActive ? viewModel.divisionBadges(for: activeDivision) : [],
            scrubCoordinate: isPureMapActive
                ? scrubPosition.flatMap { viewModel.pathCoordinate(at: $0) }
                : nil,
            recenterRequest: recenterRequest,
            poiAnnotations: viewModel.poiAnnotations,
            trackPointAnnotations: viewModel.selectableTrackPoints,
            waypointAnnotations: viewModel.waypointAnnotations,
            highlightedAnnotationIDs: viewModel.highlightedAnnotationIDs,
            startCoordinate: viewModel.mapStartCoordinate,
            endCoordinate: viewModel.mapEndCoordinate,
            showsUserLocation: false,
            edgeInsets: isPureMapActive
                ? RouteMapCamera.pureMapEdgeInsets(bottomDockHeight: RouteDetailLayout.pureMapDockHeight)
                : RouteMapCamera.detailEdgeInsets(
                    viewportHeight: viewportHeight,
                    mapRevealHeight: mapRevealHeight
                ),
            displayOptions: mapDisplayOptions,
            isMapAvailable: mapAccessAvailable,
            onSelectSegment: { id in
                if isPureMapActive { toggleSpan(id) } else { viewModel.selectSegment(id) }
            },
            onSelectMarker: { selection in
                viewModel.highlightPoint(selection)
                selectedMapDetail = RouteMapDetailPresentation(selection: selection)
            },
            onSelectSpan: { toggleSpan($0) },
            onMapEvent: handleMapEvent
        )
        .ignoresSafeArea()
    }

    private var mapToolbar: some View {
        VStack(spacing: 0) {
            HStack {
                IconButton(
                    systemName: "chevron.left",
                    accessibilityLabel: "返回",
                    variant: .overlay,
                    action: { dismiss() }
                )
                Spacer()
                if let presentation = viewModel.presentation {
                    HStack(spacing: Spacing.sm) {
                        // 生成入口：信息面与纯地图共用同一位置；禁用时可点，用轻提示说明原因。
                        RouteToolbarGenerateAction(
                            action: presentation.generationAction,
                            onGenerate: { onGenerateTrip(routeId) },
                            onUnavailable: { showsGenerationNotice = true }
                        )
                        RouteShareButton(shareText: presentation.actionPolicy.shareText)
                    }
                }
            }
            .padding(.horizontal, Spacing.pageHorizontal)
            .padding(.top, RouteDetailLayout.toolbarTop)

            HStack {
                Spacer()
                VStack(alignment: .trailing, spacing: Spacing.xs) {
                    mapDisplayControls
                    if mapDisplayOptions.showsTerrain && mapDisplayOptions.terrainLevel == .enhanced {
                        Text("增强会夸大地形起伏")
                            .font(.micro).foregroundStyle(AppColors.textPrimary)
                            .padding(Spacing.xs)
                            .background(AppColors.surfaceControlOverlay, in: Capsule())
                    }
                }
            }
            .padding(.horizontal, Spacing.pageHorizontal)
            .padding(.top, Spacing.sm)

            Spacer()
        }
    }

    private var mapDisplayControls: some View {
        Menu {
            Picker("底图", selection: $mapDisplayOptions.baseMap) {
                Text("地形地图").tag(MapDisplayOptions.BaseMap.topographic)
                Text("卫星地图").tag(MapDisplayOptions.BaseMap.satellite)
            }.pickerStyle(.inline)
            Picker("地形显示", selection: terrainModeBinding) {
                Text("二维").tag(RouteTerrainMode.flat)
                Text("普通3D").tag(RouteTerrainMode.normal)
                Text("增强3D").tag(RouteTerrainMode.enhanced)
            }.pickerStyle(.inline)
            Toggle("等高线", isOn: $mapDisplayOptions.showsContours)
        } label: {
            Label("地图显示", systemImage: "square.3.layers.3d")
                .font(.appCaption).foregroundStyle(AppColors.textPrimary)
                .padding(.horizontal, Spacing.md).padding(.vertical, Spacing.sm)
                .background(AppColors.surfaceControlOverlay, in: Capsule())
                .overlay(Capsule().stroke(AppColors.borderOverlay, lineWidth: 1))
        }
        .accessibilityIdentifier("route-map-settings")
        .accessibilityValue("\(mapDisplayOptions.baseMap == .satellite ? "卫星地图" : "地形地图")，\(terrainModeBinding.wrappedValue.title)，\(mapHasLoaded ? "地图已加载" : "地图加载中")")
        .onChange(of: mapDisplayOptions.baseMap) { _, _ in mapHasLoaded = false }
    }

    private var terrainModeBinding: Binding<RouteTerrainMode> {
        Binding(get: {
            guard mapDisplayOptions.showsTerrain else { return .flat }
            return mapDisplayOptions.terrainLevel == .enhanced ? .enhanced : .normal
        }, set: { mode in
            mapDisplayOptions.showsTerrain = mode != .flat
            if mode != .flat { mapDisplayOptions.terrainLevel = mode == .enhanced ? .enhanced : .normal }
        })
    }

    private var mapNotice: String? {
        if !mapAccessAvailable { return "地图暂不可用，路线资料仍可查看。" }
        return viewModel.mapCoordinateNotice ?? mapResourceNotice
    }

    private func handleMapEvent(_ event: OutdoorMapEvent) {
        switch event {
        case .mapLoaded:
            mapHasLoaded = true
            mapResourceNotice = nil
        case .failed:
            mapHasLoaded = false
            mapResourceNotice = "地图资源暂不可用，请检查网络后重试。"
        case .styleReady, .selected, .longPressed, .userInteractionBegan: break
        }
    }

    private var trackUnavailableText: String {
        switch viewModel.route?.currentVersion.mainTrackAvailability {
        case .processing: "主轨迹正在处理，其他路线资料仍可查看。"
        case .pendingReview: "主轨迹正在审核，暂不可生成个人行程。"
        case .invalidated: "主轨迹已失效，暂不可生成个人行程。"
        case .missing: "当前没有可用主轨迹，暂不可生成个人行程。"
        case .valid, .none: "当前没有可用主轨迹。"
        }
    }
}

private enum RouteTerrainMode: Hashable {
    case flat, normal, enhanced

    var title: String {
        switch self {
        case .flat: "二维"
        case .normal: "普通3D"
        case .enhanced: "增强3D"
        }
    }
}


private enum RouteMapDetailPresentation: Identifiable {
    case poi(RoutePOIAnnotation)
    case trackPoint(RouteTrackPointMetadata)
    case waypoint(RouteWaypointAnnotation)

    init(selection: RouteMapSelection) {
        switch selection {
        case .poi(let point): self = .poi(point)
        case .trackPoint(let point): self = .trackPoint(point)
        case .waypoint(let point): self = .waypoint(point)
        }
    }

    var id: String {
        switch self {
        case .poi(let point): "poi-\(point.id)"
        case .trackPoint(let point): "track-\(point.id)"
        case .waypoint(let waypoint): "waypoint-\(waypoint.id)"
        }
    }

    var title: String {
        switch self {
        case .poi(let point): point.title
        case .trackPoint(let point): point.title
        case .waypoint(let waypoint): waypoint.title
        }
    }

    var category: String? {
        switch self {
        case .poi(let point): point.category
        case .trackPoint(let point): point.type
        case .waypoint(let waypoint): waypoint.type
        }
    }

    var rows: [(String, String)] {
        let values: [(String, String)]
        switch self {
        case .poi(let point):
            values = [
                ("类别", point.category),
                ("子类别", point.subCategory),
                ("描述", point.detail),
                ("海拔", point.elevation),
            ]
        case .trackPoint(let point):
            values = [("类型", point.type), ("描述", point.detail)]
        case .waypoint(let waypoint):
            values = [("类型", waypoint.type), ("描述", waypoint.detail), ("海拔", waypoint.elevation)]
        }
        return values.filter { !$0.1.isEmpty }
    }

    /// D3：映射到生产 RoutePointDetail 投影。类别作类型次级说明，描述作正文，
    /// 其余事实进详情列表；图片槽位不在组件合同内，不补造。
    var pointDetailProjection: RoutePointDetailProjection {
        let description = rows.first(where: { $0.0 == "描述" })?.1
        let details = rows
            .filter { $0.0 != "描述" && $0.0 != "类别" && $0.0 != "类型" }
            .map { RoutePointDetailItemProjection(id: $0.0, label: $0.0, value: $0.1) }
        return RoutePointDetailProjection(
            id: id,
            name: title,
            type: category,
            location: nil,
            description: description,
            details: details
        )
    }
}




#if DEBUG
#Preview {
    NavigationStack {
        RouteDetailView(
            routeId: "route-1",
            service: RouteService(apiClient: MockAPIClient(fixtures: DefaultMockFixtures.all())),
            onGenerateTrip: { _ in }
        )
    }
}
#endif
