import SwiftUI

struct RouteBrowseRowProjection: Equatable {
    let routeID: String
    var coverAvailable: Bool
    var name: String?
    var region: String?
    var difficulty: String?
    var distance: String?
    var ascent: String?
    var estimatedDuration: String?
}

enum RouteListRowProjection: Equatable {
    case browse(RouteBrowseRowProjection)

    var routeID: String {
        switch self {
        case .browse(let value): value.routeID
        }
    }

    var coverAvailable: Bool {
        switch self {
        case .browse(let value): value.coverAvailable
        }
    }

    var name: String? {
        switch self {
        case .browse(let value): value.name
        }
    }

    var metadata: [String] {
        switch self {
        case .browse(let value): [value.region, value.difficulty].compactMap(routeNonEmpty)
        }
    }

    var facts: [String] {
        switch self {
        case .browse(let value):
            [value.distance, value.ascent, value.estimatedDuration].compactMap(routeNonEmpty)
        }
    }
}

extension RouteBusinessComponents {
    struct RouteListRow<Thumbnail: View>: View {
        let projection: RouteListRowProjection
        let onSelect: (String) -> Void
        private let thumbnail: Thumbnail

        init(
            projection: RouteListRowProjection,
            onSelect: @escaping (String) -> Void,
            @ViewBuilder thumbnail: () -> Thumbnail
        ) {
            self.projection = projection
            self.onSelect = onSelect
            self.thumbnail = thumbnail()
        }

        var body: some View {
            Button {
                onSelect(projection.routeID)
            } label: {
                HStack(spacing: Spacing.md) {
                    Group {
                        if projection.coverAvailable {
                            thumbnail
                        } else {
                            RouteDeterministicImageSurface(style: .forest)
                        }
                    }
                    .frame(width: 82, height: 84)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
                    .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        Text(routeNonEmpty(projection.name) ?? "路线名称未提供")
                            .font(.listTitle)
                            .foregroundStyle(routeNonEmpty(projection.name) == nil ? AppColors.textWeak : AppColors.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)

                        if !projection.metadata.isEmpty {
                            Text(projection.metadata.joined(separator: " · "))
                                .font(.micro)
                                .foregroundStyle(AppColors.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        if !projection.facts.isEmpty {
                            RouteWrapLayout {
                                ForEach(Array(projection.facts.enumerated()), id: \.offset) { _, fact in
                                    Text(fact)
                                        .font(.micro)
                                        .foregroundStyle(AppColors.textWeak)
                                        .padding(.horizontal, 7)
                                        .padding(.vertical, 5)
                                        .background(AppColors.surfaceElevated, in: Capsule())
                                }
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    Image(systemName: "chevron.right")
                        .font(.navTitle)
                        .foregroundStyle(AppColors.textWeak)
                        .frame(width: 18)
                        .accessibilityHidden(true)
                }
                .padding(11)
                .frame(maxWidth: .infinity, minHeight: 108, alignment: .leading)
                .background(AppColors.surfacePrimary)
                .clipShape(RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                        .stroke(AppColors.borderSubtle, lineWidth: 1)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .combine)
            .accessibilityHint("查看路线详情")
        }
    }
}

#if DEBUG
#Preview("RouteListRow.default") {
    BusinessComponentPreviewHost {
        RouteBusinessComponents.RouteListRow(
            projection: BusinessComponentPreviewFixtures.routeRowDefault,
            onSelect: { _ in }
        ) { RouteDeterministicImageSurface(style: .ridge) }
    }
}

#Preview("RouteListRow.nameMissing") {
    BusinessComponentPreviewHost {
        RouteBusinessComponents.RouteListRow(
            projection: BusinessComponentPreviewFixtures.routeRowNameMissing,
            onSelect: { _ in }
        ) { RouteDeterministicImageSurface(style: .forest) }
    }
}

#Preview("RouteListRow.coverMissing") {
    BusinessComponentPreviewHost {
        RouteBusinessComponents.RouteListRow(
            projection: BusinessComponentPreviewFixtures.routeRowCoverMissing,
            onSelect: { _ in }
        ) { RouteDeterministicImageSurface(style: .forest) }
    }
}

#Preview("RouteListRow.partialFacts") {
    BusinessComponentPreviewHost {
        RouteBusinessComponents.RouteListRow(
            projection: BusinessComponentPreviewFixtures.routeRowPartial,
            onSelect: { _ in }
        ) { RouteDeterministicImageSurface(style: .ridge) }
    }
}

#Preview("RouteListRow.minimal") {
    BusinessComponentPreviewHost {
        RouteBusinessComponents.RouteListRow(
            projection: BusinessComponentPreviewFixtures.routeRowMinimal,
            onSelect: { _ in }
        ) { RouteDeterministicImageSurface(style: .forest) }
    }
}

#Preview("RouteListRow.longContent") {
    BusinessComponentPreviewHost {
        RouteBusinessComponents.RouteListRow(
            projection: BusinessComponentPreviewFixtures.routeRowLong,
            onSelect: { _ in }
        ) { RouteDeterministicImageSurface(style: .ridge) }
    }
}
#endif
