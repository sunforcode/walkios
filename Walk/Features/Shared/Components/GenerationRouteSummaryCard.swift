import SwiftUI
import WalkData
import WalkDesignSystem

enum GenerationEligibilityProjection: Equatable {
    case eligible(label: String)
    case ineligible(label: String)

    var label: String {
        switch self {
        case .eligible(let label), .ineligible(let label): label
        }
    }

    var tone: InfoTagTone {
        switch self {
        case .eligible: .neutral
        case .ineligible: .warning
        }
    }
}

struct GenerationRouteSummaryProjection: Equatable {
    let routeType: String
    let generationEligibility: GenerationEligibilityProjection
    var name: String?
    var versionLabel: String?
    var region: String?
    var start: String?
    var end: String?
    var difficulty: String?
    var distance: String?
    var estimatedDuration: String?
}

extension SharedBusinessComponents {
    struct GenerationRouteSummaryCard: View {
        let projection: GenerationRouteSummaryProjection

        var body: some View {
            WalkCard {
                VStack(alignment: .leading, spacing: Spacing.md) {
                    RouteWrapLayout {
                        InfoTag(title: projection.routeType, tone: .neutral)
                        InfoTag(
                            title: projection.generationEligibility.label,
                            tone: projection.generationEligibility.tone
                        )
                    }

                    Text(routeNonEmpty(projection.name) ?? "未提供路线名称的\(projection.routeType)")
                        .font(.cardTitle)
                        .foregroundStyle(routeNonEmpty(projection.name) == nil ? AppColors.textWeak : AppColors.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)

                    if !facts.isEmpty {
                        Text(facts.joined(separator: " · "))
                            .font(.appCaption)
                            .foregroundStyle(AppColors.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .accessibilityElement(children: .combine)
        }

        private var facts: [String] {
            var values = [projection.versionLabel, projection.region].compactMap(routeNonEmpty)
            if let start = routeNonEmpty(projection.start), let end = routeNonEmpty(projection.end) {
                values.append("\(start) → \(end)")
            } else {
                values.append(contentsOf: [projection.start, projection.end].compactMap(routeNonEmpty))
            }
            values.append(contentsOf: [projection.difficulty, projection.distance, projection.estimatedDuration].compactMap(routeNonEmpty))
            return values
        }
    }
}

#if DEBUG
extension GenerationRouteSummaryProjection {
    static let `default` = GenerationRouteSummaryProjection(
        routeType: "多日路线",
        generationEligibility: .eligible(label: "可生成"),
        name: "贡嘎西南坡环线",
        versionLabel: "2026 夏季版",
        region: "四川 · 甘孜",
        start: "上木居",
        end: "草科",
        difficulty: "进阶",
        distance: "42.8 km",
        estimatedDuration: "4 天"
    )

    static let partial = GenerationRouteSummaryProjection(
        routeType: "一日路线",
        generationEligibility: .eligible(label: "可生成"),
        name: nil,
        versionLabel: nil,
        region: "北京 · 门头沟",
        start: nil,
        end: nil,
        difficulty: nil,
        distance: "12.4 km",
        estimatedDuration: nil
    )

    static let ineligible = GenerationRouteSummaryProjection(
        routeType: "多日路线",
        generationEligibility: .ineligible(label: "资料不足"),
        name: "峡谷穿越候选路线",
        versionLabel: "资料核验中",
        region: "云南 · 怒江",
        start: "北侧入口",
        end: "南侧出口",
        difficulty: "困难",
        distance: nil,
        estimatedDuration: nil
    )

    static let long = GenerationRouteSummaryProjection(
        routeType: "多日路线",
        generationEligibility: .eligible(label: "可生成"),
        name: "跨越高山草甸、原始森林与连续垭口的长距离徒步路线",
        versionLabel: "2026 年雨季前公开核验版本",
        region: "四川省甘孜藏族自治州康定市与泸定县交界区域",
        start: "高山村北侧徒步入口",
        end: "河谷游客服务站",
        difficulty: "高海拔进阶路线",
        distance: "68.5 km",
        estimatedDuration: "6 天"
    )
}

#Preview("GenerationRouteSummaryCard.default") {
    BusinessComponentPreviewHost {
        SharedBusinessComponents.GenerationRouteSummaryCard(
            projection: GenerationRouteSummaryProjection.default
        )
    }
}

#Preview("GenerationRouteSummaryCard.partial") {
    BusinessComponentPreviewHost {
        SharedBusinessComponents.GenerationRouteSummaryCard(
            projection: GenerationRouteSummaryProjection.partial
        )
    }
}

#Preview("GenerationRouteSummaryCard.ineligible") {
    BusinessComponentPreviewHost {
        SharedBusinessComponents.GenerationRouteSummaryCard(
            projection: GenerationRouteSummaryProjection.ineligible
        )
    }
}

#Preview("GenerationRouteSummaryCard.longContent") {
    BusinessComponentPreviewHost {
        SharedBusinessComponents.GenerationRouteSummaryCard(
            projection: GenerationRouteSummaryProjection.long
        )
    }
}
#endif
