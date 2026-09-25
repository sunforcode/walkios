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
#Preview("GenerationRouteSummaryCard.default") {
    BusinessComponentPreviewHost {
        SharedBusinessComponents.GenerationRouteSummaryCard(
            projection: BusinessComponentPreviewFixtures.generationRouteDefault
        )
    }
}

#Preview("GenerationRouteSummaryCard.partial") {
    BusinessComponentPreviewHost {
        SharedBusinessComponents.GenerationRouteSummaryCard(
            projection: BusinessComponentPreviewFixtures.generationRoutePartial
        )
    }
}

#Preview("GenerationRouteSummaryCard.ineligible") {
    BusinessComponentPreviewHost {
        SharedBusinessComponents.GenerationRouteSummaryCard(
            projection: BusinessComponentPreviewFixtures.generationRouteIneligible
        )
    }
}

#Preview("GenerationRouteSummaryCard.longContent") {
    BusinessComponentPreviewHost {
        SharedBusinessComponents.GenerationRouteSummaryCard(
            projection: BusinessComponentPreviewFixtures.generationRouteLong
        )
    }
}
#endif
