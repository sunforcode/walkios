import SwiftUI
import WalkDesignSystem

enum HomeStyle {
    // 与路线、我的两个一级页共用同一色彩序列（pageOuter→pageMiddle→pageBase），
    // 只保留首页特有的渐变方向与山形剪影作为页面构图差异。
    static let gradientStops: [Gradient.Stop] = [
        .init(color: AppColors.pageOuter, location: 0),
        .init(color: AppColors.pageMiddle, location: 0.46),
        .init(color: AppColors.pageBase, location: 1),
    ]
    static let gradientStartPoint = UnitPoint(x: 0, y: 0)
    static let gradientEndPoint = UnitPoint(x: 1, y: 1)
    static let weatherPlaceholder = "天气摘要暂不可用"
}
