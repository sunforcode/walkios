import SwiftUI
import WalkData
import WalkDesignSystem

extension RouteBusinessComponents {
    struct RouteImageViewer<ImageContent: View>: View {
        let image: RouteImageProjection
        let onDismiss: () -> Void
        private let imageContent: ImageContent

        init(
            image: RouteImageProjection,
            onDismiss: @escaping () -> Void,
            @ViewBuilder imageContent: () -> ImageContent
        ) {
            self.image = image
            self.onDismiss = onDismiss
            self.imageContent = imageContent()
        }

        var body: some View {
            ZStack {
                AppColors.pageBase.opacity(0.94)
                    .ignoresSafeArea()

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: Spacing.lg) {
                        imageContent
                            .frame(maxWidth: .infinity)
                            .aspectRatio(16 / 11, contentMode: .fit)
                            .clipped()
                            .clipShape(RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
                            .accessibilityLabel(image.title)

                        Text(image.title)
                            .font(.sectionTitle)
                            .foregroundStyle(AppColors.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)

                        if let description = routeNonEmpty(image.description) {
                            Text(description)
                                .font(.appBody)
                                .foregroundStyle(AppColors.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .padding(Spacing.lg)
                    .padding(.top, 64)
                }

                VStack {
                    HStack {
                        Spacer()
                        IconButton(
                            systemName: "xmark",
                            accessibilityLabel: "关闭路线图片",
                            variant: .overlay,
                            action: onDismiss
                        )
                    }
                    .padding(Spacing.lg)
                    Spacer()
                }
            }
            .accessibilityAddTraits(.isModal)
        }
    }
}

#if DEBUG
#Preview("RouteImageViewer.default") {
    RouteBusinessComponents.RouteImageViewer(
        image: BusinessComponentPreviewFixtures.routeImages[0],
        onDismiss: {}
    ) {
        RouteDeterministicImageSurface(style: .ridge)
    }
}
#endif
