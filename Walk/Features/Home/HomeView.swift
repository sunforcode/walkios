import SwiftUI

/// Values copied from the current Flutter Home implementation.
enum HomeLayout {
    static let heroHorizontalPadding: CGFloat = 20
    static let emptyHorizontalPadding: CGFloat = 28
    static let emptyBrandSize: CGFloat = 42
    static let emptyPromptSize: CGFloat = 20
    static let emptyCTAHorizontalPadding: CGFloat = 48
    static let weatherHorizontalPadding: CGFloat = 20
    static let weatherVerticalPadding: CGFloat = 16
    static let weatherBottomOffset: CGFloat = 100
    static let changeRouteBottomOffset: CGFloat = 200
    static let compactHeightThreshold: CGFloat = 600
}

@MainActor
struct HomeView: View {
    let onOpenDrawer: () -> Void
    let onFindRoute: () -> Void
    let onNavigate: (RootDestination) -> Void
    let selectedRoute: Route?

    @StateObject private var viewModel: HomeViewModel

    init(
        onOpenDrawer: @escaping () -> Void,
        onFindRoute: @escaping () -> Void,
        onNavigate: @escaping (RootDestination) -> Void,
        selectionStore: any CurrentRouteSelectionStore,
        routeService: RouteService,
        selectedRoute: Route? = nil
    ) {
        self.onOpenDrawer = onOpenDrawer
        self.onFindRoute = onFindRoute
        self.onNavigate = onNavigate
        self.selectedRoute = selectedRoute
        _viewModel = StateObject(wrappedValue: HomeViewModel(
            selectionStore: selectionStore,
            routeService: routeService
        ))
    }

    init(
        onOpenDrawer: @escaping () -> Void,
        onFindRoute: @escaping () -> Void,
        onNavigate: @escaping (RootDestination) -> Void,
        viewModel: HomeViewModel,
        selectedRoute: Route? = nil
    ) {
        self.onOpenDrawer = onOpenDrawer
        self.onFindRoute = onFindRoute
        self.onNavigate = onNavigate
        self.selectedRoute = selectedRoute
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            switch viewModel.state {
            case .loading:
                loadingContent
            case .empty:
                EmptyHomeView(onFindRoute: onFindRoute)
            case .error:
                ErrorHomeView(
                    onRetry: { Task { await viewModel.retry() } },
                    onChangeRoute: onFindRoute
                )
            case let .ready(route, weather):
                RouteHomeView(
                    route: route,
                    weather: weather,
                    onRouteDetail: { onNavigate(.routeDetail(route.id)) },
                    onNavigation: { onNavigate(.navigation) }
                )
            }

            Button(action: onOpenDrawer) {
                Image(systemName: "line.3.horizontal")
                    .font(.nav)
                    .foregroundStyle(AppColors.textPrimary)
                    .frame(width: Spacing.navBarHeight, height: Spacing.navBarHeight)
            }
                .buttonStyle(.plain)
                .accessibilityLabel("打开菜单")
                .padding(.top, Spacing.sm)
                .padding(.trailing, HomeLayout.heroHorizontalPadding)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
        }
        .background(AppColors.bgBase.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .task {
            if let selectedRoute {
                await viewModel.selectRoute(selectedRoute)
            } else {
                await viewModel.load()
            }
        }
        .onChange(of: selectedRoute) { route in
            guard let route else { return }
            Task { await viewModel.selectRoute(route) }
        }
    }

    private var loadingContent: some View {
        AppColors.bgBase
            .ignoresSafeArea()
            .accessibilityLabel("首页加载中")
    }
}

private struct EmptyHomeView: View {
    let onFindRoute: () -> Void

    var body: some View {
        ZStack {
            LinearGradient(
                gradient: Gradient(stops: HomeStyle.gradientStops),
                startPoint: HomeStyle.gradientStartPoint,
                endPoint: HomeStyle.gradientEndPoint
            )
            .ignoresSafeArea()

            MountainSilhouetteView()
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Text("WALK")
                    .font(.system(size: HomeLayout.emptyBrandSize, weight: .heavy))
                    .tracking(2)

                Text("徒步旅行助手")
                    .font(.system(size: 16))
                    .foregroundStyle(AppColors.textWeak)
                    .padding(.top, Spacing.sm)

                Text("这周去哪徒步？")
                    .font(.system(size: HomeLayout.emptyPromptSize, weight: .light))
                    .foregroundStyle(AppColors.textSecondary)
                    .padding(.top, Spacing.xxl)

                Button("找路线", action: onFindRoute)
                    .font(.system(size: 18))
                    .foregroundStyle(.white)
                    .padding(.horizontal, HomeLayout.emptyCTAHorizontalPadding)
                    .padding(.vertical, 14)
                    .background(.ultraThinMaterial, in: Capsule())
                    .background(AppColors.surfaceGlass, in: Capsule())
                    .overlay { Capsule().stroke(AppColors.interactiveCTABorder, lineWidth: 1) }
                    .buttonStyle(HomeGlassButtonStyle())
                    .padding(.top, Spacing.xxxl)

                Text("还没有行程")
                    .font(.system(size: 14))
                    .foregroundStyle(AppColors.textWeak)
                    .padding(.top, Spacing.lg)
            }
            .padding(.horizontal, HomeLayout.emptyHorizontalPadding)
            .padding(.vertical, Spacing.xl)
        }
        .foregroundStyle(AppColors.textPrimary)
    }
}

private struct RouteHomeView: View {
    let route: Route
    let weather: HomeWeatherSummary?
    let onRouteDetail: () -> Void
    let onNavigation: () -> Void

    private var hikingDate: Date { HomeViewModel.upcomingHikingDate() }

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                Button(action: onRouteDetail) {
                    ZStack {
                        HomeRouteArtwork(route: route)
                        LinearGradient(
                            colors: [Color.black.opacity(0.58), .clear, Color.black.opacity(0.78)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("查看路线详情")

                VStack(alignment: .leading, spacing: 0) {
                    routeInfo
                        .padding(.top, proxy.safeAreaInsets.top + Spacing.hero)
                    Spacer()
                }
                .padding(.horizontal, HomeLayout.heroHorizontalPadding)
                .allowsHitTesting(false)

                if proxy.size.height <= HomeLayout.compactHeightThreshold {
                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        navigationButton
                        WeatherHUD(weather: weather)
                            .allowsHitTesting(false)
                    }
                    .padding(.horizontal, HomeLayout.heroHorizontalPadding)
                    .padding(.bottom, proxy.safeAreaInsets.bottom + HomeLayout.heroHorizontalPadding)
                    .frame(maxHeight: .infinity, alignment: .bottom)
                } else {
                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        navigationButton
                        WeatherHUD(weather: weather)
                            .allowsHitTesting(false)
                    }
                        .padding(.horizontal, HomeLayout.heroHorizontalPadding)
                        .padding(.bottom, proxy.safeAreaInsets.bottom + HomeLayout.weatherBottomOffset)
                        .frame(maxHeight: .infinity, alignment: .bottom)

                    SwipeIndicator()
                        .allowsHitTesting(false)
                        .padding(.bottom, proxy.safeAreaInsets.bottom + HomeLayout.heroHorizontalPadding)
                        .frame(maxHeight: .infinity, alignment: .bottom)
                }
            }
        }
        .foregroundStyle(AppColors.textPrimary)
        .ignoresSafeArea()
    }

    private var routeInfo: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text(route.name ?? "未命名路线")
                .font(.heroTitle)
                .lineLimit(2)

            departureLine

            HStack(alignment: .top, spacing: Spacing.xl) {
                HomeMetric(value: distanceValue, unit: "公里")
                HomeMetric(value: elevationValue, unit: "米爬升")
                HomeMetric(value: route.durationDescription, unit: "预计用时")
            }
            .padding(.top, Spacing.sm)
        }
    }

    private var departureLine: some View {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        let target = calendar.startOfDay(for: hikingDate)
        let days = calendar.dateComponents([.day], from: today, to: target).day ?? 0
        let date = hikingDate.formatted(.dateTime.month().day())
        return Group {
            if days <= 0 {
                Text("\(date) · 今天出发")
                    .font(.system(size: 16))
                    .foregroundColor(AppColors.textSecondary)
            } else {
                Text("\(date) · 距离出发还有 ")
                    .font(.system(size: 16))
                    .foregroundColor(AppColors.textSecondary)
                + Text("\(days)")
                    .font(.system(size: 18, weight: .black))
                    .foregroundColor(AppColors.interactiveAccent)
                + Text(" 天")
                    .font(.system(size: 16))
                    .foregroundColor(AppColors.textSecondary)
            }
        }
    }

    private var distanceValue: String {
        guard let distance = route.distance else { return "--" }
        return distance.rounded() == distance ? String(Int(distance)) : String(format: "%.1f", distance)
    }

    private var elevationValue: String {
        route.elevation.map(String.init) ?? "--"
    }

    private var navigationButton: some View {
        Button(action: onNavigation) {
            Image(systemName: "play.fill")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(AppColors.textPrimary)
                .frame(width: 44, height: 44)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("开始导航")
    }
}

private struct HomeRouteArtwork: View {
    let route: Route

    var body: some View {
        Group {
            if let value = route.coverImageUrl, let url = URL(string: value) {
                AsyncImage(url: url) { phase in
                    if let image = phase.image {
                        image.resizable().scaledToFill()
                    } else {
                        TrailFallbackView()
                    }
                }
            } else {
                TrailFallbackView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
    }
}

private struct TrailFallbackView: View {
    var body: some View {
        Canvas { context, size in
            context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(AppColors.bgBase))

            var mountain = Path()
            mountain.move(to: CGPoint(x: 0, y: size.height * 0.74))
            mountain.addLine(to: CGPoint(x: size.width * 0.21, y: size.height * 0.43))
            mountain.addLine(to: CGPoint(x: size.width * 0.40, y: size.height * 0.56))
            mountain.addLine(to: CGPoint(x: size.width * 0.67, y: size.height * 0.35))
            mountain.addLine(to: CGPoint(x: size.width, y: size.height * 0.49))
            mountain.addLine(to: CGPoint(x: size.width, y: size.height))
            mountain.addLine(to: CGPoint(x: 0, y: size.height))
            mountain.closeSubpath()
            context.fill(mountain, with: .color(.white.opacity(0.02)))

            var trail = Path()
            trail.move(to: CGPoint(x: size.width * 0.16, y: size.height * 0.68))
            trail.addCurve(
                to: CGPoint(x: size.width * 0.85, y: size.height * 0.35),
                control1: CGPoint(x: size.width * 0.36, y: size.height * 0.45),
                control2: CGPoint(x: size.width * 0.64, y: size.height * 0.48)
            )
            context.stroke(trail, with: .color(AppColors.interactiveAccent.opacity(0.15)), lineWidth: 12)
            context.stroke(trail, with: .color(AppColors.interactiveAccent.opacity(0.60)), lineWidth: 3)
            context.fill(Path(ellipseIn: CGRect(x: size.width * 0.16 - 5, y: size.height * 0.68 - 5, width: 10, height: 10)), with: .color(AppColors.interactiveAccent.opacity(0.8)))
            context.fill(Path(ellipseIn: CGRect(x: size.width * 0.85 - 5, y: size.height * 0.35 - 5, width: 10, height: 10)), with: .color(AppColors.error.opacity(0.8)))
        }
    }
}

private struct MountainSilhouetteView: View {
    var body: some View {
        Canvas { context, size in
            let height: CGFloat = 280
            let base = size.height

            var back = Path()
            back.move(to: CGPoint(x: 0, y: base))
            back.addLine(to: CGPoint(x: size.width * 0.21, y: base - height * 0.43))
            back.addLine(to: CGPoint(x: size.width * 0.37, y: base - height * 0.32))
            back.addLine(to: CGPoint(x: size.width * 0.59, y: base - height * 0.75))
            back.addLine(to: CGPoint(x: size.width, y: base - height * 0.57))
            back.addLine(to: CGPoint(x: size.width, y: base))
            back.closeSubpath()
            context.fill(back, with: .color(.white.opacity(0.02)))

            var front = Path()
            front.move(to: CGPoint(x: 0, y: base))
            front.addLine(to: CGPoint(x: size.width * 0.16, y: base - height * 0.57))
            front.addLine(to: CGPoint(x: size.width * 0.27, y: base - height * 0.43))
            front.addLine(to: CGPoint(x: size.width * 0.48, y: base - height * 0.86))
            front.addLine(to: CGPoint(x: size.width * 0.85, y: base - height * 0.71))
            front.addLine(to: CGPoint(x: size.width, y: base - height * 0.43))
            front.addLine(to: CGPoint(x: size.width, y: base))
            front.closeSubpath()
            context.fill(front, with: .color(.white.opacity(0.04)))
        }
    }
}

private struct WeatherHUD: View {
    let weather: HomeWeatherSummary?

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("徒步日天气")
                .font(.system(size: 12))
                .foregroundStyle(AppColors.textWeak)
            HStack {
                HomeMetric(value: rainValue, unit: "降雨", centered: true)
                Spacer()
                HomeMetric(value: windValue, unit: "风", centered: true)
                Spacer()
                HomeMetric(value: temperatureValue, unit: "温度", centered: true)
            }
        }
        .padding(.horizontal, HomeLayout.weatherHorizontalPadding)
        .padding(.vertical, HomeLayout.weatherVerticalPadding)
    }

    private var rainValue: String {
        weather?.precipitationProbability.map { "\($0)%" } ?? "--"
    }

    private var windValue: String {
        weather?.windSpeed.map { "\(Int($0.rounded()))km/h" } ?? "--"
    }

    private var temperatureValue: String {
        guard let weather else { return "--" }
        if let minimum = weather.minimumTemperature, let maximum = weather.maximumTemperature {
            return "\(Int(minimum.rounded()))-\(Int(maximum.rounded()))°"
        }
        return "--"
    }
}

private struct HomeMetric: View {
    let value: String
    let unit: String
    var centered = false

    var body: some View {
        VStack(alignment: centered ? .center : .leading, spacing: 2) {
            Text(value).font(.metricValue)
            Text(unit).font(.metricUnit).foregroundStyle(AppColors.textWeak)
        }
    }
}

private struct SwipeIndicator: View {
    @State private var offset: CGFloat = 0

    var body: some View {
        VStack(spacing: Spacing.xs) {
            Image(systemName: "chevron.up")
                .font(.system(size: 18, weight: .medium))
            Text("推荐路线").font(.system(size: 11))
        }
        .foregroundStyle(AppColors.textWeak)
        .offset(y: offset)
        .onAppear {
            withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                offset = -6
            }
        }
    }
}

private struct ErrorHomeView: View {
    let onRetry: () -> Void
    let onChangeRoute: () -> Void

    var body: some View {
        ZStack {
            LinearGradient(
                gradient: Gradient(stops: HomeStyle.gradientStops),
                startPoint: HomeStyle.gradientStartPoint,
                endPoint: HomeStyle.gradientEndPoint
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 42, weight: .light))
                    .foregroundStyle(AppColors.interactiveAccent)
                Text("当前路线加载失败")
                    .font(.system(size: 24, weight: .bold))
                    .padding(.top, 18)
                Text("可以重试，或者换一条路线。")
                    .font(.system(size: 15))
                    .foregroundStyle(AppColors.textWeak)
                    .padding(.top, 10)
                HStack(spacing: 12) {
                    HomeGlassButton(title: "重试", action: onRetry)
                    HomeGlassButton(title: "更换路线", emphasized: true, action: onChangeRoute)
                }
                .padding(.top, 26)
            }
            .padding(28)
            .padding(.vertical, Spacing.xl)
        }
        .foregroundStyle(AppColors.textPrimary)
    }
}

private struct HomeGlassButton: View {
    let title: String
    var emphasized = false
    let action: () -> Void

    var body: some View {
        Button(title, action: action)
            .font(.system(size: 16, weight: .medium))
            .foregroundStyle(AppColors.textPrimary)
            .padding(.horizontal, Spacing.xl)
            .padding(.vertical, Spacing.md)
            .background(.ultraThinMaterial, in: Capsule())
            .background(emphasized ? AppColors.interactiveCTA : Color.white.opacity(0.04), in: Capsule())
            .overlay { Capsule().stroke(emphasized ? AppColors.interactiveCTABorder : AppColors.border) }
            .buttonStyle(.plain)
    }
}

private struct HomeGlassButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}
