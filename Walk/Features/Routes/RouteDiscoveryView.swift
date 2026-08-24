import SwiftUI

/// Layout values shared by route cards and their loading skeletons.
enum RouteDiscoveryLayout {
    static let cardHeightRatio: CGFloat = 0.72
    static let minimumCardHeight: CGFloat = 400
    static let maximumCardHeight: CGFloat = 680

    static func cardHeight(for viewportHeight: CGFloat) -> CGFloat {
        min(max(viewportHeight * cardHeightRatio, minimumCardHeight), maximumCardHeight)
    }
}

/// 路线发现页
struct RouteDiscoveryView: View {
    @StateObject private var viewModel: RouteDiscoveryViewModel
    private let routeService: RouteService
    private let onSelectRoute: ((Route) -> Void)?

    init(routeService: RouteService, onSelectRoute: ((Route) -> Void)? = nil) {
        self.routeService = routeService
        self.onSelectRoute = onSelectRoute
        _viewModel = StateObject(wrappedValue: RouteDiscoveryViewModel(service: routeService))
    }

    var body: some View {
        GeometryReader { geometry in
            ImmersivePageContainer {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: Spacing.xl) {
                        header

                        routeContent(cardHeight: RouteDiscoveryLayout.cardHeight(for: geometry.size.height))
                    }
                    .padding(.horizontal, Spacing.pageHorizontal)
                    .padding(.top, Spacing.lg)
                    .padding(.bottom, Spacing.xxl)
                }
                .refreshable {
                    await viewModel.loadRoutes()
                }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .task {
            await viewModel.loadRoutes()
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("探索路线")
                .font(.heroTitle)
                .tracking(-1.4)

            Text("走进山野，选择下一段旅程")
                .font(.heroSubtitle)
                .foregroundStyle(AppColors.textSecondary)
        }
        .padding(.top, Spacing.sm)
    }

    @ViewBuilder
    private func routeContent(cardHeight: CGFloat) -> some View {
        if viewModel.isLoading && viewModel.routes.isEmpty {
            RouteCardSkeletonView(height: cardHeight)
        } else if viewModel.errorMessage != nil && viewModel.routes.isEmpty {
            RouteMessageCard(
                icon: "arrow.clockwise.circle",
                message: "加载失败，点击重试",
                height: cardHeight
            ) {
                Task { await viewModel.retry() }
            }
        } else if viewModel.routes.isEmpty {
            RouteMessageCard(
                icon: "map",
                message: "暂无路线，下拉刷新",
                height: cardHeight
            )
        } else {
            ForEach(viewModel.routes) { route in
                if let onSelectRoute {
                    Button {
                        onSelectRoute(route)
                    } label: {
                        RouteCardView(route: route, height: cardHeight)
                    }
                    .buttonStyle(RouteCardButtonStyle())
                    .accessibilityHint("选择此路线并返回首页")
                } else {
                    NavigationLink(
                        destination: RouteDetailView(
                            routeId: route.id,
                            service: routeService
                        )
                    ) {
                        RouteCardView(route: route, height: cardHeight)
                    }
                    .buttonStyle(RouteCardButtonStyle())
                }
            }
        }
    }
}

/// 沉浸式路线大图卡片
struct RouteCardView: View {
    let route: Route
    let height: CGFloat

    init(route: Route, height: CGFloat = RouteDiscoveryLayout.minimumCardHeight) {
        self.route = route
        self.height = height
    }

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            RouteArtworkView(route: route)

            LinearGradient(
                colors: [.clear, Color.black.opacity(0.18), Color.black.opacity(0.92)],
                startPoint: .top,
                endPoint: .bottom
            )

            VStack(alignment: .leading, spacing: Spacing.md) {
                HStack(spacing: Spacing.sm) {
                    if let category = route.category {
                        routePill(category.displayName)
                    }
                    if let difficulty = route.difficulty {
                        routePill(difficulty.displayName)
                    }
                }

                Spacer()

                Text(route.name ?? "未命名路线")
                    .font(.system(size: 30, weight: .bold))
                    .lineLimit(2)

                if let description = route.description, !description.isEmpty {
                    Text(description)
                        .font(.bodySmall)
                        .foregroundStyle(AppColors.textSecondary)
                        .lineLimit(2)
                }

                HStack(spacing: Spacing.xl) {
                    routeMetric(icon: "point.topleft.down.curvedto.point.bottomright.up", value: route.distanceDescription)
                    if let elevation = route.elevation {
                        routeMetric(icon: "mountain.2", value: "\(elevation)m")
                    }
                }

                HStack {
                    Text("点击选择路线")
                        .font(.button)
                    Spacer()
                    Image(systemName: "arrow.up.right")
                        .font(.button)
                }
                .padding(.top, Spacing.xs)
            }
            .padding(Spacing.heroHorizontal)
        }
        .frame(maxWidth: .infinity)
        .frame(height: height)
        .clipShape(RoundedRectangle(cornerRadius: Radius.xl, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: Radius.xl, style: .continuous)
                .stroke(AppColors.border, lineWidth: 1)
        }
        .shadow(color: Color.black.opacity(0.30), radius: 20, y: 10)
        .contentShape(RoundedRectangle(cornerRadius: Radius.xl, style: .continuous))
    }

    private func routePill(_ title: String) -> some View {
        Text(title)
            .font(.label)
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.sm)
            .background(.ultraThinMaterial, in: Capsule())
            .overlay { Capsule().stroke(Color.white.opacity(0.18), lineWidth: 1) }
    }

    private func routeMetric(icon: String, value: String) -> some View {
        Label(value, systemImage: icon)
            .font(.caption)
            .foregroundStyle(AppColors.textSecondary)
    }
}

private struct RouteArtworkView: View {
    let route: Route

    var body: some View {
        Group {
            if let value = route.coverImageUrl, let url = URL(string: value) {
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
                colors: [
                    Color(red: 0.20, green: 0.38, blue: 0.29),
                    Color(red: 0.08, green: 0.20, blue: 0.16),
                    AppColors.routeInner
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            Image(systemName: "mountain.2.fill")
                .font(.system(size: 150, weight: .ultraLight))
                .foregroundStyle(Color.white.opacity(0.12))
                .offset(y: -30)
        }
    }
}

private struct RouteCardSkeletonView: View {
    let height: CGFloat

    var body: some View {
        RoundedRectangle(cornerRadius: Radius.xl, style: .continuous)
            .fill(AppColors.surfaceCard)
            .overlay {
                LinearGradient(
                    colors: [.clear, Color.white.opacity(0.08), .clear],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            }
            .frame(height: height)
            .overlay(alignment: .bottomLeading) {
                VStack(alignment: .leading, spacing: Spacing.md) {
                    Capsule().fill(AppColors.surfaceGlass).frame(width: 92, height: 28)
                    RoundedRectangle(cornerRadius: Radius.sm).fill(AppColors.surfaceGlass).frame(width: 220, height: 32)
                    RoundedRectangle(cornerRadius: Radius.sm).fill(AppColors.surfaceGlass).frame(height: 14)
                }
                .padding(Spacing.heroHorizontal)
            }
            .accessibilityLabel("路线加载中")
    }
}

private struct RouteMessageCard: View {
    let icon: String
    let message: String
    let height: CGFloat
    var action: (() -> Void)?

    var body: some View {
        Button {
            action?()
        } label: {
            VStack(spacing: Spacing.md) {
                Image(systemName: icon)
                    .font(.system(size: 36, weight: .light))
                Text(message)
                    .font(.bodyLarge)
            }
            .foregroundStyle(AppColors.textSecondary)
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .background(AppColors.surfaceCard)
            .clipShape(RoundedRectangle(cornerRadius: Radius.xl, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(action == nil)
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
    RouteCardView(route: MockData.routes.first!, height: 560)
        .padding()
        .background(AppColors.routeInner)
}
#endif
