import Foundation

struct ProfileCalendarDayPresentation: Equatable, Identifiable {
    let date: LocalDate
    let tripCount: Int

    var id: LocalDate { date }
}

struct ProfileCalendarPresentation: Equatable {
    let days: [ProfileCalendarDayPresentation]
    let cellsAreInteractive = false

    init(calendar: PersonalTripCalendar) {
        let counts = Dictionary(uniqueKeysWithValues: calendar.days.map { ($0.date, $0.tripCount) })
        guard let startDate = calendar.windowStartDate.dateAtStartOfDay,
              let endDate = calendar.windowEndDate.dateAtStartOfDay else {
            days = []
            return
        }

        var current = startDate
        var result: [ProfileCalendarDayPresentation] = []
        while current <= endDate {
            let localDate = LocalDate(date: current, calendar: .business)
            result.append(.init(date: localDate, tripCount: counts[localDate] ?? 0))
            guard let next = Calendar.business.date(byAdding: .day, value: 1, to: current) else { break }
            current = next
        }
        days = result
    }
}

@MainActor
final class ProfileViewModel: ObservableObject {
    @Published private(set) var account: AccountResponse?
    @Published private(set) var tripCalendar: PersonalTripCalendar?
    @Published private(set) var equipmentSummary: PersonalEquipmentSummary?
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?
    @Published private(set) var calendarErrorMessage: String?
    @Published private(set) var equipmentErrorMessage: String?
    @Published private(set) var isLoggedIn = false

    private let authSession: any AuthSession
    private let loadAccount: () async throws -> AccountResponse
    private let loadCalendar: () async throws -> PersonalTripCalendar
    private let loadEquipment: () async throws -> PersonalEquipmentCollection
    private let revokeSession: () async throws -> Void
    private let clearCachedResponses: () async -> Void

    init(
        accountService: any AccountServicing,
        tripService: any PersonalTripServicing,
        equipmentService: any EquipmentServicing,
        authSession: any AuthSession = AuthManager.shared,
        clearCachedResponses: @escaping () async -> Void = {}
    ) {
        self.authSession = authSession
        self.loadAccount = { try await accountService.currentAccount() }
        self.loadCalendar = { try await tripService.calendar() }
        self.loadEquipment = { try await equipmentService.getPersonalEquipment() }
        self.revokeSession = { try await accountService.logout() }
        self.clearCachedResponses = clearCachedResponses
    }

    init(
        authSession: any AuthSession,
        loadAccount: @escaping () async throws -> AccountResponse,
        loadCalendar: @escaping () async throws -> PersonalTripCalendar,
        loadEquipment: @escaping () async throws -> PersonalEquipmentCollection,
        revokeSession: @escaping () async throws -> Void = {},
        clearCachedResponses: @escaping () async -> Void = {}
    ) {
        self.authSession = authSession
        self.loadAccount = loadAccount
        self.loadCalendar = loadCalendar
        self.loadEquipment = loadEquipment
        self.revokeSession = revokeSession
        self.clearCachedResponses = clearCachedResponses
    }

    func loadProfile() async {
        isLoggedIn = authSession.isLoggedIn
        guard isLoggedIn else {
            account = nil
            tripCalendar = nil
            equipmentSummary = nil
            errorMessage = nil
            calendarErrorMessage = nil
            equipmentErrorMessage = nil
            isLoading = false
            return
        }

        isLoading = true
        errorMessage = nil
        calendarErrorMessage = nil
        equipmentErrorMessage = nil
        defer { isLoading = false }

        async let accountResult = capture(loadAccount)
        async let calendarResult = capture(loadCalendar)
        async let equipmentResult = capture(loadEquipment)

        let (accountResultValue, calendarResultValue, equipmentResultValue) = await (
            accountResult,
            calendarResult,
            equipmentResult
        )

        switch accountResultValue {
        case .success(let account):
            self.account = account
        case .failure(let error):
            errorMessage = Self.message(for: error)
        }

        switch calendarResultValue {
        case .success(let calendar):
            tripCalendar = calendar
        case .failure(let error):
            calendarErrorMessage = Self.message(for: error)
        }

        switch equipmentResultValue {
        case .success(let equipment):
            equipmentSummary = equipment.summary
        case .failure(let error):
            equipmentErrorMessage = Self.message(for: error)
        }
    }

    func logout() async {
        errorMessage = nil
        do {
            try await revokeSession()
            if authSession.isLoggedIn { authSession.logout() }
            await clearCachedResponses()
            isLoggedIn = false
            account = nil
            tripCalendar = nil
            equipmentSummary = nil
            calendarErrorMessage = nil
            equipmentErrorMessage = nil
        } catch {
            errorMessage = Self.message(for: error)
        }
    }

    private func capture<T>(_ operation: @escaping () async throws -> T) async -> Result<T, Error> {
        do {
            return .success(try await operation())
        } catch {
            return .failure(error)
        }
    }

    private static func message(for error: Error) -> String {
        if let localized = error as? LocalizedError,
           let description = localized.errorDescription {
            return description
        }
        return "加载失败：\(error.localizedDescription)"
    }
}
