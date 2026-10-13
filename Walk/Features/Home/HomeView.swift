import SwiftUI
import WalkData
import WalkDesignSystem

@MainActor
struct HomeView: View {
    let onAuthenticate: (PendingAuthIntent) -> Void
    let onNavigate: (AppDestination) -> Void
    @State private var viewModel: HomeViewModel

    init(
        onAuthenticate: @escaping (PendingAuthIntent) -> Void,
        onNavigate: @escaping (AppDestination) -> Void,
        service: any PersonalTripServicing,
        authSession: any AuthSession
    ) {
        self.onAuthenticate = onAuthenticate
        self.onNavigate = onNavigate
        _viewModel = State(initialValue: HomeViewModel(
            service: service,
            authSession: authSession
        ))
    }

    init(
        onAuthenticate: @escaping (PendingAuthIntent) -> Void = { _ in },
        onNavigate: @escaping (AppDestination) -> Void = { _ in },
        viewModel: HomeViewModel
    ) {
        self.onAuthenticate = onAuthenticate
        self.onNavigate = onNavigate
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        PageShell(
            title: "出发",
            description: "山野路线，整装待发",
            background: {
                ZStack {
                    HomePageBackground()
                    HomeContrastOverlay()
                    HomeMountainSilhouette()
                }
            }
        ) {
            if viewModel.state == .ready, viewModel.focusedTrip != nil {
                homeContentLayout
                    .contentShape(Rectangle())
                    .onTapGesture { openFocusedTripIfNeeded() }
            } else {
                homeContentLayout
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .task { await viewModel.load() }
        .onDisappear { viewModel.cancelPendingOperations() }
    }

    private var homeContentLayout: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)
            homeContent
                .padding(.bottom, Spacing.safeAreaBottom + Spacing.lg)
        }
    }

    @ViewBuilder
    private var homeContent: some View {
        switch viewModel.state {
        case .guest:
            GuestHomeContent { onAuthenticate(.trips) }
        case .loading:
            HomeLoadingContent()
        case .error(let message):
            ErrorView(message: message, variant: .scene) {
                Task { await viewModel.retry() }
            }
        case .ready:
            if let trip = viewModel.focusedTrip {
                FocusTripSummary(
                    model: focusSummary(for: trip),
                    onOpen: { onNavigate(.tripDetail(trip.tripID)) }
                )
            } else {
                NoFocusContent(
                    // browseRoutes：首页空态主动进入全部路线（app-flow）
                    onBrowseRoutes: { onNavigate(.routeList) }
                )
            }
        }
    }

    private func openFocusedTripIfNeeded() {
        guard case .ready = viewModel.state, let trip = viewModel.focusedTrip else { return }
        onNavigate(.tripDetail(trip.tripID))
    }

    private func focusSummary(for trip: PersonalTripSummary) -> FocusTripSummaryModel {
        FocusTripSummaryModel(
            routeName: trip.routeName,
            start: trip.start.name,
            end: trip.end.name,
            distance: trip.distance.map { distanceText($0.meters) },
            distanceUnit: trip.distance.map { $0.meters >= 1_000 ? "km" : "m" },
            ascent: trip.ascent.map { elevationText($0.meters) },
            ascentUnit: trip.ascent.map { _ in "m" },
            estimatedDuration: durationText(trip.estimatedDuration.seconds),
            weather: viewModel.weatherSummary.map {
                WeatherSummaryModel(
                    conclusion: $0.conclusion,
                    impact: $0.impact,
                    state: .available
                )
            }
        )
    }

    private func distanceText(_ meters: Double) -> String {
        if meters >= 1_000 {
            return (meters / 1_000).formatted(.number.precision(.fractionLength(0...1)))
        }
        return meters.formatted(.number.precision(.fractionLength(0...1)))
    }

    private func elevationText(_ meters: Double) -> String {
        meters.formatted(.number.precision(.fractionLength(0...0)))
    }

    private func durationText(_ seconds: Double) -> String {
        let totalMinutes = Int((seconds / 60).rounded())
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        if hours >= 24, minutes == 0 {
            return "约 \(hours / 24) 天"
        }
        if minutes == 0 {
            return "约 \(hours) h"
        }
        return "约 \(hours) h \(minutes) min"
    }
}

private struct GuestHomeContent: View {
    let onStart: () -> Void

    var body: some View {
        VStack(alignment: .leading) {
            Spacer()
            PrimaryAction(title: "开启一次新的徒步行程", variant: .compact, action: onStart)
        }
        .frame(maxWidth: .infinity, minHeight: 440, alignment: .bottomLeading)
        .padding(.horizontal, Spacing.pageHorizontal)
        .padding(.bottom, Spacing.xl)
    }
}

/// 无焦点空态：已登录但当前没有进行中的行程，停留在首页并提供去挑路线的主动入口。
private struct NoFocusContent: View {
    let onBrowseRoutes: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text("当前没有进行中的行程")
                .font(.appCaption)
                .foregroundStyle(AppColors.textSecondary)
            PrimaryAction(title: "去挑一条路线", variant: .compact, action: onBrowseRoutes)
        }
        .frame(maxWidth: .infinity, minHeight: 440, alignment: .bottomLeading)
        .padding(.horizontal, Spacing.pageHorizontal)
        .padding(.bottom, Spacing.xl)
        .accessibilityElement(children: .combine)
    }
}

private struct HomeLoadingContent: View {
    var body: some View {
        LoadingView(message: "正在读取当前行程", detail: "请稍候", variant: .scene)
    }
}

struct HomePageBackground: View {
    var body: some View {
        LinearGradient(
            gradient: Gradient(stops: HomeStyle.gradientStops),
            startPoint: HomeStyle.gradientStartPoint,
            endPoint: HomeStyle.gradientEndPoint
        )
        .ignoresSafeArea()
    }
}

private struct HomeContrastOverlay: View {
    var body: some View {
        LinearGradient(
            stops: [
                .init(color: AppColors.pageBase.opacity(0.18), location: 0),
                .init(color: AppColors.pageBase.opacity(0), location: 0.34),
                .init(color: AppColors.pageBase.opacity(0.90), location: 0.84),
                .init(color: AppColors.pageBase, location: 1),
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
}

private struct HomeMountainSilhouette: View {
    var body: some View {
        Canvas { context, size in
            let sceneHeight = size.height * 0.58
            let base = size.height

            var middle = Path()
            middle.move(to: CGPoint(x: -size.width * 0.08, y: base))
            middle.addLine(to: CGPoint(x: -size.width * 0.08, y: base - sceneHeight * 0.28))
            middle.addLine(to: CGPoint(x: size.width * 0.18, y: base - sceneHeight * 0.52))
            middle.addLine(to: CGPoint(x: size.width * 0.43, y: base - sceneHeight * 0.37))
            middle.addLine(to: CGPoint(x: size.width * 0.63, y: base - sceneHeight * 0.88))
            middle.addLine(to: CGPoint(x: size.width * 0.78, y: base - sceneHeight * 0.55))
            middle.addLine(to: CGPoint(x: size.width * 1.08, y: base - sceneHeight * 0.72))
            middle.addLine(to: CGPoint(x: size.width * 1.08, y: base))
            middle.closeSubpath()
            context.fill(middle, with: .color(AppColors.sceneMountainMiddle))

            var foreground = Path()
            foreground.move(to: CGPoint(x: -size.width * 0.08, y: base))
            foreground.addLine(to: CGPoint(x: -size.width * 0.08, y: base - sceneHeight * 0.14))
            foreground.addLine(to: CGPoint(x: size.width * 0.20, y: base - sceneHeight * 0.34))
            foreground.addLine(to: CGPoint(x: size.width * 0.46, y: base - sceneHeight * 0.18))
            foreground.addLine(to: CGPoint(x: size.width * 0.72, y: base - sceneHeight * 0.48))
            foreground.addLine(to: CGPoint(x: size.width * 1.08, y: base - sceneHeight * 0.20))
            foreground.addLine(to: CGPoint(x: size.width * 1.08, y: base))
            foreground.closeSubpath()
            context.fill(foreground, with: .color(AppColors.sceneMountainFront))
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

#if DEBUG
extension HomeViewModel {
    static func preview(
        state: HomeState,
        trip: PersonalTripSummary? = nil,
        weather: HomeWeatherSummary? = nil
    ) -> HomeViewModel {
        HomeViewModel(
            staticState: state,
            focusedTrip: trip,
            weatherSummary: weather
        )
    }
}

extension HomeWeatherSummary {
    static let available = HomeWeatherSummary(
        conclusion: WeatherSummaryModel.available.conclusion,
        impact: WeatherSummaryModel.available.impact
    )

    static let longContent = HomeWeatherSummary(
        conclusion: WeatherSummaryModel.longContent.conclusion,
        impact: WeatherSummaryModel.longContent.impact
    )
}

extension PersonalTripSummary {
    static let homeComplete = homePreview(
        routeName: "云岭环线",
        start: "云栈口",
        end: "云栈口",
        distanceMeters: 12_100,
        ascentMeters: 600
    )

    static let homeMissingMetrics = homePreview(
        routeName: "云岭环线",
        start: "云栈口",
        end: "云栈口",
        distanceMeters: nil,
        ascentMeters: nil
    )

    static let homeLongContent = homePreview(
        routeName: "云岭北坡高山草甸与连续山脊全景环线",
        start: "云栈口游客中心北侧长距离接驳点",
        end: "云栈口游客中心南侧返程集合点",
        distanceMeters: 12_100,
        ascentMeters: 600
    )

    private static func homePreview(
        routeName: String,
        start: String,
        end: String,
        distanceMeters: Double?,
        ascentMeters: Double?
    ) -> PersonalTripSummary {
        PersonalTripSummary(
            tripID: "home-preview-trip",
            revision: "home-preview-revision",
            name: routeName,
            status: .inProgress,
            routeReference: PersonalTripRouteReference(
                routeID: "home-preview-route",
                adoptedRouteVersionID: "home-preview-route-version"
            ),
            routeName: routeName,
            routeType: "loop",
            start: PublicRoutePlace(name: start),
            end: PublicRoutePlace(name: end),
            estimatedDuration: RouteDuration(seconds: 19_200),
            startDate: LocalDate(year: 2026, month: 9, day: 20),
            endDate: LocalDate(year: 2026, month: 9, day: 20),
            totalDayCount: 1,
            hikingDayCount: 1,
            versionLabel: "preview-v1",
            cover: nil,
            direction: "环线",
            distance: distanceMeters.map(RouteDistance.init(meters:)),
            ascent: ascentMeters.map(RouteElevationGain.init(meters:))
        )
    }
}

#Preview("guest") {
    HomeView(viewModel: HomeViewModel.preview(state: .guest))
}

#Preview("noFocus") {
    HomeView(viewModel: HomeViewModel.preview(state: .ready, trip: nil))
}

#Preview("focusComplete") {
    HomeView(viewModel: HomeViewModel.preview(
        state: .ready,
        trip: PersonalTripSummary.homeComplete,
        weather: HomeWeatherSummary.available
    ))
}

#Preview("focusMissingMetrics") {
    HomeView(viewModel: HomeViewModel.preview(
        state: .ready,
        trip: PersonalTripSummary.homeMissingMetrics,
        weather: HomeWeatherSummary.available
    ))
}

#Preview("focusWeatherOmitted") {
    HomeView(viewModel: HomeViewModel.preview(
        state: .ready,
        trip: PersonalTripSummary.homeComplete
    ))
}

#Preview("loading") {
    HomeView(viewModel: HomeViewModel.preview(state: .loading))
}

#Preview("error") {
    HomeView(viewModel: HomeViewModel.preview(
        state: .error("当前行程加载失败")
    ))
}

#Preview("longContent") {
    HomeView(viewModel: HomeViewModel.preview(
        state: .ready,
        trip: PersonalTripSummary.homeLongContent,
        weather: HomeWeatherSummary.longContent
    ))
    .environment(\.dynamicTypeSize, .accessibility2)
}
#endif
