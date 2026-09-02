import SwiftUI

enum RouteDiscoveryLayout {
    static let cardHeightRatio: CGFloat = 0.72
    static let minimumCardHeight: CGFloat = 400
    static let maximumCardHeight: CGFloat = 680

    static func cardHeight(for viewportHeight: CGFloat) -> CGFloat {
        min(max(viewportHeight * cardHeightRatio, minimumCardHeight), maximumCardHeight)
    }
}

struct RouteDiscoveryView: View {
    @StateObject private var viewModel: RouteDiscoveryViewModel
    private let routeService: RouteService
    private let onNavigate: (AppDestination) -> Void

    init(
        routeService: RouteService,
        onNavigate: @escaping (AppDestination) -> Void = { _ in }
    ) {
        self.routeService = routeService
        self.onNavigate = onNavigate
        _viewModel = StateObject(wrappedValue: RouteDiscoveryViewModel(service: routeService))
    }

    var body: some View {
        GeometryReader { geometry in
            ImmersivePageContainer {
                ZStack(alignment: .topTrailing) {
                    Group {
                        if viewModel.isLoading && viewModel.routes.isEmpty {
                            RouteCardSkeletonView(height: RouteDiscoveryLayout.cardHeight(for: geometry.size.height))
                        } else if viewModel.errorMessage != nil && viewModel.routes.isEmpty {
                            RouteMessageCard(
                                icon: "arrow.clockwise.circle",
                                message: "加载失败，点击重试",
                                height: RouteDiscoveryLayout.cardHeight(for: geometry.size.height)
                            ) {
                                Task { await viewModel.retry() }
                            }
                        } else if viewModel.routes.isEmpty {
                            RouteMessageCard(
                                icon: "map",
                                message: "暂无可发现路线",
                                height: RouteDiscoveryLayout.cardHeight(for: geometry.size.height)
                            )
                        } else {
                            ScrollView(.vertical) {
                                LazyVStack(spacing: 0) {
                                    ForEach(viewModel.routes) { route in
                                        Button {
                                            onNavigate(.routeDetail(route.routeId))
                                        } label: {
                                            RouteCardView(route: route, height: geometry.size.height)
                                                .padding(.horizontal, Spacing.pageHorizontal)
                                                .padding(.vertical, Spacing.sm)
                                        }
                                        .buttonStyle(RouteCardButtonStyle())
                                        .frame(height: geometry.size.height)
                                    }
                                }
                                .background(RoutePagingConfigurator())
                            }
                            .scrollIndicators(.hidden)
                        }
                    }

                    Button {
                        onNavigate(.routeList)
                    } label: {
                        Text("全部路线")
                            .font(.label)
                            .foregroundStyle(AppColors.textSecondary)
                            .padding(.horizontal, Spacing.md)
                            .frame(minHeight: 44)
                            .background(AppColors.shadowOverlay, in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .padding(.top, Spacing.sm)
                    .padding(.trailing, Spacing.pageHorizontal)
                }
            }
        }
        .task { await viewModel.loadRoutes() }
        .toolbar(.hidden, for: .navigationBar)
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

struct RouteCollectionView: View {
    @StateObject private var viewModel: RouteCollectionViewModel
    private let routeService: RouteService
    private let onNavigate: (AppDestination) -> Void

    init(
        routeService: RouteService,
        onNavigate: @escaping (AppDestination) -> Void = { _ in }
    ) {
        self.routeService = routeService
        self.onNavigate = onNavigate
        _viewModel = StateObject(wrappedValue: RouteCollectionViewModel(service: routeService))
    }

    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.routes.isEmpty {
                LoadingView()
            } else if viewModel.errorMessage != nil && viewModel.routes.isEmpty {
                ErrorView(message: "加载失败") { Task { await viewModel.retry() } }
            } else if viewModel.routes.isEmpty {
                EmptyStateView(title: "暂无路线", message: "当前暂无可选择路线", icon: "map")
            } else {
                List(viewModel.routes) { route in
                    Button {
                        onNavigate(.routeDetail(route.routeId))
                    } label: {
                        PublicRouteCompactRow(
                            cover: route.cover,
                            name: route.name,
                            region: route.region,
                            difficulty: route.difficulty,
                            distance: route.distance,
                            ascent: route.ascent,
                            estimatedDuration: route.estimatedDuration
                        )
                    }
                    .buttonStyle(.plain)
                    .listRowBackground(AppColors.pageBase)
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
        }
        .background(AppColors.pageBase.ignoresSafeArea())
        .navigationTitle("全部路线")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    onNavigate(.routeSearch)
                } label: {
                    Image(systemName: "magnifyingglass")
                }
                .accessibilityLabel("搜索路线")
            }
        }
        .task { await viewModel.loadRoutes() }
    }
}

struct RouteSearchView: View {
    @StateObject private var viewModel: RouteDiscoveryViewModel
    @FocusState private var searchFocused: Bool
    @State private var query = ""
    private let routeService: RouteService
    private let onNavigate: (AppDestination) -> Void

    init(
        routeService: RouteService,
        onNavigate: @escaping (AppDestination) -> Void = { _ in }
    ) {
        self.routeService = routeService
        self.onNavigate = onNavigate
        _viewModel = StateObject(wrappedValue: RouteDiscoveryViewModel(service: routeService))
    }

    var body: some View {
        VStack(spacing: Spacing.md) {
            HStack(spacing: Spacing.sm) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(AppColors.textWeak)
                TextField("搜索路线名称或地区", text: $query)
                    .focused($searchFocused)
                    .submitLabel(.search)
                    .onSubmit { Task { await viewModel.search(query: query) } }
                if !query.isEmpty {
                    Button {
                        query = ""
                        Task { await viewModel.search(query: nil) }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("清空搜索")
                }
            }
            .padding(.horizontal, Spacing.md)
            .frame(minHeight: 44)
            .background(AppColors.surfacePrimary, in: RoundedRectangle(cornerRadius: Radius.md))
            .padding(.horizontal, Spacing.pageHorizontal)

            searchContent
        }
        .background(AppColors.pageBase.ignoresSafeArea())
        .navigationTitle("路线搜索")
        .navigationBarTitleDisplayMode(.inline)
        .task { searchFocused = true }
    }

    @ViewBuilder
    private var searchContent: some View {
        if viewModel.isLoading {
            LoadingView()
        } else if viewModel.errorMessage != nil {
            ErrorView(message: "搜索失败") { Task { await viewModel.search(query: query) } }
        } else if viewModel.searchState == .initial {
            EmptyStateView(title: "搜索路线", message: "输入路线名称或地区", icon: "magnifyingglass")
        } else if viewModel.searchResults.isEmpty {
            EmptyStateView(title: "未找到路线", message: "Walk 当前没有找到相关路线", icon: "map")
        } else {
            List(viewModel.searchResults) { route in
                Button {
                    onNavigate(.routeDetail(route.routeId))
                } label: {
                    PublicRouteCompactRow(
                        cover: route.cover,
                        name: route.name,
                        region: route.region,
                        difficulty: route.difficulty,
                        distance: route.distance,
                        ascent: nil,
                        estimatedDuration: route.estimatedDuration
                    )
                }
                .buttonStyle(.plain)
                .listRowBackground(AppColors.pageBase)
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
        }
    }
}

private struct PublicRouteCompactRow: View {
    let cover: String?
    let name: String?
    let region: String?
    let difficulty: String?
    let distance: RouteDistance?
    let ascent: RouteElevationGain?
    let estimatedDuration: RouteDuration?

    var body: some View {
        HStack(spacing: Spacing.md) {
            RouteArtworkView(cover: cover)
                .frame(width: 96, height: 76)
                .clipShape(RoundedRectangle(cornerRadius: Radius.md))

            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(nonEmpty(name) ?? "未命名路线")
                    .font(.headline)
                    .foregroundStyle(AppColors.textPrimary)

                Text([region, difficulty].compactMap(nonEmpty).joined(separator: " · "))
                    .font(.bodySmall)
                    .foregroundStyle(AppColors.textSecondary)

                Text(metrics)
                    .font(.caption)
                    .foregroundStyle(AppColors.textWeak)
            }
        }
        .padding(.vertical, Spacing.xs)
    }

    private var metrics: String {
        var values: [String] = []
        if let meters = distance?.meters {
            values.append(meters >= 1_000 ? "\((meters / 1_000).formatted(.number.precision(.fractionLength(0...1)))) km" : "\(meters.formatted()) m")
        }
        if let meters = ascent?.meters {
            values.append("爬升 \(meters.formatted(.number.precision(.fractionLength(0...1)))) m")
        }
        if let seconds = estimatedDuration?.seconds {
            let hours = seconds / 3_600
            values.append(hours >= 24 ? "\((hours / 24).formatted(.number.precision(.fractionLength(0...1)))) 天" : "\(hours.formatted(.number.precision(.fractionLength(0...1)))) 小时")
        }
        return values.joined(separator: " · ")
    }

    private func nonEmpty(_ value: String?) -> String? {
        guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else { return nil }
        return value
    }
}

struct RouteCardView: View {
    let route: PublicRouteBrowseSummary
    let height: CGFloat

    init(
        route: PublicRouteBrowseSummary,
        height: CGFloat = RouteDiscoveryLayout.minimumCardHeight
    ) {
        self.route = route
        self.height = height
    }

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            RouteArtworkView(cover: route.cover)

            LinearGradient(
                colors: [AppColors.surfaceOverlay.opacity(0), AppColors.surfaceOverlay, AppColors.pageBase],
                startPoint: .top,
                endPoint: .bottom
            )

            VStack(alignment: .leading, spacing: Spacing.md) {
                HStack(spacing: Spacing.sm) {
                    if let region = nonEmpty(route.region) { routePill(region) }
                    if let difficulty = nonEmpty(route.difficulty) { routePill(difficulty) }
                }

                Spacer()

                Text(nonEmpty(route.name) ?? "未命名路线")
                    .font(.system(size: 30, weight: .bold))
                    .lineLimit(2)

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], alignment: .leading, spacing: Spacing.md) {
                    if let distance = route.distance?.meters {
                        routeMetric(icon: "point.topleft.down.curvedto.point.bottomright.up", value: formatDistance(distance))
                    }
                    if let ascent = route.ascent?.meters {
                        routeMetric(icon: "arrow.up.right", value: "爬升 \(formatMeters(ascent))")
                    }
                    if let duration = route.estimatedDuration?.seconds {
                        routeMetric(icon: "clock", value: formatDuration(duration))
                    }
                }
            }
            .padding(Spacing.heroHorizontal)
        }
        .frame(maxWidth: .infinity)
        .frame(height: min(max(height - 2 * Spacing.sm, RouteDiscoveryLayout.minimumCardHeight), RouteDiscoveryLayout.maximumCardHeight))
        .clipShape(RoundedRectangle(cornerRadius: Radius.xl, style: .continuous))
        .shadow(color: AppColors.shadowCard, radius: 20, y: 10)
        .contentShape(RoundedRectangle(cornerRadius: Radius.xl, style: .continuous))
    }

    private func routePill(_ title: String) -> some View {
        Text(title)
            .font(.label)
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.sm)
            .background(AppColors.surfaceGlass, in: Capsule())
    }

    private func routeMetric(icon: String, value: String) -> some View {
        Label(value, systemImage: icon)
            .font(.caption)
            .foregroundStyle(AppColors.textSecondary)
    }

    private func nonEmpty(_ value: String?) -> String? {
        guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else { return nil }
        return value
    }

    private func formatDistance(_ meters: Double) -> String {
        if meters >= 1_000 {
            return "\((meters / 1_000).formatted(.number.precision(.fractionLength(0...1)))) km"
        }
        return formatMeters(meters)
    }

    private func formatMeters(_ meters: Double) -> String {
        "\(meters.formatted(.number.precision(.fractionLength(0...1)))) m"
    }

    private func formatDuration(_ seconds: Double) -> String {
        let hours = seconds / 3_600
        if hours >= 24 {
            return "\((hours / 24).formatted(.number.precision(.fractionLength(0...1)))) 天"
        }
        return "\(hours.formatted(.number.precision(.fractionLength(0...1)))) 小时"
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
                        atmosphericPlaceholder
                    }
                }
            } else {
                atmosphericPlaceholder
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
    }

    private var atmosphericPlaceholder: some View {
        ZStack {
            LinearGradient(
                colors: [AppColors.surfaceElevated, AppColors.pageMiddle, AppColors.pageBase],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            Image(systemName: "mountain.2.fill")
                .font(.system(size: 150, weight: .ultraLight))
                .foregroundStyle(AppColors.surfaceGlass)
                .offset(y: -30)
        }
    }
}

private struct RouteCardSkeletonView: View {
    let height: CGFloat

    var body: some View {
        RoundedRectangle(cornerRadius: Radius.xl, style: .continuous)
            .fill(AppColors.surfacePrimary)
            .overlay {
                LinearGradient(
                    colors: [AppColors.surfaceGlass.opacity(0), AppColors.surfaceGlass, AppColors.surfaceGlass.opacity(0)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            }
            .frame(height: height)
            .padding(.horizontal, Spacing.pageHorizontal)
            .accessibilityLabel("路线加载中")
    }
}

private struct RouteMessageCard: View {
    let icon: String
    let message: String
    let height: CGFloat
    var action: (() -> Void)?

    var body: some View {
        Button { action?() } label: {
            VStack(spacing: Spacing.md) {
                Image(systemName: icon)
                    .font(.system(size: 36, weight: .light))
                Text(message)
                    .font(.bodyLarge)
            }
            .foregroundStyle(AppColors.textSecondary)
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .background(AppColors.surfacePrimary)
            .clipShape(RoundedRectangle(cornerRadius: Radius.xl, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(action == nil)
        .padding(.horizontal, Spacing.pageHorizontal)
    }
}

private struct RouteCardButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .animation(.easeOut(duration: 0.16), value: configuration.isPressed)
    }
}

#if DEBUG
#Preview("Route Discovery") {
    NavigationStack { RouteDiscoveryView(routeService: PreviewHelpers.routeService) }
}

#Preview("Route Card") {
    RouteCardView(route: RouteDiscoveryViewModel.preview.routes[0], height: 560)
        .padding()
        .background(AppColors.pageBase)
}
#endif
