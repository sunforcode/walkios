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
extension RouteIntroductionProjection {
    static let `default` = RouteIntroductionProjection(
        introduction: "路线连接高山草甸、冰川遗迹与河谷森林，适合具备连续多日徒步经验的队伍。",
        analysisItems: [
            RouteAnalysisItemProjection(id: "analysis-fitness", mark: "体", title: "体能要求", description: "连续上升路段较长，需要稳定的负重行走能力。"),
            RouteAnalysisItemProjection(id: "analysis-terrain", mark: "地", title: "主要地形", description: "以山地土路、碎石坡和草甸横切为主。"),
        ]
    )

    static let long = RouteIntroductionProjection(
        introduction: "这条路线穿过连续变化的高山环境，从河谷森林逐步进入高山草甸，再跨越开阔垭口。沿途天气变化快，完整行程需要为长距离爬升、湿滑路面与低温环境留出充分余量。",
        analysisItems: [
            RouteAnalysisItemProjection(id: "analysis-experience", mark: "经", title: "经验要求", description: "需要具备在能见度下降时识别主路径、管理队伍节奏并根据实际天气及时折返的经验。"),
            RouteAnalysisItemProjection(id: "analysis-altitude", mark: "高", title: "高海拔影响", description: "多个连续路段位于高海拔区域，队伍应按实际成员情况安排适应时间，不由路线介绍替代个人风险判断。"),
            RouteAnalysisItemProjection(id: "analysis-exposure", mark: "露", title: "暴露路段", description: "垭口两侧缺少稳定遮蔽物，雷雨、大风或结冰条件下通过难度明显增加。"),
        ]
    )
}

#Preview("RouteIntroduction.default") {
    BusinessComponentPreviewHost {
        RouteBusinessComponents.RouteIntroduction(
            projection: RouteIntroductionProjection.default
        )
    }
}

#Preview("RouteIntroduction.longContent") {
    BusinessComponentPreviewHost {
        RouteBusinessComponents.RouteIntroduction(
            projection: RouteIntroductionProjection.long
        )
    }
}
#endif
