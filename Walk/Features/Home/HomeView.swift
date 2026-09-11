import SwiftUI
import WalkData
import WalkDesignSystem

enum HomeLayout {
    static let sceneHorizontalPadding: CGFloat = 18
    static let guestHorizontalPadding: CGFloat = 28
    static let guestBottomPadding: CGFloat = 36
    static let maximumContentWidth: CGFloat = 360
}

@MainActor
struct HomeView: View {
    let onAuthenticate: (PendingAuthIntent) -> Void
    let onNavigate: (AppDestination) -> Void
    @StateObject private var viewModel: HomeViewModel

    init(
        onAuthenticate: @escaping (PendingAuthIntent) -> Void,
        onNavigate: @escaping (AppDestination) -> Void,
        onNoFocus: @escaping () -> Void,
        service: any PersonalTripServicing
    ) {
        self.onAuthenticate = onAuthenticate
        self.onNavigate = onNavigate
        _viewModel = StateObject(wrappedValue: HomeViewModel(
            service: service,
            onNoFocus: onNoFocus
        ))
    }

    init(
        onAuthenticate: @escaping (PendingAuthIntent) -> Void = { _ in },
        onNavigate: @escaping (AppDestination) -> Void = { _ in },
        viewModel: HomeViewModel
    ) {
        self.onAuthenticate = onAuthenticate
        self.onNavigate = onNavigate
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        HomeScene {
            switch viewModel.state {
            case .guest:
                GuestHomeContent { onAuthenticate(.homeStart) }
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
                    HomeLoadingContent()
                }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .task { await viewModel.load() }
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

private struct HomeScene<Content: View>: View {
    @ViewBuilder let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                HomePageBackground()
                HomeContrastOverlay()
                HomeMountainSilhouette()
                content
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .ignoresSafeArea(edges: [.top, .horizontal])
        .background(AppColors.pageBase.ignoresSafeArea())
        .foregroundStyle(AppColors.textPrimary)
    }
}

private struct GuestHomeContent: View {
    let onStart: () -> Void

    var body: some View {
        VStack(alignment: .leading) {
            Spacer()
            PrimaryAction(title: "开启一次新的徒步行程", variant: .compact, action: onStart)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
        .padding(.horizontal, HomeLayout.guestHorizontalPadding)
        .padding(.bottom, HomeLayout.guestBottomPadding)
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
#Preview("guest") {
    HomeView(viewModel: HomePreviewFixtures.homeViewModel(state: .guest))
}

#Preview("focusComplete") {
    HomeView(viewModel: HomePreviewFixtures.homeViewModel(
        state: .ready,
        trip: HomePreviewFixtures.completeTrip,
        weather: HomePreviewFixtures.homeWeatherAvailable
    ))
}

#Preview("focusMissingMetrics") {
    HomeView(viewModel: HomePreviewFixtures.homeViewModel(
        state: .ready,
        trip: HomePreviewFixtures.missingMetricsTrip,
        weather: HomePreviewFixtures.homeWeatherAvailable
    ))
}

#Preview("focusWeatherOmitted") {
    HomeView(viewModel: HomePreviewFixtures.homeViewModel(
        state: .ready,
        trip: HomePreviewFixtures.completeTrip
    ))
}

#Preview("loading") {
    HomeView(viewModel: HomePreviewFixtures.homeViewModel(state: .loading))
}

#Preview("error") {
    HomeView(viewModel: HomePreviewFixtures.homeViewModel(
        state: .error("当前行程加载失败")
    ))
}

#Preview("longContent") {
    HomeView(viewModel: HomePreviewFixtures.homeViewModel(
        state: .ready,
        trip: HomePreviewFixtures.longContentTrip,
        weather: HomePreviewFixtures.homeWeatherLongContent
    ))
    .environment(\.dynamicTypeSize, .accessibility2)
}
#endif
