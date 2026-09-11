import SwiftUI

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
#Preview("RoutePointSection.default") {
    BusinessComponentPreviewHost {
        RouteBusinessComponents.RoutePointSection(
            projection: BusinessComponentPreviewFixtures.routePointSection,
            onFocusPoint: { _ in }
        )
    }
}

#Preview("RoutePointSection.water") {
    BusinessComponentPreviewHost {
        RouteBusinessComponents.RoutePointSection(
            projection: BusinessComponentPreviewFixtures.routeWaterSection,
            onFocusPoint: { _ in }
        )
    }
}

#Preview("RoutePointSection.disabled") {
    BusinessComponentPreviewHost {
        RouteBusinessComponents.RoutePointSection(
            projection: BusinessComponentPreviewFixtures.routePointSectionDisabled,
            onFocusPoint: { _ in }
        )
    }
}
#endif
