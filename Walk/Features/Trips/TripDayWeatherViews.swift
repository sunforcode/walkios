import SwiftUI

struct TripDayPointGroup: Equatable {
    let category: String
    let title: String
    let points: [PersonalTripPoint]
}

struct TripDayPresentation: Equatable {
    let day: PersonalTripDay

    var primaryStage: String { day.primaryStage }
    var dayLabel: String { "D\(day.dayNumber)" }
    var actionSequence: [Int] { day.actions.map(\.sequence) }
    var pointSequence: [Int]? { day.points?.map(\.sequence) }
    var actions: [PersonalTripAction] { day.actions }
    var points: [PersonalTripPoint] { day.points ?? [] }

    var dailyRouteActions: [PersonalTripAction] {
        day.actions.filter { $0.actionType == "hike" }
    }

    var transportActions: [PersonalTripAction] {
        day.actions.filter { $0.actionType != "hike" }
    }

    var groupedPoints: [TripDayPointGroup] {
        let order: [(category: String, title: String)] = [
            ("campsite", "营地"),
            ("overnight_place", "过夜点"),
            ("water_source", "水源"),
            ("supply", "补给"),
            ("other", "其他点位"),
        ]
        return order.compactMap { category, title in
            let items = points.filter { $0.category == category }
            guard !items.isEmpty else { return nil }
            return TripDayPointGroup(category: category, title: title, points: items)
        }
    }

    var hasDayContent: Bool {
        !day.actions.isEmpty || !points.isEmpty
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

struct TripWeatherPresentation: Equatable {
    let weather: PersonalTripWeather

    var overview: String? { nonEmpty(weather.weatherOverview?.value) }
    var days: [PersonalTripWeatherDay] { weather.days }
    var importantImpacts: [String] {
        unique(days.flatMap { day -> [String] in
            let weather = day.weather
            return [weather.precipitation, weather.wind]
                .compactMap { qualified -> String? in
                    guard needsAttention(qualified.confidence) else { return nil }
                    return qualified.value?.text
                }
        })
    }
    var sources: [String] {
        unique(days.compactMap { nonEmpty($0.weather.source?.value) })
    }
    var updatedTimes: [String] {
        unique(days.compactMap { nonEmpty($0.weather.updatedAt?.value) })
    }

    private func needsAttention(_ confidence: InformationConfidence?) -> Bool {
        guard let status = confidence?.status else { return false }
        return status != "verified" && status != "available"
    }

    private func nonEmpty(_ value: String?) -> String? {
        guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else {
            return nil
        }
        return value
    }

    private func unique(_ values: [String]) -> [String] {
        var seen = Set<String>()
        return values.filter { seen.insert($0).inserted }
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
            Group {
                if viewModel.isLoading && viewModel.result == nil {
                    LoadingView()
                } else if let error = viewModel.errorMessage, viewModel.result == nil {
                    ErrorView(message: error) { Task { await viewModel.load() } }
                } else if !days.isEmpty {
                    dayPages
                } else {
                    EmptyStateView(title: "逐日安排暂不可用", icon: "calendar")
                }
            }
        }
        .navigationTitle(focusedPrimaryStage)
        .navigationBarTitleDisplayMode(.inline)
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

    private var dayPages: some View {
        GeometryReader { geometry in
            TabView(selection: $focusedIndex) {
                ForEach(Array(days.enumerated()), id: \.element.identity) { index, day in
                    TripDayPage(
                        presentation: TripDayPresentation(day: day),
                        canMovePrevious: index > 0,
                        canMoveNext: index < days.count - 1,
                        onPrevious: { moveFocus(by: -1) },
                        onNext: { moveFocus(by: 1) }
                    )
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .rotationEffect(.degrees(-90))
                    .tag(index)
                }
            }
            .frame(width: geometry.size.height, height: geometry.size.width)
            .tabViewStyle(.page(indexDisplayMode: .never))
            .rotationEffect(.degrees(90), anchor: .topLeading)
            .offset(x: geometry.size.width)
        }
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

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            PageHeroHeader(title: presentation.dayLabel, subtitle: presentation.day.date.description)

            if presentation.hasDayContent {
                WalkPanel {
                    VStack(alignment: .leading, spacing: Spacing.lg) {
                        if !presentation.dailyRouteActions.isEmpty {
                            VStack(alignment: .leading, spacing: Spacing.md) {
                                Text("每日路程")
                                    .font(.sectionTitle)
                                ForEach(presentation.dailyRouteActions) { action in
                                    dailyRouteRow(action)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }

                        internalScrollArea
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                }
            } else {
                WalkPanel {
                    Text("当天安排暂不可用")
                        .foregroundStyle(AppColors.textWeak)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .padding(.horizontal, Spacing.pageHorizontal)
        .padding(.vertical, Spacing.xl)
    }

    private var internalScrollArea: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                ForEach(presentation.transportActions) { action in
                    actionRow(action)
                }
                ForEach(presentation.groupedPoints, id: \.category) { group in
                    pointGroupSection(group)
                }
                if hasWeatherContent {
                    contentRow(title: "当日天气", detail: weatherLine(presentation.day.weather))
                }
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
        .simultaneousGesture(DragGesture(minimumDistance: 10).onEnded { value in
            scrollBoundaryHandoff(predictedTranslation: value.predictedEndTranslation.height)
        })
    }

    private func scrollBoundaryHandoff(predictedTranslation: CGFloat) {
        let maxOffset = max(0, innerContentHeight - innerViewportHeight)
        let atTop = innerScrollOffset >= -24
        let atBottom = -innerScrollOffset >= maxOffset - 24
        if predictedTranslation < -60 && atBottom && canMoveNext {
            onNext()
        } else if predictedTranslation > 60 && atTop && canMovePrevious {
            onPrevious()
        }
    }

    private var hasWeatherContent: Bool {
        !weatherLine(presentation.day.weather).isEmpty
    }

    private func pointGroupSection(_ group: TripDayPointGroup) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text(group.title).font(.sectionTitle)
            ForEach(group.points) { point in
                pointRow(point)
            }
        }
    }

    private func dailyRouteRow(_ action: PersonalTripAction) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            if let sectionName = action.routeSectionSnapshot?.name, !sectionName.isEmpty {
                Text(sectionName).font(.headline)
            }
            ForEach(dailyRouteDetails(action), id: \.self) { detail in
                Text(detail)
                    .font(.body)
                    .foregroundStyle(AppColors.textSecondary)
            }
        }
    }

    private func dailyRouteDetails(_ action: PersonalTripAction) -> [String] {
        var result: [String] = []
        let start = action.start?.value?.name ?? action.origin?.value?.name
        let end = action.end?.value?.name ?? action.destination?.value?.name
        if let start, let end { result.append("\(start) → \(end)") }
        if let meters = action.distance?.value?.meters { result.append("距离 \(formatDistance(meters))") }
        if let meters = action.ascent?.value?.meters { result.append("爬升 \(Int(meters.rounded())) m") }
        if let seconds = action.estimatedDuration?.value?.seconds { result.append("预计 \(formatDuration(seconds))") }
        return result
    }

    private func actionRow(_ action: PersonalTripAction) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text(actionTitle(action)).font(.headline)
            ForEach(actionDetails(action), id: \.self) { detail in
                Text(detail)
                    .font(.body)
                    .foregroundStyle(AppColors.textSecondary)
            }
        }
    }

    private func pointRow(_ point: PersonalTripPoint) -> some View {
        var details: [String] = []
        if let distance = point.distance?.value?.meters {
            details.append("距离 \(formatDistance(distance))")
        }
        if let value = point.details?.value, !value.isEmpty { details.append(value) }
        let detail = details.isEmpty ? point.type : "\(point.type) · \(details.joined(separator: " · "))"
        return contentRow(title: point.name ?? point.type, detail: detail)
    }

    private func contentRow(title: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text(title).font(.headline)
            if !detail.isEmpty {
                Text(detail)
                    .font(.body)
                    .foregroundStyle(AppColors.textSecondary)
            }
        }
    }

    private func actionTitle(_ action: PersonalTripAction) -> String {
        switch action.actionType {
        case "long_distance_transport": "大交通"
        case "route_transfer": "路线接驳"
        case "hike": action.routeSectionSnapshot?.name ?? "每日路程"
        default: action.actionType
        }
    }

    private func actionDetails(_ action: PersonalTripAction) -> [String] {
        var result: [String] = []
        let start = action.start?.value?.name ?? action.origin?.value?.name
        let end = action.end?.value?.name ?? action.destination?.value?.name
        if let start, let end { result.append("\(start) → \(end)") }
        if let mode = action.mode?.value { result.append(mode) }
        if let times = action.keyTimes?.value, !times.isEmpty { result.append(times.joined(separator: " · ")) }
        if let meters = action.distance?.value?.meters { result.append("距离 \(formatDistance(meters))") }
        if let meters = action.ascent?.value?.meters { result.append("爬升 \(Int(meters.rounded())) m") }
        if let seconds = action.estimatedDuration?.value?.seconds { result.append("预计 \(formatDuration(seconds))") }
        if let notes = action.transferNotes?.value, !notes.isEmpty { result.append(notes.joined(separator: " · ")) }
        return result
    }
}

@MainActor
final class TripWeatherViewModel: ObservableObject {
    @Published private(set) var weather: PersonalTripWeather?
    @Published private(set) var isLoading = false
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
        errorMessage = nil
        defer { isLoading = false }
        do {
            async let loadedWeather = loadWeather(tripID)
            async let currentRevision = loadCurrentRevision(tripID)
            let (weather, revision) = try await (loadedWeather, currentRevision)
            guard weather.tripID == tripID, weather.revision == revision else {
                throw APIClientError.invalidResponse
            }
            self.weather = weather
        } catch {
            weather = nil
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }
}

struct TripWeatherView: View {
    @StateObject private var viewModel: TripWeatherViewModel

    init(tripID: String, service: any PersonalTripServicing) {
        _viewModel = StateObject(wrappedValue: TripWeatherViewModel(tripID: tripID, service: service))
    }

    var body: some View {
        UtilityPageContainer {
            Group {
                if viewModel.isLoading && viewModel.weather == nil {
                    LoadingView()
                } else if let error = viewModel.errorMessage, viewModel.weather == nil {
                    ErrorView(message: error) { Task { await viewModel.load() } }
                } else if let weather = viewModel.weather {
                    weatherContent(TripWeatherPresentation(weather: weather))
                }
            }
        }
        .navigationTitle("行程天气")
        .navigationBarTitleDisplayMode(.inline)
        .task { await viewModel.load() }
    }

    private func weatherContent(_ presentation: TripWeatherPresentation) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.xl) {
                PageHeroHeader(
                    title: presentation.weather.routeName,
                    subtitle: dateRange(presentation.weather.startDate, presentation.weather.endDate)
                )

                if let overview = presentation.overview {
                    weatherPanel(title: "天气概况", values: [overview])
                }
                if !presentation.importantImpacts.isEmpty {
                    weatherPanel(title: "重要提醒", values: presentation.importantImpacts)
                }

                ForEach(presentation.days) { day in
                    WalkPanel {
                        VStack(alignment: .leading, spacing: Spacing.sm) {
                            Text("D\(day.dayNumber) · \(day.date.description)").font(.headline)
                            Text(day.primaryStage).foregroundStyle(AppColors.textSecondary)
                            Text(weatherLine(day.weather)).foregroundStyle(AppColors.textSecondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }

                if !presentation.sources.isEmpty || !presentation.updatedTimes.isEmpty {
                    weatherPanel(
                        title: "来源与时效",
                        values: presentation.sources.map { "来源：\($0)" }
                            + presentation.updatedTimes.map { "更新：\($0)" }
                    )
                }
            }
            .padding(.horizontal, Spacing.pageHorizontal)
            .padding(.vertical, Spacing.xl)
        }
    }

    private func weatherPanel(title: String, values: [String]) -> some View {
        WalkPanel {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                Text(title).font(.sectionTitle)
                ForEach(values, id: \.self) { value in
                    Text(value).foregroundStyle(AppColors.textSecondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func dateRange(_ start: LocalDate, _ end: LocalDate) -> String {
        start == end ? start.description : "\(start) - \(end)"
    }
}

func weatherLine(_ weather: PersonalTripDayWeather) -> String {
    [
        weather.condition.value?.text,
        weather.temperatureRange.value?.text,
        weather.precipitation.value?.text,
        weather.wind.value?.text,
    ]
    .compactMap { value in
        guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else {
            return nil
        }
        return value
    }
    .joined(separator: " · ")
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
