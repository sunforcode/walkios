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
extension RouteSegmentListProjection {
    static let `default` = RouteSegmentListProjection(
        segments: [
            RouteSegmentProjection(id: "segment-1", order: 1, name: "河谷入口至林线营地", start: "上木居", end: "林线营地", metrics: ["14.8 km", "爬升 920 m"], description: "沿河谷与森林缓慢爬升。"),
            RouteSegmentProjection(id: "segment-2", order: 2, name: "林线营地至北侧垭口", start: "林线营地", end: "北侧垭口", metrics: ["9.6 km", "约 6 小时"], description: "后半段进入碎石坡与暴露山脊。"),
        ],
        activeSegmentID: "segment-2"
    )

    static let single = RouteSegmentListProjection(
        segments: [
            RouteSegmentProjection(id: "segment-only", order: 4, name: "河谷下降段", start: "北侧垭口", end: "草科", metrics: [], description: nil),
        ]
    )

    static let disabled = RouteSegmentListProjection(
        segments: RouteSegmentListProjection.default.segments,
        activeSegmentID: nil,
        isDisabled: true
    )
}

#Preview("RouteSegmentList.default") {
    BusinessComponentPreviewHost {
        RouteBusinessComponents.RouteSegmentList(
            projection: RouteSegmentListProjection.default,
            onSelectSegment: { _ in }
        )
    }
}

#Preview("RouteSegmentList.single") {
    BusinessComponentPreviewHost {
        RouteBusinessComponents.RouteSegmentList(
            projection: RouteSegmentListProjection.single,
            onSelectSegment: { _ in }
        )
    }
}

#Preview("RouteSegmentList.disabled") {
    BusinessComponentPreviewHost {
        RouteBusinessComponents.RouteSegmentList(
            projection: RouteSegmentListProjection.disabled,
            onSelectSegment: { _ in }
        )
    }
}
#endif
