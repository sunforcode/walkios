import SwiftUI
import MapKit
import WalkData
import WalkDesignSystem

private enum RouteDetailLayout {
    static let mapRevealHeight: CGFloat = 330
    static let compactMapRevealHeight: CGFloat = 280
    static let compactHeightThreshold: CGFloat = 760
    static let toolbarTop: CGFloat = 54
    static let bottomDetailMinimumHeight: CGFloat = 355
}

@MainActor
struct RouteDetailView: View {
    let routeId: String
    @StateObject private var viewModel: RouteDetailViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var selectedMapDetail: RouteMapDetailPresentation?
    private let onGenerateTrip: (String) -> Void

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
            let topSpacerHeight = geometry.size.height < RouteDetailLayout.compactHeightThreshold
                ? RouteDetailLayout.compactMapRevealHeight
                : RouteDetailLayout.mapRevealHeight

            ZStack(alignment: .bottom) {
                mapLayer(viewportHeight: geometry.size.height)

                detailContent(topSpacerHeight: topSpacerHeight)

                mapToolbar

                if viewModel.hasUnavailableTrack {
                    NoticeView(message: trackUnavailableText)
                        .frame(maxWidth: 320)
                        .position(x: geometry.size.width / 2, y: 124)
                        .zIndex(9)
                }

                if let presentation = viewModel.presentation {
                    RouteGenerationPrimaryAction(
                        action: presentation.generationAction,
                        onGenerateTrip: { onGenerateTrip(routeId) }
                    )
                }

                if let selectedMapDetail {
                    RouteBusinessComponents.RoutePointDetail(
                        projection: selectedMapDetail.pointDetailProjection
                    ) {
                        self.selectedMapDetail = nil
                    }
                    .zIndex(20)
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

    @ViewBuilder
    private func detailContent(topSpacerHeight: CGFloat) -> some View {
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
                selectedSegmentID: viewModel.selectedSegmentID,
                highlightedPointIdentity: viewModel.highlightedPointIdentity,
                onSelectSegment: viewModel.selectSegment,
                onSelectItem: viewModel.togglePointHighlight,
                onFocusPoint: viewModel.togglePointHighlight
            )
        }
    }

    private func mapLayer(viewportHeight: CGFloat) -> some View {
        let mapRevealHeight = viewportHeight < RouteDetailLayout.compactHeightThreshold
            ? RouteDetailLayout.compactMapRevealHeight
            : RouteDetailLayout.mapRevealHeight
        return RouteMapView(
            coordinates: viewModel.mapCoordinates,
            segments: viewModel.mapSegments,
            selectedSegmentID: viewModel.selectedSegmentID,
            poiAnnotations: viewModel.poiAnnotations,
            trackPointAnnotations: viewModel.selectableTrackPoints,
            waypointAnnotations: viewModel.waypointAnnotations,
            highlightedAnnotationIDs: viewModel.highlightedAnnotationIDs,
            startCoordinate: viewModel.mapStartCoordinate,
            endCoordinate: viewModel.mapEndCoordinate,
            cameraPitch: 45,
            edgeInsets: RouteMapCamera.detailEdgeInsets(
                viewportHeight: viewportHeight,
                mapRevealHeight: mapRevealHeight
            ),
            onSelectSegment: { viewModel.selectSegment($0) },
            onSelectMarker: { selection in
                viewModel.highlightPoint(selection)
                selectedMapDetail = RouteMapDetailPresentation(selection: selection)
            }
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
                    RouteShareButton(shareText: presentation.actionPolicy.shareText)
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

private struct RouteGenerationPrimaryAction: View {
    let action: RouteGenerationActionPresentation
    let onGenerateTrip: () -> Void

    var body: some View {
        FixedActionArea {
            PrimaryAction(
                title: action.isEnabled ? action.title : "路线资料不足，暂不可生成",
                isDisabled: !action.isEnabled,
                fillsWidth: true,
                action: onGenerateTrip
            )
            .disabled(!action.isEnabled)
            .accessibilityHint(action.unavailableMessage ?? "使用当前路线生成个人行程")
        }
    }
}

private struct RouteDetailScrollOverlay: View {
    let presentation: RouteDetailPresentation
    let topSpacerHeight: CGFloat
    let selectedSegmentID: String?
    let highlightedPointIdentity: String?
    let onSelectSegment: (String) -> Void
    let onSelectItem: (String) -> Void
    let onFocusPoint: (String) -> Void

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 0) {
                AppColors.surfacePrimary.opacity(0)
                    .frame(height: topSpacerHeight)
                    .allowsHitTesting(false)

                WalkPanel(variant: .edgeAttached) {
                    VStack(alignment: .leading, spacing: 0) {
                        SheetHandle()
                        VStack(alignment: .leading, spacing: Spacing.md) {
                            RouteBusinessComponents.RouteSummary(
                                projection: presentation.routeSummaryProjection
                            )
                        }
                        .padding(.bottom, Spacing.xl)

                        if let generationMessage = presentation.generationMessage {
                            NoticeView(
                                message: generationMessage,
                                title: "路线资料不足",
                                icon: "exclamationmark.triangle",
                                tone: .warning
                            )
                            .padding(.bottom, Spacing.xl)
                        }

                        VStack(alignment: .leading, spacing: Spacing.xl) {
                            if let introduction = presentation.routeIntroductionProjection {
                                RouteBusinessComponents.RouteIntroduction(projection: introduction)
                            }

                            if let elevationProfile = presentation.elevationProfileProjection {
                                RouteBusinessComponents.ElevationProfile(projection: elevationProfile)
                            }

                            if !presentation.referenceDayProjections.isEmpty {
                                RouteBusinessComponents.RouteReferenceDayList(
                                    days: presentation.referenceDayProjections
                                )
                            }

                            if let segments = presentation.routeSegmentListProjection {
                                RouteBusinessComponents.RouteSegmentList(
                                    projection: selectedSegments(segments),
                                    onSelectSegment: onSelectSegment
                                )
                            }

                            ForEach(Array(presentation.routePointSectionProjections.enumerated()), id: \.element.title) { _, section in
                                RouteBusinessComponents.RoutePointSection(
                                    projection: selectedPointSection(section),
                                    onFocusPoint: onFocusPoint
                                )
                            }

                            ForEach(Array(presentation.routeFactSectionProjections.enumerated()), id: \.element.title) { _, section in
                                RouteBusinessComponents.RouteFactSection(projection: section)
                            }

                            if presentation.sections.contains(where: { $0.id == .imagery }) {
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

                        AppColors.surfacePrimary.opacity(0)
                            .frame(height: 104)
                            .accessibilityHidden(true)
                    }
                    .frame(maxWidth: 600)
                    .frame(maxWidth: .infinity)
                }
            }
        }
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
