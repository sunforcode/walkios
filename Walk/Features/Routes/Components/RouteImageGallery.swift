import SwiftUI
import WalkData
import WalkDesignSystem

struct RouteImageProjection: Identifiable, Equatable {
    let id: String
    let title: String?
    var description: String?
}

extension RouteBusinessComponents {
    /// 只读图片集合：图片、标题和说明均不建立按钮、选择或打开事件；
    /// 标题或说明缺失时省略对应槽位，不用默认文案补齐。
    struct RouteImageGallery<ImageContent: View>: View {
        @Environment(\.dynamicTypeSize) private var dynamicTypeSize
        let images: [RouteImageProjection]
        let title: String
        private let imageContent: (RouteImageProjection) -> ImageContent

        init(
            images: [RouteImageProjection],
            title: String = "路线图片",
            @ViewBuilder imageContent: @escaping (RouteImageProjection) -> ImageContent
        ) {
            self.images = images
            self.title = title
            self.imageContent = imageContent
        }

        var body: some View {
            RouteBusinessSection(title: title) {
                LazyVGrid(columns: columns, alignment: .leading, spacing: Spacing.sm) {
                    ForEach(images) { image in
                        VStack(alignment: .leading, spacing: Spacing.xs) {
                            imageContent(image)
                                .frame(maxWidth: .infinity)
                                .frame(height: 70)
                                .clipped()
                                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                                .accessibilityHidden(true)

                            if let title = routeNonEmpty(image.title) {
                                Text(title)
                                    .font(.microStrong)
                                    .foregroundStyle(AppColors.textPrimary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }

                            if let description = routeNonEmpty(image.description) {
                                Text(description)
                                    .font(.micro)
                                    .foregroundStyle(AppColors.textWeak)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                        .accessibilityElement(children: .combine)
                    }
                }
            }
        }

        private var columns: [GridItem] {
            Array(
                repeating: GridItem(.flexible(), spacing: Spacing.sm),
                count: dynamicTypeSize.isAccessibilitySize ? 2 : 3
            )
        }
    }
}

#if DEBUG
extension RouteImageProjection {
    static let samples = [
        RouteImageProjection(id: "route-image-1", title: "高山垭口", description: "从垭口回望连续山谷。"),
        RouteImageProjection(id: "route-image-2", title: "林线营地", description: "靠近稳定水源的开阔营地。"),
        RouteImageProjection(id: "route-image-3", title: "河谷路段", description: "沿河谷下降的主要路径。"),
    ]

    static func sampleStyle(for identity: String) -> RouteVisualStyle {
        switch identity {
        case "route-image-2": .forest
        case "route-image-3": .water
        default: .ridge
        }
    }
}

#Preview("RouteImageGallery.default") {
    BusinessComponentPreviewHost {
        RouteBusinessComponents.RouteImageGallery(
            images: RouteImageProjection.samples
        ) { image in
            RouteDeterministicImageSurface(style: RouteImageProjection.sampleStyle(for: image.id))
        }
    }
}

#Preview("RouteImageGallery.single") {
    BusinessComponentPreviewHost {
        RouteBusinessComponents.RouteImageGallery(
            images: [RouteImageProjection.samples[0]]
        ) { _ in
            RouteDeterministicImageSurface(style: .ridge)
        }
    }
}
#endif
