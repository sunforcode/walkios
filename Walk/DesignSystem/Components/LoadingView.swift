import SwiftUI

/// 加载视图组件
struct LoadingView: View {
    var body: some View {
        UtilityPageContainer {
            VStack(spacing: Spacing.md) {
                ProgressView()
                    .tint(AppColors.interactionPrimary)
                    .scaleEffect(1.25)
                Text("加载中...")
                    .font(.bodyLarge)
                    .foregroundStyle(AppColors.textSecondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

#Preview {
    LoadingView()
}
