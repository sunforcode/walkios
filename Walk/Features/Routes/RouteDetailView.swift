import SwiftUI
import MapKit
import UIKit

@MainActor
struct RouteDetailView: View {
    let routeId: String
    @StateObject private var viewModel: RouteDetailViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var drawerExpanded = false
    @State private var drawerDrag: CGFloat = 0
    @State private var selectedMapDetail: RouteMapDetailPresentation?

    init(routeId: String, service: any RouteDetailServicing) {
        self.init(routeId: routeId, viewModel: RouteDetailViewModel(service: service))
    }

    init(routeId: String, viewModel: RouteDetailViewModel) {
        self.routeId = routeId
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        GeometryReader { geometry in
            let collapsedHeight = max(330, geometry.size.height * 0.40)
            let expandedHeight = max(collapsedHeight, geometry.size.height * 0.88)
            ZStack(alignment: .bottom) {
                mapLayer(in: geometry)

                if viewModel.isLoading {
                    detailStatus(message: "正在加载路线…", icon: "map")
                } else if viewModel.errorMessage != nil {
                    detailStatus(message: "加载失败，点击重试", icon: "arrow.clockwise.circle") {
                        Task { await viewModel.retry() }
                    }
                } else if let presentation = viewModel.presentation {
                    RouteDetailDrawer(
                        presentation: presentation,
                        isExpanded: $drawerExpanded,
                        onCopyPhone: copyPhone
                    )
                    .frame(height: drawerExpanded ? expandedHeight : collapsedHeight)
                    .offset(y: max(0, drawerDrag))
                    .gesture(drawerGesture)
                    .animation(.spring(response: 0.32, dampingFraction: 0.86), value: drawerExpanded)
                }

                VStack {
                    HStack {
                        detailBackButton
                        Spacer()
                        if let presentation = viewModel.presentation {
                            GlassIconButton(
                                systemName: viewModel.isFavorite ? "heart.fill" : "heart",
                                size: 40,
                                backgroundColor: Color.black.opacity(0.40)
                            ) { Task { await viewModel.toggleFavorite() } }
                            .accessibilityLabel(viewModel.isFavorite ? "取消收藏" : "收藏")

                            ShareLink(item: presentation.actionPolicy.shareText) {
                                Image(systemName: "square.and.arrow.up")
                                    .foregroundStyle(.white)
                                    .frame(width: 40, height: 40)
                                    .background(Color.black.opacity(0.40), in: Circle())
                            }
                            .accessibilityLabel("分享")
                        }
                    }
                    Spacer()
                }
                .padding(.horizontal, Spacing.pageHorizontal)
                .padding(.top, Spacing.sm)

                if let message = viewModel.actionMessage {
                    Text(message)
                        .font(.bodySmall)
                        .foregroundStyle(.white)
                        .padding(.horizontal, Spacing.lg)
                        .padding(.vertical, Spacing.md)
                        .background(AppColors.surfaceToast, in: Capsule())
                        .padding(.bottom, (drawerExpanded ? expandedHeight : collapsedHeight) + Spacing.md)
                        .onTapGesture { viewModel.actionMessage = nil }
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

    private var drawerGesture: some Gesture {
        DragGesture()
            .onChanged { drawerDrag = max(0, $0.translation.height) }
            .onEnded {
                if $0.translation.height < -50 { drawerExpanded = true }
                if $0.translation.height > 50 { drawerExpanded = false }
                drawerDrag = 0
            }
    }

    @ViewBuilder
    private func mapLayer(in geometry: GeometryProxy) -> some View {
        ZStack {
            RouteMapView(
                coordinates: viewModel.mapCoordinates,
                poiAnnotations: viewModel.poiAnnotations,
                trackPointAnnotations: viewModel.selectableTrackPoints,
                waypointAnnotations: viewModel.waypointAnnotations,
                cameraPitch: 45,
                edgeInsets: RouteMapCamera.detailEdgeInsets(
                    viewportHeight: geometry.size.height,
                    safeAreaTop: geometry.safeAreaInsets.top,
                    safeAreaBottom: geometry.safeAreaInsets.bottom
                ),
                onSelectTrackPoint: { selectedMapDetail = .trackPoint($0) },
                onSelectWaypoint: { selectedMapDetail = .waypoint($0) }
            )
            .ignoresSafeArea()

            if viewModel.hasMissingTrack {
                Text("暂无轨迹数据")
                    .font(.bodySmall)
                    .foregroundStyle(.white)
                    .padding(.horizontal, Spacing.md)
                    .padding(.vertical, Spacing.sm)
                    .background(AppColors.surfaceToast, in: Capsule())
                    .padding(.bottom, 300)
            }
        }
    }

    private var detailBackButton: some View {
        GlassIconButton(systemName: "chevron.left", size: 40, backgroundColor: Color.black.opacity(0.40)) { dismiss() }
            .frame(minWidth: 44, minHeight: 44)
            .contentShape(Rectangle())
            .accessibilityLabel("返回")
    }

    private func detailStatus(message: String, icon: String, action: (() -> Void)? = nil) -> some View {
        Button { action?() } label: {
            Label(message, systemImage: icon)
                .font(.bodyLarge)
                .foregroundStyle(AppColors.sheetTextSecondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, Spacing.xxl)
                .background(AppColors.sheetBackground)
                .clipShape(UnevenRoundedRectangle(topLeadingRadius: Radius.xl, topTrailingRadius: Radius.xl))
        }
        .buttonStyle(.plain)
        .disabled(action == nil)
    }

    private func copyPhone(_ phone: String) {
        viewModel.copyPhone(phone) { UIPasteboard.general.string = $0 }
    }
}

private struct RouteDetailDrawer: View {
    let presentation: RouteDetailPresentation
    @Binding var isExpanded: Bool
    let onCopyPhone: (String) -> Void

    private var route: RouteDetailResponse { presentation.route }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.xl) {
                Capsule()
                    .fill(AppColors.sheetDragHandle)
                    .frame(width: 42, height: 5)
                    .frame(maxWidth: .infinity)
                    .onTapGesture { isExpanded.toggle() }

                summary
                if isExpanded {
                    Divider().overlay(AppColors.sheetDivider)
                    ForEach(presentation.sections) { section in
                        sectionView(section)
                    }
                }
            }
            .padding(.horizontal, Spacing.heroHorizontal)
            .padding(.top, Spacing.md)
            .padding(.bottom, Spacing.xxl)
        }
        .scrollDisabled(!isExpanded)
        .background(AppColors.sheetBackground)
        .clipShape(UnevenRoundedRectangle(topLeadingRadius: Radius.xl, topTrailingRadius: Radius.xl))
        .shadow(color: Color.black.opacity(0.25), radius: 24, y: -4)
    }

    private var summary: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text(presentation.name)
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(AppColors.sheetTextPrimary)
                .fixedSize(horizontal: false, vertical: true)

            Text("创建者：\(presentation.creatorName)")
                .font(.bodySmall)
                .foregroundStyle(AppColors.sheetTextSecondary)

            tags([presentation.difficulty, presentation.routeType, presentation.loopState, presentation.region])

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: Spacing.sm), count: 4), spacing: Spacing.sm) {
                ForEach(Array(presentation.summaryMetrics.enumerated()), id: \.offset) { _, metric in
                    metricCard(metric)
                }
            }
        }
    }

    @ViewBuilder
    private func sectionView(_ section: RouteDetailSectionPresentation) -> some View {
        switch section.id {
        case .overview: overviewGroup(section)
        case .itinerary: itineraryGroup(section)
        case .safeguards: safeguardsGroup(section)
        case .preparation: preparationGroup(section)
        case .imagery: imageryGroup(section)
        case .related: relatedGroup(section)
        }
    }

    private func overviewGroup(_ section: RouteDetailSectionPresentation) -> some View {
        detailSection(section.title) {
            ForEach(section.items) { item in
                textBlock(item.title, item.value)
            }
        }
    }

    @ViewBuilder
    private func itineraryGroup(_ section: RouteDetailSectionPresentation) -> some View {
        detailSection(section.title) {
            if section.items.isEmpty {
                sectionEmptyText(section)
            } else {
                subsection("每日计划") {
                    if route.dailyPlans.isEmpty { emptyText } else {
                        ForEach(route.dailyPlans.sorted { $0.dayNumber < $1.dayNumber }, id: \.id) { plan in
                            card {
                                Text("第 \(plan.dayNumber) 天 · \(presentation.text(plan.title))").font(.cardTitle)
                                textBlock("描述", presentation.text(plan.description))
                                detailRows([
                                    ("距离", presentation.decimal(plan.distance, unit: "km")),
                                    ("预计时间", presentation.decimal(plan.estimatedTime, unit: "小时")),
                                    ("爬升", plan.elevationGain.map { "\($0)m" } ?? "—"),
                                    ("下降", presentation.decimal(plan.elevationLoss, unit: "m")),
                                    ("最高海拔", presentation.decimal(plan.maxElevation, unit: "m")),
                                    ("最低海拔", presentation.decimal(plan.minElevation, unit: "m")),
                                    ("住宿", presentation.text(plan.accommodation)),
                                    ("备注", presentation.text(plan.notes))
                                ])
                                subsection("当日路段") {
                                    if plan.segments.isEmpty { emptyText } else {
                                        ForEach(plan.segments, id: \.id) { item in
                                            Text(item.segment.map { presentation.text($0.name) } ?? "暂无数据")
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
                subsection("分段方案") {
                    if route.segmentSchemes.isEmpty { emptyText } else {
                        ForEach(route.segmentSchemes, id: \.id) { scheme in
                            card {
                                Text(presentation.text(scheme.label)).font(.cardTitle)
                                if scheme.segments.isEmpty { emptyText } else {
                                    ForEach(scheme.segments.sorted { $0.sequenceNumber < $1.sequenceNumber }, id: \.id) { segment in
                                        segmentView(segment)
                                    }
                                }
                            }
                        }
                    }
                }
                subsection("沿途兴趣点") {
                    if route.poiPoints.isEmpty { emptyText } else {
                        ForEach(route.poiPoints, id: \.id) { poi in
                            card {
                                Text(presentation.text(poi.name)).font(.cardTitle)
                                detailRows([
                                    ("主类别", presentation.text(poi.category)),
                                    ("子类别", presentation.text(poi.subCategory)),
                                    ("描述", presentation.text(poi.description)),
                                    ("海拔", presentation.decimal(poi.elevation, unit: "m"))
                                ])
                            }
                        }
                    }
                }
            }
        }
    }

    private func safeguardsGroup(_ section: RouteDetailSectionPresentation) -> some View {
        detailSection(section.title) { sectionEmptyText(section) }
    }

    private func preparationGroup(_ section: RouteDetailSectionPresentation) -> some View {
        detailSection(section.title) {
            if section.items.isEmpty {
                sectionEmptyText(section)
            } else {
                fixedEmptySubsection("季节装备")
                subsection("拼车联系人") {
                    if presentation.contacts.isEmpty { emptyText } else {
                        ForEach(presentation.contacts) { contact in
                            card {
                                Text(contact.name).font(.cardTitle)
                                detailRows([
                                    ("描述", contact.description),
                                    ("位置", contact.location),
                                    ("价格", contact.price),
                                    ("认证状态", contact.verification)
                                ])
                                Button("复制号码") { onCopyPhone(contact.phone) }
                                    .buttonStyle(.borderedProminent)
                                    .disabled(!RouteDetailActionPolicy.canCopyPhone(contact.phone))
                            }
                        }
                    }
                }
            }
        }
    }

    private func imageryGroup(_ section: RouteDetailSectionPresentation) -> some View {
        detailSection(section.title) {
            subsection("路线影像") {
                if presentation.images.isEmpty { emptyText } else {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: Spacing.md) {
                            ForEach(presentation.images) { image in
                                AsyncImage(url: URL(string: image.source)) { phase in
                                    switch phase {
                                    case .success(let image): image.resizable().scaledToFill()
                                    default: imagePlaceholder(systemName: image.failurePlaceholderSystemImage)
                                    }
                                }
                                .frame(width: 220, height: 140)
                                .clipShape(RoundedRectangle(cornerRadius: Radius.md))
                            }
                        }
                    }
                }
            }
            detailRows([
                ("路线热度", "\(route.popularity)"),
                ("使用次数", "\(route.usageCount)"),
                ("创建者", presentation.creatorName)
            ])
            if let avatar = route.creator?.avatarUrl.flatMap(URL.init(string:)) {
                AsyncImage(url: avatar) { phase in
                    switch phase {
                    case .success(let image): image.resizable().scaledToFill()
                    default: imagePlaceholder()
                    }
                }
                .frame(width: 48, height: 48)
                .clipShape(Circle())
            }
        }
    }

    private func relatedGroup(_ section: RouteDetailSectionPresentation) -> some View {
        detailSection(section.title) { sectionEmptyText(section) }
    }

    private func segmentView(_ segment: RouteSegment) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text(presentation.text(segment.name)).font(.cardTitle)
            textBlock("描述", presentation.text(segment.description))
            detailRows([
                ("距离", presentation.decimal(segment.distance, unit: "km")),
                ("预计时间", presentation.decimal(segment.estimatedTime, unit: "小时")),
                ("爬升", presentation.decimal(segment.elevationGain, unit: "m")),
                ("下降", presentation.decimal(segment.elevationLoss, unit: "m")),
                ("难度", segment.difficulty?.displayText ?? "暂无数据"),
                ("路线类型", segment.routeType?.displayText ?? "暂无数据"),
                ("备注", presentation.text(segment.notes))
            ])
            waypointView("起点", segment.startPoint)
            waypointView("终点", segment.endPoint)
            subsection("关键点") {
                if segment.keypoints.isEmpty { emptyText } else {
                    ForEach(segment.keypoints.sorted { $0.sequenceNumber < $1.sequenceNumber }, id: \.id) { waypoint in
                        waypointView(nil, waypoint)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func waypointView(_ label: String?, _ waypoint: RouteWaypoint?) -> some View {
        if let waypoint {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                Text(label.map { "\($0)：\(presentation.text(waypoint.name))" } ?? presentation.text(waypoint.name)).font(.headline)
                detailRows([
                    ("描述", presentation.text(waypoint.description)),
                    ("海拔", presentation.decimal(waypoint.elevation, unit: "m")),
                    ("类型", presentation.text(waypoint.type))
                ])
                let visualURL = waypoint.imageUrl ?? waypoint.iconUrl
                if let visualURL, let url = URL(string: visualURL) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image): image.resizable().scaledToFill()
                        default: imagePlaceholder()
                        }
                    }
                    .frame(height: 100)
                    .clipShape(RoundedRectangle(cornerRadius: Radius.sm))
                }
            }
        } else if let label {
            textBlock(label, "暂无数据")
        }
    }

    private func detailSection<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text(title).font(.sectionTitle).foregroundStyle(AppColors.sheetTextPrimary)
            content()
        }
    }

    private func subsection<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text(title).font(.headline).foregroundStyle(AppColors.sheetTextPrimary)
            content()
        }
    }

    private func fixedEmptySubsection(_ title: String) -> some View {
        subsection(title) { emptyText }
    }

    private func card<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: Spacing.md) { content() }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Spacing.md)
            .background(AppColors.sheetCardBackground)
            .clipShape(RoundedRectangle(cornerRadius: Radius.md))
    }

    private func textBlock(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text(title).font(.caption).foregroundStyle(AppColors.sheetTextSecondary)
            Text(value).font(.body).foregroundStyle(AppColors.sheetTextPrimary).fixedSize(horizontal: false, vertical: true)
        }
    }

    private func collectionBlock(_ title: String, values: [String]) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text(title).font(.caption).foregroundStyle(AppColors.sheetTextSecondary)
            if values.isEmpty { emptyText } else { tags(values.map(presentation.text)) }
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

    private func metricCard(_ metric: RouteSummaryMetric) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Image(systemName: metric.icon).foregroundStyle(AppColors.sheetTextSecondary)
            Text(metric.value).font(.metricValue).foregroundStyle(AppColors.sheetTextPrimary).lineLimit(1).minimumScaleFactor(0.55)
            Text(metric.title).font(.caption).foregroundStyle(AppColors.sheetTextSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.sm)
        .background(AppColors.sheetCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: Radius.md))
    }

    private func detailRows(_ rows: [(String, String)]) -> some View {
        VStack(spacing: Spacing.sm) {
            ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                HStack(alignment: .top) {
                    Text(row.0).foregroundStyle(AppColors.sheetTextSecondary)
                    Spacer(minLength: Spacing.md)
                    Text(row.1).foregroundStyle(AppColors.sheetTextPrimary).multilineTextAlignment(.trailing)
                }
                .font(.body)
            }
        }
    }

    private var emptyText: some View {
        Text("暂无数据").font(.body).foregroundStyle(AppColors.sheetTextSecondary)
    }

    private func sectionEmptyText(_ section: RouteDetailSectionPresentation) -> some View {
        Text(section.emptyState).font(.body).foregroundStyle(AppColors.sheetTextSecondary)
    }

    private func imagePlaceholder(systemName: String = "photo") -> some View {
        ZStack {
            AppColors.sheetCardBackground
            Image(systemName: systemName).foregroundStyle(AppColors.sheetTextWeak)
        }
    }
}

private enum RouteMapDetailPresentation: Identifiable {
    case trackPoint(RouteTrackPointMetadata)
    case waypoint(RouteWaypointAnnotation)

    var id: String {
        switch self {
        case .trackPoint(let point): "track-\(point.id)"
        case .waypoint(let waypoint): "waypoint-\(waypoint.id)"
        }
    }

    var title: String {
        switch self {
        case .trackPoint(let point): point.title
        case .waypoint(let waypoint): waypoint.title
        }
    }

    var rows: [(String, String)] {
        switch self {
        case .trackPoint(let point): [("类型", point.type), ("描述", point.detail)]
        case .waypoint(let waypoint): [("描述", waypoint.detail), ("海拔", waypoint.elevation), ("类型", waypoint.type)]
        }
    }

    var imageURL: URL? {
        switch self {
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
                Text(detail.title).font(.pageTitle)
                ForEach(Array(detail.rows.enumerated()), id: \.offset) { _, row in
                    LabeledContent(row.0, value: row.1)
                }
                if let imageURL = detail.imageURL {
                    AsyncImage(url: imageURL) { phase in
                        switch phase {
                        case .success(let image): image.resizable().scaledToFit()
                        default:
                            ZStack {
                                AppColors.sheetCardBackground
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
    }
}

#if DEBUG
#Preview {
    NavigationStack { RouteDetailView(routeId: "route-1", service: PreviewHelpers.routeService) }
}
#endif
