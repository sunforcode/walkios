import SwiftUI
import WalkData
import WalkDesignSystem

/// 业务组合 TripDayTransportSummary（L2c）：自然日去程或返程大交通与路线接驳摘要块。
/// 视觉合同见 docs/ui/components/business/composites/trip-day-transport-summary/spec.md。
struct TripDayTransportSummaryProjection: Equatable {
    enum Direction: Equatable {
        case outbound
        case `return`
    }

    let direction: Direction
    let title: String
    var timeRange: String?
    var duration: String?
    var path: String?
    var modes: String?
    var notice: String?

    var isUnavailable: Bool {
        path == nil && timeRange == nil && duration == nil && modes == nil
    }

    var fallbackTitle: String {
        direction == .outbound ? "大交通与路线接驳" : "返程接驳与大交通"
    }
}

extension TripBusinessComponents {
    struct TripDayTransportSummary: View {
        let projection: TripDayTransportSummaryProjection

        private var title: String {
            tripNonEmpty(projection.title) ?? projection.fallbackTitle
        }

        var body: some View {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                HStack(alignment: .firstTextBaseline, spacing: Spacing.sm) {
                    Text(title)
                        .font(.listTitle)
                        .foregroundStyle(AppColors.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                    if projection.isUnavailable {
                        Text("暂不可用")
                            .font(.appCaption)
                            .foregroundStyle(AppColors.textWeak)
                            .fixedSize(horizontal: false, vertical: true)
                    } else {
                        metaText
                    }
                }

                if projection.isUnavailable {
                    Text("不会补造班次、时间或完整衔接方案，请在出发前自行核验。")
                        .font(.appCaption)
                        .foregroundStyle(AppColors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    if let path = tripNonEmpty(projection.path) {
                        Text(path)
                            .font(.appCaption)
                            .foregroundStyle(AppColors.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    if let modes = tripNonEmpty(projection.modes) ?? tripNonEmpty(projection.notice) {
                        Text([tripNonEmpty(projection.modes), tripNonEmpty(projection.notice)]
                            .compactMap { $0 }
                            .joined(separator: " · "))
                            .font(.appCaption)
                            .foregroundStyle(AppColors.textWeak)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .padding(Spacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                AppColors.surfaceSoft,
                in: RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
            )
            .accessibilityElement(children: .combine)
        }

        @ViewBuilder
        private var metaText: some View {
            Text([
                tripNonEmpty(projection.timeRange),
                tripNonEmpty(projection.duration),
            ].compactMap { $0 }.joined(separator: " · "))
                .font(.appCaption)
                .foregroundStyle(AppColors.textWeak)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

#if DEBUG
#Preview("TripDayTransportSummary.outbound") {
    BusinessComponentPreviewHost {
        TripBusinessComponents.TripDayTransportSummary(
            projection: TripDayTransportSummaryProjection(
                direction: .outbound,
                title: "大交通与路线接驳",
                timeRange: "08:00 出发",
                duration: "3.0 小时",
                path: "成都 → 四姑娘山镇",
                modes: "公共交通",
                notice: "游客中心换乘"
            )
        )
        .padding(Spacing.lg)
    }
}

#Preview("TripDayTransportSummary.return") {
    BusinessComponentPreviewHost {
        TripBusinessComponents.TripDayTransportSummary(
            projection: TripDayTransportSummaryProjection(
                direction: .return,
                title: "返程接驳与大交通",
                timeRange: nil,
                duration: nil,
                path: "四姑娘山镇 → 成都",
                modes: nil,
                notice: nil
            )
        )
        .padding(Spacing.lg)
    }
}

#Preview("TripDayTransportSummary.unavailable") {
    BusinessComponentPreviewHost {
        TripBusinessComponents.TripDayTransportSummary(
            projection: TripDayTransportSummaryProjection(
                direction: .outbound,
                title: "大交通与路线接驳",
                timeRange: nil,
                duration: nil,
                path: nil,
                modes: nil,
                notice: nil
            )
        )
        .padding(Spacing.lg)
    }
}
#endif
