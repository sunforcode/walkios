import SwiftUI

/// 字体 Token；按 ui-new 语义字号映射为 iOS Dynamic Type 字体。
public enum AppTypography {
     public static let brandMark = Font.system(size: 18, weight: .bold)
     public static let displayTitle = Font.system(size: 32, weight: .bold)
     public static let editorialTitleBaseSize: CGFloat = 42
     public static func editorialTitle(size: CGFloat) -> Font {
         .system(size: size, weight: .semibold, design: .serif)
     }
     public static let pageTitle = Font.system(size: 32, weight: .bold)
     public static let contextTitle = Font.system(size: 18, weight: .semibold)
     public static let dayDate = Font.system(size: 27, weight: .bold)
     public static let sequence = Font.system(size: 13, weight: .bold, design: .monospaced)
     public static let sectionTitle = Font.system(size: 19, weight: .semibold)
     public static let sceneTitle = Font.system(size: 34, weight: .bold)
     public static let stateTitle = Font.system(size: 17, weight: .semibold)
     public static let action = Font.system(size: 15, weight: .semibold)
     public static let navTitle = Font.system(size: 17, weight: .semibold)
     public static let listTitle = Font.system(size: 14, weight: .semibold)
     public static let appBody = Font.system(size: 15, weight: .regular)
     public static let appCaption = Font.system(size: 13, weight: .regular)
     public static let micro = Font.system(size: 10, weight: .medium)
     public static let microStrong = Font.system(size: 10, weight: .bold)
     public static let tag = Font.system(size: 10, weight: .bold)
     public static let tabLabel = Font.system(size: 10, weight: .bold)
     public static let metricValue = Font.system(size: 18, weight: .semibold, design: .monospaced)
     public static let metricLabel = Font.system(size: 12, weight: .regular)
     public static let metricCompactValue = Font.system(size: 15, weight: .bold, design: .monospaced)
     public static let metricCompactLabel = Font.system(size: 9, weight: .regular)
     public static let weatherConclusion = Font.system(size: 12, weight: .semibold)
     public static let weatherImpact = Font.system(size: 9, weight: .regular)
     public static let heroTitle = Font.system(size: 48, weight: .bold)
     public static let heroSubtitle = Font.system(size: 16, weight: .regular)
     public static let detailTitle = Font.system(size: 25, weight: .bold)
     public static let cardTitle = Font.system(size: 18, weight: .semibold)
     public static let authTitle = Font.system(size: 21, weight: .bold)
     public static let identityTitle = Font.system(size: 18, weight: .semibold)
     public static let dateTitle = Font.system(size: 16, weight: .semibold)
     public static let bodyLarge = Font.system(size: 16, weight: .regular)
     public static let bodySmall = Font.system(size: 14, weight: .regular)
     public static let bodyEmphasis = Font.system(size: 15, weight: .semibold)
     public static let label = Font.system(size: 12, weight: .medium)
     public static let timelineTime = Font.system(size: 13, weight: .regular, design: .monospaced)
     public static let sequenceCompact = Font.system(size: 11, weight: .bold, design: .monospaced)
     public static let metricUnit = Font.system(size: 12, weight: .regular)
     public static let metricGridValue = Font.system(size: 12, weight: .bold, design: .monospaced)
     public static let metricGridLabel = Font.system(size: 8, weight: .regular)
}

public extension Font {
     public static let brandMark = AppTypography.brandMark
     public static let displayTitle = AppTypography.displayTitle
     public static func editorialTitle(size: CGFloat) -> Font { AppTypography.editorialTitle(size: size) }
     public static let pageTitle = AppTypography.pageTitle
     public static let contextTitle = AppTypography.contextTitle
     public static let dayDate = AppTypography.dayDate
     public static let sequence = AppTypography.sequence
     public static let sectionTitle = AppTypography.sectionTitle
     public static let sceneTitle = AppTypography.sceneTitle
     public static let stateTitle = AppTypography.stateTitle
     public static let action = AppTypography.action
     public static let navTitle = AppTypography.navTitle
     public static let listTitle = AppTypography.listTitle
     public static let appBody = AppTypography.appBody
     public static let appCaption = AppTypography.appCaption
     public static let micro = AppTypography.micro
     public static let microStrong = AppTypography.microStrong
     public static let tag = AppTypography.tag
     public static let tabLabel = AppTypography.tabLabel
     public static let metricValue = AppTypography.metricValue
     public static let metricLabel = AppTypography.metricLabel
     public static let metricCompactValue = AppTypography.metricCompactValue
     public static let metricCompactLabel = AppTypography.metricCompactLabel
     public static let weatherConclusion = AppTypography.weatherConclusion
     public static let weatherImpact = AppTypography.weatherImpact
     public static let heroTitle = AppTypography.heroTitle
     public static let heroSubtitle = AppTypography.heroSubtitle
     public static let detailTitle = AppTypography.detailTitle
     public static let cardTitle = AppTypography.cardTitle
     public static let authTitle = AppTypography.authTitle
     public static let identityTitle = AppTypography.identityTitle
     public static let dateTitle = AppTypography.dateTitle
     public static let bodyLarge = AppTypography.bodyLarge
     public static let bodySmall = AppTypography.bodySmall
     public static let bodyEmphasis = AppTypography.bodyEmphasis
     public static let label = AppTypography.label
     public static let timelineTime = AppTypography.timelineTime
     public static let sequenceCompact = AppTypography.sequenceCompact
     public static let metricUnit = AppTypography.metricUnit
     public static let metricGridValue = AppTypography.metricGridValue
     public static let metricGridLabel = AppTypography.metricGridLabel

    /// 装饰性衬底字形（数字水印、背景大字）。
    /// 不占用字号标尺；每个场景字号必须先在根仓对应 Page UI 规格登记。
     public static func ornament(_ size: CGFloat, weight: Font.Weight = .ultraLight) -> Font {
        .system(size: size, weight: weight)
    }
}
