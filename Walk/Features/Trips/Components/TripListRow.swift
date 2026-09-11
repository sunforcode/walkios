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
    var coverAvailable: Bool = true

    var dateRange: String {
        startDate == endDate ? startDate : "\(startDate)–\(endDate)"
    }
}

extension TripBusinessComponents {
    struct TripListRow<Cover: View>: View {
        let projection: TripListRowProjection
        let onActivate: (String) -> Void
        private let cover: Cover

        init(
            projection: TripListRowProjection,
            onActivate: @escaping (String) -> Void,
            @ViewBuilder cover: () -> Cover
        ) {
            self.projection = projection
            self.onActivate = onActivate
            self.cover = cover()
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
                artwork
                copy
                TripStatusBadge(status: projection.status)
            }
        }

        private var compactLayout: some View {
            HStack(alignment: .top, spacing: Spacing.md) {
                artwork
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    copy
                    TripStatusBadge(status: projection.status)
                }
            }
        }

        private var artwork: some View {
            Group {
                if projection.coverAvailable {
                    cover
                } else {
                    AppColors.surfaceElevated
                }
            }
            .frame(width: 52, height: 52)
            .clipped()
            .clipShape(RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
            .accessibilityHidden(true)
        }

        private var copy: some View {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(projection.name)
                    .font(.listTitle)
                    .foregroundStyle(AppColors.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                Text(projection.routeName)
                    .font(.appCaption)
                    .foregroundStyle(AppColors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                Text(projection.dateRange)
                    .font(.appCaption)
                    .foregroundStyle(AppColors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, minHeight: 52, alignment: .leading)
        }

        private var accessibilityLabel: String {
            "\(projection.name)，\(projection.routeName)，\(projection.dateRange)，\(projection.status.title)"
        }
    }
}

#if DEBUG
#Preview("TripListRow.default") {
    BusinessComponentPreviewHost {
        TripBusinessComponents.TripListRow(
            projection: BusinessComponentPreviewFixtures.tripRowDefault,
            onActivate: { _ in }
        ) {
            TripDeterministicCoverSurface()
        }
    }
}

#Preview("TripListRow.inProgress") {
    BusinessComponentPreviewHost {
        TripBusinessComponents.TripListRow(
            projection: BusinessComponentPreviewFixtures.tripRowInProgress,
            onActivate: { _ in }
        ) {
            TripDeterministicCoverSurface()
        }
    }
}

#Preview("TripListRow.completed") {
    BusinessComponentPreviewHost {
        TripBusinessComponents.TripListRow(
            projection: BusinessComponentPreviewFixtures.tripRowCompleted,
            onActivate: { _ in }
        ) {
            TripDeterministicCoverSurface()
        }
    }
}

#Preview("TripListRow.cancelled") {
    BusinessComponentPreviewHost {
        TripBusinessComponents.TripListRow(
            projection: BusinessComponentPreviewFixtures.tripRowCancelled,
            onActivate: { _ in }
        ) {
            TripDeterministicCoverSurface()
        }
    }
}

#Preview("TripListRow.coverMissing") {
    BusinessComponentPreviewHost {
        TripBusinessComponents.TripListRow(
            projection: BusinessComponentPreviewFixtures.tripRowCoverMissing,
            onActivate: { _ in }
        ) {
            TripDeterministicCoverSurface()
        }
    }
}

#Preview("TripListRow.longContent") {
    BusinessComponentPreviewHost {
        TripBusinessComponents.TripListRow(
            projection: BusinessComponentPreviewFixtures.tripRowLongContent,
            onActivate: { _ in }
        ) {
            TripDeterministicCoverSurface()
        }
    }
}
#endif
