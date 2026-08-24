import SwiftUI

struct ShadowToken {
    let opacity: Double
    let radius: CGFloat
    let x: CGFloat
    let y: CGFloat

    var color: Color { .black.opacity(opacity) }
}

enum AppShadow {
    static let floating = ShadowToken(opacity: 0.20, radius: 8, x: 0, y: 2)
    static let panel = ShadowToken(opacity: 0.30, radius: 16, x: 0, y: 4)
    static let overlay = ShadowToken(opacity: 0.40, radius: 24, x: 0, y: 8)
}

extension View {
    func appShadow(_ token: ShadowToken) -> some View {
        shadow(color: token.color, radius: token.radius, x: token.x, y: token.y)
    }
}
