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
    @State private var selectedImage: RouteDetailImagePresentation?
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
                    RoutePointBottomDetail(detail: selectedMapDetail) {
                        self.selectedMapDetail = nil
                    }
                    .ignoresSafeArea()
                    .zIndex(20)
                }

                if let selectedImage {
                    RouteImageViewer(image: selectedImage) {
                        self.selectedImage = nil
                    }
                    .ignoresSafeArea()
                    .zIndex(30)
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
                onFocusPoint: viewModel.togglePointHighlight,
                onOpenImage: { selectedImage = $0 }
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

private struct RouteDetailMetricPanel: View {
    let metrics: [RouteSummaryMetric]

    var body: some View {
        if !metrics.isEmpty {
            VStack(spacing: Spacing.md) {
                ForEach(Array(metrics.enumerated()), id: \.offset) { _, metric in
                    HStack(spacing: Spacing.sm) {
                        Image(systemName: metric.systemImage)
                            .font(.appCaption)
                            .foregroundStyle(AppColors.interactionPrimary)
                            .frame(width: 20)
                        Text(metric.title)
                            .font(.appCaption)
                            .foregroundStyle(AppColors.textSecondary)
                        Spacer()
                        Text(metric.value)
                            .font(.metricGridValue)
                            .foregroundStyle(AppColors.textPrimary)
                    }
                }
            }
            .padding(Spacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppColors.sheetSectionBackground)
            .clipShape(RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
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
    let onOpenImage: (RouteDetailImagePresentation) -> Void

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
                            RouteDetailMetricPanel(metrics: presentation.summaryMetrics)
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

                            if let imageSection = presentation.sections.first(where: { $0.id == .imagery }) {
                                RouteDetailSectionContainer(onOpenImage: onOpenImage) {
                                    Text(imageSection.title)
                                        .font(.sectionTitle)
                                        .foregroundStyle(AppColors.textPrimary)
                                    RouteImageGrid(images: presentation.images, onOpenImage: onOpenImage)
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
}

private struct RouteDetailSectionContainer<Content: View>: View {
    let onOpenImage: (RouteDetailImagePresentation) -> Void
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            content()
        }
        .padding(15)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColors.sheetSectionBackground)
        .clipShape(RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
    }
}

private struct RouteImageGrid: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let images: [RouteDetailImagePresentation]
    let onOpenImage: (RouteDetailImagePresentation) -> Void

    var body: some View {
        LazyVGrid(columns: columns, alignment: .leading, spacing: 7) {
            ForEach(images) { item in
                Button {
                    onOpenImage(item)
                } label: {
                    VStack(alignment: .leading, spacing: Spacing.xs) {
                        AsyncImage(url: URL(string: item.source)) { phase in
                            switch phase {
                            case .success(let image):
                                image.resizable().scaledToFill()
                            default:
                                ZStack {
                                    AppColors.surfaceElevated
                                    Image(systemName: item.failurePlaceholderSystemImage)
                                        .foregroundStyle(AppColors.textWeak)
                                }
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 70)
                        .clipped()
                        .clipShape(RoundedRectangle(cornerRadius: Radius.md, style: .continuous))

                        Text(item.caption ?? "路线图片")
                            .font(.tag)
                            .foregroundStyle(AppColors.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("查看图片：\(item.caption ?? "路线图片")")
            }
        }
    }

    private var columns: [GridItem] {
        Array(
            repeating: GridItem(.flexible(), spacing: 7),
            count: dynamicTypeSize.isAccessibilitySize ? 2 : 3
        )
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

    var imageURL: URL? {
        switch self {
        case .poi(let point): point.imageURL
        case .trackPoint(let point): point.imageURL
        case .waypoint(let waypoint): waypoint.imageURL
        }
    }
}

private struct RoutePointBottomDetail: View {
    let detail: RouteMapDetailPresentation
    let onClose: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack(alignment: .bottom) {
            AppColors.surfaceOverlay
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture(perform: onClose)

            VStack(spacing: 0) {
                SheetHandle()

                ScrollView(.vertical, showsIndicators: false) {
                    detailContent
                }
            }
            .frame(maxHeight: UIScreen.main.bounds.height - 54)
            .padding(.horizontal, Spacing.xl)
            .padding(.top, Spacing.sm)
            .padding(.bottom, Spacing.xl)
            .background(AppColors.sceneForestMiddle)
            .clipShape(RouteDetailTopRoundedShape(radius: Radius.xl))
            .overlay(alignment: .top) {
                RouteDetailTopRoundedShape(radius: Radius.xl)
                    .stroke(AppColors.interactionPrimary.opacity(0.20), lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.48), radius: 30, y: -12)
        }
        .accessibilityAddTraits(.isModal)
    }

    private var detailContent: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack(alignment: .top, spacing: Spacing.md) {
                Text(detail.title)
                    .font(.sectionTitle)
                    .foregroundStyle(AppColors.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                IconButton(
                    systemName: "xmark",
                    accessibilityLabel: "关闭详情",
                    variant: .compactClose,
                    action: onClose
                )
            }

            if let category = detail.category, !category.isEmpty {
                Text(category)
                    .font(.appCaption)
                    .foregroundStyle(AppColors.textSecondary)
            }

            if let imageURL = detail.imageURL {
                AsyncImage(url: imageURL) { phase in
                    switch phase {
                    case .success(let image): image.resizable().scaledToFill()
                    default:
                        ZStack {
                            AppColors.surfaceElevated
                            Image(systemName: "photo")
                                .foregroundStyle(AppColors.textWeak)
                        }
                    }
                }
                .frame(maxWidth: .infinity, minHeight: 160, maxHeight: 220)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: Radius.md))
            }

            VStack(spacing: 0) {
                ForEach(Array(detail.rows.enumerated()), id: \.offset) { index, row in
                    HStack(alignment: .top, spacing: Spacing.md) {
                        Text(row.0)
                            .font(.label)
                            .foregroundStyle(AppColors.textWeak)
                            .frame(width: 64, alignment: .leading)
                        Text(row.1)
                            .font(.appBody)
                            .foregroundStyle(AppColors.textPrimary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(.vertical, Spacing.md)

                    if index < detail.rows.count - 1 {
                        Rectangle()
                            .fill(AppColors.surfaceDivider)
                            .frame(height: 1)
                    }
                }
            }
        }
    }
}

private struct RouteDetailTopRoundedShape: Shape {
    let radius: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + radius))
        path.addQuadCurve(
            to: CGPoint(x: rect.minX + radius, y: rect.minY),
            control: CGPoint(x: rect.minX, y: rect.minY)
        )
        path.addLine(to: CGPoint(x: rect.maxX - radius, y: rect.minY))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: rect.minY + radius),
            control: CGPoint(x: rect.maxX, y: rect.minY)
        )
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

private struct RouteImageViewer: View {
    let image: RouteDetailImagePresentation
    let onClose: () -> Void

    var body: some View {
        ZStack {
            AppColors.surfaceNavigation
                .ignoresSafeArea()

            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: Spacing.lg) {
                    AsyncImage(url: URL(string: image.source)) { phase in
                        switch phase {
                        case .success(let loaded):
                            loaded.resizable().scaledToFit()
                        default:
                            ZStack {
                                AppColors.surfaceElevated
                                Image(systemName: image.failurePlaceholderSystemImage)
                                    .font(.ornament(42, weight: .light))
                                    .foregroundStyle(AppColors.textWeak)
                            }
                            .aspectRatio(16 / 11, contentMode: .fit)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))

                    Text(image.caption ?? "路线图片")
                        .font(.sectionTitle)
                        .foregroundStyle(AppColors.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(Spacing.lg)
                .padding(.top, 64)
            }

            VStack {
                HStack {
                    Spacer()
                    IconButton(
                        systemName: "xmark",
                        accessibilityLabel: "关闭图片",
                        variant: .overlay,
                        action: onClose
                    )
                }
                .padding(Spacing.lg)
                Spacer()
            }
        }
        .accessibilityAddTraits(.isModal)
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
