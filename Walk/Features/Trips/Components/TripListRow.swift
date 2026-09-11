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
                        .font(.system(size: 17, weight: .medium))
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
#Preview("TripListRow.default") {
    BusinessComponentPreviewHost {
        TripBusinessComponents.TripListRow(
            projection: BusinessComponentPreviewFixtures.tripRowDefault,
            onActivate: { _ in }
        )
    }
}

#Preview("TripListRow.inProgress") {
    BusinessComponentPreviewHost {
        TripBusinessComponents.TripListRow(
            projection: BusinessComponentPreviewFixtures.tripRowInProgress,
            onActivate: { _ in }
        )
    }
}

#Preview("TripListRow.completed") {
    BusinessComponentPreviewHost {
        TripBusinessComponents.TripListRow(
            projection: BusinessComponentPreviewFixtures.tripRowCompleted,
            onActivate: { _ in }
        )
    }
}

#Preview("TripListRow.cancelled") {
    BusinessComponentPreviewHost {
        TripBusinessComponents.TripListRow(
            projection: BusinessComponentPreviewFixtures.tripRowCancelled,
            onActivate: { _ in }
        )
    }
}

#Preview("TripListRow.longContent") {
    BusinessComponentPreviewHost {
        TripBusinessComponents.TripListRow(
            projection: BusinessComponentPreviewFixtures.tripRowLongContent,
            onActivate: { _ in }
        )
    }
}
#endif
