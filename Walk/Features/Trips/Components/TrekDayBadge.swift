import SwiftUI
import WalkData
import WalkDesignSystem

/// 业务原子 TrekDayBadge（L2a）：自然日徒步日序事实徽章。
/// 视觉合同见 docs/ui/components/business/atoms/trek-day-badge/spec.md。
struct TrekDayBadgeProjection: Equatable {
    let trekDayNumber: Int?
    let totalTrekDays: Int

    var label: String? {
        guard let trekDayNumber else { return nil }
        return totalTrekDays == 1 ? "一日徒步" : "徒步第 \(trekDayNumber) 天"
    }
}

extension TripBusinessComponents {
    struct TrekDayBadge: View {
        let projection: TrekDayBadgeProjection

        var body: some View {
            if let label = projection.label {
                Text(label)
                    .font(.appCaption.weight(.semibold))
                    .foregroundStyle(AppColors.interactionPrimary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(
                        AppColors.interactionBackground,
                        in: Capsule()
                    )
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(label)
            }
        }
    }
}

#if DEBUG
#Preview("TrekDayBadge.sequence") {
    BusinessComponentPreviewHost {
        TripBusinessComponents.TrekDayBadge(
            projection: TrekDayBadgeProjection(trekDayNumber: 2, totalTrekDays: 3)
        )
        .padding(Spacing.lg)
    }
}

#Preview("TrekDayBadge.single") {
    BusinessComponentPreviewHost {
        TripBusinessComponents.TrekDayBadge(
            projection: TrekDayBadgeProjection(trekDayNumber: 1, totalTrekDays: 1)
        )
        .padding(Spacing.lg)
    }
}
#endif
