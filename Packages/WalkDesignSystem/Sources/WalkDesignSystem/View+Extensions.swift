import SwiftUI

public extension View {
    /// 条件修饰符
    @ViewBuilder
     public func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }

    /// 卡片背景样式
     public func cardBackground() -> some View {
        self
            .background(AppColors.surfacePrimary)
            .clipShape(RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                    .stroke(AppColors.borderPrimary, lineWidth: 1)
            }
            .appShadow(AppShadow.floating)
    }

    /// 内容边距
     public func contentPadding() -> some View {
        self.padding(.horizontal, Spacing.pageHorizontal)
            .padding(.vertical, Spacing.md)
    }
}
