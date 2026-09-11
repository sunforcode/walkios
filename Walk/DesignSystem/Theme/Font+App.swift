import SwiftUI

/// 字体 Token；按 ui-new 语义字号映射为 iOS Dynamic Type 字体。
enum AppTypography {
    static let brandMark = Font.system(size: 18, weight: .bold)
    static let displayTitle = Font.system(size: 32, weight: .bold)
    static let pageTitle = Font.system(size: 26, weight: .bold)
    static let contextTitle = Font.system(size: 18, weight: .semibold)
    static let dayDate = Font.system(size: 27, weight: .bold)
    static let sequence = Font.system(size: 13, weight: .bold, design: .monospaced)
    static let sectionTitle = Font.system(size: 19, weight: .semibold)
    static let sceneTitle = Font.system(size: 34, weight: .bold)
    static let stateTitle = Font.system(size: 17, weight: .semibold)
    static let action = Font.system(size: 15, weight: .semibold)
    static let navTitle = Font.system(size: 17, weight: .semibold)
    static let listTitle = Font.system(size: 14, weight: .semibold)
    static let appBody = Font.system(size: 15, weight: .regular)
    static let appCaption = Font.system(size: 13, weight: .regular)
    static let micro = Font.system(size: 10, weight: .medium)
    static let microStrong = Font.system(size: 10, weight: .bold)
    static let tag = Font.system(size: 10, weight: .bold)
    static let tabLabel = Font.system(size: 10, weight: .bold)
    static let metricValue = Font.system(size: 18, weight: .semibold, design: .monospaced)
    static let metricLabel = Font.system(size: 12, weight: .regular)
    static let metricCompactValue = Font.system(size: 15, weight: .bold, design: .monospaced)
    static let metricCompactLabel = Font.system(size: 9, weight: .regular)
    static let weatherConclusion = Font.system(size: 12, weight: .semibold)
    static let weatherImpact = Font.system(size: 9, weight: .regular)
    static let heroTitle = Font.system(size: 48, weight: .bold)
    static let heroSubtitle = Font.system(size: 16, weight: .regular)
    static let detailTitle = Font.system(size: 25, weight: .bold)
    static let cardTitle = Font.system(size: 18, weight: .semibold)
    static let authTitle = Font.system(size: 21, weight: .bold)
    static let identityTitle = Font.system(size: 18, weight: .semibold)
    static let dateTitle = Font.system(size: 16, weight: .semibold)
    static let bodyLarge = Font.system(size: 16, weight: .regular)
    static let bodySmall = Font.system(size: 14, weight: .regular)
    static let bodyEmphasis = Font.system(size: 15, weight: .semibold)
    static let label = Font.system(size: 12, weight: .medium)
    static let timelineTime = Font.system(size: 13, weight: .regular, design: .monospaced)
    static let sequenceCompact = Font.system(size: 11, weight: .bold, design: .monospaced)
    static let metricUnit = Font.system(size: 12, weight: .regular)
    static let metricGridValue = Font.system(size: 12, weight: .bold, design: .monospaced)
    static let metricGridLabel = Font.system(size: 8, weight: .regular)
}

extension Font {
    static let brandMark = AppTypography.brandMark
    static let displayTitle = AppTypography.displayTitle
    static let pageTitle = AppTypography.pageTitle
    static let contextTitle = AppTypography.contextTitle
    static let dayDate = AppTypography.dayDate
    static let sequence = AppTypography.sequence
    static let sectionTitle = AppTypography.sectionTitle
    static let sceneTitle = AppTypography.sceneTitle
    static let stateTitle = AppTypography.stateTitle
    static let action = AppTypography.action
    static let navTitle = AppTypography.navTitle
    static let listTitle = AppTypography.listTitle
    static let appBody = AppTypography.appBody
    static let appCaption = AppTypography.appCaption
    static let micro = AppTypography.micro
    static let microStrong = AppTypography.microStrong
    static let tag = AppTypography.tag
    static let tabLabel = AppTypography.tabLabel
    static let metricValue = AppTypography.metricValue
    static let metricLabel = AppTypography.metricLabel
    static let metricCompactValue = AppTypography.metricCompactValue
    static let metricCompactLabel = AppTypography.metricCompactLabel
    static let weatherConclusion = AppTypography.weatherConclusion
    static let weatherImpact = AppTypography.weatherImpact
    static let heroTitle = AppTypography.heroTitle
    static let heroSubtitle = AppTypography.heroSubtitle
    static let detailTitle = AppTypography.detailTitle
    static let cardTitle = AppTypography.cardTitle
    static let authTitle = AppTypography.authTitle
    static let identityTitle = AppTypography.identityTitle
    static let dateTitle = AppTypography.dateTitle
    static let bodyLarge = AppTypography.bodyLarge
    static let bodySmall = AppTypography.bodySmall
    static let bodyEmphasis = AppTypography.bodyEmphasis
    static let label = AppTypography.label
    static let timelineTime = AppTypography.timelineTime
    static let sequenceCompact = AppTypography.sequenceCompact
    static let metricUnit = AppTypography.metricUnit
    static let metricGridValue = AppTypography.metricGridValue
    static let metricGridLabel = AppTypography.metricGridLabel

    /// 装饰性衬底字形（数字水印、背景大字）。
    /// 不占用字号标尺；每个场景字号必须先在根仓对应 Page UI 规格登记。
    static func ornament(_ size: CGFloat, weight: Font.Weight = .ultraLight) -> Font {
        .system(size: size, weight: weight)
    }
}
