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
        enum Presentation {
            case cover
            case identity(headline: String? = nil, eyebrow: String? = nil, subtitle: String? = nil)
        }

        let projection: TripCoverHeaderProjection
        private let presentation: Presentation
        private let cover: Cover
        @ScaledMetric(relativeTo: .largeTitle) private var titleSize = AppTypography.editorialTitleBaseSize

        init(
            projection: TripCoverHeaderProjection,
            presentation: Presentation = .cover,
            @ViewBuilder cover: () -> Cover
        ) {
            self.projection = projection
            self.presentation = presentation
            self.cover = cover()
        }

        @ViewBuilder
        var body: some View {
            switch presentation {
            case .cover:
                coverContent
            case let .identity(headline, eyebrow, subtitle):
                compactIdentity(headline: headline, eyebrow: eyebrow, subtitle: subtitle)
            }
        }

        private var coverContent: some View {
            VStack(alignment: .leading, spacing: 0) {
                Spacer(minLength: 230)
                identity
                    .padding(.horizontal, Spacing.xl)
                    .padding(.bottom, Spacing.xl)
            }
            .frame(maxWidth: .infinity, minHeight: 480, alignment: .bottomLeading)
            .background {
                GeometryReader { proxy in
                    Group {
                        if projection.coverAvailable {
                            cover
                        } else {
                            TripExpeditionCoverSurface()
                        }
                    }
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .clipped()
                    .overlay {
                        LinearGradient(
                            stops: [
                                .init(color: AppColors.pageBase.opacity(0.4), location: 0),
                                .init(color: AppColors.pageBase.opacity(0), location: 0.25),
                                .init(color: AppColors.pageBase.opacity(0), location: 0.48),
                                .init(color: AppColors.pageBase.opacity(0.78), location: 0.8),
                                .init(color: AppColors.pageBase, location: 1),
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    }
                }
                .accessibilityHidden(true)
            }
            .background(AppColors.pageBase)
            .accessibilityElement(children: .combine)
        }

        private func compactIdentity(headline: String?, eyebrow: String?, subtitle: String?) -> some View {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                if let eyebrow = tripNonEmpty(eyebrow) {
                    Text(eyebrow)
                        .font(.microStrong)
                        .tracking(1.5)
                        .foregroundStyle(AppColors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Text(tripNonEmpty(headline) ?? projection.name)
                    .font(.editorialTitle(size: titleSize))
                    .foregroundStyle(AppColors.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)

                if let subtitle = tripNonEmpty(subtitle) {
                    Text(subtitle)
                        .font(.appCaption)
                        .foregroundStyle(AppColors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(identityAccessibilitySummary(headline: headline, eyebrow: eyebrow, subtitle: subtitle))
        }

        private func identityAccessibilitySummary(headline: String?, eyebrow: String?, subtitle: String?) -> String {
            let context = [tripNonEmpty(eyebrow), tripNonEmpty(headline), tripNonEmpty(subtitle)]
                .compactMap { $0 }
                .filter { $0 != projection.name && !projection.conditionTags.contains($0) }
            return ([projection.name, "行程状态：\(projection.status.badgeTitle)"] + projection.conditionTags + context)
                .joined(separator: "，")
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
                .font(.editorialTitle(size: titleSize))
                .foregroundStyle(AppColors.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

// 随包固定的 AIGC 山野氛围图，不代表冻结路线的真实摄影或地理依据。
struct TripExpeditionCoverSurface: View {
    var body: some View {
        GeometryReader { proxy in
            Image("TripExpeditionCover")
                .resizable()
                .scaledToFill()
                .frame(width: proxy.size.width, height: proxy.size.height)
                .clipped()
        }
        .accessibilityHidden(true)
    }
}

#if DEBUG
extension TripCoverHeaderProjection {
    static let `default` = TripCoverHeaderProjection(
        name: "贡嘎西南坡四日行程",
        status: .planned,
        departureCity: "成都",
        startDate: "2026-09-07",
        endDate: "2026-09-10",
        totalDayCount: 4,
        hikingDayCount: 3
    )

    static let longName = TripCoverHeaderProjection(
        name: "穿越高山草甸、原始森林与连续垭口的长距离个人徒步行程",
        status: .inProgress,
        departureCity: "四川省成都市",
        startDate: "2026-09-07",
        endDate: "2026-09-12",
        totalDayCount: 6,
        hikingDayCount: 5,
        coverAvailable: false
    )
}

#Preview("TripCoverHeader.default") {
    TripBusinessComponents.TripCoverHeader(
        projection: TripCoverHeaderProjection.default
    ) {
        TripExpeditionCoverSurface()
    }
    .frame(width: 390)
    .background(AppColors.pageBase)
}

#Preview("TripCoverHeader.longName") {
    TripBusinessComponents.TripCoverHeader(
        projection: TripCoverHeaderProjection.longName
    ) {
        TripExpeditionCoverSurface()
    }
    .frame(width: 390)
    .background(AppColors.pageBase)
}

#Preview("TripCoverHeader.identity") {
    BusinessComponentPreviewHost {
        TripBusinessComponents.TripCoverHeader(
            projection: TripCoverHeaderProjection.default,
            presentation: .identity(
                headline: "贡嘎环线",
                eyebrow: "全程总览",
                subtitle: "9月7日 — 9月10日"
            )
        ) {
            EmptyView()
        }
    }
}

#Preview("TripCoverHeader.identityWithoutSubtitle") {
    BusinessComponentPreviewHost {
        TripBusinessComponents.TripCoverHeader(
            projection: TripCoverHeaderProjection.default,
            presentation: .identity(headline: "山脊穿行", eyebrow: "DAY 02")
        ) {
            EmptyView()
        }
    }
}

#Preview("TripCoverHeader.identityOverviewDate") {
    BusinessComponentPreviewHost {
        TripBusinessComponents.TripCoverHeader(
            projection: TripCoverHeaderProjection.default,
            presentation: .identity(headline: "贡嘎环线", eyebrow: "8月25–8月27日")
        ) {
            EmptyView()
        }
    }
}

#Preview("TripCoverHeader.identityDayEndpoints") {
    BusinessComponentPreviewHost {
        TripBusinessComponents.TripCoverHeader(
            projection: TripCoverHeaderProjection.default,
            presentation: .identity(headline: "河谷入山", eyebrow: "老榆林 → 下日乌且营地")
        ) {
            EmptyView()
        }
    }
}
#endif
