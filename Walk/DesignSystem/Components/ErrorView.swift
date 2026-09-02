import SwiftUI

/// 错误视图组件
struct ErrorView: View {
    let message: String
    let retryAction: (() -> Void)?

    init(message: String, retry: (() -> Void)? = nil) {
        self.message = message
        self.retryAction = retry
    }

    var body: some View {
        ZStack {
            AppColors.pageBase.ignoresSafeArea()

            VStack(spacing: Spacing.md) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(AppColors.statusCancelled)

                Text(message)
                    .font(.body)
                    .foregroundStyle(AppColors.textSecondary)
                    .multilineTextAlignment(.center)

                if let retryAction {
                    Button(action: retryAction) {
                        Text("重试")
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
    ErrorView(message: "网络连接失败，请检查网络设置") {
        print("Retry tapped")
    }
}
