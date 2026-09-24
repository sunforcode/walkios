import Foundation
import WalkData
import WalkDesignSystem

struct ProfileCalendarDayPresentation: Equatable, Identifiable {
    let date: LocalDate
    let tripCount: Int

    var id: LocalDate { date }
}

struct ProfileCalendarPresentation: Equatable {
    let days: [ProfileCalendarDayPresentation]
    let hasTrips: Bool

    init(calendar: PersonalTripCalendar) {
        let counts = Dictionary(uniqueKeysWithValues: calendar.days.map { ($0.date, $0.tripCount) })
        guard let startDate = calendar.windowStartDate.dateAtStartOfDay,
              let endDate = calendar.windowEndDate.dateAtStartOfDay else {
            days = []
            hasTrips = false
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
        hasTrips = result.contains { $0.tripCount > 0 }
    }

    var tripCalendarCardProjection: TripCalendarCardProjection {
        TripCalendarCardProjection(
            days: days.map {
                TripHeatmapDayProjection(
                    businessDate: $0.date.description,
                    level: Self.heatmapLevel(for: $0.tripCount)
                )
            },
            emptyHint: days.count == TripBusinessComponents.HeatmapCalendar.requiredDayCount && !hasTrips
                ? "过去 365 天还没有个人行程"
                : nil
        )
    }

    private static func heatmapLevel(for tripCount: Int) -> TripHeatmapLevel {
        switch tripCount {
        case ...0: .empty
        case 1: .low
        case 2: .medium
        default: .high
        }
    }
}

@MainActor
final class ProfileViewModel: ObservableObject {
    @Published private(set) var account: AccountResponse?
    @Published private(set) var tripCalendar: PersonalTripCalendar?
    @Published private(set) var equipmentSummary: PersonalEquipmentSummary?
    @Published private(set) var isLoading = false
    @Published private(set) var isAccountLoading = false
    @Published private(set) var isCalendarLoading = false
    @Published private(set) var isEquipmentLoading = false
    @Published private(set) var isLoggingOut = false
    @Published var errorMessage: String?
    @Published private(set) var accountErrorMessage: String?
    @Published private(set) var calendarErrorMessage: String?
    @Published private(set) var equipmentErrorMessage: String?
    @Published private(set) var logoutErrorMessage: String?
    @Published private(set) var isLoggedIn = false
    @Published private(set) var isAvatarUpdating = false
    @Published private(set) var avatarErrorMessage: String?
    @Published private(set) var isSavingProfile = false
    @Published private(set) var profileUpdateErrorMessage: String?

    private let authSession: any AuthSession
    private let loadAccount: () async throws -> AccountResponse
    private let loadCalendar: () async throws -> PersonalTripCalendar
    private let loadEquipment: () async throws -> PersonalEquipmentCollection
    private let uploadAvatar: ((Data, String) async throws -> AvatarMediaResponse)?
    private let updateProfile: ((ProfileUpdate) async throws -> ProfileResponse)?
    private let revokeSession: () async throws -> Void
    private let clearCachedResponses: () async -> Void

    init(
        accountService: any AccountServicing,
        tripService: any PersonalTripServicing,
        equipmentService: any EquipmentServicing,
        authSession: any AuthSession,
        clearCachedResponses: @escaping () async -> Void = {}
    ) {
        self.authSession = authSession
        self.loadAccount = { try await accountService.currentAccount() }
        self.loadCalendar = { try await tripService.calendar() }
        self.loadEquipment = { try await equipmentService.getPersonalEquipment() }
        self.uploadAvatar = { try await accountService.uploadAvatar(data: $0, contentType: $1) }
        self.updateProfile = { try await accountService.updateProfile($0) }
        self.revokeSession = { try await accountService.logout() }
        self.clearCachedResponses = clearCachedResponses
    }

    init(
        authSession: any AuthSession,
        loadAccount: @escaping () async throws -> AccountResponse,
        loadCalendar: @escaping () async throws -> PersonalTripCalendar,
        loadEquipment: @escaping () async throws -> PersonalEquipmentCollection,
        uploadAvatar: ((Data, String) async throws -> AvatarMediaResponse)? = nil,
        updateProfile: ((ProfileUpdate) async throws -> ProfileResponse)? = nil,
        revokeSession: @escaping () async throws -> Void = {},
        clearCachedResponses: @escaping () async -> Void = {}
    ) {
        self.authSession = authSession
        self.loadAccount = loadAccount
        self.loadCalendar = loadCalendar
        self.loadEquipment = loadEquipment
        self.uploadAvatar = uploadAvatar
        self.updateProfile = updateProfile
        self.revokeSession = revokeSession
        self.clearCachedResponses = clearCachedResponses
    }

    /// 头像更新：先上传头像媒体取得 mediaReference，再写入 Profile；
    /// 成功后刷新共享 `account.profile`，失败保留原头像并暴露当前 Modal 可见错误。
    func updateAvatar(data: Data, contentType: String) async {
        guard !isAvatarUpdating else { return }
        guard let uploadAvatar, let updateProfile else {
            avatarErrorMessage = "头像更新暂不可用"
            return
        }
        isAvatarUpdating = true
        avatarErrorMessage = nil
        defer { isAvatarUpdating = false }

        do {
            let media = try await uploadAvatar(data, contentType)
            let response = try await updateProfile(ProfileUpdate(avatar: .value(media.mediaReference)))
            if let account {
                self.account = AccountResponse(account: account.account, profile: response.profile)
            }
        } catch {
            avatarErrorMessage = Self.message(for: error)
        }
    }

    /// 头像数据读取失败：在设置 Modal 内可见，不改变内部层级、不关闭 Modal。
    func reportAvatarReadFailure() {
        avatarErrorMessage = "无法读取所选头像"
    }

    /// 昵称保存：写入既有 Profile 更新接口，成功后刷新共享 `account.profile`。
    func updateNickname(_ nickname: String) async {
        guard let updateProfile else {
            profileUpdateErrorMessage = "昵称保存暂不可用"
            return
        }
        guard !isSavingProfile else { return }
        isSavingProfile = true
        profileUpdateErrorMessage = nil
        defer { isSavingProfile = false }

        do {
            let trimmed = nickname.trimmingCharacters(in: .whitespacesAndNewlines)
            let response = try await updateProfile(
                ProfileUpdate(nickname: trimmed.isEmpty ? .clear : .value(trimmed))
            )
            if let account {
                self.account = AccountResponse(account: account.account, profile: response.profile)
            }
        } catch {
            profileUpdateErrorMessage = Self.message(for: error)
        }
    }

    func loadProfile() async {
        isLoggedIn = authSession.isLoggedIn
        guard isLoggedIn else {
            account = nil
            tripCalendar = nil
            equipmentSummary = nil
            errorMessage = nil
            accountErrorMessage = nil
            calendarErrorMessage = nil
            equipmentErrorMessage = nil
            logoutErrorMessage = nil
            isLoading = false
            isAccountLoading = false
            isCalendarLoading = false
            isEquipmentLoading = false
            isLoggingOut = false
            return
        }

        isLoading = true
        errorMessage = nil
        accountErrorMessage = nil
        calendarErrorMessage = nil
        equipmentErrorMessage = nil
        logoutErrorMessage = nil
        isAccountLoading = true
        isCalendarLoading = true
        isEquipmentLoading = true

        async let accountLoad: Void = loadAccountSection()
        async let calendarLoad: Void = loadCalendarSection()
        async let equipmentLoad: Void = loadEquipmentSection()
        _ = await (accountLoad, calendarLoad, equipmentLoad)

        isLoading = false
    }

    func retryAccount() async {
        isAccountLoading = true
        errorMessage = nil
        await loadAccountSection()
    }

    func retryCalendar() async {
        isCalendarLoading = true
        await loadCalendarSection()
    }

    func retryEquipment() async {
        isEquipmentLoading = true
        await loadEquipmentSection()
    }

    func logout() async {
        guard !isLoggingOut else { return }
        isLoggingOut = true
        errorMessage = nil
        logoutErrorMessage = nil
        defer { isLoggingOut = false }

        do {
            try await revokeSession()
            if authSession.isLoggedIn { authSession.logout() }
            await clearCachedResponses()
            isLoggedIn = false
            account = nil
            tripCalendar = nil
            equipmentSummary = nil
            accountErrorMessage = nil
            calendarErrorMessage = nil
            equipmentErrorMessage = nil
        } catch {
            let message = Self.message(for: error)
            errorMessage = message
            logoutErrorMessage = message
        }
    }

    private func loadAccountSection() async {
        accountErrorMessage = nil
        defer { isAccountLoading = false }
        do {
            account = try await loadAccount()
        } catch {
            let message = Self.message(for: error)
            accountErrorMessage = message
            errorMessage = message
        }
    }

    private func loadCalendarSection() async {
        calendarErrorMessage = nil
        defer { isCalendarLoading = false }
        do {
            tripCalendar = try await loadCalendar()
        } catch {
            calendarErrorMessage = Self.message(for: error)
        }
    }

    private func loadEquipmentSection() async {
        equipmentErrorMessage = nil
        defer { isEquipmentLoading = false }
        do {
            equipmentSummary = try await loadEquipment().summary
        } catch {
            equipmentErrorMessage = Self.message(for: error)
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
