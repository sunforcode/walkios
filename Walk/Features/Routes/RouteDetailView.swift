import SwiftUI
import MapKit
import WalkData
import WalkDesignSystem

private enum RouteDetailLayout {
    static let toolbarTop: CGFloat = 54
    static let bottomDetailMinimumHeight: CGFloat = 355
    /// 首屏信息区固定高度（分区式：屏幕分为地图区 + 信息区，信息区只装下标题/描述/标签/指标，剩余全给地图）。
    static let summarySectionHeight: CGFloat = 380
    /// section 间距（空白 border 10，设计系统暂无对应 token）。
    static let sectionSpacing: CGFloat = 10
    /// section 卡片左右边距（悬浮卡样式，参考首屏单框左右露底 10，设计系统暂无对应 token）。
    static let sectionHorizontalMargin: CGFloat = 10
    /// 纯地图底部 dock 的估算高度，用于地图镜头底部避让。
    static let pureMapDockHeight: CGFloat = 216
    /// 纯地图下选中区间信息卡的估算高度，用于定位按钮避让。
    static let spanCardEstimatedHeight: CGFloat = 216
}

@MainActor
struct RouteDetailView: View {
    let routeId: String
    @StateObject private var viewModel: RouteDetailViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var selectedMapDetail: RouteMapDetailPresentation?
    private let onGenerateTrip: (String) -> Void

    // 纯地图模式页面内状态：不持久化，离开页面即重置。
    @State private var isPureMapActive = false
    @State private var activeDivision: RouteDivisionKind = .day
    @State private var activeSpanID: String?
    @State private var scrubPosition: PublicRoutePathPosition?
    @State private var showsGenerationNotice = false
    @State private var recenterRequest = 0
    /// 信息面是否滚动在顶部：控制全屏按钮显隐。
    @State private var isPanelScrolledToTop = true
    /// 信息面顶部下拽的跟手偏移：收起时保持不归零，随收起动画一起滑出。
    @State private var panelDragOffset: CGFloat = 0

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
        _viewModel = StateObject(wrappedValue: viewModel)
        self.onGenerateTrip = onGenerateTrip
    }

    var body: some View {
        GeometryReader { geometry in
            // 分区式首屏：信息区固定高度，地图区吸收剩余空间。
            // firstSectionHeight 为含内边距的 section 外高，panelSections 调用处再减内边距得内容高。
            // 滚动内容延伸到物理屏幕底，topSpacer 需补偿底部安全区，让下一 section 顶边刚好落在物理底之外。
            let topSpacerHeight = geometry.size.height + geometry.safeAreaInsets.bottom
                - RouteDetailLayout.summarySectionHeight
                - RouteDetailLayout.sectionSpacing
            let firstSectionHeight = RouteDetailLayout.summarySectionHeight

            ZStack(alignment: .bottom) {
                mapLayer(viewportHeight: geometry.size.height)

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
        .task { await viewModel.loadRoute(id: routeId) }
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
            cameraPitch: 45,
            edgeInsets: isPureMapActive
                ? RouteMapCamera.pureMapEdgeInsets(bottomDockHeight: RouteDetailLayout.pureMapDockHeight)
                : RouteMapCamera.detailEdgeInsets(
                    viewportHeight: viewportHeight,
                    mapRevealHeight: mapRevealHeight
                ),
            onSelectSegment: { viewModel.selectSegment($0) },
            onSelectMarker: { selection in
                viewModel.highlightPoint(selection)
                selectedMapDetail = RouteMapDetailPresentation(selection: selection)
            },
            onSelectSpan: { toggleSpan($0) }
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

            Spacer()
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

private struct RouteShareButton: View {
    let shareText: String
    @State private var isPresented = false

    var body: some View {
        IconButton(
            systemName: "square.and.arrow.up",
            accessibilityLabel: "分享路线",
            variant: .overlay,
            action: { isPresented = true }
        )
        .sheet(isPresented: $isPresented) {
            ShareSheet(items: [shareText])
        }
    }
}

private struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}

private struct RouteDetailStateOverlay<Content: View>: View {
    @ViewBuilder let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.horizontal, Spacing.xl)
            .padding(.top, 100)
            .padding(.bottom, 110)
            .background(AppColors.pageBase.opacity(0.52))
    }
}

/// 工具栏紧凑生成入口：资格不足时保持可见，禁用呈现但可点，触发原因提示。
private struct RouteToolbarGenerateAction: View {
    let action: RouteGenerationActionPresentation
    let onGenerate: () -> Void
    let onUnavailable: () -> Void

    var body: some View {
        PrimaryAction(
            title: "立即出发",
            systemImage: "wand.and.stars",
            variant: .compact,
            isDisabled: false,
            action: action.isEnabled ? onGenerate : onUnavailable
        )
        .opacity(action.isEnabled ? 1 : 0.62)
        .accessibilityHint(action.isEnabled ? "使用当前路线生成个人行程" : action.unavailableMessage ?? "路线资料不足，暂不可生成")
    }
}

/// 顶部滚动状态读取：iOS 18+ 用 onScrollGeometryChange；低版本用 preference 侦测内容位移。
/// contentMargins + viewAligned 下内容全局 frame 不随滚动变化，preference 在新系统上失效。
private struct RouteDetailScrollTopReader: ViewModifier {
    let baseline: CGFloat
    let onChange: (Bool) -> Void

    func body(content: Content) -> some View {
        if #available(iOS 18, *) {
            content.onScrollGeometryChange(for: Bool.self) { geometry in
                geometry.contentOffset.y <= 1
            } action: { _, isTop in
                onChange(isTop)
            }
        } else {
            content
                .background(
                    GeometryReader { geometry in
                        AppColors.surfacePrimary.opacity(0)
                            .preference(
                                key: RouteDetailScrollOffsetKey.self,
                                value: geometry.frame(in: .global).minY
                            )
                    }
                )
                .onPreferenceChange(RouteDetailScrollOffsetKey.self) { value in
                    onChange(value >= baseline - 1)
                }
        }
    }
}

private struct RouteDetailScrollOffsetKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

extension View {
    /// scrollBounceBehavior 需要 iOS 16.4；低版本回退为默认弹性行为。
    @ViewBuilder
    var routeDetailScrollNoBounce: some View {
        if #available(iOS 16.4, *) {
            scrollBounceBehavior(.basedOnSize)
        } else {
            self
        }
    }

    /// 标记 section 列表为吸附目标布局（iOS 17+，低版本无操作）。
    @ViewBuilder
    func routeDetailScrollTargetLayout() -> some View {
        if #available(iOS 17, *) {
            scrollTargetLayout()
        } else {
            self
        }
    }

    /// 滚动容器：顶部内边距让首屏 section 对齐屏幕（iOS 17+）。
    /// 不再挂 scrollTargetBehavior：viewAligned 的「最近目标」策略会把小幅上划
    /// 直接吸回原 section；去掉后滚动完全自然，轻扫停在松手位置，拂动靠惯性滑动。
    @ViewBuilder
    func routeDetailAlignedScrolling(topInset: CGFloat) -> some View {
        if #available(iOS 17, *) {
            contentMargins(.top, topInset, for: .scrollContent)
        } else {
            self
        }
    }
}

private struct RouteDetailScrollOverlay: View {
    let presentation: RouteDetailPresentation
    let topSpacerHeight: CGFloat
    /// 首屏 section 固定高度：首屏只展示路线概要，不露出后续 section。
    let firstSectionHeight: CGFloat
    /// 顶部下拽跟手偏移，由页面持有：收起时保持原值随动画滑出，唤回时归零。
    @Binding var panelDragOffset: CGFloat
    let selectedSegmentID: String?
    let highlightedPointIdentity: String?
    let onSelectSegment: (String) -> Void
    let onSelectItem: (String) -> Void
    let onFocusPoint: (String) -> Void
    /// 信息面顶部下拽越过阈值后松手，自动收起进入纯地图。
    let onCollapse: () -> Void
    /// 滚动离顶/回顶回调：驱动全屏按钮显隐。
    let onScrolledTopChange: (Bool) -> Void

    @State private var isScrolledToTop = true

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 0) {
                // iOS 17+ 用 contentMargins 提供顶部内边距并参与吸附对齐；低版本用占位 spacer。
                if #unavailable(iOS 17) {
                    AppColors.surfacePrimary.opacity(0)
                        .frame(height: topSpacerHeight)
                        .allowsHitTesting(false)
                }

                panelSections

                // 底部安全区：最后一个区块不被手势条遮挡；放在 target layout 外避免成为吸附点。
                AppColors.surfacePrimary.opacity(0)
                    .frame(height: 120)
                    .accessibilityHidden(true)
            }
        }
        .routeDetailAlignedScrolling(topInset: topSpacerHeight)
        .modifier(RouteDetailScrollTopReader(
            baseline: scrollOffsetBaseline,
            onChange: { isTop in
                if isTop != isScrolledToTop {
                    isScrolledToTop = isTop
                    onScrolledTopChange(isTop)
                }
            }
        ))
        .offset(y: panelDragOffset)
        .simultaneousGesture(
            DragGesture(minimumDistance: 16)
                .onChanged { value in
                    guard isScrolledToTop else { return }
                    // 顶部下拽：面板跟手移动；禁弹后不再叠加滚动阻尼。
                    panelDragOffset = max(0, value.translation.height)
                }
                .onEnded { value in
                    if isScrolledToTop, value.translation.height > 120 {
                        // 不归零跟手偏移：面板从当前拖拽位置随收起动画直接滑出，避免先弹回再消失的跳变。
                        onCollapse()
                        return
                    }
                    withAnimation(.easeOut(duration: 0.22)) { panelDragOffset = 0 }
                }
        )
        .routeDetailScrollNoBounce
        .accessibilityAction(named: Text("收起信息面进入纯地图")) {
            onCollapse()
        }
    }

    /// iOS 17+ 吸附滚动基线：contentMargins 模式下内容 minY 静止时等于顶部内边距。
    private var scrollOffsetBaseline: CGFloat {
        if #available(iOS 17, *) { return topSpacerHeight }
        return 0
    }

    /// 信息面容器透明，每个资料区独立成卡片悬浮展示；海拔曲线固定在最底部。
    @ViewBuilder
    private var panelSections: some View {
        VStack(spacing: RouteDetailLayout.sectionSpacing) {
            sectionCard(fixedHeight: firstSectionHeight - Spacing.xl * 2) {
                RouteBusinessComponents.RouteSummary(
                    projection: presentation.routeSummaryProjection
                )
            }

            if let generationMessage = presentation.generationMessage {
                NoticeView(
                    message: generationMessage,
                    title: "路线资料不足",
                    icon: "exclamationmark.triangle",
                    tone: .warning
                )
                .padding(.horizontal, Spacing.pageHorizontal)
            }

            if let introduction = presentation.routeIntroductionProjection {
                sectionCard {
                    RouteBusinessComponents.RouteIntroduction(projection: introduction)
                }
            }

            if !presentation.referenceDayProjections.isEmpty {
                sectionCard {
                    RouteBusinessComponents.RouteReferenceDayList(
                        days: presentation.referenceDayProjections
                    )
                }
            }

            if let segments = presentation.routeSegmentListProjection {
                sectionCard {
                    RouteBusinessComponents.RouteSegmentList(
                        projection: selectedSegments(segments),
                        onSelectSegment: onSelectSegment
                    )
                }
            }

            ForEach(Array(presentation.routePointSectionProjections.enumerated()), id: \.element.title) { _, section in
                sectionCard {
                    RouteBusinessComponents.RoutePointSection(
                        projection: selectedPointSection(section),
                        onFocusPoint: onFocusPoint
                    )
                }
            }

            ForEach(Array(presentation.routeFactSectionProjections.enumerated()), id: \.element.title) { _, section in
                sectionCard {
                    RouteBusinessComponents.RouteFactSection(projection: section)
                }
            }

            if presentation.sections.contains(where: { $0.id == .imagery }) {
                sectionCard {
                    RouteBusinessComponents.RouteImageGallery(
                        images: presentation.images.map { item in
                            RouteImageProjection(
                                id: item.id,
                                title: item.caption,
                                description: nil
                            )
                        }
                    ) { image in
                        detailImageSurface(
                            source: presentation.images.first(where: { $0.id == image.id })?.source ?? "",
                            failurePlaceholderSystemImage: "photo"
                        )
                    }
                }
            }

            if let elevationProfile = presentation.elevationProfileProjection {
                sectionCard {
                    RouteBusinessComponents.ElevationProfile(projection: elevationProfile)
                }
            }

            // 底部安全区留白已上移到滚动内容层，此处仅收束 section 列表。
        }
        .routeDetailScrollTargetLayout()
        .frame(maxWidth: 600)
        .frame(maxWidth: .infinity)
    }

    private func sectionCard<Content: View>(
        fixedHeight: CGFloat? = nil,
        @ViewBuilder _ content: () -> Content
    ) -> some View {
        let card = content()
            .frame(maxWidth: .infinity, alignment: .leading)
        return Group {
            if let fixedHeight {
                card.frame(height: fixedHeight, alignment: .top)
            } else {
                card
            }
        }
        .padding(Spacing.xl)
        .background(
            AppColors.surfacePrimary,
            in: RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
        )
        .padding(.horizontal, RouteDetailLayout.sectionHorizontalMargin)
    }

    private func selectedSegments(_ projection: RouteSegmentListProjection) -> RouteSegmentListProjection {
        var projection = projection
        projection.activeSegmentID = selectedSegmentID
        return projection
    }

    private func selectedPointSection(_ projection: RoutePointSectionProjection) -> RoutePointSectionProjection {
        var projection = projection
        projection.activePointID = highlightedPointIdentity
        return projection
    }

    /// 只读图片视觉：保留实际 URL 加载与失败占位，不建立任何打开事件。
    private func detailImageSurface(source: String, failurePlaceholderSystemImage: String) -> some View {
        AsyncImage(url: URL(string: source)) { phase in
            switch phase {
            case .success(let image):
                image.resizable().scaledToFill()
            default:
                ZStack {
                    AppColors.surfaceElevated
                    Image(systemName: failurePlaceholderSystemImage)
                        .foregroundStyle(AppColors.textWeak)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 70)
        .clipped()
        .clipShape(RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
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
            service: PreviewHelpers.routeService,
            onGenerateTrip: { _ in }
        )
    }
}
#endif
