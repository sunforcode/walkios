import SwiftUI
import WalkData
import WalkDesignSystem

struct TripListView: View {
    @State private var viewModel: TripListViewModel
    private let onNavigate: (AppDestination) -> Void
    private let onFindRoute: () -> Void

    init(
        service: any PersonalTripServicing,
        onNavigate: @escaping (AppDestination) -> Void = { _ in },
        onFindRoute: @escaping () -> Void = {}
    ) {
        self.onNavigate = onNavigate
        self.onFindRoute = onFindRoute
        _viewModel = State(initialValue: TripListViewModel(service: service))
    }

    init(
        viewModel: TripListViewModel,
        onNavigate: @escaping (AppDestination) -> Void = { _ in },
        onFindRoute: @escaping () -> Void = {}
    ) {
        self.onNavigate = onNavigate
        self.onFindRoute = onFindRoute
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        UtilityPage(title: "我的全部行程") {
            VStack(alignment: .leading, spacing: Spacing.xl) {
                stateContent
            }
            .frame(maxWidth: 600, alignment: .topLeading)
            .frame(maxWidth: .infinity, alignment: .top)
        }
        .task {
            guard viewModel.automaticallyLoads else { return }
            await viewModel.loadTrips()
        }
    }

    @ViewBuilder
    private var stateContent: some View {
        if viewModel.isLoading {
            loadingRows
        } else if viewModel.errorMessage != nil {
            ErrorView(
                message: "不会使用缓存或离线行程补齐。",
                title: "无法加载行程列表",
                variant: .page,
                retry: { Task { await viewModel.retry() } }
            )
            .frame(maxWidth: .infinity, minHeight: 420, alignment: .center)
        } else if viewModel.isEmpty {
            EmptyStateView(
                title: "还没有行程",
                message: "先查找一条路线并生成个人行程。",
                icon: "calendar",
                actionTitle: "查找路线",
                action: onFindRoute,
                variant: .default
            )
            .frame(maxWidth: .infinity, minHeight: 420, alignment: .center)
        } else {
            tripSection(
                title: "当前行程",
                subtitle: "进行中优先",
                trips: viewModel.currentTrips,
                emptyText: "暂无当前行程"
            )
            tripSection(
                title: "历史行程",
                subtitle: "按出发日期排序",
                trips: viewModel.historicalTrips,
                emptyText: "暂无历史行程"
            )
        }
    }

    private var loadingRows: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            ForEach(0..<4, id: \.self) { _ in
                LoadingView(message: "行程加载中", variant: .rowSkeleton)
            }
        }
    }

    private func tripSection(
        title: String,
        subtitle: String,
        trips: [PersonalTripSummary],
        emptyText: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline, spacing: Spacing.md) {
                Text(title)
                    .font(.sectionTitle)
                    .foregroundStyle(AppColors.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text(subtitle)
                    .font(.label)
                    .foregroundStyle(AppColors.interactionPrimary)
            }
            .padding(.horizontal, Spacing.md)
            .padding(.bottom, Spacing.sm)

            if trips.isEmpty {
                Text(emptyText)
                    .font(.appCaption)
                    .foregroundStyle(AppColors.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, Spacing.sm)
            } else {
                ForEach(trips) { trip in
                    TripBusinessComponents.TripListRow(
                        projection: TripListRowProjection(
                            tripID: trip.tripID,
                            name: trip.name,
                            status: trip.status,
                            routeName: trip.routeName,
                            startDate: trip.startDate.description,
                            endDate: trip.endDate.description
                        ),
                        onActivate: { tripID in
                            onNavigate(.tripDetail(tripID))
                        }
                    )
                }
            }
        }
    }
}
