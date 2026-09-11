import SwiftUI

enum RouteDiscoveryLayout {
    static let tagTop: CGFloat = 72
    static let copyBottom: CGFloat = 36
    static let sceneHorizontalPadding: CGFloat = 20
    static let compactHorizontalPadding: CGFloat = 16
    static let allRoutesTop: CGFloat = 58

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

    var body: some View {
        GeometryReader { geometry in
            ImmersivePageContainer {
                ZStack(alignment: .topTrailing) {
                    routeState(viewport: geometry.size)

                    SecondaryAction(title: "全部路线", variant: .overlayCompact) {
                        onNavigate(.routeList)
                    }
                    .padding(.top, RouteDiscoveryLayout.allRoutesTop)
                    .padding(.trailing, horizontalPadding(for: geometry.size.width))
                }
            }
        }
        .task { await viewModel.loadRoutes() }
        .toolbar(.hidden, for: .navigationBar)
        .ignoresSafeArea(edges: .top)
    }

    @ViewBuilder
    private func routeState(viewport: CGSize) -> some View {
        if viewModel.isLoading && viewModel.routes.isEmpty {
            RouteSceneSkeleton()
                .frame(width: viewport.width, height: viewport.height)
        } else if let message = viewModel.errorMessage, viewModel.routes.isEmpty {
            RouteSceneState {
                ErrorView(message: message, title: "暂时无法加载路线", variant: .section) {
                    Task { await viewModel.retry() }
                }
            }
            .frame(width: viewport.width, height: viewport.height)
        } else if viewModel.routes.isEmpty {
            RouteSceneState {
                EmptyStateView(
                    title: "暂无路线",
                    message: "当前暂无可发现路线",
                    icon: nil,
                    variant: .compactText
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
            }
            .scrollIndicators(.hidden)
        }
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
            ErrorView(message: message, variant: .section) {
                Task { await viewModel.retry() }
            }
            .frame(minHeight: 360)
        } else if viewModel.routes.isEmpty {
            EmptyStateView(
                title: "暂无路线",
                message: "当前暂无可选择路线",
                icon: "map",
                variant: .section
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
    @StateObject private var viewModel: RouteDiscoveryViewModel
    @State private var query = ""
    private let onNavigate: (AppDestination) -> Void

    init(
        routeService: RouteService,
        onNavigate: @escaping (AppDestination) -> Void = { _ in }
    ) {
        self.onNavigate = onNavigate
        _viewModel = StateObject(wrappedValue: RouteDiscoveryViewModel(service: routeService))
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
        .task(id: query) {
            await viewModel.search(query: normalizedQueryIsEmpty(query) ? nil : query)
        }
    }

    private var searchInputRegion: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            SearchField(
                text: $query,
                placeholder: "搜索路线名称或地区",
                onSubmit: submitSearch
            )
            .background(SearchFocusActivator(placeholder: "搜索路线名称或地区"))

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
            ErrorView(message: message, title: "搜索失败", variant: .section) {
                submitSearch()
            }
        } else if viewModel.searchState == .initial {
            EmptyStateView(
                title: "搜索路线",
                message: "输入路线名称或地区",
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

    private func submitSearch() {
        Task { await viewModel.search(query: query) }
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
            .padding(.bottom, RouteDiscoveryLayout.copyBottom)
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
