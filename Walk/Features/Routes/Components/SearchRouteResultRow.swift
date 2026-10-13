import SwiftUI
import WalkData
import WalkDesignSystem

struct SearchRouteResultRowProjection: Equatable {
    let routeID: String
    var coverAvailable: Bool
    var name: String?
    var region: String?
    var difficulty: String?
    var distance: String?
    var estimatedDuration: String?

    var metadata: [String] {
        [region, difficulty].compactMap(routeNonEmpty)
    }

    var facts: [String] {
        [distance, estimatedDuration].compactMap(routeNonEmpty)
    }

    var displayName: String {
        routeNonEmpty(name) ?? "路线名称未提供"
    }

    var nameMissing: Bool {
        routeNonEmpty(name) == nil
    }
}

extension RouteBusinessComponents {
    /// 紧凑搜索结果行，独立于 `RouteListRow`，不承载 PAGE-ROUTE-LIST 标准列表行外观。
    struct SearchRouteResultRow<Thumbnail: View>: View {
        let projection: SearchRouteResultRowProjection
        let onSelect: (String) -> Void
        private let thumbnail: Thumbnail

        init(
            projection: SearchRouteResultRowProjection,
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
                    .frame(width: 72, height: 66)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
                    .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: Spacing.xs) {
                        Text(projection.displayName)
                            .font(.listTitle)
                            .foregroundStyle(projection.nameMissing ? AppColors.textWeak : AppColors.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)

                        if !projection.metadata.isEmpty {
                            Text(projection.metadata.joined(separator: " · "))
                                .font(.appCaption)
                                .foregroundStyle(AppColors.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        if !projection.facts.isEmpty {
                            RouteWrapLayout {
                                ForEach(Array(projection.facts.enumerated()), id: \.offset) { _, fact in
                                    Text(fact)
                                        .font(.appCaption)
                                        .foregroundStyle(AppColors.textWeak)
                                        .padding(.horizontal, 7)
                                        .padding(.vertical, 4)
                                        .background(AppColors.surfaceElevated, in: Capsule())
                                }
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    Image(systemName: "chevron.right")
                        .font(.appBody)
                        .foregroundStyle(AppColors.textWeak)
                        .frame(width: 18)
                        .accessibilityHidden(true)
                }
                .padding(Spacing.md)
                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
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
            .accessibilityLabel(accessibilityLabel)
            .accessibilityHint("打开路线详情")
        }

        private var accessibilityLabel: String {
            var parts: [String] = [projection.displayName]
            parts.append(contentsOf: projection.metadata)
            parts.append(contentsOf: projection.facts)
            parts.append("可打开路线详情")
            return parts.joined(separator: "，")
        }
    }
}

#if DEBUG
extension SearchRouteResultRowProjection {
    static let `default` = SearchRouteResultRowProjection(
        routeID: "route-search-001",
        coverAvailable: true,
        name: "海坨山谷穿越",
        region: "北京 · 延庆",
        difficulty: "中等",
        distance: "18.6 km",
        estimatedDuration: "约 8 小时"
    )

    static let nameMissing = SearchRouteResultRowProjection(
        routeID: "route-search-002",
        coverAvailable: true,
        name: nil,
        region: "云南 · 香格里拉",
        difficulty: "进阶",
        distance: "32.0 km",
        estimatedDuration: "约 3 天"
    )

    static let coverMissing = SearchRouteResultRowProjection(
        routeID: "route-search-003",
        coverAvailable: false,
        name: "五台山逆穿",
        region: "山西 · 忻州",
        difficulty: "中等",
        distance: "52.0 km",
        estimatedDuration: "约 3 天"
    )

    static let partial = SearchRouteResultRowProjection(
        routeID: "route-search-004",
        coverAvailable: true,
        name: "武功山穿越",
        region: nil,
        difficulty: nil,
        distance: "24.0 km",
        estimatedDuration: nil
    )
}

#Preview("SearchRouteResultRow.default") {
    BusinessComponentPreviewHost {
        RouteBusinessComponents.SearchRouteResultRow(
            projection: SearchRouteResultRowProjection.default,
            onSelect: { _ in }
        ) { RouteDeterministicImageSurface(style: .ridge) }
    }
}

#Preview("SearchRouteResultRow.nameMissing") {
    BusinessComponentPreviewHost {
        RouteBusinessComponents.SearchRouteResultRow(
            projection: SearchRouteResultRowProjection.nameMissing,
            onSelect: { _ in }
        ) { RouteDeterministicImageSurface(style: .forest) }
    }
}

#Preview("SearchRouteResultRow.coverMissing") {
    BusinessComponentPreviewHost {
        RouteBusinessComponents.SearchRouteResultRow(
            projection: SearchRouteResultRowProjection.coverMissing,
            onSelect: { _ in }
        ) { RouteDeterministicImageSurface(style: .forest) }
    }
}

#Preview("SearchRouteResultRow.partialFacts") {
    BusinessComponentPreviewHost {
        RouteBusinessComponents.SearchRouteResultRow(
            projection: SearchRouteResultRowProjection.partial,
            onSelect: { _ in }
        ) { RouteDeterministicImageSurface(style: .water) }
    }
}
#endif
