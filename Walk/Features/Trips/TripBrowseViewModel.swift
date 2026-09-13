import SwiftUI
import WalkData

// MARK: - ViewModel

@MainActor
final class TripBrowseViewModel: ObservableObject {
    @Published private(set) var trip: PersonalTripDetail?
    @Published private(set) var pages: [TripBrowsePage] = []
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?

    private let loadDetail: (String) async throws -> PersonalTripDetail
    private let loadDays: (String) async throws -> PersonalTripDays

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

    func loadTrip(id: String) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            async let loadedDetail = loadDetail(id)
            async let loadedDays = loadDays(id)
            let (detail, days) = try await (loadedDetail, loadedDays)
            guard detail.revision == days.revision,
                  days.tripID == detail.trip.identity else {
                throw APIClientError.invalidResponse
            }
            trip = detail
            pages = TripBrowsePagePlan.plan(days: days)
        } catch {
            errorMessage = TripBrowseErrorFormatter.message(error, operation: "加载")
        }
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
