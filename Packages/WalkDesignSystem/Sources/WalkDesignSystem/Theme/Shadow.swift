import SwiftUI

public struct ShadowToken {
     public let color: Color
     public let opacity: Double
     public let radius: CGFloat
     public let x: CGFloat
     public let y: CGFloat

     public init(
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

     public var resolvedColor: Color { color.opacity(opacity) }
}

public enum AppShadow {
     public static let card = ShadowToken(opacity: 0.18, radius: 14, x: 0, y: 4)
     public static let floating = ShadowToken(opacity: 0.20, radius: 8, x: 0, y: 2)
     public static let navigation = ShadowToken(opacity: 0.32, radius: 38, x: 0, y: 14)
     public static let panel = ShadowToken(opacity: 0.30, radius: 16, x: 0, y: 4)
     public static let overlay = ShadowToken(opacity: 0.40, radius: 24, x: 0, y: 8)
     public static let compactAction = ShadowToken(color: AppColors.interactionPrimary, opacity: 0.18, radius: 24, x: 0, y: 8)
     public static let interactionGlow = ShadowToken(color: AppColors.interactionPrimary, opacity: 0.30, radius: 20, x: 0, y: 0)
}

public extension View {
     public func appShadow(_ token: ShadowToken) -> some View {
        shadow(color: token.resolvedColor, radius: token.radius, x: token.x, y: token.y)
    }
}
