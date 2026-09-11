import SwiftUI
import WalkData
import WalkDesignSystem

struct RouteAnalysisItemProjection: Identifiable, Equatable {
    let id: String
    let mark: String
    let title: String
    let description: String
    var confidence: InformationConfidence? = nil
}

struct RouteIntroductionProjection: Equatable {
    var introduction: String?
    let analysisItems: [RouteAnalysisItemProjection]
}

extension RouteBusinessComponents {
    struct RouteIntroduction: View {
        let projection: RouteIntroductionProjection

        var body: some View {
            RouteBusinessSection(title: "路线介绍") {
                VStack(alignment: .leading, spacing: 0) {
                    if let introduction = routeNonEmpty(projection.introduction) {
                        Text(introduction)
                            .font(.appBody)
                            .foregroundStyle(AppColors.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.bottom, projection.analysisItems.isEmpty ? 0 : Spacing.md)
                    }

                    ForEach(Array(projection.analysisItems.enumerated()), id: \.element.id) { index, item in
                        HStack(alignment: .top, spacing: Spacing.md) {
                            Text(item.mark)
                                .font(.microStrong)
                                .foregroundStyle(AppColors.interactionPrimary)
                                .frame(width: 28, height: 28)
                                .background(AppColors.interactionBackground)
                                .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                                .accessibilityHidden(true)

                            VStack(alignment: .leading, spacing: Spacing.xs) {
                                Text(item.title)
                                    .font(.listTitle)
                                    .foregroundStyle(AppColors.textPrimary)
                                Text(item.description)
                                    .font(.appCaption)
                                    .foregroundStyle(AppColors.textSecondary)
                            }
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(.vertical, Spacing.md)
                        .accessibilityElement(children: .combine)

                        if index < projection.analysisItems.count - 1 {
                            Rectangle()
                                .fill(AppColors.surfaceDivider)
                                .frame(height: 1)
                        }
                    }
                }
            }
        }
    }
}

#if DEBUG
#Preview("RouteIntroduction.default") {
    BusinessComponentPreviewHost {
        RouteBusinessComponents.RouteIntroduction(
            projection: BusinessComponentPreviewFixtures.routeIntroduction
        )
    }
}

#Preview("RouteIntroduction.longContent") {
    BusinessComponentPreviewHost {
        RouteBusinessComponents.RouteIntroduction(
            projection: BusinessComponentPreviewFixtures.routeIntroductionLong
        )
    }
}
#endif
