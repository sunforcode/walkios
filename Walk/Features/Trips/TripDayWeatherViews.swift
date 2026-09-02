import SwiftUI

struct TripDayPresentation: Equatable {
    let day: PersonalTripDay

    var primaryStage: String { day.primaryStage }
    var dayLabel: String { "D\(day.dayNumber)" }
    var actionSequence: [Int] { day.actions.map(\.sequence) }
    var pointSequence: [Int]? { day.points?.map(\.sequence) }
    var actions: [PersonalTripAction] { day.actions }
    var points: [PersonalTripPoint] { day.points ?? [] }
}

struct TripDaySelection: Equatable {
    let days: [PersonalTripDay]
    private(set) var focusedDayID: String?

    init(days: [PersonalTripDay], initialDayID: String) {
        self.days = days
        focusedDayID = days.contains(where: { $0.identity == initialDayID })
            ? initialDayID
            : days.first?.identity
    }

    var focusedDay: PersonalTripDay? {
        guard let focusedDayID else { return days.first }
        return days.first(where: { $0.identity == focusedDayID }) ?? days.first
    }

    mutating func movePrevious() -> Bool {
        move(by: -1)
    }

    mutating func moveNext() -> Bool {
        move(by: 1)
    }

    private mutating func move(by offset: Int) -> Bool {
        guard let focusedDayID,
              let index = days.firstIndex(where: { $0.identity == focusedDayID }) else {
            return false
        }
        let target = index + offset
        guard days.indices.contains(target) else { return false }
        self.focusedDayID = days[target].identity
        return true
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
    @State private var selection: TripDaySelection?

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
                } else if let day = selection?.focusedDay {
                    TripDayPage(
                        presentation: TripDayPresentation(day: day),
                        canMovePrevious: canMovePrevious,
                        canMoveNext: canMoveNext,
                        onPrevious: { _ = selection?.movePrevious() },
                        onNext: { _ = selection?.moveNext() }
                    )
                } else {
                    EmptyStateView(title: "逐日安排暂不可用", icon: "calendar")
                }
            }
        }
        .navigationTitle(selection?.focusedDay?.primaryStage ?? "逐日详情")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.load()
            if let result = viewModel.result {
                selection = TripDaySelection(days: result.days, initialDayID: viewModel.initialDayID)
            }
        }
    }

    private var focusedIndex: Int? {
        guard let id = selection?.focusedDayID else { return nil }
        return selection?.days.firstIndex(where: { $0.identity == id })
    }

    private var canMovePrevious: Bool { (focusedIndex ?? 0) > 0 }
    private var canMoveNext: Bool {
        guard let selection, let focusedIndex else { return false }
        return focusedIndex < selection.days.count - 1
    }
}

private struct TripDayPage: View {
    let presentation: TripDayPresentation
    let canMovePrevious: Bool
    let canMoveNext: Bool
    let onPrevious: () -> Void
    let onNext: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.xl) {
                PageHeroHeader(title: presentation.dayLabel, subtitle: presentation.day.date.description)

                if !presentation.actions.isEmpty || !presentation.points.isEmpty || hasWeatherContent {
                    WalkPanel {
                        VStack(alignment: .leading, spacing: Spacing.lg) {
                            ForEach(presentation.actions) { action in
                                actionRow(action)
                            }
                            ForEach(presentation.points) { point in
                                pointRow(point)
                            }
                            if hasWeatherContent {
                                contentRow(title: "当日天气", detail: weatherLine(presentation.day.weather))
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                } else {
                    WalkPanel {
                        Text("当天安排暂不可用")
                            .foregroundStyle(AppColors.textWeak)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }

                if canMovePrevious || canMoveNext {
                    HStack {
                        Button("前一天", action: onPrevious).disabled(!canMovePrevious)
                        Spacer()
                        Button("后一天", action: onNext).disabled(!canMoveNext)
                    }
                    .buttonStyle(.bordered)
                    .tint(AppColors.interactionPrimary)
                }
            }
            .padding(.horizontal, Spacing.pageHorizontal)
            .padding(.vertical, Spacing.xl)
        }
    }

    private var hasWeatherContent: Bool {
        !weatherLine(presentation.day.weather).isEmpty
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

private func formatDistance(_ meters: Double) -> String {
    meters >= 1_000
        ? "\((meters / 1_000).formatted(.number.precision(.fractionLength(0...1)))) km"
        : "\(Int(meters.rounded())) m"
}

private func formatDuration(_ seconds: Double) -> String {
    "\((seconds / 3_600).formatted(.number.precision(.fractionLength(0...1)))) 小时"
}
