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
extension RouteFactSectionProjection {
    static let safety = RouteFactSectionProjection(
        title: "通信与安全",
        items: [
            RouteFactItemProjection(id: "safety-signal", bookmark: "信", title: "通信覆盖", content: "峡谷路段信号不稳定，垭口附近可短暂恢复。"),
            RouteFactItemProjection(id: "safety-risk", bookmark: "险", title: "危险区域", content: "雨后碎石坡湿滑，需避开坡脚停留。"),
            RouteFactItemProjection(id: "safety-evacuation", bookmark: "撤", title: "撤离难度", content: "中段最近公路距离较远，需预留返程体力。"),
        ]
    )

    static let season = RouteFactSectionProjection(
        title: "季节天气",
        items: [
            RouteFactItemProjection(id: "season-main", bookmark: "季", title: "适宜季节", content: "五月下旬至六月、九月至十月。"),
            RouteFactItemProjection(id: "season-summer", bookmark: "夏", title: "夏季", content: "午后对流天气频繁，需提前通过暴露山脊。"),
            RouteFactItemProjection(id: "season-autumn", bookmark: "秋", title: "秋季", content: "昼夜温差明显，背阴坡可能提前结冰。"),
        ]
    )
}

#Preview("RouteFactSection.default") {
    BusinessComponentPreviewHost {
        RouteBusinessComponents.RouteFactSection(
            projection: RouteFactSectionProjection.safety
        )
    }
}

#Preview("RouteFactSection.season") {
    BusinessComponentPreviewHost {
        RouteBusinessComponents.RouteFactSection(
            projection: RouteFactSectionProjection.season
        )
    }
}
#endif
