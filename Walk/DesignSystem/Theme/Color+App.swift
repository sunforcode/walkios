import SwiftUI

enum AppColors {
    // MARK: - Green-black foundation
    static let pageBase = Color(red: 4 / 255, green: 12 / 255, blue: 8 / 255)
    static let pageMiddle = Color(red: 7 / 255, green: 19 / 255, blue: 15 / 255)
    static let pageOuter = Color(red: 13 / 255, green: 31 / 255, blue: 24 / 255)

    // MARK: - Surfaces
    static let surfacePrimary = Color(red: 16 / 255, green: 35 / 255, blue: 27 / 255)
    static let surfaceElevated = Color(red: 23 / 255, green: 49 / 255, blue: 38 / 255)
    static let surfaceGlass = Color.white.opacity(0.12)
    static let surfaceInput = Color.white.opacity(0.04)
    static let surfaceDivider = Color.white.opacity(0.04)
    static let surfaceOverlay = Color.black.opacity(0.50)
    static let surfaceToast = Color.black.opacity(0.80)

    // MARK: - Text and interaction
    static let textPrimary = Color.white
    static let textSecondary = Color(red: 184 / 255, green: 194 / 255, blue: 189 / 255)
    static let textWeak = Color(red: 143 / 255, green: 154 / 255, blue: 149 / 255)
    static let interactionPrimary = Color(red: 139 / 255, green: 214 / 255, blue: 173 / 255)
    static let interactionBackground = interactionPrimary.opacity(0.12)
    static let interactionFocus = interactionPrimary.opacity(0.30)
    static let borderPrimary = Color(red: 113 / 255, green: 135 / 255, blue: 123 / 255)
    static let borderStrong = Color(red: 143 / 255, green: 163 / 255, blue: 153 / 255)
    static let shadowCard = Color.black.opacity(0.25)
    static let shadowOverlay = Color.black.opacity(0.40)

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
    static let warning = Color(red: 255 / 255, green: 183 / 255, blue: 77 / 255)

    // MARK: - Map semantics
    static let mapRoute = interactionPrimary
    static let mapStart = statusProgress
    static let mapEnd = statusCancelled
    static let mapWaypoint = statusCompleted
    static let mapPOI = warning

    // MARK: - Route detail overlay
    static let sheetBackground = Color.clear
    static let sheetTextPrimary = Color.white
    static let sheetTextSecondary = Color(red: 186 / 255, green: 205 / 255, blue: 194 / 255)
    static let sheetTextWeak = Color(red: 151 / 255, green: 177 / 255, blue: 162 / 255)
    static let sheetTextTag = Color(red: 210 / 255, green: 226 / 255, blue: 217 / 255)
    static let sheetDivider = Color.white.opacity(0.12)
    static let sheetDragHandle = Color.white.opacity(0.35)
    static let sheetTagBackground = Color.white.opacity(0.08)
    static let sheetCardBackground = Color.white.opacity(0.06)
    static let sheetSectionBackground = Color(red: 20 / 255, green: 48 / 255, blue: 36 / 255)
}
