import SwiftUI

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
            || !weatherLine(day.weather).isEmpty
            || !weatherPresentation.statusNotices.isEmpty
    }

    var dailyRouteSummary: TripActionPresentation? {
        presentationItems.first(where: \.isDailyRouteSummary)
    }

    var detailActionItems: [TripActionPresentation] {
        presentationItems
    }
}

enum TripDayFocusPolicy {
    static func initialIndex(days: [PersonalTripDay], initialDayID: String) -> Int {
        days.firstIndex(where: { $0.identity == initialDayID }) ?? 0
    }

    static func clampedIndex(_ index: Int, dayCount: Int) -> Int {
        guard dayCount > 0 else { return 0 }
        return min(max(index, 0), dayCount - 1)
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
            weather: TripWeatherProjection(
                condition: Self.value(TripWeatherFieldPresentation(qualified: day.weather.condition)),
                temperature: Self.value(TripWeatherFieldPresentation(temperatureRange: day.weather.temperatureRange)),
                precipitation: Self.value(TripWeatherFieldPresentation(qualified: day.weather.precipitation)),
                wind: Self.value(TripWeatherFieldPresentation(qualified: day.weather.wind))
            )
        )
    }

    private static func value(_ field: TripWeatherFieldPresentation) -> TripWeatherValueProjection {
        TripWeatherValueProjection(value: field.text, state: informationState(field.status))
    }

    private static func informationState(_ status: String?) -> TripInformationState? {
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

@MainActor
final class TripDayViewModel: ObservableObject {
    @Published private(set) var result: PersonalTripDays?
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?

    let initialDayID: String
    private let tripID: String
    private let loadDays: (String) async throws -> PersonalTripDays
    private let loadCurrentRevision: (String) async throws -> String

    init(tripID: String, initialDayID: String, service: any PersonalTripServicing) {
        self.tripID = tripID
        self.initialDayID = initialDayID
        self.loadDays = { try await service.days(tripID: $0) }
        self.loadCurrentRevision = { try await service.detail(tripID: $0).revision }
    }

    init(
        tripID: String,
        initialDayID: String,
        loadDays: @escaping (String) async throws -> PersonalTripDays,
        loadCurrentRevision: @escaping (String) async throws -> String
    ) {
        self.tripID = tripID
        self.initialDayID = initialDayID
        self.loadDays = loadDays
        self.loadCurrentRevision = loadCurrentRevision
    }

    func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            async let loadedDays = loadDays(tripID)
            async let currentRevision = loadCurrentRevision(tripID)
            let (days, revision) = try await (loadedDays, currentRevision)
            guard days.tripID == tripID, days.revision == revision else {
                throw APIClientError.invalidResponse
            }
            result = days
        } catch {
            result = nil
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }
}

struct TripDayView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: TripDayViewModel
    @State private var days: [PersonalTripDay] = []
    @State private var focusedIndex: Int = 0

    init(tripID: String, initialDayID: String, service: any PersonalTripServicing) {
        _viewModel = StateObject(wrappedValue: TripDayViewModel(
            tripID: tripID,
            initialDayID: initialDayID,
            service: service
        ))
    }

    var body: some View {
        UtilityPageContainer {
            VStack(spacing: 0) {
                dayHeader

                Group {
                    if viewModel.isLoading && viewModel.result == nil {
                        LoadingView(message: "正在加载自然日安排", variant: .page)
                    } else if viewModel.errorMessage != nil, viewModel.result == nil {
                        ErrorView(
                            message: "完整自然日投影缺失或冲突，不生成空 Pager。",
                            title: "无法显示自然日安排",
                            variant: .page,
                            retry: { Task { await viewModel.load() } }
                        )
                    } else if !days.isEmpty {
                        dayPages
                    } else {
                        ErrorView(
                            message: "完整自然日投影缺失或冲突，不生成空 Pager。",
                            title: "无法显示自然日安排",
                            variant: .page,
                            retry: { Task { await viewModel.load() } }
                        )
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .task {
            await viewModel.load()
            if let result = viewModel.result {
                days = result.days
                focusedIndex = TripDayFocusPolicy.initialIndex(
                    days: result.days,
                    initialDayID: viewModel.initialDayID
                )
            }
        }
    }

    private var focusedPrimaryStage: String {
        days.indices.contains(focusedIndex) ? days[focusedIndex].primaryStage : "逐日详情"
    }

    private var dayHeader: some View {
        HStack(spacing: Spacing.sm) {
            IconButton(
                systemName: "chevron.left",
                accessibilityLabel: "返回个人行程",
                variant: .overlay,
                action: { dismiss() }
            )

            Text(focusedPrimaryStage)
                .font(.ornament(13, weight: .bold))
                .foregroundStyle(AppColors.interactionPrimary)
                .lineLimit(1)
                .frame(maxWidth: .infinity)

            AppColors.surfacePrimary.opacity(0)
                .frame(width: 44, height: 44)
                .accessibilityHidden(true)
        }
        .frame(height: 56)
        .padding(.horizontal, Spacing.pageHorizontal)
        .background(AppColors.pageBase.opacity(0.94))
    }

    @ViewBuilder
    private var dayPages: some View {
        TabView(selection: $focusedIndex) {
            ForEach(Array(days.enumerated()), id: \.element.identity) { index, day in
                TripDayPage(
                    presentation: TripDayPresentation(day: day),
                    canMovePrevious: index > 0,
                    canMoveNext: index < days.count - 1,
                    onPrevious: { moveFocus(by: -1) },
                    onNext: { moveFocus(by: 1) }
                )
                .tag(index)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
    }

    private func moveFocus(by offset: Int) {
        focusedIndex = TripDayFocusPolicy.clampedIndex(focusedIndex + offset, dayCount: days.count)
    }
}

private struct TripDayPage: View {
    let presentation: TripDayPresentation
    let canMovePrevious: Bool
    let canMoveNext: Bool
    let onPrevious: () -> Void
    let onNext: () -> Void

    @State private var innerScrollOffset: CGFloat = 0
    @State private var innerContentHeight: CGFloat = 0
    @State private var innerViewportHeight: CGFloat = 0
    @State private var boundaryDirection: Int?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            dayIdentityRow

            WalkPanel(variant: .default) {
                if presentation.hasDayContent {
                    VStack(spacing: 0) {
                        ForEach(presentation.presentationItems) { item in
                            dailyRouteSummaryRow(for: item)
                        }

                        internalScrollArea
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    }
                } else {
                    UnavailableStateView(
                        title: "当天安排暂不可用",
                        message: "不会使用其他自然日或默认模板补齐。",
                        icon: "calendar.badge.exclamationmark",
                        variant: .section
                    )
                }
            }
            .frame(maxWidth: .infinity, minHeight: 420, maxHeight: .infinity, alignment: .top)
        }
        .padding(.horizontal, Spacing.pageHorizontal)
        .padding(.top, 10)
        .padding(.bottom, Spacing.xl)
    }

    private var dayIdentityRow: some View {
        HStack(spacing: 10) {
            Text(presentation.dayLabel)
                .font(.sequence)
                .foregroundStyle(AppColors.interactionPrimary)
                .padding(.trailing, 10)
                .overlay(alignment: .trailing) {
                    Rectangle()
                        .fill(AppColors.surfaceDivider)
                        .frame(width: 1)
                }
            Text(presentation.day.date.description)
                .font(.dayDate)
                .foregroundStyle(AppColors.textPrimary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, minHeight: 42, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private func dailyRouteSummaryRow(for item: TripActionPresentation) -> some View {
        if item.isDailyRouteSummary {
            dailyRouteSummary(item)
            Divider().overlay(AppColors.surfaceDivider)
                .padding(.vertical, Spacing.md)
        }
    }

    private func dailyRouteSummary(_ item: TripActionPresentation) -> some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text("每日路程")
                .font(.tag)
                .foregroundStyle(AppColors.textWeak)

            Text(item.action.routeSectionSnapshot?.name ?? "当天徒步路线")
                .font(.action)
                .foregroundStyle(AppColors.textPrimary)

            if let start = item.action.start?.value?.name,
               let end = item.action.end?.value?.name {
                Text("\(start) → \(end)")
                    .font(.appCaption)
                    .foregroundStyle(AppColors.textSecondary)
            }

            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: Spacing.sm), count: 3),
                spacing: Spacing.sm
            ) {
                routeMetric(
                    value: item.action.distance?.value.map { formatDistance($0.meters) } ?? "--",
                    label: "距离"
                )
                routeMetric(
                    value: item.action.ascent?.value.map { "\(Int($0.meters.rounded())) m" } ?? "--",
                    label: "爬升"
                )
                routeMetric(
                    value: item.action.estimatedDuration?.value.map { formatDuration($0.seconds) } ?? "--",
                    label: "预计用时"
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func routeMetric(value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text(value)
                .font(.metricGridValue)
                .foregroundStyle(AppColors.textPrimary)
            Text(label)
                .font(.metricGridLabel)
                .foregroundStyle(AppColors.textWeak)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 7)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColors.surfaceSubtle, in: RoundedRectangle(cornerRadius: Radius.md))
    }

    private var internalScrollArea: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.xl) {
                if !presentation.presentationItems.isEmpty {
                    VStack(alignment: .leading, spacing: Spacing.md) {
                        Text("当天行动")
                            .font(.action)
                            .foregroundStyle(AppColors.textPrimary)
                        ForEach(presentation.presentationItems) { item in
                            actionRow(item)
                        }
                    }
                    .padding(.vertical, Spacing.md)
                }

                if !presentation.pointItems.isEmpty {
                    VStack(alignment: .leading, spacing: Spacing.md) {
                        Text("沿途点位")
                            .font(.action)
                            .foregroundStyle(AppColors.textPrimary)
                        ForEach(presentation.pointItems) { item in
                            pointRow(item)
                        }
                    }
                }

                weatherSummary

                Text(boundaryText)
                    .font(.ornament(10, weight: .regular))
                    .foregroundStyle(AppColors.textWeak)
                    .frame(maxWidth: .infinity)
                    .multilineTextAlignment(.center)
                    .padding(.top, Spacing.sm)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                GeometryReader { proxy in
                    AppColors.pageBase.opacity(0.001).preference(
                        key: TripDayInnerMetricsKey.self,
                        value: TripDayInnerMetrics(
                            offset: proxy.frame(in: .named("trip-day-inner-scroll")).minY,
                            contentHeight: proxy.size.height
                        )
                    )
                }
            )
        }
        .coordinateSpace(name: "trip-day-inner-scroll")
        .background(
            GeometryReader { proxy in
                AppColors.pageBase.opacity(0.001).preference(
                    key: TripDayInnerViewportHeightKey.self,
                    value: proxy.size.height
                )
            }
        )
        .onPreferenceChange(TripDayInnerMetricsKey.self) { metrics in
            innerScrollOffset = metrics.offset
            innerContentHeight = metrics.contentHeight
        }
        .onPreferenceChange(TripDayInnerViewportHeightKey.self) { innerViewportHeight = $0 }
        .simultaneousGesture(
            DragGesture(minimumDistance: 10)
                .onChanged { value in
                    scrollBoundaryHandoff(translation: value.translation.height)
                }
                .onEnded { _ in boundaryDirection = nil }
        )
    }

    private func scrollBoundaryHandoff(translation: CGFloat) {
        let maxOffset = max(0, innerContentHeight - innerViewportHeight)
        let atTop = innerScrollOffset >= -24
        let atBottom = -innerScrollOffset >= maxOffset - 24
        if translation < -60, atBottom, canMoveNext, boundaryDirection != 1 {
            boundaryDirection = 1
            onNext()
        } else if translation > 60, atTop, canMovePrevious, boundaryDirection != -1 {
            boundaryDirection = -1
            onPrevious()
        }
    }

    private var hasWeatherContent: Bool {
        !weatherLine(presentation.day.weather).isEmpty
    }

    private func actionRow(_ item: TripActionPresentation) -> some View {
        let action = item.action
        return VStack(alignment: .leading, spacing: Spacing.xs) {
            Text(actionTitle(action))
                .font(.listTitle)
                .foregroundStyle(AppColors.textPrimary)
            ForEach(item.details, id: \.self) { detail in
                Text(detail)
                    .font(.appCaption)
                    .foregroundStyle(AppColors.textSecondary)
            }
            ForEach(item.statusNotices) { notice in
                NoticeView(message: notice.message, tone: .warning)
            }
        }
    }

    private func pointRow(_ item: TripPointPresentation) -> some View {
        let point = item.point
        var details: [String] = []
        if let distance = point.distance?.value?.meters {
            details.append("距离 \(formatDistance(distance))")
        }
        if let location = point.location?.value {
            let latitude = location.latitude.formatted(.number.precision(.fractionLength(4)))
            let longitude = location.longitude.formatted(.number.precision(.fractionLength(4)))
            details.append("位置 \(latitude), \(longitude)")
        }
        if let value = point.details?.value, !value.isEmpty { details.append(value) }
        return ListRow(variant: .grouped, showsDivider: true) {
            HStack(alignment: .top, spacing: Spacing.md) {
                Text(point.type)
                    .font(.micro)
                    .foregroundStyle(AppColors.textWeak)
                    .frame(width: 54, alignment: .leading)
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text(point.name ?? point.type)
                        .font(.listTitle)
                        .foregroundStyle(AppColors.textPrimary)
                    if !details.isEmpty {
                        Text(details.joined(separator: " · "))
                            .font(.appCaption)
                            .foregroundStyle(AppColors.textSecondary)
                    }
                    ForEach(item.statusNotices) { notice in
                        Text(notice.message)
                            .font(.appCaption)
                            .foregroundStyle(AppColors.warning)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var weatherSummary: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text("当天行程天气")
                .font(.action)
                .foregroundStyle(AppColors.textPrimary)
            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: Spacing.md), count: 2),
                spacing: Spacing.md
            ) {
                dayWeatherField("天气状况", TripWeatherFieldPresentation(qualified: presentation.day.weather.condition))
                dayWeatherField("温度", TripWeatherFieldPresentation(temperatureRange: presentation.day.weather.temperatureRange))
                dayWeatherField("降水", TripWeatherFieldPresentation(qualified: presentation.day.weather.precipitation))
                dayWeatherField("风力", TripWeatherFieldPresentation(qualified: presentation.day.weather.wind))
            }
        }
    }

    private func dayWeatherField(
        _ label: String,
        _ field: TripWeatherFieldPresentation
    ) -> some View {
        return VStack(alignment: .leading, spacing: Spacing.xs) {
            Text(label)
                .font(.appCaption.weight(.semibold))
                .foregroundStyle(AppColors.textPrimary)
            Text(field.text ?? tripWeatherConfidenceTitle(field.status ?? "unavailable"))
                .font(.appCaption)
                .foregroundStyle(field.text == nil ? AppColors.textWeak : AppColors.textSecondary)
            if let status = field.status, statusNeedsNotice(status) {
                if status == "stale" {
                    NoticeView(
                        message: "该状态只作用于当前天气字段。",
                        title: "\(label)可能过期",
                        tone: .warning
                    )
                } else if field.text != nil {
                    Text(tripWeatherConfidenceTitle(status))
                        .font(.appCaption)
                        .foregroundStyle(AppColors.textSecondary)
                }
            }
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, minHeight: 76, alignment: .topLeading)
        .background(AppColors.surfaceSoft, in: RoundedRectangle(cornerRadius: Radius.sm))
    }

    private var boundaryText: String {
        if !canMovePrevious && !canMoveNext { return "本次行程只有一天" }
        if canMoveNext { return "滚动到边界后继续同方向滑动，切换相邻日期" }
        return "已到行程最后一天"
    }

    private func actionTime(_ item: TripActionPresentation) -> String {
        item.action.keyTimes?.value?.first ?? "--"
    }

    private func actionTitle(_ action: PersonalTripAction) -> String {
        switch action.actionType {
        case "long_distance_transport": "大交通"
        case "route_transfer": "路线接驳"
        case "hike": action.routeSectionSnapshot?.name ?? "徒步"
        default: action.actionType
        }
    }

    private func statusNeedsNotice(_ status: String) -> Bool {
        status != "known" && status != "verified" && status != "available"
    }

}

@MainActor
final class TripWeatherViewModel: ObservableObject {
    @Published private(set) var weather: PersonalTripWeather?
    @Published private(set) var isLoading = false
    @Published private(set) var isUnavailable = false
    @Published var errorMessage: String?

    private let tripID: String
    private let loadWeather: (String) async throws -> PersonalTripWeather
    private let loadCurrentRevision: (String) async throws -> String

    init(tripID: String, service: any PersonalTripServicing) {
        self.tripID = tripID
        self.loadWeather = { try await service.weather(tripID: $0) }
        self.loadCurrentRevision = { try await service.detail(tripID: $0).revision }
    }

    init(
        tripID: String,
        loadWeather: @escaping (String) async throws -> PersonalTripWeather,
        loadCurrentRevision: @escaping (String) async throws -> String
    ) {
        self.tripID = tripID
        self.loadWeather = loadWeather
        self.loadCurrentRevision = loadCurrentRevision
    }

    func load() async {
        isLoading = true
        isUnavailable = false
        errorMessage = nil
        defer { isLoading = false }
        do {
            let weather = try await loadWeather(tripID)
            let revision = try await loadCurrentRevision(tripID)
            guard PersonalTripWeatherValidator.isValid(
                weather,
                tripID: tripID,
                revision: revision
            ) else {
                throw APIClientError.invalidResponse
            }
            self.weather = weather
        } catch let error where Self.isProjectionUnavailable(error) {
            weather = nil
            isUnavailable = true
        } catch {
            weather = nil
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    private static func isProjectionUnavailable(_ error: Error) -> Bool {
        guard case APIClientError.api(let code, _, _, _) = error else { return false }
        return code == "trip_weather_projection_unavailable"
    }
}

struct TripWeatherView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: TripWeatherViewModel

    init(tripID: String, service: any PersonalTripServicing) {
        _viewModel = StateObject(wrappedValue: TripWeatherViewModel(tripID: tripID, service: service))
    }

    var body: some View {
        UtilityPageContainer {
            VStack(spacing: 0) {
                UtilityNavigationHeader(
                    title: "行程天气",
                    leading: IconButtonConfiguration(
                        systemName: "chevron.left",
                        accessibilityLabel: "返回个人行程",
                        action: { dismiss() }
                    )
                )

                Group {
                    if viewModel.isLoading && viewModel.weather == nil {
                        LoadingView(message: "正在加载行程天气", variant: .page)
                    } else if viewModel.isUnavailable {
                        ErrorView(
                            message: "行程天气关联尚未形成完整投影。",
                            title: "行程天气暂不可用",
                            variant: .page,
                            retry: { Task { await viewModel.load() } }
                        )
                    } else if viewModel.errorMessage != nil, viewModel.weather == nil {
                        ErrorView(
                            message: "逐日天气投影缺失或顺序冲突。",
                            title: "无法显示行程天气",
                            variant: .page,
                            retry: { Task { await viewModel.load() } }
                        )
                    } else if viewModel.weather != nil {
                        EmptyStateView(
                            title: "行程天气已加载",
                            message: "天气关联已读取，逐日天气卡片待开放。",
                            icon: "cloud.sun",
                            variant: .default
                        )
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        ErrorView(
                            message: "逐日天气投影缺失或顺序冲突。",
                            title: "无法显示行程天气",
                            variant: .page,
                            retry: { Task { await viewModel.load() } }
                        )
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .task { await viewModel.load() }
    }

}

private func tripWeatherConfidenceTitle(_ status: String) -> String {
    switch status {
    case "unknown": "未知"
    case "missing": "缺失"
    case "pending_verification": "待核验"
    case "stale": "可能过期"
    case "unavailable": "不可用"
    default: status
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

private struct TripDayInnerMetrics: Equatable {
    let offset: CGFloat
    let contentHeight: CGFloat
}

private struct TripDayInnerMetricsKey: PreferenceKey {
    static var defaultValue: TripDayInnerMetrics = .init(offset: 0, contentHeight: 0)

    static func reduce(value: inout TripDayInnerMetrics, nextValue: () -> TripDayInnerMetrics) {
        value = nextValue()
    }
}

private struct TripDayInnerViewportHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

private func formatDistance(_ meters: Double) -> String {
    meters >= 1_000
        ? "\((meters / 1_000).formatted(.number.precision(.fractionLength(0...1)))) km"
        : "\(Int(meters.rounded())) m"
}

private func formatDuration(_ seconds: Double) -> String {
    "\((seconds / 3_600).formatted(.number.precision(.fractionLength(0...1)))) 小时"
}
