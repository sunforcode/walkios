import SwiftUI

struct IconButtonConfiguration {
    let systemName: String
    let accessibilityLabel: String
    var variant: IconButtonVariant = .default
    let action: () -> Void

    init(
        systemName: String,
        accessibilityLabel: String,
        variant: IconButtonVariant = .default,
        action: @escaping () -> Void
    ) {
        self.systemName = systemName
        self.accessibilityLabel = accessibilityLabel
        self.variant = variant
        self.action = action
    }
}

struct UtilityNavigationHeader: View {
    let title: String
    var leading: IconButtonConfiguration? = nil
    var trailing: IconButtonConfiguration? = nil
    var showsDivider = false
    var titleAsLabel = false

    var body: some View {
        HStack(spacing: 0) {
            navigationItem(leading)
            titleView
            navigationItem(trailing)
        }
        .frame(minHeight: Spacing.xxxl + Spacing.sm)
        .background(AppColors.surfaceGlass)
        .background(AppColors.surfaceHeader)
        .overlay(alignment: .bottom) {
            if showsDivider {
                Rectangle()
                    .fill(AppColors.surfaceDivider)
                    .frame(height: 1)
            }
        }
    }

    @ViewBuilder
    private var titleView: some View {
        let title = Text(title)
            .font(.navTitle)
            .foregroundStyle(AppColors.textPrimary)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity)

        if titleAsLabel {
            title
        } else {
            title.accessibilityAddTraits(.isHeader)
        }
    }

    @ViewBuilder
    private func navigationItem(_ configuration: IconButtonConfiguration?) -> some View {
        if let configuration {
            IconButton(
                systemName: configuration.systemName,
                accessibilityLabel: configuration.accessibilityLabel,
                variant: configuration.variant,
                action: configuration.action
            )
        } else {
            Spacer(minLength: 0)
                .frame(width: Spacing.navBarHeight, height: Spacing.navBarHeight)
                .accessibilityHidden(true)
        }
    }
}

#if DEBUG
#Preview("UtilityNavigationHeader.default") {
    UtilityNavigationHeader(
        title: ComponentPreviewFixtures.navigationTitle,
        leading: IconButtonConfiguration(
            systemName: "chevron.left",
            accessibilityLabel: "返回",
            action: {}
        ),
        trailing: IconButtonConfiguration(
            systemName: "magnifyingglass",
            accessibilityLabel: "搜索路线",
            action: {}
        )
    )
    .background(AppColors.pageBase)
}

#Preview("UtilityNavigationHeader.long") {
    UtilityNavigationHeader(
        title: ComponentPreviewFixtures.longNavigationTitle,
        leading: IconButtonConfiguration(
            systemName: "chevron.left",
            accessibilityLabel: "返回",
            action: {}
        ),
        trailing: IconButtonConfiguration(
            systemName: "ellipsis",
            accessibilityLabel: "更多操作",
            action: {}
        )
    )
    .background(AppColors.pageBase)
}

#Preview("UtilityNavigationHeader.back") {
    UtilityNavigationHeader(
        title: ComponentPreviewFixtures.navigationTitle,
        leading: IconButtonConfiguration(
            systemName: "chevron.left",
            accessibilityLabel: "返回",
            action: {}
        )
    )
    .background(AppColors.pageBase)
}

#Preview("UtilityNavigationHeader.tail") {
    UtilityNavigationHeader(
        title: ComponentPreviewFixtures.navigationTitle,
        trailing: IconButtonConfiguration(
            systemName: "magnifyingglass",
            accessibilityLabel: "搜索路线",
            action: {}
        )
    )
    .background(AppColors.pageBase)
}
#endif
