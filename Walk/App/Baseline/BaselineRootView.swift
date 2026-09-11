import SwiftUI

struct BaselineRootView: View {
    let scenario: CurrentBaselineScenario

    var body: some View {
        ZStack {
            AppColors.pageBase.ignoresSafeArea()

            if let fixture = try? BaselineFixtureProvider.tripListFixture(for: scenario) {
                TripListBaselineHost(fixture: fixture)
                    .accessibilityIdentifier(
                        BaselineReadiness.identifier(for: scenario, status: .ready)
                    )
            } else {
                BaselineUnsupportedScenarioView(scenario: scenario)
                    .accessibilityIdentifier(
                        BaselineReadiness.identifier(for: scenario, status: .unsupported)
                    )
            }
        }
        .frame(width: 390, height: 844)
        .clipped()
        .ignoresSafeArea()
        .preferredColorScheme(.dark)
        .environment(\.locale, Locale(identifier: "zh_CN"))
        .transaction { transaction in
            transaction.animation = nil
            transaction.disablesAnimations = true
        }
    }
}

private struct TripListBaselineHost: View {
    let fixture: TripListBaselineFixture

    var body: some View {
        TripListView(
            viewModel: TripListViewModel(baselineState: fixture.state)
        )
    }
}

private struct BaselineUnsupportedScenarioView: View {
    let scenario: CurrentBaselineScenario

    var body: some View {
        VStack(spacing: 12) {
            Text(scenario.pageID?.rawValue ?? "component")
                .font(.headline)
            Text("该场景尚未接入 iOS Baseline Host")
                .font(.subheadline)
            Text(scenario.rawValue)
                .font(.caption.monospaced())
        }
        .multilineTextAlignment(.center)
        .foregroundStyle(AppColors.textPrimary)
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppColors.pageBase)
    }
}
