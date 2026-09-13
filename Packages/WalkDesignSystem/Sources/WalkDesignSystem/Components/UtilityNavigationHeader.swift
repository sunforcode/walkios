import SwiftUI

public struct IconButtonConfiguration {
     public let systemName: String
     public let accessibilityLabel: String
     public var variant: IconButtonVariant = .overlay
     public let action: () -> Void

     public init(
        systemName: String,
        accessibilityLabel: String,
        variant: IconButtonVariant = .overlay,
        action: @escaping () -> Void
    ) {
        self.systemName = systemName
        self.accessibilityLabel = accessibilityLabel
        self.variant = variant
        self.action = action
    }
}

/// 二级任务页统一悬浮导航承载：无固定底色与下边界线，返回为悬浮圆形
/// `IconButton.overlay`，标题与尾部动作悬浮于页面顶部区域。标题可选——
/// 同页 `PageTitleBlock` 拥有唯一主标题时由 Page 省略标题，避免重复。
public struct UtilityNavigationHeader: View {
     public let title: String?
     public var leading: IconButtonConfiguration? = nil
     public var trailing: IconButtonConfiguration? = nil

     public var body: some View {
        HStack(spacing: 0) {
            navigationItem(leading)
            titleView
            navigationItem(trailing)
        }
        // 返回钮与尾部动作距屏幕左右缘一个页边距，不再贴边。
        .padding(.horizontal, Spacing.pageHorizontal)
        .frame(minHeight: Spacing.navBarHeight)
    }

    @ViewBuilder
    private var titleView: some View {
        if let title {
            Text(title)
                .font(.navTitle)
                .foregroundStyle(AppColors.textPrimary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity)
                .accessibilityAddTraits(.isHeader)
        } else {
            Color.clear
                .frame(maxWidth: .infinity, maxHeight: Spacing.navBarHeight)
                .accessibilityHidden(true)
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
        title: String? = nil,
        leading: IconButtonConfiguration? = nil,
        trailing: IconButtonConfiguration? = nil
    ) {
        self.title = title
        self.leading = leading
        self.trailing = trailing
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
        leading: IconButtonConfiguration(
            systemName: "chevron.left",
            accessibilityLabel: "返回",
            action: {}
        )
    )
    .background(AppColors.pageBase)
}

#Preview("UtilityNavigationHeader.titleOnly") {
    UtilityNavigationHeader(
        title: "行程天气"
    )
    .background(AppColors.pageBase)
}
#endif
