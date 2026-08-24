import SwiftUI

enum AppTypography {
    static let heroTitle = Font.system(size: 48, weight: .bold)
    static let heroSubtitle = Font.system(size: 16, weight: .regular)
    static let displayTitle = Font.system(size: 32, weight: .bold)
    static let pageTitle = Font.system(size: 28, weight: .bold)
    static let sectionTitle = Font.system(size: 20, weight: .semibold)
    static let cardTitle = Font.system(size: 18, weight: .semibold)
    static let bodyLarge = Font.system(size: 16, weight: .regular)
    static let body = Font.system(size: 15, weight: .regular)
    static let bodySmall = Font.system(size: 14, weight: .regular)
    static let caption = Font.system(size: 13, weight: .regular)
    static let label = Font.system(size: 12, weight: .medium)
    static let metricValue = Font.system(size: 18, weight: .semibold, design: .monospaced)
    static let metricUnit = Font.system(size: 12, weight: .regular)

    // Compatibility aliases used by existing screens.
    static let hero = heroTitle
    static let display = displayTitle
    static let page = pageTitle
    static let section = sectionTitle
    static let card = cardTitle
    static let nav = Font.system(size: 17, weight: .semibold)
    static let micro = Font.system(size: 10)
    static let button = Font.system(size: 15, weight: .semibold)
}

extension Font {
    // Canonical names
    static let heroTitle = AppTypography.heroTitle
    static let heroSubtitle = AppTypography.heroSubtitle
    static let displayTitle = AppTypography.displayTitle
    static let pageTitle = AppTypography.pageTitle
    static let sectionTitle = AppTypography.sectionTitle
    static let cardTitle = AppTypography.cardTitle
    static let metricValue = AppTypography.metricValue
    static let metricUnit = AppTypography.metricUnit

    // Compatibility aliases used by existing screens.
    static let hero = AppTypography.hero
    static let display = AppTypography.display
    static let page = AppTypography.page
    static let section = AppTypography.section
    static let card = AppTypography.card
    static let nav = AppTypography.nav
    static let bodyLarge = AppTypography.bodyLarge
    static let bodySmall = AppTypography.bodySmall
    static let label = AppTypography.label
    static let micro = AppTypography.micro
    static let button = AppTypography.button
    static let largeTitle = AppTypography.display
    static let title = AppTypography.page
    static let title2 = AppTypography.section
    static let headline = AppTypography.nav
    static let body = AppTypography.body
    static let callout = AppTypography.bodyLarge
    static let subheadline = AppTypography.bodySmall
    static let footnote = AppTypography.caption
    static let caption = AppTypography.caption
}
