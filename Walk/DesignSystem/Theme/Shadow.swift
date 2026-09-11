import SwiftUI

struct ShadowToken {
    let color: Color
    let opacity: Double
    let radius: CGFloat
    let x: CGFloat
    let y: CGFloat

    init(
        color: Color = .black,
        opacity: Double,
        radius: CGFloat,
        x: CGFloat,
        y: CGFloat
    ) {
        self.color = color
        self.opacity = opacity
        self.radius = radius
        self.x = x
        self.y = y
    }

    var resolvedColor: Color { color.opacity(opacity) }
}

enum AppShadow {
    static let card = ShadowToken(opacity: 0.18, radius: 14, x: 0, y: 4)
    static let floating = ShadowToken(opacity: 0.20, radius: 8, x: 0, y: 2)
    static let navigation = ShadowToken(opacity: 0.32, radius: 38, x: 0, y: 14)
    static let panel = ShadowToken(opacity: 0.30, radius: 16, x: 0, y: 4)
    static let overlay = ShadowToken(opacity: 0.40, radius: 24, x: 0, y: 8)
    static let compactAction = ShadowToken(color: AppColors.interactionPrimary, opacity: 0.18, radius: 24, x: 0, y: 8)
    static let interactionGlow = ShadowToken(color: AppColors.interactionPrimary, opacity: 0.30, radius: 20, x: 0, y: 0)
}

extension View {
    func appShadow(_ token: ShadowToken) -> some View {
        shadow(color: token.resolvedColor, radius: token.radius, x: token.x, y: token.y)
    }
}
