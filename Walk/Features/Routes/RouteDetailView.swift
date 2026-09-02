import SwiftUI
import MapKit

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
            let summaryHeight = min(max(330, geometry.size.height * 0.40), geometry.size.height * 0.48)
            let topSpacerHeight = geometry.size.height - summaryHeight

            ZStack(alignment: .bottom) {
                mapLayer(in: geometry)

                if viewModel.isLoading {
                    detailStatus(message: "正在加载路线…", icon: "map")
                } else if viewModel.errorMessage != nil {
                    detailStatus(message: "加载失败，点击重试", icon: "arrow.clockwise.circle") {
                        Task { await viewModel.retry() }
                    }
                } else if let presentation = viewModel.presentation {
                    RouteDetailScrollOverlay(
                        presentation: presentation,
                        topSpacerHeight: topSpacerHeight,
                        onSelectItem: handleSectionItemSelection
                    )
                }

                VStack {
                    HStack {
                        detailBackButton
                        Spacer()
                        if let presentation = viewModel.presentation {
                            ShareLink(item: presentation.actionPolicy.shareText) {
                                Image(systemName: "square.and.arrow.up")
                                    .foregroundStyle(AppColors.textPrimary)
                                    .frame(width: 40, height: 40)
                                    .background(AppColors.shadowOverlay, in: Circle())
                            }
                            .accessibilityLabel("分享")
                        }
                    }
                    Spacer()
                }
                .padding(.horizontal, Spacing.pageHorizontal)
                .padding(.top, Spacing.sm)

                if let presentation = viewModel.presentation {
                    RouteGenerationPrimaryAction(action: presentation.generationAction) {
                        onGenerateTrip(routeId)
                    }
                    .padding(.horizontal, Spacing.pageHorizontal)
                    .padding(.bottom, max(geometry.safeAreaInsets.bottom, Spacing.md))
                }
            }
            .ignoresSafeArea(edges: .bottom)
        }
        .toolbar(.hidden, for: .navigationBar)
        .task { await viewModel.loadRoute(id: routeId) }
        .sheet(item: $selectedMapDetail) { detail in
            RouteMapDetailView(detail: detail)
                .presentationDetents([.medium])
        }
    }

    private func handleSectionItemSelection(_ section: RouteDetailSectionID, _ item: RouteDetailSectionItem) {
        switch section {
        case .segments:
            viewModel.selectSegment(item.id)
        case .keyPoints, .interestPoints, .campsites, .overnightPlaces, .waterSources, .supplyPoints:
            viewModel.togglePointHighlight(for: item.id)
        default:
            break
        }
    }

    @ViewBuilder
    private func mapLayer(in geometry: GeometryProxy) -> some View {
        ZStack {
            RouteMapView(
                coordinates: viewModel.mapCoordinates,
                segments: viewModel.mapSegments,
                selectedSegmentID: viewModel.selectedSegmentID,
                poiAnnotations: viewModel.poiAnnotations,
                trackPointAnnotations: viewModel.selectableTrackPoints,
                waypointAnnotations: viewModel.waypointAnnotations,
                highlightedAnnotationIDs: viewModel.highlightedAnnotationIDs,
                cameraPitch: 45,
                edgeInsets: RouteMapCamera.detailEdgeInsets(
                    viewportHeight: geometry.size.height,
                    safeAreaTop: geometry.safeAreaInsets.top,
                    safeAreaBottom: geometry.safeAreaInsets.bottom
                ),
                onSelectSegment: { viewModel.selectSegment($0) },
                onSelectMarker: { selectedMapDetail = RouteMapDetailPresentation(selection: $0) }
            )
            .ignoresSafeArea()

            if viewModel.hasUnavailableTrack {
                VStack(spacing: Spacing.sm) {
                    Image(systemName: "map")
                    Text(trackUnavailableText)
                }
                .font(.bodySmall)
                .foregroundStyle(AppColors.textPrimary)
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, Spacing.sm)
                .background(AppColors.surfaceToast, in: Capsule())
                .padding(.bottom, 300)
            }
        }
    }

    private var trackUnavailableText: String {
        switch viewModel.route?.currentVersion.mainTrackAvailability {
        case .processing: "主轨迹处理中"
        case .pendingReview: "主轨迹待审核"
        case .invalidated: "主轨迹已失效"
        case .missing: "暂无主轨迹"
        case .valid, .none: "暂无主轨迹"
        }
    }

    private var detailBackButton: some View {
        GlassIconButton(systemName: "chevron.left", size: 40, backgroundColor: AppColors.shadowOverlay) { dismiss() }
            .frame(minWidth: 44, minHeight: 44)
            .contentShape(Rectangle())
            .accessibilityLabel("返回")
    }

    private func detailStatus(message: String, icon: String, action: (() -> Void)? = nil) -> some View {
        Button { action?() } label: {
            Label(message, systemImage: icon)
                .font(.bodyLarge)
                .foregroundStyle(AppColors.textSecondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, Spacing.xxl)
                .background(AppColors.surfacePrimary)
                .clipShape(UnevenRoundedRectangle(topLeadingRadius: Radius.xl, topTrailingRadius: Radius.xl))
        }
        .buttonStyle(.plain)
        .disabled(action == nil)
    }
}

private struct RouteDetailScrollOverlay: View {
    let presentation: RouteDetailPresentation
    let topSpacerHeight: CGFloat
    let onSelectItem: (RouteDetailSectionID, RouteDetailSectionItem) -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                AppColors.sheetBackground.opacity(0.001)
                    .frame(height: topSpacerHeight)

                VStack(alignment: .leading, spacing: Spacing.xl) {
                    RouteDetailDrawerHandle()
                    summary

                    ForEach(presentation.sections) { section in
                        RouteDetailSectionContainer {
                            VStack(alignment: .leading, spacing: Spacing.md) {
                                Text(section.title)
                                    .font(.sectionTitle)
                                    .foregroundStyle(AppColors.sheetTextPrimary)

                                if section.id == .imagery {
                                    imageStrip
                                } else {
                                    routeItems(section.id, section.items)
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, Spacing.heroHorizontal)
                .padding(.top, Spacing.md)
                .padding(.bottom, Spacing.hero + Spacing.xl)
                .background(AppColors.sheetBackground)
                .clipShape(UnevenRoundedRectangle(topLeadingRadius: Radius.xl, topTrailingRadius: Radius.xl))
                .shadow(color: AppColors.sheetDragHandle, radius: 24, y: -4)
            }
        }
        .coordinateSpace(name: "route-detail-scroll")
    }

    private var summary: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text(presentation.name)
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(AppColors.sheetTextPrimary)
                .fixedSize(horizontal: false, vertical: true)

            if !presentation.summaryTags.isEmpty {
                tags(presentation.summaryTags)
            }

            if !presentation.summaryMetrics.isEmpty {
                RouteDetailMetricPanel(metrics: presentation.summaryMetrics)
            }

            if let generationMessage = presentation.generationMessage {
                Label(generationMessage, systemImage: "exclamationmark.triangle")
                    .font(.bodySmall)
                    .foregroundStyle(AppColors.sheetTextSecondary)
            }
        }
    }

    private func routeItems(_ section: RouteDetailSectionID, _ items: [RouteDetailSectionItem]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                Button {
                    onSelectItem(section, item)
                } label: {
                    VStack(alignment: .leading, spacing: Spacing.xs) {
                        Text(item.title)
                            .font(.headline)
                            .foregroundStyle(AppColors.sheetTextPrimary)
                        if !item.value.isEmpty {
                            Text(item.value)
                                .font(.body)
                                .foregroundStyle(AppColors.sheetTextSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .padding(.vertical, Spacing.sm)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)

                if index < items.count - 1 {
                    Divider().overlay(AppColors.sheetDivider)
                }
            }
        }
    }

    private var imageStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Spacing.md) {
                ForEach(presentation.images) { image in
                    AsyncImage(url: URL(string: image.source)) { phase in
                        switch phase {
                        case .success(let image):
                            image.resizable().scaledToFill()
                        default:
                            ZStack {
                                AppColors.sheetSectionBackground
                                Image(systemName: image.failurePlaceholderSystemImage)
                                    .foregroundStyle(AppColors.sheetTextWeak)
                            }
                        }
                    }
                    .frame(width: 220, height: 140)
                    .clipShape(RoundedRectangle(cornerRadius: Radius.md))
                    .accessibilityLabel(image.caption ?? "路线图片")
                }
            }
        }
    }

    private func tags(_ values: [String]) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Spacing.sm) {
                ForEach(Array(values.enumerated()), id: \.offset) { _, value in
                    Text(value)
                        .font(.label)
                        .foregroundStyle(AppColors.sheetTextTag)
                        .padding(.horizontal, Spacing.md)
                        .padding(.vertical, Spacing.sm)
                        .background(AppColors.sheetTagBackground, in: Capsule())
                }
            }
        }
    }
}

private struct RouteDetailDrawerHandle: View {
    var body: some View {
        Capsule()
            .fill(AppColors.sheetDragHandle)
            .frame(width: 42, height: 5)
            .frame(maxWidth: .infinity)
            .padding(.vertical, Spacing.md)
            .accessibilityHidden(true)
    }
}

private struct RouteGenerationPrimaryAction: View {
    let action: RouteGenerationActionPresentation
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            Text(action.title)
                .font(.headline)
                .foregroundStyle(action.isEnabled ? AppColors.pageBase : AppColors.textWeak)
                .frame(maxWidth: .infinity, minHeight: RootNavigation.toolButtonHitSize)
                .background(
                    action.isEnabled ? AppColors.interactionPrimary : AppColors.surfaceElevated,
                    in: RoundedRectangle(cornerRadius: Radius.md)
                )
        }
        .buttonStyle(.plain)
        .disabled(!action.isEnabled)
        .accessibilityHint(action.unavailableMessage ?? "使用当前路线生成个人行程")
    }
}

private struct RouteDetailMetricPanel: View {
    let metrics: [RouteSummaryMetric]
    private let columns = Array(repeating: GridItem(.flexible(), spacing: Spacing.lg), count: 2)

    var body: some View {
        LazyVGrid(columns: columns, alignment: .leading, spacing: Spacing.lg) {
            ForEach(Array(metrics.enumerated()), id: \.offset) { _, metric in
                HStack(alignment: .firstTextBaseline, spacing: Spacing.sm) {
                    Image(systemName: metric.systemImage)
                        .font(.bodyLarge)
                        .foregroundStyle(AppColors.interactionPrimary)
                        .frame(width: 22)

                    Text(metric.value)
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(AppColors.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                .frame(maxWidth: .infinity, minHeight: 46, alignment: .leading)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(metric.title) \(metric.value)")
            }
        }
        .padding(Spacing.lg)
        .background(AppColors.sheetSectionBackground)
        .clipShape(RoundedRectangle(cornerRadius: Radius.lg))
    }
}

private struct RouteDetailSectionContainer<Content: View>: View {
    @ViewBuilder let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Spacing.lg)
            .background(AppColors.sheetSectionBackground)
            .clipShape(RoundedRectangle(cornerRadius: Radius.lg))
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

    var rows: [(String, String)] {
        let values: [(String, String)]
        switch self {
        case .poi(let point):
            values = [("类别", point.category), ("子类别", point.subCategory), ("描述", point.detail), ("海拔", point.elevation)]
        case .trackPoint(let point):
            values = [("类型", point.type), ("描述", point.detail)]
        case .waypoint(let waypoint):
            values = [("描述", waypoint.detail), ("海拔", waypoint.elevation), ("类型", waypoint.type)]
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

private struct RouteMapDetailView: View {
    let detail: RouteMapDetailPresentation

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.md) {
                Text(detail.title)
                    .font(.pageTitle)
                    .foregroundStyle(AppColors.sheetTextPrimary)
                ForEach(Array(detail.rows.enumerated()), id: \.offset) { _, row in
                    LabeledContent(row.0, value: row.1)
                        .foregroundStyle(AppColors.sheetTextPrimary)
                }
                if let imageURL = detail.imageURL {
                    AsyncImage(url: imageURL) { phase in
                        switch phase {
                        case .success(let image): image.resizable().scaledToFit()
                        default:
                            ZStack {
                                AppColors.sheetSectionBackground
                                Image(systemName: "photo").foregroundStyle(AppColors.sheetTextWeak)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, minHeight: 160)
                    .clipShape(RoundedRectangle(cornerRadius: Radius.md))
                }
            }
            .padding(Spacing.xl)
        }
        .background(AppColors.sheetBackground)
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
