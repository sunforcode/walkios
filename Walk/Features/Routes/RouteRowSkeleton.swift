import SwiftUI
import WalkDesignSystem

// 路线发现页加载骨架的私有排版。原在 WalkDesignSystem，因绑定路线概念移回 Routes（W5）。
// 属于页面非组件，不建立组件身份；与业务组件 RouteBusinessComponents.RouteListRow 区分命名。

struct RouteSkeletonThumbnail: View {
     var systemImage = "photo"

     var body: some View {
        ZStack {
            AppColors.surfaceElevated
            Image(systemName: systemImage)
                .font(.ornament(20, weight: .medium))
                .foregroundStyle(AppColors.textWeak)
        }
        .accessibilityHidden(true)
    }

    init(
        systemImage: String = "photo"
    ) {
        self.systemImage = systemImage
    }
}

struct RouteSkeletonRow<Thumbnail: View, Metadata: View>: View {
     let title: String
     var showsDisclosure = true
    private let thumbnail: Thumbnail
    private let metadata: Metadata

     init(
        title: String,
        showsDisclosure: Bool = true,
        @ViewBuilder thumbnail: () -> Thumbnail,
        @ViewBuilder metadata: () -> Metadata
    ) {
        self.title = title
        self.showsDisclosure = showsDisclosure
        self.thumbnail = thumbnail()
        self.metadata = metadata()
    }

     var body: some View {
        ListRow {
            HStack(spacing: Spacing.md) {
                thumbnail
                    .frame(width: 82, height: 84)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: Radius.md, style: .continuous))

                VStack(alignment: .leading, spacing: Spacing.sm) {
                    Text(title)
                        .font(.listTitle)
                        .foregroundStyle(AppColors.textPrimary)
                        .lineLimit(2)

                    metadata
                        .font(.micro)
                        .foregroundStyle(AppColors.textSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                if showsDisclosure {
                    Image(systemName: "chevron.right")
                        .font(.contextTitle)
                        .foregroundStyle(AppColors.textWeak)
                        .frame(width: 18)
                }
            }
            .frame(minHeight: 84)
        }
    }
}
