import Foundation

/// Spacing tokens shared with the Flutter application.
enum Spacing {
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 12
    static let lg: CGFloat = 16
    static let xl: CGFloat = 24
    static let xxl: CGFloat = 32
    static let xxxl: CGFloat = 48
    static let hero: CGFloat = 80

    static let pageHorizontal: CGFloat = 16
    static let heroHorizontal: CGFloat = 20
    static let pageVertical: CGFloat = 16
    static let componentPadding: CGFloat = 16
    static let listItemGap: CGFloat = 12
    static let sectionGap: CGFloat = 24
    static let navBarHeight: CGFloat = 44

    // Compatibility aliases for call sites authored before the canonical scale correction.
    static let s12 = md
    static let legacyMd: CGFloat = 16
    static let legacyLg: CGFloat = 24
}
