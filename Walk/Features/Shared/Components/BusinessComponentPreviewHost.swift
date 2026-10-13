#if DEBUG
import SwiftUI
import WalkDesignSystem

/// 业务组件独立预览的统一外壳：只提供页面底色与宽度约束，不承载任何业务数据。
struct BusinessComponentPreviewHost<Content: View>: View {
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        ScrollView {
            content
                .frame(maxWidth: 560, alignment: .leading)
                .padding(Spacing.lg)
                .frame(maxWidth: .infinity, alignment: .top)
        }
        .background(AppColors.pageBase)
        .foregroundStyle(AppColors.textPrimary)
    }
}
#endif
