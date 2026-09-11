import SwiftUI

public struct IconButtonConfiguration {
     public let systemName: String
     public let accessibilityLabel: String
     public var variant: IconButtonVariant = .default
     public let action: () -> Void

     public init(
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

public struct UtilityNavigationHeader: View {
     public let title: String
     public var leading: IconButtonConfiguration? = nil
     public var trailing: IconButtonConfiguration? = nil
     public var showsDivider = false
     public var titleAsLabel = false

     public var body: some View {
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

    public init(
        title: String,
        leading: IconButtonConfiguration? = nil,
        trailing: IconButtonConfiguration? = nil,
        showsDivider: Bool = false,
        titleAsLabel: Bool = false
    ) {
        self.title = title
        self.leading = leading
        self.trailing = trailing
        self.showsDivider = showsDivider
        self.titleAsLabel = titleAsLabel
    }
}

#if DEBUG
#Preview("UtilityNavigationHeader.default") {
    UtilityNavigationHeader(
        title: "全部路线",
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
        title: "路线详情页标题文案较长时单行截断展示",
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
        title: "全部路线",
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
        title: "全部路线",
        trailing: IconButtonConfiguration(
            systemName: "magnifyingglass",
            accessibilityLabel: "搜索路线",
            action: {}
        )
    )
    .background(AppColors.pageBase)
}
#endif
