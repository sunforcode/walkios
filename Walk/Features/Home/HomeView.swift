import SwiftUI

enum HomeLayout {
    static let heroHorizontalPadding = Spacing.pageHorizontal
    static let emptyHorizontalPadding: CGFloat = 28
    static let contentBottomPadding: CGFloat = 24
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
        onNavigate: @escaping (AppDestination) -> Void,
        viewModel: HomeViewModel
    ) {
        self.onAuthenticate = onAuthenticate
        self.onNavigate = onNavigate
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        ZStack {
            switch viewModel.state {
            case .guest:
                GuestHomeView { onAuthenticate(.homeStart) }
            case .loading, .empty:
                AppColors.pageBase
                    .ignoresSafeArea()
                    .accessibilityLabel("首页加载中")
            case .error:
                ErrorHomeView(onRetry: { Task { await viewModel.retry() } })
            case .ready:
                if let trip = viewModel.focusedTrip {
                    TripHomeView(
                        trip: trip,
                        weather: viewModel.weatherSummary,
                        refreshError: viewModel.refreshError,
                        onOpenTrip: { onNavigate(.tripDetail(trip.tripID)) }
                    )
                }
            }
        }
        .background(AppColors.pageBase.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .task { await viewModel.load() }
    }
}

private struct GuestHomeView: View {
    let onStart: () -> Void

    var body: some View {
        ZStack {
            HomePageBackground().ignoresSafeArea()
            MountainSilhouetteView().ignoresSafeArea()
            VStack(alignment: .leading) {
                Spacer()
                HomeGlassButton(
                    title: "开启一次新的徒步行程",
                    emphasized: true,
                    action: onStart
                )
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, HomeLayout.emptyHorizontalPadding)
            .padding(.bottom, HomeLayout.contentBottomPadding)
        }
        .foregroundStyle(AppColors.textPrimary)
    }
}

private struct TripHomeView: View {
    let trip: PersonalTripSummary
    let weather: HomeWeatherSummary?
    let refreshError: String?
    let onOpenTrip: () -> Void

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                TripArtworkView(cover: trip.cover).ignoresSafeArea()
                LinearGradient(
                    colors: [
                        AppColors.surfaceOverlay.opacity(0.40),
                        AppColors.surfaceOverlay.opacity(0),
                        AppColors.surfaceToast
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                Rectangle()
                    .fill(AppColors.pageBase.opacity(0.001))
                    .contentShape(Rectangle())
                    .onTapGesture(perform: onOpenTrip)
                    .accessibilityElement()
                    .accessibilityLabel("查看\(trip.name)")
                    .accessibilityAddTraits(.isButton)
                    .accessibilityAction { onOpenTrip() }

                VStack(alignment: .leading, spacing: Spacing.md) {
                    PageHeroHeader(
                        title: trip.routeName,
                        subtitle: "\(trip.start.name) → \(trip.end.name)"
                    )
                    .allowsHitTesting(false)

                    Spacer()

                    if let refreshError {
                        Text(refreshError)
                            .font(.caption)
                            .foregroundStyle(AppColors.textWeak)
                    }

                    HStack(alignment: .bottom, spacing: Spacing.md) {
                        WeatherHUD(text: weather?.text ?? "天气摘要暂不可用")
                        Spacer(minLength: Spacing.md)
                        VStack(alignment: .trailing, spacing: Spacing.xs) {
                            if let distance = trip.distance {
                                Text(formatDistance(distance.meters))
                            }
                            if let ascent = trip.ascent {
                                Text("累计爬升 \(Int(ascent.meters.rounded())) m")
                            }
                            Text(formatDuration(trip.estimatedDuration.seconds))
                        }
                        .font(.caption)
                        .foregroundStyle(AppColors.textSecondary)
                    }
                    .allowsHitTesting(false)
                }
                .padding(.top, Spacing.xl)
                .padding(.horizontal, HomeLayout.heroHorizontalPadding)
                .padding(.bottom, proxy.safeAreaInsets.bottom + HomeLayout.contentBottomPadding)
            }
        }
        .foregroundStyle(AppColors.textPrimary)
    }

    private func formatDistance(_ meters: Double) -> String {
        if meters >= 1_000 {
            return "\((meters / 1_000).formatted(.number.precision(.fractionLength(0...1)))) km"
        }
        return "\(Int(meters.rounded())) m"
    }

    private func formatDuration(_ seconds: Double) -> String {
        let hours = seconds / 3_600
        return hours >= 24
            ? "约 \((hours / 24).formatted(.number.precision(.fractionLength(0...1)))) 天"
            : "约 \(hours.formatted(.number.precision(.fractionLength(0...1)))) 小时"
    }
}

struct HomePageBackground: View {
    var body: some View {
        LinearGradient(
            gradient: Gradient(stops: HomeStyle.gradientStops),
            startPoint: HomeStyle.gradientStartPoint,
            endPoint: HomeStyle.gradientEndPoint
        )
    }
}

private struct MountainSilhouetteView: View {
    var body: some View {
        Canvas { context, size in
            let height: CGFloat = 280
            let base = size.height
            var path = Path()
            path.move(to: CGPoint(x: 0, y: base))
            path.addLine(to: CGPoint(x: size.width * 0.16, y: base - height * 0.57))
            path.addLine(to: CGPoint(x: size.width * 0.48, y: base - height * 0.86))
            path.addLine(to: CGPoint(x: size.width, y: base - height * 0.43))
            path.addLine(to: CGPoint(x: size.width, y: base))
            path.closeSubpath()
            context.fill(path, with: .color(AppColors.surfaceDivider))
        }
    }
}

private struct WeatherHUD: View {
    let text: String

    var body: some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: "cloud.sun")
            Text(text).lineLimit(1)
        }
        .font(.system(size: 13, weight: .medium))
        .foregroundStyle(AppColors.textSecondary)
    }
}

private struct ErrorHomeView: View {
    let onRetry: () -> Void

    var body: some View {
        ZStack {
            HomePageBackground().ignoresSafeArea()
            VStack(spacing: Spacing.md) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 42, weight: .light))
                    .foregroundStyle(AppColors.statusCancelled)
                Text("当前行程加载失败").font(.system(size: 24, weight: .bold))
                HomeGlassButton(title: "重试", emphasized: true, action: onRetry)
            }
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
            .foregroundStyle(emphasized ? AppColors.pageBase : AppColors.textPrimary)
            .padding(.horizontal, Spacing.xl)
            .padding(.vertical, Spacing.md)
            .background(emphasized ? AppColors.interactionPrimary : AppColors.surfaceGlass, in: Capsule())
            .overlay { Capsule().stroke(emphasized ? AppColors.borderStrong : AppColors.borderPrimary) }
            .buttonStyle(.plain)
    }
}
