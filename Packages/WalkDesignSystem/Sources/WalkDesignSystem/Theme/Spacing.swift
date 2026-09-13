import Foundation

/// Spacing tokens mapped from the approved design contract.
public enum Spacing {
     public static let xs: CGFloat = 4
     public static let sm: CGFloat = 8
     public static let md: CGFloat = 12
     public static let lg: CGFloat = 16
     public static let xl: CGFloat = 24
     public static let xxl: CGFloat = 32
     public static let xxxl: CGFloat = 48

     public static let pageHorizontal = lg

     public static let navBarHeight: CGFloat = 44

     /// 底部 Home 指示器安全区估算值（Feature 不得直接读 safeAreaInsets，用此 token 替代）。
     public static let safeAreaBottom: CGFloat = 34
}
