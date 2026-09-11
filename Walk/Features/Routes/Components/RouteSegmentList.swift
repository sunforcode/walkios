import SwiftUI
import WalkData
import WalkDesignSystem

struct RouteSegmentProjection: Identifiable, Equatable {
    let id: String
    let order: Int
    let name: String
    var start: String?
    var end: String?
    var metrics: [String]
    var description: String?
}

struct RouteSegmentListProjection: Equatable {
    let segments: [RouteSegmentProjection]
    var activeSegmentID: String? = nil
    var isDisabled = false
}

extension RouteBusinessComponents {
    struct RouteSegmentList: View {
        let projection: RouteSegmentListProjection
        let onSelectSegment: (String) -> Void

        var body: some View {
            RouteBusinessSection(title: "路线分段") {
                VStack(spacing: 0) {
                    ForEach(Array(projection.segments.enumerated()), id: \.element.id) { index, segment in
                        Button {
                            onSelectSegment(segment.id)
                        } label: {
                            row(segment)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .disabled(projection.isDisabled)
                        .opacity(projection.isDisabled ? 0.45 : 1)

                        if index < projection.segments.count - 1 {
                            Rectangle()
                                .fill(AppColors.surfaceDivider)
                                .frame(height: 1)
                        }
                    }
                }
            }
        }

        private func row(_ segment: RouteSegmentProjection) -> some View {
            let isSelected = projection.activeSegmentID == segment.id
            return HStack(alignment: .top, spacing: 11) {
                RouteBookmark(title: "S\(segment.order)", isSelected: isSelected)
                    .frame(width: 31)

                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text(segment.name)
                        .font(.listTitle)
                        .foregroundStyle(AppColors.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                    if let endpointText = endpointText(for: segment) {
                        Text(endpointText)
                            .font(.appCaption)
                            .foregroundStyle(AppColors.interactionPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    if !segment.metrics.isEmpty {
                        Text(segment.metrics.joined(separator: " · "))
                            .font(.appCaption)
                            .foregroundStyle(AppColors.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    if let description = routeNonEmpty(segment.description) {
                        Text(description)
                            .font(.appCaption)
                            .foregroundStyle(AppColors.textWeak)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.vertical, Spacing.md)
            .padding(.horizontal, isSelected ? 7 : 0)
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

        private func endpointText(for segment: RouteSegmentProjection) -> String? {
            let start = routeNonEmpty(segment.start)
            let end = routeNonEmpty(segment.end)
            if let start, let end { return "\(start) → \(end)" }
            return start ?? end
        }
    }
}

#if DEBUG
#Preview("RouteSegmentList.default") {
    BusinessComponentPreviewHost {
        RouteBusinessComponents.RouteSegmentList(
            projection: BusinessComponentPreviewFixtures.routeSegments,
            onSelectSegment: { _ in }
        )
    }
}

#Preview("RouteSegmentList.single") {
    BusinessComponentPreviewHost {
        RouteBusinessComponents.RouteSegmentList(
            projection: BusinessComponentPreviewFixtures.routeSegmentSingle,
            onSelectSegment: { _ in }
        )
    }
}

#Preview("RouteSegmentList.disabled") {
    BusinessComponentPreviewHost {
        RouteBusinessComponents.RouteSegmentList(
            projection: BusinessComponentPreviewFixtures.routeSegmentsDisabled,
            onSelectSegment: { _ in }
        )
    }
}
#endif
