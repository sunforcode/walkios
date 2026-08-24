import SwiftUI
import CoreLocation

/// 行程详情页；导航容器由调用方提供。
struct TripDetailView: View {
    let tripId: String
    @StateObject private var viewModel: TripDetailViewModel

    init(tripId: String, repository: any TripRepository, routeService: RouteService) {
        self.tripId = tripId
        _viewModel = StateObject(wrappedValue: TripDetailViewModel(
            repository: repository,
            loadRoute: { try await routeService.getRouteDetail(id: $0) }
        ))
    }

    var body: some View {
        UtilityPageContainer {
            Group {
                if viewModel.isLoading {
                    LoadingView()
                } else if let error = viewModel.errorMessage {
                    ErrorView(message: error) {
                        Task { await viewModel.loadTrip(id: tripId) }
                    }
                } else if let trip = viewModel.trip {
                    tripDetailContent(trip: trip)
                }
            }
        }
        .navigationTitle(viewModel.trip?.displayName ?? "行程详情")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.loadTrip(id: tripId)
        }
    }

    private func tripDetailContent(trip: Trip) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.sectionGap) {
                detailHeader

                sectionPanel(title: "概览") {
                    HStack {
                        TripStatusBadge(status: trip.status)
                        Spacer()
                        Label(trip.dateRangeDescription, systemImage: "calendar")
                            .font(.caption)
                            .foregroundStyle(AppColors.textSecondary)
                    }

                    Label(trip.durationDescription, systemImage: "clock")
                        .font(.caption)
                        .foregroundStyle(AppColors.textWeak)

                    Text(trip.description?.isEmpty == false ? trip.description! : "暂无行程描述")
                        .font(.body)
                        .foregroundStyle(AppColors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                sectionPanel(title: "关联路线") {
                    if let routeName = viewModel.associatedRouteName {
                        Label(routeName, systemImage: "point.topleft.down.curvedto.point.bottomright.up")
                            .font(.body)
                            .foregroundStyle(AppColors.textPrimary)
                    } else {
                        Text(trip.routeId == nil ? "未关联路线" : "关联路线暂不可用")
                            .font(.body)
                            .foregroundStyle(AppColors.textWeak)
                    }
                }

                sectionPanel(title: "行程准备") {
                    placeholderRow(icon: "backpack", title: "装备清单")
                    placeholderRow(icon: "cloud.sun", title: "天气与提醒")
                }

                sectionPanel(title: "行程记录") {
                    placeholderRow(icon: "photo.on.rectangle", title: "照片与笔记")
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, Spacing.md)
        }
        .background(AppColors.bgBase)
        .refreshable {
            await viewModel.loadTrip(id: tripId)
        }
    }

    @ViewBuilder
    private var detailHeader: some View {
        if viewModel.mapCoordinates.isEmpty {
            TripAtmosphericCover()
                .frame(height: TripLayout.detailCoverHeight)
                .clipShape(RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                        .stroke(AppColors.border, lineWidth: 1)
                }
        } else {
            RouteMapView(
                coordinates: viewModel.mapCoordinates,
                cameraPitch: 45
            )
            .frame(height: TripLayout.detailMapHeight)
            .clipShape(RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
        }
    }

    private func sectionPanel<Content: View>(
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        WalkPanel {
            VStack(alignment: .leading, spacing: Spacing.md) {
                Text(title)
                    .font(.sectionTitle)
                    .foregroundStyle(AppColors.textPrimary)
                content()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func placeholderRow(icon: String, title: String) -> some View {
        HStack(spacing: Spacing.md) {
            Image(systemName: icon)
                .foregroundStyle(AppColors.textWeak)
                .frame(width: 24)
            Text(title)
                .foregroundStyle(AppColors.textSecondary)
            Spacer()
            Text("即将开放")
                .font(.caption)
                .foregroundStyle(AppColors.textWeak)
        }
        .font(.body)
    }
}

#if DEBUG
#Preview {
    NavigationStack {
        TripDetailView(
            tripId: "preview",
            repository: PreviewTripRepository(),
            routeService: PreviewHelpers.routeService
        )
    }
}
#endif
