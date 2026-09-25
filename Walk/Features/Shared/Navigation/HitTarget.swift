import CoreGraphics

/// 触控目标下限。
///
/// 依据 docs/ui/app-structure.md「触控目标至少 44 × 44 pt」。这是 App 结构规则，不是 Design Token，
/// 因此不放入 WalkDesignSystem 的 Token 体系；Feature 与 App 共用此常量。
enum HitTarget {
    static let minimum: CGFloat = 44
}
