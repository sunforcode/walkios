import SwiftUI

struct RoutePointDetailItemProjection: Identifiable, Equatable {
    let id: String
    let label: String
    let value: String
}

struct RoutePointDetailProjection: Equatable {
    let id: String
    let name: String
    var type: String?
    var location: String?
    var description: String?
    var details: [RoutePointDetailItemProjection]
}

extension RouteBusinessComponents {
    struct RoutePointDetail: View {
        let projection: RoutePointDetailProjection
        let onDismiss: () -> Void

        var body: some View {
            ModalBottomSheet(onDismiss: onDismiss) {
                VStack(alignment: .leading, spacing: Spacing.md) {
                    HStack(alignment: .top, spacing: Spacing.md) {
                        Text(projection.name)
                            .font(.sectionTitle)
                            .foregroundStyle(AppColors.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        IconButton(
                            systemName: "xmark",
                            accessibilityLabel: "关闭点位详情",
                            variant: .compactClose,
                            action: onDismiss
                        )
                    }

                    if !metadata.isEmpty {
                        Text(metadata.joined(separator: " · "))
                            .font(.appCaption)
                            .foregroundStyle(AppColors.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    if let description = routeNonEmpty(projection.description) {
                        Text(description)
                            .font(.appBody)
                            .foregroundStyle(AppColors.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    if !projection.details.isEmpty {
                        VStack(spacing: 0) {
                            ForEach(Array(projection.details.enumerated()), id: \.element.id) { index, item in
                                HStack(alignment: .top, spacing: Spacing.md) {
                                    Text(item.label)
                                        .font(.label)
                                        .foregroundStyle(AppColors.textWeak)
                                        .frame(width: 64, alignment: .leading)
                                    Text(item.value)
                                        .font(.appBody)
                                        .foregroundStyle(AppColors.textPrimary)
                                        .fixedSize(horizontal: false, vertical: true)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                                .padding(.vertical, Spacing.md)

                                if index < projection.details.count - 1 {
                                    Rectangle()
                                        .fill(AppColors.surfaceDivider)
                                        .frame(height: 1)
                                }
                            }
                        }
                    }
                }
            }
        }

        private var metadata: [String] {
            [projection.type, projection.location].compactMap(routeNonEmpty)
        }
    }
}

#if DEBUG
#Preview("RoutePointDetail.default") {
    RouteBusinessComponents.RoutePointDetail(
        projection: BusinessComponentPreviewFixtures.routePointDetail,
        onDismiss: {}
    )
    .background(AppColors.pageBase)
}
#endif
