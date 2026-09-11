import SwiftUI

struct RouteImageProjection: Identifiable, Equatable {
    let id: String
    let title: String
    var description: String?
}

extension RouteBusinessComponents {
    struct RouteImageGallery<ImageContent: View>: View {
        @Environment(\.dynamicTypeSize) private var dynamicTypeSize
        let images: [RouteImageProjection]
        let onOpenImage: (String) -> Void
        private let imageContent: (RouteImageProjection) -> ImageContent

        init(
            images: [RouteImageProjection],
            onOpenImage: @escaping (String) -> Void,
            @ViewBuilder imageContent: @escaping (RouteImageProjection) -> ImageContent
        ) {
            self.images = images
            self.onOpenImage = onOpenImage
            self.imageContent = imageContent
        }

        var body: some View {
            RouteBusinessSection(title: "路线图片") {
                LazyVGrid(columns: columns, alignment: .leading, spacing: Spacing.sm) {
                    ForEach(images) { image in
                        Button {
                            onOpenImage(image.id)
                        } label: {
                            VStack(alignment: .leading, spacing: Spacing.xs) {
                                imageContent(image)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 70)
                                    .clipped()
                                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                                Text(image.title)
                                    .font(.microStrong)
                                    .foregroundStyle(AppColors.textPrimary)
                                    .fixedSize(horizontal: false, vertical: true)

                                if let description = routeNonEmpty(image.description) {
                                    Text(description)
                                        .font(.micro)
                                        .foregroundStyle(AppColors.textWeak)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .topLeading)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("查看图片：\(image.title)")
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
            images: BusinessComponentPreviewFixtures.routeImages,
            onOpenImage: { _ in }
        ) { image in
            RouteDeterministicImageSurface(style: BusinessComponentPreviewFixtures.imageStyle(for: image.id))
        }
    }
}

#Preview("RouteImageGallery.single") {
    BusinessComponentPreviewHost {
        RouteBusinessComponents.RouteImageGallery(
            images: [BusinessComponentPreviewFixtures.routeImages[0]],
            onOpenImage: { _ in }
        ) { _ in
            RouteDeterministicImageSurface(style: .ridge)
        }
    }
}
#endif
