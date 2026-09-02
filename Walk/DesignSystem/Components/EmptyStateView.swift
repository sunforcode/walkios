import SwiftUI

/// 空状态视图组件
struct EmptyStateView: View {
    let title: String
    let message: String?
    let icon: String?
    let actionTitle: String?
    let action: (() -> Void)?

    init(
        title: String,
        message: String? = nil,
        icon: String? = "tray",
        actionTitle: String? = nil,
        action: (() -> Void)? = nil
    ) {
        self.title = title
        self.message = message
        self.icon = icon
        self.actionTitle = actionTitle
        self.action = action
    }

    var body: some View {
        ZStack {
            AppColors.pageBase.ignoresSafeArea()

            VStack(spacing: Spacing.md) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 48))
                        .foregroundStyle(AppColors.textWeak)
                }

                Text(title)
                    .font(.section)
                    .foregroundStyle(AppColors.textPrimary)

                if let message {
                    Text(message)
                        .font(.bodyLarge)
                        .foregroundStyle(AppColors.textSecondary)
                        .multilineTextAlignment(.center)
                }

                if let actionTitle, let action {
                    Button(action: action) {
                        Text(actionTitle)
                            .font(.button)
                            .foregroundStyle(AppColors.pageBase)
                            .padding(.horizontal, Spacing.xl)
                            .padding(.vertical, Spacing.md)
                            .background(AppColors.interactionPrimary)
                            .clipShape(RoundedRectangle(cornerRadius: Radius.sm, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(Spacing.xl)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

#Preview {
    EmptyStateView(
        title: "暂无行程",
        message: "开始规划你的下一次户外探险吧",
        actionTitle: "创建行程"
    ) {
        print("Create tapped")
    }
}
