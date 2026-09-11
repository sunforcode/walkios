import SwiftUI
import WalkData
import WalkDesignSystem

struct TripCoverHeaderProjection: Equatable {
    let name: String
    let status: PersonalTripStatus
    let departureCity: String
    let startDate: String
    let endDate: String
    let totalDayCount: Int
    let hikingDayCount: Int
    let versionLabel: String?
    var coverAvailable: Bool = true

    var conditionTags: [String] {
        var tags = [
            "\(departureCity)出发",
            startDate == endDate ? startDate : "\(startDate)–\(endDate)",
            "\(totalDayCount) 天 · 徒步 \(hikingDayCount) 天",
        ]
        if let versionLabel = tripNonEmpty(versionLabel) {
            tags.append("生成依据 · \(versionLabel)")
        }
        return tags
    }
}

extension TripBusinessComponents {
    struct TripCoverHeader<Cover: View>: View {
        let projection: TripCoverHeaderProjection
        let onNavigateBack: () -> Void
        private let cover: Cover

        init(
            projection: TripCoverHeaderProjection,
            onNavigateBack: @escaping () -> Void,
            @ViewBuilder cover: () -> Cover
        ) {
            self.projection = projection
            self.onNavigateBack = onNavigateBack
            self.cover = cover()
        }

        var body: some View {
            ZStack(alignment: .bottomLeading) {
                Group {
                    if projection.coverAvailable {
                        cover
                    } else {
                        TripDeterministicCoverSurface()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()
                .accessibilityHidden(true)

                LinearGradient(
                    colors: [
                        AppColors.pageBase.opacity(0),
                        AppColors.pageBase.opacity(0.12),
                        AppColors.pageBase,
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .allowsHitTesting(false)
                .accessibilityHidden(true)

                identity
                    .padding(.horizontal, Spacing.lg)
                    .padding(.bottom, Spacing.lg)
            }
            .overlay(alignment: .topLeading) {
                IconButton(
                    systemName: "chevron.left",
                    accessibilityLabel: "返回上一页",
                    variant: .overlay,
                    action: onNavigateBack
                )
                .padding(.top, 54)
                .padding(.leading, Spacing.lg)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 275)
            .clipShape(
                UnevenRoundedRectangle(
                    bottomLeadingRadius: Radius.xl,
                    bottomTrailingRadius: Radius.xl,
                    style: .continuous
                )
            )
        }

        private var identity: some View {
            VStack(alignment: .leading, spacing: Spacing.md) {
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .top, spacing: Spacing.md) {
                        title
                        TripStatusBadge(status: projection.status)
                    }

                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        title
                        TripStatusBadge(status: projection.status)
                    }
                }

                TripWrapLayout {
                    ForEach(projection.conditionTags, id: \.self) { tag in
                        InfoTag(title: tag, tone: .overlay)
                    }
                }
            }
            .accessibilityElement(children: .combine)
        }

        private var title: some View {
            Text(projection.name)
                .font(.pageTitle)
                .foregroundStyle(AppColors.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

#if DEBUG
#Preview("TripCoverHeader.default") {
    TripBusinessComponents.TripCoverHeader(
        projection: BusinessComponentPreviewFixtures.tripCoverDefault,
        onNavigateBack: {}
    ) {
        TripDeterministicCoverSurface()
    }
    .frame(width: 390)
    .background(AppColors.pageBase)
}

#Preview("TripCoverHeader.longName") {
    TripBusinessComponents.TripCoverHeader(
        projection: BusinessComponentPreviewFixtures.tripCoverLongName,
        onNavigateBack: {}
    ) {
        TripDeterministicCoverSurface()
    }
    .frame(width: 390)
    .background(AppColors.pageBase)
}
#endif
