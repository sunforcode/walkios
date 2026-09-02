import SwiftUI

struct TripListView: View {
    @StateObject private var viewModel: TripListViewModel
    private let onNavigate: (AppDestination) -> Void
    private let onFindRoute: () -> Void

    init(
        service: any PersonalTripServicing,
        onNavigate: @escaping (AppDestination) -> Void = { _ in },
        onFindRoute: @escaping () -> Void = {}
    ) {
        self.onNavigate = onNavigate
        self.onFindRoute = onFindRoute
        _viewModel = StateObject(wrappedValue: TripListViewModel(service: service))
    }

    init(
        viewModel: TripListViewModel,
        onNavigate: @escaping (AppDestination) -> Void = { _ in },
        onFindRoute: @escaping () -> Void = {}
    ) {
        self.onNavigate = onNavigate
        self.onFindRoute = onFindRoute
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        UtilityPageContainer {
            Group {
                if viewModel.isLoading {
                    LoadingView()
                } else if let error = viewModel.errorMessage {
                    ErrorView(message: error) { Task { await viewModel.retry() } }
                } else if viewModel.isEmpty {
                    EmptyStateView(
                        title: "还没有行程",
                        message: "从路线详情生成第一趟个人行程。",
                        icon: "map",
                        actionTitle: "查找路线",
                        action: onFindRoute
                    )
                } else {
                    tripListContent
                }
            }
        }
        .navigationTitle("我的全部行程")
        .task { await viewModel.loadTrips() }
    }

    private var tripListContent: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: Spacing.sectionGap) {
                if !viewModel.currentTrips.isEmpty {
                    tripSection(title: "当前行程", trips: viewModel.currentTrips)
                }
                if !viewModel.historicalTrips.isEmpty {
                    tripSection(title: "历史行程", trips: viewModel.historicalTrips)
                }
            }
            .padding(.horizontal, Spacing.pageHorizontal)
            .padding(.vertical, Spacing.md)
        }
        .background(AppColors.pageBase)
        .refreshable { await viewModel.refresh() }
    }

    private func tripSection(
        title: String,
        trips: [PersonalTripSummary]
    ) -> some View {
        VStack(alignment: .leading, spacing: Spacing.listItemGap) {
            Text(title)
                .font(.sectionTitle)
                .foregroundStyle(AppColors.textPrimary)

            ForEach(trips) { trip in
                Button {
                    onNavigate(.tripDetail(trip.tripID))
                } label: {
                    TripRowView(trip: trip)
                }
                .buttonStyle(.plain)
            }
        }
    }
}
