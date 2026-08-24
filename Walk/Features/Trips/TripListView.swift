import SwiftUI

/// 行程列表页
struct TripListView: View {
    @StateObject private var viewModel: TripListViewModel
    private let repository: any TripRepository
    private let routeService: RouteService

    init(repository: any TripRepository, routeService: RouteService) {
        self.repository = repository
        self.routeService = routeService
        _viewModel = StateObject(wrappedValue: TripListViewModel(repository: repository))
    }

    var body: some View {
        UtilityPageContainer {
            Group {
                if viewModel.isLoading {
                    LoadingView()
                } else if let error = viewModel.errorMessage {
                    ErrorView(message: error) {
                        Task { await viewModel.retry() }
                    }
                } else if viewModel.trips.isEmpty {
                    EmptyStateView(
                        title: "暂无行程",
                        message: "开始规划你的下一次户外探险吧",
                        icon: "map",
                        actionTitle: "创建行程"
                    ) {
                        // TODO: 跳转到创建行程页
                    }
                } else {
                    tripListContent
                }
            }
        }
        .navigationTitle("我的行程")
        .task {
            await viewModel.loadTrips()
        }
    }

    private var tripListContent: some View {
        ScrollView {
            LazyVStack(spacing: Spacing.listItemGap) {
                ForEach(viewModel.trips) { trip in
                    NavigationLink(
                        destination: TripDetailView(
                            tripId: trip.id,
                            repository: repository,
                            routeService: routeService
                        )
                    ) {
                        TripRowView(trip: trip)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, Spacing.md)
        }
        .background(AppColors.bgBase)
        .refreshable {
            await viewModel.refresh()
        }
    }
}
