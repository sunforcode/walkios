import SwiftUI

struct EmptyStateView: View {
    let title: String
    let message: String?
    let icon: String?
    let actionTitle: String?
    let action: (() -> Void)?
    var variant: EmptyStateVariant

    init(
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

    var body: some View {
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

enum EmptyStateVariant {
    case `default`
    case compactText
    case section

    var showsIcon: Bool { self != .compactText }

    var spacing: CGFloat { self == .default ? Spacing.sm : Spacing.md }

    var iconContainerSize: CGFloat {
        switch self {
        case .default: 60
        case .section: 44
        case .compactText: 0
        }
    }

    var iconCornerRadius: CGFloat { self == .default ? Radius.lg + Spacing.xs : Radius.md }

    var iconSize: CGFloat {
        switch self {
        case .default: 28
        case .section: 20
        case .compactText: 0
        }
    }

    var titleFont: Font {
        switch self {
        case .default: .stateTitle
        case .compactText, .section: .action
        }
    }

    var maxCopyWidth: CGFloat? {
        switch self {
        case .default: 320
        case .compactText: 250
        case .section: nil
        }
    }

    var contentPadding: CGFloat {
        switch self {
        case .default: Spacing.xl
        case .compactText: Spacing.md
        case .section: Spacing.lg
        }
    }

    var alignment: HorizontalAlignment { self == .default ? .center : .leading }
    var textAlignment: TextAlignment { self == .default ? .center : .leading }
    var frameAlignment: Alignment { self == .default ? .center : .leading }
}

typealias EmptyState = EmptyStateView

#Preview {
    EmptyStateView(
        title: "暂无行程",
        message: "开始规划你的下一次户外探险吧",
        actionTitle: "创建行程"
    ) {
        print("Create tapped")
    }
}
