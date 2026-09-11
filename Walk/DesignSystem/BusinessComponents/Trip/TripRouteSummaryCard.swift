import SwiftUI

enum TripRouteVersionRelationship: Equatable {
    case current
    case newerPublicVersionAvailable
    case currentPublicVersionUnavailable
}

enum TripRouteDifferenceChangeType: Equatable {
    case added
    case noLongerProvided
    case modified
}

struct TripRouteDifferenceProjection: Identifiable, Equatable {
    let id: String
    let label: String
    let changeType: TripRouteDifferenceChangeType
    let summary: String
    var before: String?
    var after: String?

    var detail: String {
        var values = [summary]
        switch changeType {
        case .added:
            if let after = tripNonEmpty(after) { values.append("新增：\(after)") }
        case .noLongerProvided:
            if let before = tripNonEmpty(before) { values.append("原资料：\(before)") }
        case .modified:
            if let before = tripNonEmpty(before) { values.append("原为：\(before)") }
            if let after = tripNonEmpty(after) { values.append("现为：\(after)") }
        }
        return values.joined(separator: "；")
    }
}

struct TripRouteSummaryProjection: Equatable {
    let routeName: String
    let versionLabel: String?
    var routeType: String?
    var region: String
    var start: String
    var end: String
    var direction: String?
    var metrics: [MetricItemModel]
}

extension TripBusinessComponents {
    struct TripRouteSummaryCard: View {
        let projection: TripRouteSummaryProjection
        let onActivate: () -> Void

        var body: some View {
            Button(action: onActivate) {
                VStack(alignment: .leading, spacing: Spacing.lg) {
                    header

                    if let routeType = tripNonEmpty(projection.routeType) {
                        Text(routeType)
                            .font(.appCaption)
                            .foregroundStyle(AppColors.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    routeContext

                    if !projection.metrics.isEmpty {
                        Rectangle()
                            .fill(AppColors.surfaceDivider)
                            .frame(height: 1)
                            .accessibilityHidden(true)
                        MetricGroup(items: projection.metrics, variant: .grid)
                    }
                }
                .padding(Spacing.lg)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    LinearGradient(
                        colors: [
                            AppColors.surfacePrimary,
                            AppColors.sceneForestMiddle,
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    in: RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                        .stroke(AppColors.borderSubtle, lineWidth: 1)
                }
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isButton)
        }

        private var header: some View {
            HStack(alignment: .top, spacing: Spacing.md) {
                Text(projection.routeName)
                    .font(.listTitle)
                    .foregroundStyle(AppColors.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)

                if let versionLabel = tripNonEmpty(projection.versionLabel) {
                    InfoTag(title: "生成依据 · \(versionLabel)", tone: .neutral)
                }

                Image(systemName: "chevron.right")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(AppColors.textWeak)
                    .frame(width: 18)
                    .accessibilityHidden(true)
            }
        }

        @ViewBuilder
        private var routeContext: some View {
            let context = routeContextText
            if !context.isEmpty {
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text(context)
                        .font(.appBody)
                        .foregroundStyle(AppColors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                    if let direction = tripNonEmpty(projection.direction) {
                        Text(direction)
                            .font(.appCaption)
                            .foregroundStyle(AppColors.textWeak)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }

        private var routeContextText: String {
            [tripNonEmpty(projection.region),
             tripNonEmpty(projection.start).map { start -> String in
                 tripNonEmpty(projection.end).map { "\(start) → \($0)" } ?? start
             }]
                .compactMap { $0 }
                .joined(separator: " · ")
        }
    }
}

#if DEBUG
#Preview("TripRouteSummaryCard.default") {
    BusinessComponentPreviewHost {
        TripBusinessComponents.TripRouteSummaryCard(
            projection: BusinessComponentPreviewFixtures.tripRouteEntryDefault,
            onActivate: {}
        )
    }
}

#Preview("TripRouteSummaryCard.partial") {
    BusinessComponentPreviewHost {
        TripBusinessComponents.TripRouteSummaryCard(
            projection: BusinessComponentPreviewFixtures.tripRouteEntryPartial,
            onActivate: {}
        )
    }
}

#Preview("TripRouteSummaryCard.longContent") {
    BusinessComponentPreviewHost {
        TripBusinessComponents.TripRouteSummaryCard(
            projection: BusinessComponentPreviewFixtures.tripRouteEntryLong,
            onActivate: {}
        )
    }
}
#endif
