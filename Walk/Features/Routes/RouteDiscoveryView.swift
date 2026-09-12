import SwiftUI
import UIKit
import WalkData
import WalkDesignSystem

enum RouteDiscoveryLayout {
    static let headerTop: CGFloat = 54
    static let sceneHorizontalPadding: CGFloat = 20
    static let compactHorizontalPadding: CGFloat = 16

    static func cardHeight(for viewportHeight: CGFloat) -> CGFloat {
        max(0, viewportHeight - (2 * Spacing.sm))
    }
}

struct RouteDiscoveryView: View {
    @StateObject private var viewModel: RouteDiscoveryViewModel
    private let onNavigate: (AppDestination) -> Void

    init(
        routeService: RouteService,
        onNavigate: @escaping (AppDestination) -> Void = { _ in }
    ) {
        self.onNavigate = onNavigate
        _viewModel = StateObject(wrappedValue: RouteDiscoveryViewModel(service: routeService))
    }

    @State private var currentRouteIndex = 0
    @State private var lastAnnouncedIndex: Int?

    var body: some View {
        GeometryReader { geometry in
            ImmersivePageContainer {
                ZStack(alignment: .top) {
                    routeState(viewport: geometry.size)

                    // 页面头与全部路线入口同行：入口固定右上角，与页面头垂直居中对齐；
                    // 页面头不拦截场景的分页手势。
                    HStack(alignment: .center, spacing: Spacing.md) {
                        PageTitleBlock(title: "路线", description: "选一条想走的，看清了再出发")
                            .allowsHitTesting(false)

                        Spacer(minLength: Spacing.md)

                        SecondaryAction(title: "全部路线", variant: .overlayCompact) {
                            onNavigate(.routeList)
                        }
                    }
                    .padding(.top, RouteDiscoveryLayout.headerTop)
                    .padding(.horizontal, horizontalPadding(for: geometry.size.width))
                }
            }
        }
        .task { await viewModel.loadRoutes() }
        .toolbar(.hidden, for: .navigationBar)
    }

    @ViewBuilder
    private func routeState(viewport: CGSize) -> some View {
        if viewModel.isLoading && viewModel.routes.isEmpty {
            RouteSceneSkeleton()
                .frame(width: viewport.width, height: viewport.height)
        } else if let message = viewModel.errorMessage, viewModel.routes.isEmpty {
            RouteSceneState {
                ErrorView(
                    message: "不会用缓存猜测替代真实路线资料。",
                    title: "暂时无法加载路线",
                    variant: .scene
                ) {
                    Task { await viewModel.retry() }
                }
            }
            .frame(width: viewport.width, height: viewport.height)
        } else if viewModel.routes.isEmpty {
            RouteSceneState {
                EmptyStateView(
                    title: "暂无路线",
                    message: "当前暂无可发现路线",
                    icon: "route",
                    variant: .default
                )
            }
            .frame(width: viewport.width, height: viewport.height)
        } else {
            ScrollView(.vertical) {
                LazyVStack(spacing: 0) {
                    ForEach(viewModel.routes) { route in
                        RouteBusinessComponents.RouteScene(
                            projection: RouteSceneProjection(
                                routeID: route.routeId,
                                coverAvailable: false,
                                name: route.name,
                                region: route.region,
                                difficulty: route.difficulty,
                                metrics: [
                                    route.distance.map {
                                        MetricItemModel(
                                            id: "distance",
                                            value: distanceText($0.meters),
                                            label: "距离"
                                        )
                                    },
                                    route.ascent.map {
                                        MetricItemModel(
                                            id: "ascent",
                                            value: metersText($0.meters),
                                            label: "累计爬升"
                                        )
                                    },
                                    route.estimatedDuration.map {
                                        MetricItemModel(
                                            id: "estimated-duration",
                                            value: durationText($0.seconds),
                                            label: "预计用时"
                                        )
                                    },
                                ].compactMap { $0 }
                            ),
                            onSelect: { _ in
                                onNavigate(.routeDetail(route.routeId))
                            }
                        ) {
                            RouteDeterministicImageSurface(style: .forest)
                        }
                        .frame(width: viewport.width, height: viewport.height)
                    }
                }
                .background(RoutePagingConfigurator())
                .background(
                    GeometryReader { proxy in
                        AppColors.surfacePrimary.opacity(0)
                            .preference(
                            key: RoutePagingOffsetKey.self,
                            value: proxy.frame(in: .named("routePaging")).minY
                        )
                    }
                )
            }
            .coordinateSpace(name: "routePaging")
            .scrollIndicators(.hidden)
            .onPreferenceChange(RoutePagingOffsetKey.self) { offset in
                guard !viewModel.routes.isEmpty else { return }
                let index = max(
                    0,
                    min(
                        viewModel.routes.count - 1,
                        Int(round(-offset / viewport.height))
                    )
                )
                guard index != currentRouteIndex else { return }
                currentRouteIndex = index
                announcePage(at: index)
            }
        }
    }

    /// R3：换页公告。首尾用边界文案，中段用「{路线身份}，第 X 条，共 N 条」；
    /// 单条路线不暴露相邻切换，不做公告。
    private func announcePage(at index: Int) {
        let count = viewModel.routes.count
        guard count > 1, lastAnnouncedIndex != index else { return }
        lastAnnouncedIndex = index
        let route = viewModel.routes[index]
        let message: String
        if index == 0 {
            message = "已到第一条路线"
        } else if index == count - 1 {
            message = "已到最后一条路线"
        } else {
            message = "\(route.name)，第 \(index + 1) 条，共 \(count) 条"
        }
        UIAccessibility.post(notification: .announcement, argument: message)
    }

    private func horizontalPadding(for width: CGFloat) -> CGFloat {
        width < 390
            ? RouteDiscoveryLayout.compactHorizontalPadding
            : RouteDiscoveryLayout.sceneHorizontalPadding
    }
}

struct RouteCollectionView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: RouteCollectionViewModel
    private let showsBackButton: Bool
    private let onNavigate: (AppDestination) -> Void

    init(
        routeService: RouteService,
        showsBackButton: Bool = true,
        onNavigate: @escaping (AppDestination) -> Void = { _ in }
    ) {
        self.showsBackButton = showsBackButton
        self.onNavigate = onNavigate
        _viewModel = StateObject(wrappedValue: RouteCollectionViewModel(service: routeService))
    }

    var body: some View {
        UtilityPageContainer {
            VStack(spacing: 0) {
                UtilityNavigationHeader(
                    title: "全部路线",
                    leading: showsBackButton
                        ? IconButtonConfiguration(
                            systemName: "chevron.left",
                            accessibilityLabel: "返回",
                            action: { dismiss() }
                        )
                        : nil,
                    trailing: IconButtonConfiguration(
                        systemName: "magnifyingglass",
                        accessibilityLabel: "搜索路线",
                        action: { onNavigate(.routeSearch) }
                    )
                )

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: Spacing.lg) {
                        Text("快速扫描和比较 Walk 当前提供的路线")
                            .font(.appCaption)
                            .foregroundStyle(AppColors.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)

                        collectionState
                            .frame(maxWidth: .infinity)
                    }
                    .frame(maxWidth: 600, alignment: .topLeading)
                    .frame(maxWidth: .infinity, alignment: .top)
                    .padding(Spacing.lg)
                }
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .task { await viewModel.loadRoutes() }
    }

    @ViewBuilder
    private var collectionState: some View {
        if viewModel.isLoading && viewModel.routes.isEmpty {
            RouteRowSkeletonList()
        } else if let message = viewModel.errorMessage, viewModel.routes.isEmpty {
            ErrorView(
                message: "不会使用缓存或猜测路线替代。",
                title: "暂时无法加载全部路线",
                variant: .section
            ) {
                Task { await viewModel.retry() }
            }
            .frame(minHeight: 360)
        } else if viewModel.routes.isEmpty {
            EmptyStateView(
                title: "当前暂无可选择路线",
                message: "路线准备完成后会出现在这里。",
                icon: "route",
                variant: .default
            )
            .frame(maxWidth: .infinity, minHeight: 360, alignment: .center)
        } else {
            LazyVStack(spacing: Spacing.md) {
                ForEach(viewModel.routes) { route in
                    RouteBusinessComponents.RouteListRow(
                        projection: .browse(
                            RouteBrowseRowProjection(
                                routeID: route.routeId,
                                coverAvailable: false,
                                name: route.name,
                                region: route.region,
                                difficulty: route.difficulty,
                                distance: route.distance.map { distanceText($0.meters) },
                                ascent: route.ascent.map { "爬升 \(metersText($0.meters))" },
                                estimatedDuration: route.estimatedDuration.map { "约 \(durationText($0.seconds))" }
                            )
                        ),
                        onSelect: { routeID in
                            onNavigate(.routeDetail(routeID))
                        }
                    ) {
                        RouteDeterministicImageSurface(style: .forest)
                    }
                }
            }
        }
    }
}

struct RouteSearchView: View {
    @Environment(\.dismiss) private var dismiss
    /// S5：会话状态由 App 层持有，返回后再进恢复 query 与结果；预览/独立使用时用 convenience init 自建。
    @ObservedObject private var viewModel: RouteDiscoveryViewModel
    @Binding private var query: String
    private let ownsModel: Bool
    @State private var localQuery = ""
    private let onNavigate: (AppDestination) -> Void

    init(
        model: RouteDiscoveryViewModel,
        query: Binding<String>,
        onNavigate: @escaping (AppDestination) -> Void
    ) {
        _viewModel = ObservedObject(wrappedValue: model)
        _query = query
        ownsModel = false
        self.onNavigate = onNavigate
    }

    init(
        routeService: RouteDiscoveryServicing,
        onNavigate: @escaping (AppDestination) -> Void = { _ in }
    ) {
        _viewModel = ObservedObject(wrappedValue: RouteDiscoveryViewModel(service: routeService))
        _query = .constant("")
        ownsModel = true
        self.onNavigate = onNavigate
    }

    private var boundQuery: Binding<String> {
        ownsModel ? $localQuery : $query
    }

    var body: some View {
        UtilityPageContainer {
            VStack(spacing: 0) {
                UtilityNavigationHeader(
                    title: "路线搜索",
                    leading: IconButtonConfiguration(
                        systemName: "chevron.left",
                        accessibilityLabel: "返回全部路线",
                        action: { dismiss() }
                    )
                )

                searchInputRegion

                ScrollView(.vertical, showsIndicators: false) {
                    searchState
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 320, alignment: .top)
                        .frame(maxWidth: 600, alignment: .topLeading)
                        .padding(.horizontal, Spacing.lg)
                        .padding(.bottom, Spacing.xxl)
                }
                .scrollDismissesKeyboard(.interactively)
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .task(id: boundQuery.wrappedValue) {
            await viewModel.search(query: normalizedQueryIsEmpty(boundQuery.wrappedValue) ? nil : boundQuery.wrappedValue)
        }
    }

    private var searchInputRegion: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            SearchField(
                text: boundQuery,
                placeholder: "输入路线名称或地区",
                onSubmit: submitSearch
            )
            .background(SearchFocusActivator(placeholder: "输入路线名称或地区"))

            Text("只搜索 Walk 当前提供的徒步路线")
                .font(.appCaption)
                .foregroundStyle(AppColors.textWeak)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: 600, alignment: .topLeading)
        .frame(maxWidth: .infinity, alignment: .top)
        .padding(.horizontal, Spacing.lg)
        .padding(.top, Spacing.md)
        .padding(.bottom, Spacing.lg)
        .background(AppColors.pageBase.opacity(0.96))
        .zIndex(2)
    }

    @ViewBuilder
    private var searchState: some View {
        if viewModel.isLoading {
            RouteRowSkeletonList()
        } else if let message = viewModel.errorMessage {
            ErrorView(
                message: "已保留关键词，不会用猜测结果替代。",
                title: "暂时无法搜索路线",
                variant: .section,
                retryTitle: "重新搜索"
            ) {
                submitSearch()
            }
        } else if viewModel.searchState == .initial {
            EmptyStateView(
                title: "输入名称或地区",
                message: "初始状态不展示默认结果。",
                icon: nil,
                variant: .compactText
            )
            .padding(.top, Spacing.xxxl)
        } else if viewModel.searchResults.isEmpty {
            EmptyStateView(
                title: "未找到路线",
                message: "Walk 当前没有找到相关路线",
                icon: nil,
                variant: .compactText
            )
            .padding(.top, Spacing.xxxl)
        } else {
            LazyVStack(spacing: Spacing.md) {
                ForEach(viewModel.searchResults) { route in
                    RouteBusinessComponents.SearchRouteResultRow(
                        projection: SearchRouteResultRowProjection(
                            routeID: route.routeId,
                            coverAvailable: nonEmpty(route.cover) != nil,
                            name: route.name,
                            region: route.region,
                            difficulty: route.difficulty,
                            distance: route.distance.map { distanceText($0.meters) },
                            estimatedDuration: route.estimatedDuration.map { "约 \(durationText($0.seconds))" }
                        ),
                        onSelect: { routeID in
                            onNavigate(.routeDetail(routeID))
                        }
                    ) {
                        RouteArtworkView(cover: route.cover)
                    }
                }
            }
        }
    }

    /// S4：submit 立即提交同一 query，不经防抖。
    private func submitSearch() {
        Task { await viewModel.search(query: boundQuery.wrappedValue, immediate: true) }
    }

    private func normalizedQueryIsEmpty(_ value: String) -> Bool {
        value.unicodeScalars.allSatisfy { scalar in
            switch scalar.value {
            case 0x20, 0x09, 0x0A, 0x0D, 0x3000: true
            default: false
            }
        }
    }
}

private struct SearchFocusActivator: UIViewRepresentable {
    let placeholder: String

    func makeUIView(context: Context) -> FocusProbeView {
        FocusProbeView(placeholder: placeholder)
    }

    func updateUIView(_ view: FocusProbeView, context: Context) {
        view.placeholder = placeholder
        view.requestFocus()
    }

    final class FocusProbeView: UIView {
        var placeholder: String
        private var didRequestFocus = false

        init(placeholder: String) {
            self.placeholder = placeholder
            super.init(frame: .zero)
            isUserInteractionEnabled = false
        }

        @available(*, unavailable)
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        override func didMoveToWindow() {
            super.didMoveToWindow()
            requestFocus()
        }

        func requestFocus() {
            guard window != nil, !didRequestFocus else { return }
            didRequestFocus = true
            DispatchQueue.main.async { [weak self] in
                guard let self,
                      let textField = self.window?.firstTextField(placeholder: self.placeholder) else { return }
                textField.becomeFirstResponder()
            }
        }
    }
}

private extension UIView {
    func firstTextField(placeholder: String) -> UITextField? {
        if let textField = self as? UITextField, textField.placeholder == placeholder {
            return textField
        }
        for subview in subviews {
            if let match = subview.firstTextField(placeholder: placeholder) { return match }
        }
        return nil
    }
}

private struct RoutePagingOffsetKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

private struct RoutePagingConfigurator: UIViewRepresentable {
    func makeUIView(context: Context) -> PagingConfigurationView {
        PagingConfigurationView()
    }

    func updateUIView(_ view: PagingConfigurationView, context: Context) {
        view.applyPagingBehavior()
    }

    final class PagingConfigurationView: UIView {
        override func layoutSubviews() {
            super.layoutSubviews()
            applyPagingBehavior()
        }

        func applyPagingBehavior() {
            var ancestor = superview
            while let view = ancestor {
                if let scrollView = view as? UIScrollView {
                    scrollView.isPagingEnabled = true
                    scrollView.decelerationRate = .fast
                    return
                }
                ancestor = view.superview
            }
        }
    }
}

private struct RouteSceneSkeleton: View {
    var body: some View {
        ZStack(alignment: .bottomLeading) {
            LinearGradient(
                colors: [AppColors.surfacePrimary, AppColors.pageBase],
                startPoint: .top,
                endPoint: .bottom
            )

            VStack(alignment: .leading, spacing: Spacing.lg) {
                Spacer()
                RoundedRectangle(cornerRadius: Radius.sm)
                    .fill(AppColors.surfaceGlass)
                    .frame(width: 228, height: 34)
                HStack(spacing: Spacing.xl) {
                    ForEach(0..<3, id: \.self) { _ in
                        RoundedRectangle(cornerRadius: Radius.sm)
                            .fill(AppColors.surfaceGlass)
                            .frame(width: 68, height: 36)
                    }
                }
            }
            .padding(.horizontal, RouteDiscoveryLayout.sceneHorizontalPadding)
            .padding(.bottom, 36)
        }
        .accessibilityLabel("路线加载中")
    }
}

private struct RouteSceneState<Content: View>: View {
    @ViewBuilder let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .frame(maxWidth: 320)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.horizontal, Spacing.xl)
    }
}

private struct RouteRowSkeletonList: View {
    var body: some View {
        VStack(spacing: Spacing.md) {
            ForEach(0..<3, id: \.self) { _ in
                RouteListRow(title: " ") {
                    RouteThumbnailPlaceholder(systemImage: "map")
                } metadata: {
                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        RoundedRectangle(cornerRadius: Radius.sm)
                            .fill(AppColors.surfaceDivider)
                            .frame(width: 110, height: 10)
                        RoundedRectangle(cornerRadius: Radius.sm)
                            .fill(AppColors.surfaceDivider)
                            .frame(width: 150, height: 10)
                    }
                }
                .redacted(reason: .placeholder)
                .accessibilityLabel("路线加载中")
            }
        }
    }
}

private struct RouteArtworkView: View {
    let cover: String?

    var body: some View {
        Group {
            if let value = cover, let url = URL(string: value) {
                AsyncImage(url: url) { phase in
                    if let image = phase.image {
                        image.resizable().scaledToFill()
                    } else {
                        neutralTerrain
                    }
                }
            } else {
                neutralTerrain
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
    }

    private var neutralTerrain: some View {
        ZStack {
            LinearGradient(
                colors: [AppColors.surfacePrimary, AppColors.pageMiddle, AppColors.pageBase],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            Image(systemName: "mountain.2.fill")
                .font(.ornament(64))
                .foregroundStyle(AppColors.surfaceGlass)
        }
    }
}

private func nonEmpty(_ value: String?) -> String? {
    guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else {
        return nil
    }
    return value
}

private func distanceText(_ meters: Double) -> String {
    if meters >= 1_000 {
        return "\((meters / 1_000).formatted(.number.precision(.fractionLength(0...1)))) km"
    }
    return metersText(meters)
}

private func metersText(_ meters: Double) -> String {
    "\(meters.formatted(.number.precision(.fractionLength(0...1)))) m"
}

private func durationText(_ seconds: Double) -> String {
    let hours = seconds / 3_600
    if hours >= 24 {
        return "\((hours / 24).formatted(.number.precision(.fractionLength(0...1)))) 天"
    }
    return "\(hours.formatted(.number.precision(.fractionLength(0...1)))) 小时"
}

#if DEBUG
#Preview("Route Discovery") {
    NavigationStack { RouteDiscoveryView(routeService: PreviewHelpers.routeService) }
}
#endif
