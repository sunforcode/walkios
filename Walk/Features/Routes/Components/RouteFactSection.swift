import SwiftUI
import WalkData
import WalkDesignSystem

struct RouteFactItemProjection: Identifiable, Equatable {
    let id: String
    let bookmark: String
    let title: String
    let content: String
}

struct RouteFactSectionProjection: Equatable {
    let title: String
    let items: [RouteFactItemProjection]
}

extension RouteBusinessComponents {
    struct RouteFactSection: View {
        let projection: RouteFactSectionProjection

        var body: some View {
            RouteBusinessSection(title: projection.title) {
                VStack(spacing: 0) {
                    ForEach(Array(projection.items.enumerated()), id: \.element.id) { index, item in
                        HStack(alignment: .top, spacing: 11) {
                            RouteBookmark(title: item.bookmark)
                                .frame(width: 31)

                            VStack(alignment: .leading, spacing: Spacing.xs) {
                                Text(item.title)
                                    .font(.listTitle)
                                    .foregroundStyle(AppColors.textPrimary)
                                Text(item.content)
                                    .font(.appCaption)
                                    .foregroundStyle(AppColors.textSecondary)
                            }
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(.vertical, Spacing.md)
                        .accessibilityElement(children: .combine)

                        if index < projection.items.count - 1 {
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
#Preview("RouteFactSection.default") {
    BusinessComponentPreviewHost {
        RouteBusinessComponents.RouteFactSection(
            projection: BusinessComponentPreviewFixtures.routeSafetyFacts
        )
    }
}

#Preview("RouteFactSection.season") {
    BusinessComponentPreviewHost {
        RouteBusinessComponents.RouteFactSection(
            projection: BusinessComponentPreviewFixtures.routeSeasonFacts
        )
    }
}
#endif
