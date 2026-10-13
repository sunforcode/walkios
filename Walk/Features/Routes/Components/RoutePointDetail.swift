import SwiftUI
import WalkData
import WalkDesignSystem

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
            ZStack {
                Rectangle()
                    .fill(AppColors.surfaceModalScrim)
                    .background(AppColors.surfaceOverlay)
                    .ignoresSafeArea()
                    .contentShape(Rectangle())
                    .onTapGesture(perform: onDismiss)

                popoverCard
                    .padding(.horizontal, Spacing.pageHorizontal)
                    .padding(.bottom, 148)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
            }
            .accessibilityAddTraits(.isModal)
        }

        /// Popover 式悬浮卡：不占满宽度，悬浮于地图下方区域之上。
        private var popoverCard: some View {
            let shape = RoundedRectangle(cornerRadius: Radius.xl, style: .continuous)
            return ScrollView(.vertical, showsIndicators: false) {
                popoverContent
            }
            .frame(maxHeight: 460)
            .padding(Spacing.xl)
            .frame(maxWidth: 360, alignment: .leading)
            .background(AppColors.surfacePrimary)
            .clipShape(shape)
            .overlay {
                shape.stroke(AppColors.interactionPrimary.opacity(0.2), lineWidth: 1)
            }
            .appShadow(AppShadow.overlay)
        }

        private var popoverContent: some View {
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

        private var metadata: [String] {
            [projection.type, projection.location].compactMap(routeNonEmpty)
        }
    }
}

#if DEBUG
extension RoutePointDetailProjection {
    static let `default` = RoutePointDetailProjection(
        id: "point-camp-1",
        name: "林线营地",
        type: "营地",
        location: "路线第 18.6 km",
        description: "营地位于林线边缘的平缓台地，应避开低洼积水区域。",
        details: [
            RoutePointDetailItemProjection(id: "point-elevation", label: "海拔", value: "3,260 m"),
            RoutePointDetailItemProjection(id: "point-water", label: "水源", value: "营地下方约 180 m 有季节性溪流"),
        ]
    )
}

#Preview("RoutePointDetail.default") {
    RouteBusinessComponents.RoutePointDetail(
        projection: RoutePointDetailProjection.default,
        onDismiss: {}
    )
    .background(AppColors.pageBase)
}
#endif
