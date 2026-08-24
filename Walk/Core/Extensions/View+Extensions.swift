import SwiftUI

extension View {
    /// 条件修饰符
    @ViewBuilder
    func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }

    /// 卡片背景样式
    func cardBackground() -> some View {
        self
            .background(AppColors.surfaceCard)
            .clipShape(RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                    .stroke(AppColors.border, lineWidth: 1)
            }
            .appShadow(AppShadow.floating)
    }

    /// 内容边距
    func contentPadding() -> some View {
        self.padding(.horizontal, Spacing.pageHorizontal)
            .padding(.vertical, Spacing.s12)
    }
}
