import SwiftUI
import WalkData
import WalkDesignSystem

struct TripContentNotice: Equatable, Identifiable {
    let field: String
    let status: String

    var id: String { "\(field):\(status)" }
    var message: String { "\(field)：\(Self.statusTitle(status))" }

    private static func statusTitle(_ status: String) -> String {
        switch status {
        case "unknown": "信息未知"
        case "missing": "信息缺失"
        case "pending_verification": "待核验"
        case "stale": "信息已过期"
        case "unavailable": "信息不可用"
        default: "状态未知"
        }
    }
}

struct TripActionPresentation: Equatable, Identifiable {
    let action: PersonalTripAction

    var id: Int { action.sequence }
    var sequence: Int { action.sequence }
    var isDailyRouteSummary: Bool { action.actionType == "hike" }
    var details: [String] {
        var result: [String] = []
        if let start = action.start?.value?.name ?? action.origin?.value?.name {
            result.append("起点 \(start)")
        }
        if let end = action.end?.value?.name ?? action.destination?.value?.name {
            result.append("终点 \(end)")
        }
        if let mode = action.mode?.value { result.append(mode) }
        if let times = action.keyTimes?.value, !times.isEmpty { result.append(times.joined(separator: " · ")) }
        if let meters = action.distance?.value?.meters { result.append("距离 \(formatDistance(meters))") }
        if let meters = action.ascent?.value?.meters { result.append("爬升 \(Int(meters.rounded())) m") }
        if let seconds = action.estimatedDuration?.value?.seconds { result.append("预计 \(formatDuration(seconds))") }
        if let notes = action.transferNotes?.value, !notes.isEmpty { result.append(notes.joined(separator: " · ")) }
        return result
    }
    var statusNotices: [TripContentNotice] {
        switch action.actionType {
        case "long_distance_transport", "route_transfer":
            return Self.notices([
                ("起点", action.origin?.confidence),
                ("终点", action.destination?.confidence),
                ("交通方式", action.mode?.confidence),
                ("关键时间", action.keyTimes?.confidence),
                ("预计耗时", action.estimatedDuration?.confidence),
                ("换乘说明", action.transferNotes?.confidence),
            ])
        case "hike":
            return Self.notices([
                ("徒步路段", action.routeSectionConfidence),
                ("起点", action.start?.confidence),
                ("终点", action.end?.confidence),
                ("距离", action.distance?.confidence),
                ("爬升", action.ascent?.confidence),
                ("预计耗时", action.estimatedDuration?.confidence),
            ])
        default:
            return []
        }
    }

    private static func notices(_ fields: [(String, InformationConfidence?)]) -> [TripContentNotice] {
        fields.compactMap { field, confidence in
            guard let status = confidence?.status,
                  ["unknown", "missing", "pending_verification", "stale", "unavailable"].contains(status) else {
                return nil
            }
            return TripContentNotice(field: field, status: status)
        }
    }
}

struct TripPointPresentation: Equatable, Identifiable {
    let point: PersonalTripPoint

    var id: Int { point.sequence }
    var sequence: Int { point.sequence }
    var statusNotices: [TripContentNotice] {
        let fields: [(String, InformationConfidence?)] = [
            ("距离", point.distance?.confidence),
            ("位置", point.location?.confidence),
            ("详情", point.details?.confidence),
        ]
        return fields.compactMap { field, confidence in
            guard let status = confidence?.status,
                  ["unknown", "missing", "pending_verification", "stale", "unavailable"].contains(status) else {
                return nil
            }
            return TripContentNotice(field: field, status: status)
        }
    }
}

struct TripDayPresentation: Equatable {
    let day: PersonalTripDay

    var primaryStage: String { day.primaryStage }
    var dayLabel: String { "D\(day.dayNumber)" }
    var actionSequence: [Int] { presentationItems.map(\.sequence) }
    var pointSequence: [Int]? { pointItems.isEmpty ? nil : pointItems.map(\.sequence) }
    var actions: [PersonalTripAction] { presentationItems.map(\.action) }
    var points: [PersonalTripPoint] { pointItems.map(\.point) }
    // 后端 sequence 原序：行动与点位都按后端 sequence 字段升序展示，客户端不按业务类别重排。
    var presentationItems: [TripActionPresentation] {
        day.actions
            .map(TripActionPresentation.init)
            .sorted { $0.sequence < $1.sequence }
    }
    var pointItems: [TripPointPresentation] {
        (day.points ?? [])
            .map(TripPointPresentation.init)
            .sorted { $0.sequence < $1.sequence }
    }
    var weatherPresentation: TripDayWeatherPresentation {
        TripDayWeatherPresentation(weather: day.weather)
    }

    var hasDayContent: Bool {
        !presentationItems.isEmpty
            || !pointItems.isEmpty
            || routeGuideProjection != nil
            || !weatherLine(day.weather).isEmpty
            || !weatherPresentation.statusNotices.isEmpty
    }

    var routeGuideProjection: TripRouteGuideProjection? {
        guard let guide = day.routeGuide else { return nil }
        let projection = TripRouteGuideProjection(guide: guide)
        return projection.fields.isEmpty ? nil : projection
    }

    var dailyRouteSummary: TripActionPresentation? {
        presentationItems.first(where: \.isDailyRouteSummary)
    }

    var detailActionItems: [TripActionPresentation] {
        presentationItems
    }
}

struct TripDayWeatherPresentation: Equatable {
    let weather: PersonalTripDayWeather

    var statusNotices: [TripContentNotice] {
        let fields: [(String, InformationConfidence?)] = [
            ("天气状况", weather.condition.confidence),
            ("温度", weather.temperatureRange.confidence),
            ("降水", weather.precipitation.confidence),
            ("风力", weather.wind.confidence),
        ]
        return fields.compactMap { field, confidence in
            guard let status = confidence?.status,
                  ["unknown", "missing", "pending_verification", "stale", "unavailable"].contains(status) else {
                return nil
            }
            return TripContentNotice(field: field, status: status)
        }
    }
}

struct TripTemperatureRangePresentation: Equatable {
    let low: Double?
    let high: Double?
    let text: String?

    init(qualified: QualifiedTemperatureRange) {
        low = qualified.value?.low
        high = qualified.value?.high
        switch (low, high) {
        case let (low?, high?):
            text = "\(Self.temperature(low))–\(Self.temperature(high))°C"
        case let (low?, nil):
            text = "最低 \(Self.temperature(low))°C"
        case let (nil, high?):
            text = "最高 \(Self.temperature(high))°C"
        case (nil, nil):
            text = nil
        }
    }

    private static func temperature(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(0...1)))
    }
}

struct TripWeatherFieldPresentation: Equatable {
    let text: String?
    let status: String?

    init(qualified: QualifiedString) {
        text = Self.nonEmpty(qualified.value)
        status = qualified.confidence?.status
    }

    init(temperatureRange qualified: QualifiedTemperatureRange) {
        text = TripTemperatureRangePresentation(qualified: qualified).text
        status = qualified.confidence?.status
    }

    private static func nonEmpty(_ value: String?) -> String? {
        guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else {
            return nil
        }
        return value
    }
}

struct TripWeatherDayComponentPresentation: Equatable {
    let projection: TripWeatherDayProjection

    init(day: PersonalTripWeatherDay) {
        projection = TripWeatherDayProjection(
            id: day.tripDayID,
            dayNumber: day.dayNumber,
            date: day.date.description,
            primaryStage: day.primaryStage,
            hikingDayNumber: day.hikingDayNumber,
            placeContext: Self.placeText(day.weather.placeContext.value),
            weather: TripWeatherProjection(
                condition: Self.value(TripWeatherFieldPresentation(qualified: day.weather.condition)),
                temperature: Self.value(TripWeatherFieldPresentation(temperatureRange: day.weather.temperatureRange)),
                precipitation: Self.value(TripWeatherFieldPresentation(qualified: day.weather.precipitation)),
                wind: Self.value(TripWeatherFieldPresentation(qualified: day.weather.wind))
            )
        )
    }

    private static func placeText(_ value: String?) -> String? {
        guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else {
            return nil
        }
        return value
    }

    private static func value(_ field: TripWeatherFieldPresentation) -> TripWeatherValueProjection {
        TripWeatherValueProjection(value: field.text, state: informationState(field.status))
    }

    static func informationState(_ status: String?) -> TripInformationState? {
        switch status {
        case "unknown": .unknown
        case "missing": .missing
        case "pending_verification": .pendingVerification
        case "stale": .stale
        case "unavailable": .unavailable
        default: nil
        }
    }
}


/// PAGE-TRIP-WEATHER 页面非组件：路线 + 完整年月日区间，双胶囊芯片。
private struct TripWeatherContextLine: View {
    let routeName: String
    let startDate: LocalDate
    let endDate: LocalDate

    var body: some View {
        HStack(spacing: Spacing.sm) {
            chip(routeName)
            chip(dateRangeText)
            Spacer(minLength: 0)
        }
    }

    private var dateRangeText: String {
        let start = Self.fullDate(startDate)
        let end = Self.fullDate(endDate)
        return start == end ? start : "\(start)—\(end)"
    }

    private func chip(_ text: String) -> some View {
        Text(text)
            .font(.tag)
            .foregroundStyle(AppColors.textSecondary)
            .lineLimit(1)
            .padding(.horizontal, Spacing.sm)
            .padding(.vertical, Spacing.xs)
            .background(AppColors.surfaceSoft, in: Capsule())
    }

    private static func fullDate(_ date: LocalDate) -> String {
        "\(date.year)年\(date.month)月\(date.day)日"
    }
}

struct TripWeatherView: View {
    @State private var viewModel: TripWeatherViewModel

    init(tripID: String, service: any PersonalTripServicing) {
        _viewModel = State(initialValue: TripWeatherViewModel(tripID: tripID, service: service))
    }

    var body: some View {
        UtilityPage(title: "行程天气") {
            Group {
                if viewModel.isLoading && viewModel.weather == nil {
                    LoadingView(message: "正在加载行程天气", variant: .page)
                        .frame(maxWidth: .infinity, minHeight: 420, alignment: .center)
                } else if viewModel.isUnavailable {
                    weatherUnavailableContent
                } else if viewModel.errorMessage != nil || viewModel.weather == nil {
                    ErrorView(
                        message: "逐日天气投影缺失或顺序冲突。",
                        title: "无法显示行程天气",
                        variant: .page,
                        retry: { Task { await viewModel.load() } }
                    )
                    .frame(maxWidth: .infinity, minHeight: 420, alignment: .center)
                } else if let detail = viewModel.detail, !detail.days.isEmpty {
                    TripWeatherContent(detail: detail)
                        .padding(.bottom, Spacing.xl)
                } else {
                    ErrorView(
                        message: "完整自然日投影缺失，不生成空逐日区。",
                        title: "无法显示行程天气",
                        variant: .page,
                        retry: { Task { await viewModel.load() } }
                    )
                    .frame(maxWidth: .infinity, minHeight: 420, alignment: .center)
                }
            }
        }
        .task { await viewModel.load() }
    }

    /// 分支 B：整趟天气目标不可用；保留导航与上下文，整页 EmptyState，不用其他地点或日期补齐。
    private var weatherUnavailableContent: some View {
        VStack(spacing: 0) {
            if let detail = viewModel.detail {
                TripWeatherContextLine(
                    routeName: detail.trip.frozenRouteBasis.routeName,
                    startDate: detail.trip.startDate,
                    endDate: detail.trip.endDate
                )
            }
            EmptyStateView(
                title: "暂时无法获取本次天气",
                message: "不会用其他地点、其他日期或季节天气补齐。",
                icon: "cloud.sun",
                variant: .default
            )
            .frame(maxWidth: .infinity, minHeight: 380, alignment: .center)
        }
        .frame(maxWidth: .infinity, minHeight: 420, alignment: .top)
    }
}

/// 逐日天气共享内容：独立天气页与行程浏览天气分页共用同一实现；纯 VStack，
/// 不自带 ScrollView 与页面水平边距（由宿主滚动层与页面壳负责）。
struct TripWeatherContent: View {
    let detail: PersonalTripDetail

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xl) {
            TripWeatherContextLine(
                routeName: detail.trip.frozenRouteBasis.routeName,
                startDate: detail.trip.startDate,
                endDate: detail.trip.endDate
            )

            HStack(spacing: Spacing.sm) {
                InfoTag(title: "外部动态信息", tone: .info)
                if detail.trip.weatherOverview != nil {
                    InfoTag(
                        title: expired ? "信息已过期" : "更新时间有效",
                        tone: expired ? .warning : .info
                    )
                }
            }

            if expired {
                NoticeView(
                    message: "当前版本不提供调整或重新生成，请在出发前核对最新天气。",
                    title: "天气信息可能不再准确",
                    tone: .warning
                )
            }

            if let overview = detail.trip.weatherOverview {
                TripBusinessComponents.WeatherOverview(projection: Self.overviewProjection(overview))
            }

            SectionHeader(title: "逐日天气") {
                Text("\(detail.days.count) 个自然日")
                    .font(.appCaption)
                    .foregroundStyle(AppColors.textSecondary)
            }

            VStack(spacing: Spacing.lg) {
                ForEach(detail.days) { day in
                    TripBusinessComponents.DailyWeatherCard(day: Self.dayProjection(day))
                }
            }
        }
        .frame(maxWidth: 600, alignment: .leading)
        .frame(maxWidth: .infinity)
    }

    private var expired: Bool {
        detail.trip.weatherOverview?.summary.confidence?.status == "stale"
    }

    private static func overviewProjection(_ overview: WeatherOverview) -> WeatherOverviewProjection {
        WeatherOverviewProjection(
            summary: TripWeatherValueProjection(
                value: overview.summary.value,
                state: TripWeatherDayComponentPresentation.informationState(overview.summary.confidence?.status)
            ),
            importantImpacts: (overview.importantImpacts ?? [])
                .sorted { $0.sequence < $1.sequence }
                .compactMap { impact in
                    guard let value = impact.content.value?.trimmingCharacters(in: .whitespacesAndNewlines),
                          !value.isEmpty else { return nil }
                    return value
                }
        )
    }

    private static func dayProjection(_ day: PersonalTripDay) -> TripWeatherDayProjection {
        TripWeatherDayComponentPresentation(
            day: PersonalTripWeatherDay(
                tripDayID: day.identity,
                dayNumber: day.dayNumber,
                date: day.date,
                primaryStage: day.primaryStage,
                hikingDayNumber: day.hikingDayNumber,
                weather: day.weather
            )
        ).projection
    }
}

func weatherLine(_ weather: PersonalTripDayWeather) -> String {
    let fields = [
        TripWeatherFieldPresentation(qualified: weather.condition),
        TripWeatherFieldPresentation(temperatureRange: weather.temperatureRange),
        TripWeatherFieldPresentation(qualified: weather.precipitation),
        TripWeatherFieldPresentation(qualified: weather.wind),
    ]
    let values = fields.compactMap(\.text)
    if !values.isEmpty { return values.joined(separator: " · ") }
    return fields.contains(where: { $0.status == "unavailable" }) ? "暂不可用" : ""
}

private func formatDistance(_ meters: Double) -> String {
    meters >= 1_000
        ? "\((meters / 1_000).formatted(.number.precision(.fractionLength(0...1)))) km"
        : "\(Int(meters.rounded())) m"
}

private func formatDuration(_ seconds: Double) -> String {
    "\((seconds / 3_600).formatted(.number.precision(.fractionLength(0...1)))) 小时"
}
