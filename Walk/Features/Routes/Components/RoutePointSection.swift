import SwiftUI
import WalkData
import WalkDesignSystem

struct RoutePointRowProjection: Identifiable, Equatable {
    let id: String
    let bookmark: String
    let name: String
    var elevation: String?
    var type: String?
    var location: String?
    var description: String?
}

struct RoutePointSectionProjection: Equatable {
    let title: String
    let points: [RoutePointRowProjection]
    var activePointID: String? = nil
    var isDisabled = false
}

extension RouteBusinessComponents {
    struct RoutePointSection: View {
        let projection: RoutePointSectionProjection
        let onFocusPoint: (String) -> Void

        var body: some View {
            RouteBusinessSection(title: projection.title) {
                VStack(spacing: 0) {
                    ForEach(Array(projection.points.enumerated()), id: \.element.id) { index, point in
                        Button {
                            onFocusPoint(point.id)
                        } label: {
                            row(point)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .disabled(projection.isDisabled)
                        .opacity(projection.isDisabled ? 0.45 : 1)

                        if index < projection.points.count - 1 {
                            Rectangle()
                                .fill(AppColors.surfaceDivider)
                                .frame(height: 1)
                        }
                    }
                }
            }
        }

        private func row(_ point: RoutePointRowProjection) -> some View {
            let isSelected = projection.activePointID == point.id
            return HStack(alignment: .top, spacing: 11) {
                RouteBookmark(title: point.bookmark, isSelected: isSelected)
                    .frame(width: 31)

                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text([point.name, routeNonEmpty(point.elevation)].compactMap { $0 }.joined(separator: " · "))
                        .font(.listTitle)
                        .foregroundStyle(AppColors.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)

                    let metadata = [point.type, point.location].compactMap(routeNonEmpty)
                    if !metadata.isEmpty {
                        Text(metadata.joined(separator: " · "))
                            .font(.appCaption)
                            .foregroundStyle(AppColors.interactionPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    if let description = routeNonEmpty(point.description) {
                        Text(description)
                            .font(.appCaption)
                            .foregroundStyle(AppColors.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.vertical, Spacing.md)
            .padding(.horizontal, isSelected ? 7 : 0)
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            .background(
                isSelected ? AppColors.interactionBackground : AppColors.surfacePrimary.opacity(0),
                in: RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
            )
            .overlay(alignment: .leading) {
                if isSelected {
                    RoundedRectangle(cornerRadius: Radius.full)
                        .fill(AppColors.interactionPrimary)
                        .frame(width: 3)
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(isSelected ? .isSelected : [])
        }
    }
}

#if DEBUG
extension RoutePointSectionProjection {
    static let keyPoints = RoutePointSectionProjection(
        title: "关键点",
        points: [
            RoutePointRowProjection(id: "point-key-1", bookmark: "关", name: "北侧垭口", elevation: "3,860 m", type: "关键点", location: "路线第 12.4 km", description: "通过后进入暴露山脊。"),
            RoutePointRowProjection(id: "point-camp-1", bookmark: "营", name: "林线营地", elevation: "3,260 m", type: "营地", location: "路线第 18.6 km", description: "平缓台地，靠近季节性水源。"),
        ],
        activePointID: "point-camp-1"
    )

    static let water = RoutePointSectionProjection(
        title: "水源",
        points: [
            RoutePointRowProjection(id: "point-water-1", bookmark: "水", name: "石壁溪流", elevation: "2,940 m", type: "季节性水源", location: "路线第 21.3 km", description: "枯水季可能断流。"),
        ]
    )

    static let disabled = RoutePointSectionProjection(
        title: "补给点",
        points: [
            RoutePointRowProjection(id: "point-supply-1", bookmark: "补", name: "河谷补给站", elevation: nil, type: "补给", location: "路线终点", description: nil),
        ],
        activePointID: nil,
        isDisabled: true
    )
}

#Preview("RoutePointSection.default") {
    BusinessComponentPreviewHost {
        RouteBusinessComponents.RoutePointSection(
            projection: RoutePointSectionProjection.keyPoints,
            onFocusPoint: { _ in }
        )
    }
}

#Preview("RoutePointSection.water") {
    BusinessComponentPreviewHost {
        RouteBusinessComponents.RoutePointSection(
            projection: RoutePointSectionProjection.water,
            onFocusPoint: { _ in }
        )
    }
}

#Preview("RoutePointSection.disabled") {
    BusinessComponentPreviewHost {
        RouteBusinessComponents.RoutePointSection(
            projection: RoutePointSectionProjection.disabled,
            onFocusPoint: { _ in }
        )
    }
}
#endif
