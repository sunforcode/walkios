import SwiftUI
import WalkData
import WalkDesignSystem

struct TripListRowProjection: Equatable {
    let tripID: String
    let name: String
    let status: PersonalTripStatus
    let routeName: String
    let startDate: String
    let endDate: String

    /// 日期区间按 spec shortDate 口径展示（「M月D日」，区间用「—」连接）。
    var dateRange: String {
        DateCopy.dateRange(start: startDate, end: endDate)
    }

    var detailLine: String {
        "\(routeName) · \(dateRange)"
    }
}

extension TripBusinessComponents {
    struct TripListRow: View {
        let projection: TripListRowProjection
        let onActivate: (String) -> Void

        init(
            projection: TripListRowProjection,
            onActivate: @escaping (String) -> Void
        ) {
            self.projection = projection
            self.onActivate = onActivate
        }

        var body: some View {
            Button {
                onActivate(projection.tripID)
            } label: {
                ViewThatFits(in: .horizontal) {
                    regularLayout
                    compactLayout
                }
                .padding(.vertical, Spacing.md)
                .frame(maxWidth: .infinity, minHeight: 84, alignment: .leading)
                .overlay(alignment: .bottom) {
                    Rectangle()
                        .fill(AppColors.surfaceDivider)
                        .frame(height: 1)
                        .accessibilityHidden(true)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .combine)
            .accessibilityLabel(accessibilityLabel)
            .accessibilityHint("打开行程")
        }

        private var regularLayout: some View {
            HStack(spacing: Spacing.md) {
                routeMark
                copy
                TripStatusBadge(status: projection.status)
            }
        }

        private var compactLayout: some View {
            HStack(alignment: .top, spacing: Spacing.md) {
                routeMark
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    copy
                    TripStatusBadge(status: projection.status)
                }
            }
        }

        /// RouteMark（mark 变体）：42 × 42，route 图标，薄荷软底，13px 原型圆角映射 Radius.md（12）。
        private var routeMark: some View {
            RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                .fill(AppColors.interactionBackground)
                .frame(width: 42, height: 42)
                .overlay {
                    Image(systemName: "point.topleft.down.curvedto.point.bottomright.up")
                        .font(.ornament(17, weight: .medium))
                        .foregroundStyle(AppColors.interactionPrimary)
                }
                .accessibilityHidden(true)
        }

        private var copy: some View {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(projection.name)
                    .font(.listTitle)
                    .foregroundStyle(AppColors.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                Text(projection.detailLine)
                    .font(.appCaption)
                    .foregroundStyle(AppColors.textSecondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            .frame(maxWidth: .infinity, minHeight: 42, alignment: .leading)
        }

        private var accessibilityLabel: String {
            "\(projection.name)，\(projection.detailLine)，\(projection.status.title)"
        }
    }
}

#if DEBUG
extension TripListRowProjection {
    static let `default` = TripListRowProjection(
        tripID: "trip-001",
        name: "贡嘎西南坡四日行程",
        status: .planned,
        routeName: "贡嘎西南坡环线",
        startDate: "2026-09-07",
        endDate: "2026-09-10"
    )

    static let inProgress = TripListRowProjection(
        tripID: "trip-002",
        name: "海坨山谷穿越",
        status: .inProgress,
        routeName: "海坨山谷穿越线",
        startDate: "2026-09-08",
        endDate: "2026-09-09"
    )

    static let completed = TripListRowProjection(
        tripID: "trip-003",
        name: "白河峡谷周末行程",
        status: .completed,
        routeName: "白河峡谷",
        startDate: "2026-08-22",
        endDate: "2026-08-23"
    )

    static let cancelled = TripListRowProjection(
        tripID: "trip-004",
        name: "河谷森林线行程",
        status: .cancelled,
        routeName: "河谷森林线",
        startDate: "2026-07-18",
        endDate: "2026-07-19"
    )

    static let longContent = TripListRowProjection(
        tripID: "trip-006",
        name: "穿越高山草甸、原始森林与连续垭口的长距离个人徒步行程",
        status: .planned,
        routeName: "四川省甘孜藏族自治州高海拔连续垭口环形路线",
        startDate: "2026-09-07",
        endDate: "2026-09-12"
    )
}

#Preview("TripListRow.default") {
    BusinessComponentPreviewHost {
        TripBusinessComponents.TripListRow(
            projection: TripListRowProjection.default,
            onActivate: { _ in }
        )
    }
}

#Preview("TripListRow.inProgress") {
    BusinessComponentPreviewHost {
        TripBusinessComponents.TripListRow(
            projection: TripListRowProjection.inProgress,
            onActivate: { _ in }
        )
    }
}

#Preview("TripListRow.completed") {
    BusinessComponentPreviewHost {
        TripBusinessComponents.TripListRow(
            projection: TripListRowProjection.completed,
            onActivate: { _ in }
        )
    }
}

#Preview("TripListRow.cancelled") {
    BusinessComponentPreviewHost {
        TripBusinessComponents.TripListRow(
            projection: TripListRowProjection.cancelled,
            onActivate: { _ in }
        )
    }
}

#Preview("TripListRow.longContent") {
    BusinessComponentPreviewHost {
        TripBusinessComponents.TripListRow(
            projection: TripListRowProjection.longContent,
            onActivate: { _ in }
        )
    }
}
#endif
