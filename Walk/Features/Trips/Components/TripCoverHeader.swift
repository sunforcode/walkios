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
    var coverAvailable: Bool = true

    var conditionTags: [String] {
        [
            "\(departureCity)出发",
            startDate == endDate ? startDate : "\(startDate)–\(endDate)",
            "\(totalDayCount) 天 · 徒步 \(hikingDayCount) 天",
        ]
    }
}

extension TripBusinessComponents {
    /// 封面身份区：行程名称 + 状态徽章 + 条件标签，悬浮于封面表面之上。
    /// 返回入口由页面壳的导航行承载（悬浮于封面之上），组件不再自建返回按钮。
    struct TripCoverHeader<Cover: View>: View {
        let projection: TripCoverHeaderProjection
        private let cover: Cover

        init(
            projection: TripCoverHeaderProjection,
            @ViewBuilder cover: () -> Cover
        ) {
            self.projection = projection
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
        projection: BusinessComponentPreviewFixtures.tripCoverDefault
    ) {
        TripDeterministicCoverSurface()
    }
    .frame(width: 390)
    .background(AppColors.pageBase)
}

#Preview("TripCoverHeader.longName") {
    TripBusinessComponents.TripCoverHeader(
        projection: BusinessComponentPreviewFixtures.tripCoverLongName
    ) {
        TripDeterministicCoverSurface()
    }
    .frame(width: 390)
    .background(AppColors.pageBase)
}
#endif
