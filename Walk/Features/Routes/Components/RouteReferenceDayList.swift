import SwiftUI
import WalkData
import WalkDesignSystem

struct RouteReferenceDayProjection: Identifiable, Equatable {
    let id: String
    let dayNumber: Int
    var title: String?
    var metrics: [String]
    var description: String?
}

extension RouteBusinessComponents {
    struct RouteReferenceDayList: View {
        let days: [RouteReferenceDayProjection]

        var body: some View {
            RouteBusinessSection(title: "参考分日") {
                VStack(spacing: 0) {
                    ForEach(Array(days.enumerated()), id: \.element.id) { index, day in
                        HStack(alignment: .top, spacing: 11) {
                            RouteBookmark(title: "D\(day.dayNumber)")
                                .frame(width: 31)

                            VStack(alignment: .leading, spacing: Spacing.xs) {
                                if let title = routeNonEmpty(day.title) {
                                    Text(title)
                                        .font(.listTitle)
                                        .foregroundStyle(AppColors.textPrimary)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                                if !day.metrics.isEmpty {
                                    Text(day.metrics.joined(separator: " · "))
                                        .font(.appCaption)
                                        .foregroundStyle(AppColors.interactionPrimary)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                                if let description = routeNonEmpty(day.description) {
                                    Text(description)
                                        .font(.appCaption)
                                        .foregroundStyle(AppColors.textSecondary)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(.vertical, Spacing.md)
                        .accessibilityElement(children: .combine)

                        if index < days.count - 1 {
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
#Preview("RouteReferenceDayList.default") {
    BusinessComponentPreviewHost {
        RouteBusinessComponents.RouteReferenceDayList(
            days: BusinessComponentPreviewFixtures.referenceDays
        )
    }
}
#endif
