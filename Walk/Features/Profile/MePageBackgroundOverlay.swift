import SwiftUI
import WalkDesignSystem

/// 我的页已登录态背景：底部渐变叠加层，用于图片之上渐变过渡到页面底色。
/// 只属于 PAGE-ME，W5 从设计系统移回 Profile；渐变登记于 DesignSystemTests 的 Feature 渐变白名单。
struct MePageBackgroundOverlay: View {
    var body: some View {
        LinearGradient(
            colors: [AppColors.pageBase.opacity(0), AppColors.pageBase],
            startPoint: .init(x: 0.5, y: 0.72),
            endPoint: .bottom
        )
    }
}
