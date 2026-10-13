import SwiftUI
import WalkData
import WalkDesignSystem

enum TripBusinessComponents {}

enum TripInformationState: Equatable {
    case unknown
    case missing
    case pendingVerification
    case stale
    case unavailable

    var label: String {
        switch self {
        case .unknown: "未知"
        case .missing: "缺失"
        case .pendingVerification: "待核验"
        case .stale: "可能过期"
        case .unavailable: "不可用"
        }
    }
}

struct TripWeatherValueProjection: Equatable {
    var value: String?
    var state: TripInformationState?

    var displayText: String {
        guard let value = tripNonEmpty(value) else {
            return state?.label ?? TripInformationState.unavailable.label
        }
        guard let state else { return value }
        return "\(value)（\(state.label)）"
    }

    var isUnavailable: Bool {
        tripNonEmpty(value) == nil
    }
}

struct TripWeatherProjection: Equatable {
    let condition: TripWeatherValueProjection
    let temperature: TripWeatherValueProjection
    let precipitation: TripWeatherValueProjection
    let wind: TripWeatherValueProjection

    var fields: [(label: String, value: TripWeatherValueProjection)] {
        [
            ("天气状况", condition),
            ("温度", temperature),
            ("降水", precipitation),
            ("风力", wind),
        ]
    }

    var conclusion: String {
        fields.map { $0.value.displayText }.joined(separator: " · ")
    }

    var hasStaleField: Bool {
        fields.contains { $0.value.state == .stale }
    }
}

struct TripWeatherDayProjection: Identifiable, Equatable {
    let id: String
    let dayNumber: Int
    let date: String
    let primaryStage: String
    var hikingDayNumber: Int?
    /// 天气地点（冻结 placeContext）；缺失为 nil，不从行程其他位置推断。
    var placeContext: String?
    let weather: TripWeatherProjection
}

struct TripTimelineItemProjection: Identifiable, Equatable {
    let id: String
    var time: String?
    let title: String
    var details: [String]
    var notices: [String] = []
    /// 不能因普通摘要的行数限制而隐藏的已有关键时间。
    var additionalTimes: [String] = []
}

struct TripPointProjection: Identifiable, Equatable {
    let id: String
    let title: String
    var details: [String]
    var trailing: String?
}

struct TripDayResourceProjection: Identifiable, Equatable {
    let id: String
    let category: String
    let name: String?
    var distance: String?
}

struct TripDailyRouteSummaryProjection: Equatable {
    let title: String
    var endpoints: String?
    let metrics: [MetricItemModel]
}

struct TripDayProjection: Equatable {
    let tripDayID: String
    let dayNumber: Int
    let date: String
    let primaryStage: String
    var hikingDayNumber: Int?
    let actions: [TripTimelineItemProjection]
    var points: [TripPointProjection]
    var resources: [TripDayResourceProjection] = []
    let weather: TripWeatherProjection
    var dailyRouteSummary: TripDailyRouteSummaryProjection?
    var totalTrekDays: Int = 0
    var outboundTransport: TripDayTransportSummaryProjection?
    var hikeSummary: TripDayHikeSummaryProjection?
    var returnTransport: TripDayTransportSummaryProjection?
}

enum TripNoticeTone: Equatable {
    case info
    case warning
    case stale
    case danger

    var noticeTone: NoticeTone {
        switch self {
        case .info: .info
        case .warning: .warning
        case .stale: .stale
        case .danger: .danger
        }
    }
}

struct TripNoticeProjection: Identifiable, Equatable {
    let id: String
    let title: String
    let message: String
    let tone: TripNoticeTone
}

struct TripDeterministicCoverSurface: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    AppColors.sceneForestHighlight,
                    AppColors.sceneForestMiddle,
                    AppColors.pageBase,
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Image(systemName: "mountain.2.fill")
                .font(.ornament(112, weight: .ultraLight))
                .foregroundStyle(AppColors.interactionPrimary.opacity(0.18))
                .offset(y: Spacing.xxl)
        }
        .accessibilityHidden(true)
    }
}

struct TripWeatherField: View {
    let label: String
    let value: TripWeatherValueProjection

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text(label)
                .font(.label)
                .foregroundStyle(AppColors.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            if value.isUnavailable {
                UnavailableStateView(
                    title: value.state?.label ?? TripInformationState.unavailable.label,
                    message: nil,
                    icon: nil,
                    variant: .inline
                )
            } else {
                Text(value.displayText)
                    .font(.appCaption)
                    .foregroundStyle(AppColors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, minHeight: 76, alignment: .topLeading)
        .background(
            AppColors.surfaceSoft,
            in: RoundedRectangle(cornerRadius: Radius.sm, style: .continuous)
        )
        .accessibilityElement(children: .combine)
    }
}

struct TripWrapLayout: Layout {
    var horizontalSpacing: CGFloat = Spacing.sm
    var verticalSpacing: CGFloat = Spacing.sm

    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) -> CGSize {
        let availableWidth = proposal.width ?? .infinity
        var lineWidth: CGFloat = 0
        var lineHeight: CGFloat = 0
        var totalHeight: CGFloat = 0
        var maximumWidth: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            let candidateWidth = lineWidth == 0 ? size.width : lineWidth + horizontalSpacing + size.width
            if lineWidth > 0, candidateWidth > availableWidth {
                maximumWidth = max(maximumWidth, lineWidth)
                totalHeight += lineHeight + verticalSpacing
                lineWidth = size.width
                lineHeight = size.height
            } else {
                lineWidth = candidateWidth
                lineHeight = max(lineHeight, size.height)
            }
        }

        maximumWidth = max(maximumWidth, lineWidth)
        totalHeight += lineHeight
        return CGSize(width: proposal.width ?? maximumWidth, height: totalHeight)
    }

    func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) {
        var origin = bounds.origin
        var lineHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if origin.x > bounds.minX, origin.x + size.width > bounds.maxX {
                origin.x = bounds.minX
                origin.y += lineHeight + verticalSpacing
                lineHeight = 0
            }
            subview.place(at: origin, proposal: ProposedViewSize(size))
            origin.x += size.width + horizontalSpacing
            lineHeight = max(lineHeight, size.height)
        }
    }
}

func tripNonEmpty(_ value: String?) -> String? {
    guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else {
        return nil
    }
    return value
}

#if DEBUG
extension TripWeatherProjection {
    static let known = TripWeatherProjection(
        condition: TripWeatherValueProjection(value: "多云", state: nil),
        temperature: TripWeatherValueProjection(value: "8–16 ℃", state: nil),
        precipitation: TripWeatherValueProjection(value: "降水概率 20%", state: nil),
        wind: TripWeatherValueProjection(value: "3 级", state: nil)
    )

    static let pendingVerification = TripWeatherProjection(
        condition: TripWeatherValueProjection(value: "多云", state: .pendingVerification),
        temperature: TripWeatherValueProjection(value: "8–16 ℃", state: .pendingVerification),
        precipitation: TripWeatherValueProjection(value: "降水概率 20%", state: .pendingVerification),
        wind: TripWeatherValueProjection(value: "3 级", state: .pendingVerification)
    )

    static let partial = TripWeatherProjection(
        condition: TripWeatherValueProjection(value: "阵雨", state: .pendingVerification),
        temperature: TripWeatherValueProjection(value: "6–13 ℃", state: nil),
        precipitation: TripWeatherValueProjection(value: nil, state: .unavailable),
        wind: TripWeatherValueProjection(value: "4 级", state: .stale)
    )

    static let unavailable = TripWeatherProjection(
        condition: TripWeatherValueProjection(value: nil, state: .unavailable),
        temperature: TripWeatherValueProjection(value: nil, state: .unavailable),
        precipitation: TripWeatherValueProjection(value: nil, state: .unavailable),
        wind: TripWeatherValueProjection(value: nil, state: .unavailable)
    )
}

extension TripWeatherDayProjection {
    static let `default` = TripWeatherDayProjection(
        id: "trip-day-weather-1",
        dayNumber: 1,
        date: "2026-09-07",
        primaryStage: "抵达与适应",
        hikingDayNumber: nil,
        weather: TripWeatherProjection.pendingVerification
    )

    static let unavailable = TripWeatherDayProjection(
        id: "trip-day-weather-3",
        dayNumber: 3,
        date: "2026-09-09",
        primaryStage: "河谷下降",
        hikingDayNumber: 2,
        weather: TripWeatherProjection.unavailable
    )

    static let knownWithPlace = TripWeatherDayProjection(
        id: "trip-day-weather-row-known",
        dayNumber: 2,
        date: "2026-09-08",
        primaryStage: "翻越北侧垭口",
        hikingDayNumber: 1,
        placeContext: "老榆林村",
        weather: TripWeatherProjection.known
    )
}
#endif
