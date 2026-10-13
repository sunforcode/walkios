import SwiftUI
import WalkData
import WalkDesignSystem

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
extension RouteListRowProjection {
    static let `default` = RouteListRowProjection.browse(
        RouteBrowseRowProjection(
            routeID: "route-001",
            coverAvailable: true,
            name: "贡嘎西南坡环线",
            region: "四川 · 甘孜",
            difficulty: "进阶",
            distance: "42.8 km",
            ascent: "爬升 2,340 m",
            estimatedDuration: "约 4 天"
        )
    )

    static let nameMissing = RouteListRowProjection.browse(
        RouteBrowseRowProjection(
            routeID: "route-003",
            coverAvailable: true,
            name: nil,
            region: "云南 · 怒江",
            difficulty: "困难",
            distance: "31.2 km",
            ascent: "爬升 1,980 m",
            estimatedDuration: "约 3 天"
        )
    )

    static let coverMissing = RouteListRowProjection.browse(
        RouteBrowseRowProjection(
            routeID: "route-004",
            coverAvailable: false,
            name: "峡谷森林线",
            region: "云南 · 怒江",
            difficulty: "中等",
            distance: "21.4 km",
            ascent: "爬升 1,120 m",
            estimatedDuration: "约 2 天"
        )
    )

    static let partial = RouteListRowProjection.browse(
        RouteBrowseRowProjection(
            routeID: "route-005",
            coverAvailable: true,
            name: "白河峡谷",
            region: nil,
            difficulty: nil,
            distance: "9.8 km",
            ascent: nil,
            estimatedDuration: nil
        )
    )

    static let minimal = RouteListRowProjection.browse(
        RouteBrowseRowProjection(
            routeID: "route-006",
            coverAvailable: false,
            name: "河谷短线",
            region: nil,
            difficulty: nil,
            distance: nil,
            ascent: nil,
            estimatedDuration: nil
        )
    )

    static let long = RouteListRowProjection.browse(
        RouteBrowseRowProjection(
            routeID: "route-007",
            coverAvailable: true,
            name: "穿越原始森林、高山草甸与连续垭口的长距离环形徒步路线",
            region: "四川省甘孜藏族自治州康定市与泸定县交界区域",
            difficulty: "高海拔进阶路线",
            distance: "68.5 km",
            ascent: "爬升 3,920 m",
            estimatedDuration: "约 6 天"
        )
    )
}

#Preview("RouteListRow.default") {
    BusinessComponentPreviewHost {
        RouteBusinessComponents.RouteListRow(
            projection: RouteListRowProjection.default,
            onSelect: { _ in }
        ) { RouteDeterministicImageSurface(style: .ridge) }
    }
}

#Preview("RouteListRow.nameMissing") {
    BusinessComponentPreviewHost {
        RouteBusinessComponents.RouteListRow(
            projection: RouteListRowProjection.nameMissing,
            onSelect: { _ in }
        ) { RouteDeterministicImageSurface(style: .forest) }
    }
}

#Preview("RouteListRow.coverMissing") {
    BusinessComponentPreviewHost {
        RouteBusinessComponents.RouteListRow(
            projection: RouteListRowProjection.coverMissing,
            onSelect: { _ in }
        ) { RouteDeterministicImageSurface(style: .forest) }
    }
}

#Preview("RouteListRow.partialFacts") {
    BusinessComponentPreviewHost {
        RouteBusinessComponents.RouteListRow(
            projection: RouteListRowProjection.partial,
            onSelect: { _ in }
        ) { RouteDeterministicImageSurface(style: .ridge) }
    }
}

#Preview("RouteListRow.minimal") {
    BusinessComponentPreviewHost {
        RouteBusinessComponents.RouteListRow(
            projection: RouteListRowProjection.minimal,
            onSelect: { _ in }
        ) { RouteDeterministicImageSurface(style: .forest) }
    }
}

#Preview("RouteListRow.longContent") {
    BusinessComponentPreviewHost {
        RouteBusinessComponents.RouteListRow(
            projection: RouteListRowProjection.long,
            onSelect: { _ in }
        ) { RouteDeterministicImageSurface(style: .ridge) }
    }
}
#endif
