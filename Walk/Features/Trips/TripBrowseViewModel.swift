import Foundation
import Observation
import WalkData

@MainActor @Observable
final class TripBrowseViewModel {
    private(set) var trip: PersonalTripDetail?
    private(set) var pages: [TripBrowsePage] = []
    private(set) var isLoading = false
    private(set) var errorMessage: String?

    private let loadDetail: (String) async throws -> PersonalTripDetail
    private let loadDays: (String) async throws -> PersonalTripDays
    @ObservationIgnored private var loading: TripRequestLifetime?

    init(service: any PersonalTripServicing) {
        self.loadDetail = { try await service.detail(tripID: $0) }
        self.loadDays = { try await service.days(tripID: $0) }
    }

    init(
        loadDetail: @escaping (String) async throws -> PersonalTripDetail,
        loadDays: @escaping (String) async throws -> PersonalTripDays
    ) {
        self.loadDetail = loadDetail
        self.loadDays = loadDays
    }

    @discardableResult
    func loadTrip(id: String) async -> Bool {
        guard !Task.isCancelled, loading == nil || loading?.isCancelled == true else { return false }
        let request = TripRequestLifetime()
        loading = request
        isLoading = true
        errorMessage = nil
        defer {
            if loading === request {
                loading = nil
                isLoading = false
            }
        }
        return await withTaskCancellationHandler {
            do {
                async let loadedDetail = loadDetail(id)
                async let loadedDays = loadDays(id)
                let (detail, days) = try await (loadedDetail, loadedDays)
                guard loading === request, !request.isCancelled, !Task.isCancelled else { return false }
                guard detail.revision == days.revision,
                      days.tripID == detail.trip.identity else {
                    throw APIClientError.invalidResponse
                }
                trip = detail
                pages = TripBrowsePagePlan.plan(days: days)
                return true
            } catch {
                guard loading === request, !request.isCancelled, !Task.isCancelled,
                      !tripRequestWasCancelled(error) else { return false }
                errorMessage = TripBrowseErrorFormatter.message(error, operation: "加载")
                return false
            }
        } onCancel: {
            request.cancel()
        }
    }

    /// 首次和失败重试使用同一成功路径；未发布结果时不改变页面位置。
    func loadInitialDay(id: String, dayNumber: Int) async -> Int? {
        guard await loadTrip(id: id), !Task.isCancelled else { return nil }
        return initialDayIndex(dayNumber: dayNumber)
    }

    func initialDayIndex(dayNumber: Int) -> Int {
        pages.firstIndex { $0.dayNumber == dayNumber } ?? 0
    }
}

private enum TripBrowseErrorFormatter {
    static func message(_ error: Error, operation: String) -> String {
        if let localized = error as? LocalizedError,
           let description = localized.errorDescription {
            return description
        }
        return "\(operation)失败：\(error.localizedDescription)"
    }
}
