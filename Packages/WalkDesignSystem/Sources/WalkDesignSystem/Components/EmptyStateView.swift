import SwiftUI

public struct EmptyStateView: View {
     public let title: String
     public let message: String?
     public let icon: String?
     public let actionTitle: String?
     public let action: (() -> Void)?
     public var variant: EmptyStateVariant

     public init(
        title: String,
        message: String? = nil,
        icon: String? = "tray",
        actionTitle: String? = nil,
        action: (() -> Void)? = nil,
        variant: EmptyStateVariant = .default
    ) {
        self.title = title
        self.message = message
        self.icon = icon
        self.actionTitle = actionTitle
        self.action = action
        self.variant = variant
    }

     public var body: some View {
        VStack(alignment: variant.alignment, spacing: variant.spacing) {
            if variant.showsIcon, let icon {
                Image(systemName: icon)
                    .font(.ornament(variant.iconSize, weight: .medium))
                    .foregroundStyle(AppColors.interactionPrimary)
                    .frame(width: variant.iconContainerSize, height: variant.iconContainerSize)
                    .background(
                        AppColors.interactionBackground,
                        in: RoundedRectangle(cornerRadius: variant.iconCornerRadius, style: .continuous)
                    )
                    .accessibilityHidden(true)
            }

            Text(title)
                .font(variant.titleFont)
                .foregroundStyle(AppColors.textPrimary)
                .multilineTextAlignment(variant.textAlignment)
                .fixedSize(horizontal: false, vertical: true)

            if let message {
                Text(message)
                    .font(.appCaption)
                    .foregroundStyle(AppColors.textSecondary)
                    .multilineTextAlignment(variant.textAlignment)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let actionTitle, let action {
                PrimaryAction(title: actionTitle, variant: .compact, action: action)
            }
        }
        .frame(maxWidth: variant.maxCopyWidth, alignment: variant.frameAlignment)
        .padding(variant.contentPadding)
        .frame(maxWidth: .infinity, alignment: variant.frameAlignment)
        .accessibilityElement(children: .combine)
    }
}

public enum EmptyStateVariant {
    case `default`
    case compactText
    case section

     public var showsIcon: Bool { self != .compactText }

     public var spacing: CGFloat { self == .default ? Spacing.sm : Spacing.md }

     public var iconContainerSize: CGFloat {
        switch self {
        case .default: 60
        case .section: 44
        case .compactText: 0
        }
    }

     public var iconCornerRadius: CGFloat { self == .default ? Radius.lg + Spacing.xs : Radius.md }

     public var iconSize: CGFloat {
        switch self {
        case .default: 28
        case .section: 20
        case .compactText: 0
        }
    }

     public var titleFont: Font {
        switch self {
        case .default: .stateTitle
        case .compactText, .section: .action
        }
    }

     public var maxCopyWidth: CGFloat? {
        switch self {
        case .default: 320
        case .compactText: 250
        case .section: nil
        }
    }

     public var contentPadding: CGFloat {
        switch self {
        case .default: Spacing.xl
        case .compactText: Spacing.md
        case .section: Spacing.lg
        }
    }

     public var alignment: HorizontalAlignment { self == .default ? .center : .leading }
     public var textAlignment: TextAlignment { self == .default ? .center : .leading }
     public var frameAlignment: Alignment { self == .default ? .center : .leading }
}

public typealias EmptyState = EmptyStateView

#Preview {
    EmptyStateView(
        title: "暂无行程",
        message: "开始规划你的下一次户外探险吧",
        actionTitle: "创建行程"
    ) {
        print("Create tapped")
    }
}
