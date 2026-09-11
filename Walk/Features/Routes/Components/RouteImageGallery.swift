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
        private let imageContent: (RouteImageProjection) -> ImageContent

        init(
            images: [RouteImageProjection],
            @ViewBuilder imageContent: @escaping (RouteImageProjection) -> ImageContent
        ) {
            self.images = images
            self.imageContent = imageContent
        }

        var body: some View {
            RouteBusinessSection(title: "路线图片") {
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
#Preview("RouteImageGallery.default") {
    BusinessComponentPreviewHost {
        RouteBusinessComponents.RouteImageGallery(
            images: BusinessComponentPreviewFixtures.routeImages
        ) { image in
            RouteDeterministicImageSurface(style: BusinessComponentPreviewFixtures.imageStyle(for: image.id))
        }
    }
}

#Preview("RouteImageGallery.single") {
    BusinessComponentPreviewHost {
        RouteBusinessComponents.RouteImageGallery(
            images: [BusinessComponentPreviewFixtures.routeImages[0]]
        ) { _ in
            RouteDeterministicImageSurface(style: .ridge)
        }
    }
}
#endif
