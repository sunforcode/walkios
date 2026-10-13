import Foundation
import Observation
import WalkData

@MainActor @Observable
final class TripWeatherViewModel {
    private(set) var state: TripWeatherState = .idle
    private let tripID: String
    private let loadWeather: (String) async throws -> PersonalTripWeather
    private let loadDetail: (String) async throws -> PersonalTripDetail
    @ObservationIgnored private var loading: TripRequestLifetime?

    var weather: PersonalTripWeather? { state.weather }
    var detail: PersonalTripDetail? { state.detail }
    var isLoading: Bool { state.isLoading }
    var isUnavailable: Bool { state.isUnavailable }
    var errorMessage: String? { state.errorMessage }

    init(tripID: String, service: any PersonalTripServicing) {
        self.tripID = tripID
        self.loadWeather = { try await service.weather(tripID: $0) }
        self.loadDetail = { try await service.detail(tripID: $0) }
    }

    init(
        tripID: String,
        loadWeather: @escaping (String) async throws -> PersonalTripWeather,
        loadDetail: @escaping (String) async throws -> PersonalTripDetail
    ) {
        self.tripID = tripID
        self.loadWeather = loadWeather
        self.loadDetail = loadDetail
    }

    func load() async {
        guard !Task.isCancelled, loading == nil || loading?.isCancelled == true else { return }
        let request = TripRequestLifetime()
        loading = request
        let previous = state.content
        state = .loading(previous: previous)
        defer {
            if loading === request {
                loading = nil
                if state.isLoading { state = previous.map(TripWeatherState.settled) ?? .idle }
            }
        }
        await withTaskCancellationHandler {
            do {
                let weather = try await loadWeather(tripID)
                guard isCurrent(request) else { return }
                let detail = try await loadDetail(tripID)
                guard isCurrent(request) else { return }
                guard PersonalTripWeatherValidator.isValid(
                    weather,
                    tripID: tripID,
                    revision: detail.revision
                ) else {
                    throw APIClientError.invalidResponse
                }
                state = .settled(.ready(weather: weather, detail: detail))
            } catch {
                guard isCurrent(request), !tripRequestWasCancelled(error) else { return }
                if Self.isProjectionUnavailable(error) {
                    // 只为明确的整趟天气不可用读取上下文；取消不得触发或完成降级。
                    do {
                        let detail = try await loadDetail(tripID)
                        guard isCurrent(request) else { return }
                        state = .settled(.unavailable(detail: detail))
                    } catch {
                        guard isCurrent(request), !tripRequestWasCancelled(error) else { return }
                        state = .settled(.unavailable(detail: nil))
                    }
                } else {
                    state = .settled(.failed((error as? LocalizedError)?.errorDescription ?? error.localizedDescription))
                }
            }
        } onCancel: {
            request.cancel()
        }
    }

    private func isCurrent(_ request: TripRequestLifetime) -> Bool {
        loading === request && !request.isCancelled && !Task.isCancelled
    }

    private static func isProjectionUnavailable(_ error: Error) -> Bool {
        guard case APIClientError.api(let code, _, _, _) = error else { return false }
        return code == "trip_weather_projection_unavailable"
    }
}
