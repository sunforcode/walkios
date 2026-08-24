import SwiftUI

/// Canonical color tokens shared with the Flutter application.
enum AppColors {
    // MARK: - Dark backgrounds
    static let bgBase = Color(red: 10 / 255, green: 10 / 255, blue: 26 / 255)
    static let bgMap = Color(red: 13 / 255, green: 27 / 255, blue: 42 / 255)
    static let bgGradientEnd = Color(red: 27 / 255, green: 40 / 255, blue: 56 / 255)
    static let bgPanel = Color(red: 26 / 255, green: 26 / 255, blue: 46 / 255)
    static let bgDrawer = Color(red: 17 / 255, green: 17 / 255, blue: 34 / 255)

    // MARK: - Brand and interaction
    static let brandStart = Color(red: 59 / 255, green: 130 / 255, blue: 246 / 255)
    static let brandEnd = Color(red: 99 / 255, green: 102 / 255, blue: 241 / 255)
    static let interactiveAccent = Color(red: 100 / 255, green: 200 / 255, blue: 255 / 255)
    static let interactiveAccentSoft = interactiveAccent.opacity(0.60)
    static let interactiveAccentBackground = interactiveAccent.opacity(0.12)
    static let interactiveAccentFocus = interactiveAccent.opacity(0.30)
    static let interactiveCTA = Color.white.opacity(0.12)
    static let interactiveCTABorder = Color.white.opacity(0.20)

    // MARK: - Dark text and surfaces
    static let textPrimary = Color.white
    static let textSecondary = Color.white.opacity(0.70)
    static let textWeak = Color.white.opacity(0.50)
    static let surfaceCard = Color.white.opacity(0.06)
    static let surfaceCardHover = Color.white.opacity(0.08)
    static let surfaceGlass = Color.white.opacity(0.12)
    static let surfaceInput = Color.white.opacity(0.04)
    static let surfaceInputFocus = interactiveAccent.opacity(0.04)
    static let surfaceDivider = Color.white.opacity(0.04)
    static let surfaceOverlay = Color.black.opacity(0.50)
    static let surfaceToast = Color.black.opacity(0.80)
    static let border = Color.white.opacity(0.10)

    // MARK: - Immersive route background
    static let routeOuter = Color(red: 13 / 255, green: 31 / 255, blue: 24 / 255)
    static let routeMiddle = Color(red: 7 / 255, green: 19 / 255, blue: 15 / 255)
    static let routeInner = Color(red: 4 / 255, green: 12 / 255, blue: 8 / 255)

    // MARK: - Semantic colors
    static let success = Color(red: 76 / 255, green: 175 / 255, blue: 80 / 255)
    static let warning = Color(red: 255 / 255, green: 183 / 255, blue: 77 / 255)
    static let error = Color(red: 255 / 255, green: 100 / 255, blue: 100 / 255)
    static let info = interactiveAccent

    // MARK: - Status
    static let statusPlanning = Color(red: 251 / 255, green: 191 / 255, blue: 36 / 255)
    static let statusPlanningBackground = Color(red: 245 / 255, green: 158 / 255, blue: 11 / 255).opacity(0.15)
    static let statusConfirmed = Color(red: 96 / 255, green: 165 / 255, blue: 250 / 255)
    static let statusConfirmedBackground = Color(red: 59 / 255, green: 130 / 255, blue: 246 / 255).opacity(0.15)
    static let statusProgress = Color(red: 74 / 255, green: 222 / 255, blue: 128 / 255)
    static let statusProgressBackground = Color(red: 34 / 255, green: 197 / 255, blue: 94 / 255).opacity(0.12)
    static let statusCompleted = Color(red: 192 / 255, green: 132 / 255, blue: 252 / 255)
    static let statusCompletedBackground = Color(red: 168 / 255, green: 85 / 255, blue: 247 / 255).opacity(0.12)
    static let statusCancelled = Color(red: 248 / 255, green: 113 / 255, blue: 113 / 255)
    static let statusCancelledBackground = Color(red: 239 / 255, green: 68 / 255, blue: 68 / 255).opacity(0.10)

    // MARK: - Light detail sheet
    static let sheetBackground = Color.white
    static let sheetTextPrimary = Color(red: 26 / 255, green: 26 / 255, blue: 26 / 255)
    static let sheetTextSecondary = Color(red: 136 / 255, green: 136 / 255, blue: 136 / 255)
    static let sheetTextWeak = Color(red: 170 / 255, green: 170 / 255, blue: 170 / 255)
    static let sheetTextTag = Color(red: 85 / 255, green: 85 / 255, blue: 85 / 255)
    static let sheetDivider = Color.black.opacity(0.06)
    static let sheetDragHandle = Color.black.opacity(0.15)
    static let sheetTagBackground = Color.black.opacity(0.05)
    static let sheetCardBackground = Color.black.opacity(0.03)

    // Compatibility aliases used by existing screens.
    static let accent = interactiveAccent
    static let detailSheet = sheetBackground
    static let detailTextPrimary = sheetTextPrimary
    static let detailTextSecondary = sheetTextSecondary
}

extension Color {
    // Canonical names
    static let bgBase = AppColors.bgBase
    static let bgMap = AppColors.bgMap
    static let bgGradientEnd = AppColors.bgGradientEnd
    static let bgPanel = AppColors.bgPanel
    static let bgDrawer = AppColors.bgDrawer
    static let brandStart = AppColors.brandStart
    static let brandEnd = AppColors.brandEnd
    static let textWeak = AppColors.textWeak
    static let surfaceCard = AppColors.surfaceCard
    static let surfaceGlass = AppColors.surfaceGlass
    static let surfaceInput = AppColors.surfaceInput
    static let interactiveAccent = AppColors.interactiveAccent
    static let routeOuter = AppColors.routeOuter
    static let routeMiddle = AppColors.routeMiddle
    static let routeInner = AppColors.routeInner
    static let sheetBackground = AppColors.sheetBackground
    static let sheetTextPrimary = AppColors.sheetTextPrimary
    static let sheetTextSecondary = AppColors.sheetTextSecondary

    // Compatibility aliases used by existing screens.
    static let primary = AppColors.interactiveAccent
    static let primaryVariant = AppColors.interactiveAccent
    static let secondary = AppColors.textSecondary
    static let accent = AppColors.interactiveAccent
    static let background = AppColors.bgBase
    static let surfaceBackground = AppColors.bgPanel
    static let cardBackground = AppColors.surfaceCard
    static let groupedBackground = AppColors.bgBase
    static let textPrimary = AppColors.textPrimary
    static let textSecondary = AppColors.textSecondary
    static let textTertiary = AppColors.textWeak
    static let success = AppColors.success
    static let warning = AppColors.warning
    static let error = AppColors.error
    static let info = AppColors.info
    static let divider = AppColors.border
    static let border = AppColors.border
    static let detailSheet = AppColors.sheetBackground
    static let detailTextPrimary = AppColors.sheetTextPrimary
    static let detailTextSecondary = AppColors.sheetTextSecondary
}
