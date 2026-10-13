import Foundation
import Observation
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
            emptyHint: days.count == SharedBusinessComponents.HeatmapCalendar.requiredDayCount && !hasTrips
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
@Observable
final class ProfileViewModel {
    private(set) var account: AccountResponse?
    private(set) var tripCalendar: PersonalTripCalendar?
    var isLoading: Bool { isAccountLoading || isCalendarLoading }
    private(set) var isAccountLoading = false
    private(set) var isCalendarLoading = false
    private(set) var isLoggingOut = false
    private(set) var errorMessage: String?
    private(set) var accountErrorMessage: String?
    private(set) var calendarErrorMessage: String?
    private(set) var logoutErrorMessage: String?
    private(set) var isLoggedIn = false
    private(set) var isAvatarUpdating = false
    private(set) var avatarErrorMessage: String?
    private(set) var isSavingProfile = false
    private(set) var profileUpdateErrorMessage: String?

    private let authSession: any AuthSession
    private let loadAccount: () async throws -> AccountResponse
    private let loadCalendar: () async throws -> PersonalTripCalendar
    private let uploadAvatar: ((Data, String) async throws -> AvatarMediaResponse)?
    private let updateProfile: ((ProfileUpdate) async throws -> ProfileResponse)?
    private let revokeSession: () async throws -> Void
    private let clearCachedResponses: () async -> Void
    private var sessionIdentity: String?
    private var sessionGeneration = 0
    private var accountGeneration = 0
    private var calendarGeneration = 0
    private var mutationGeneration = 0
    private var logoutGeneration = 0

    init(
        accountService: any AccountServicing,
        tripService: any PersonalTripServicing,
        authSession: any AuthSession,
        clearCachedResponses: @escaping () async -> Void = {}
    ) {
        self.authSession = authSession
        self.loadAccount = { try await accountService.currentAccount() }
        self.loadCalendar = { try await tripService.calendar() }
        self.uploadAvatar = { try await accountService.uploadAvatar(data: $0, contentType: $1) }
        self.updateProfile = { try await accountService.updateProfile($0) }
        self.revokeSession = { try await accountService.logout() }
        self.clearCachedResponses = clearCachedResponses
    }

    init(
        authSession: any AuthSession,
        loadAccount: @escaping () async throws -> AccountResponse,
        loadCalendar: @escaping () async throws -> PersonalTripCalendar,
        uploadAvatar: ((Data, String) async throws -> AvatarMediaResponse)? = nil,
        updateProfile: ((ProfileUpdate) async throws -> ProfileResponse)? = nil,
        revokeSession: @escaping () async throws -> Void = {},
        clearCachedResponses: @escaping () async -> Void = {}
    ) {
        self.authSession = authSession
        self.loadAccount = loadAccount
        self.loadCalendar = loadCalendar
        self.uploadAvatar = uploadAvatar
        self.updateProfile = updateProfile
        self.revokeSession = revokeSession
        self.clearCachedResponses = clearCachedResponses
    }

    /// 头像更新仍先上传媒体，再写 Profile；返回值只表示本次操作是否成功回填。
    @discardableResult
    func updateAvatar(data: Data, contentType: String) async -> Bool {
        guard !Task.isCancelled, let identity = synchronizeSession(),
              !isLoggingOut, !isAvatarUpdating, !isSavingProfile, account != nil else { return false }
        guard let uploadAvatar, let updateProfile else {
            avatarErrorMessage = "头像更新暂不可用"
            return false
        }
        mutationGeneration += 1
        let generation = mutationGeneration
        let session = sessionGeneration
        isAvatarUpdating = true
        avatarErrorMessage = nil
        defer { if generation == mutationGeneration { isAvatarUpdating = false } }

        do {
            let media = try await uploadAvatar(data, contentType)
            guard acceptsResult(session: session, identity: identity),
                  generation == mutationGeneration, !Task.isCancelled else { return false }
            let response = try await updateProfile(ProfileUpdate(avatar: .value(media.mediaReference)))
            guard acceptsResult(session: session, identity: identity),
                  generation == mutationGeneration, !Task.isCancelled else { return false }
            applyProfile(response)
            return true
        } catch {
            guard acceptsResult(session: session, identity: identity),
                  generation == mutationGeneration, !Self.isCancellation(error) else { return false }
            avatarErrorMessage = Self.message(for: error)
            return false
        }
    }

    func reportAvatarReadFailure() {
        guard synchronizeSession() != nil, !isLoggingOut else { return }
        avatarErrorMessage = "无法读取所选头像"
    }

    @discardableResult
    func updateNickname(_ nickname: String) async -> Bool {
        guard !Task.isCancelled, let identity = synchronizeSession(),
              !isLoggingOut, !isSavingProfile, !isAvatarUpdating, account != nil else { return false }
        guard let updateProfile else {
            profileUpdateErrorMessage = "昵称保存暂不可用"
            return false
        }
        mutationGeneration += 1
        let generation = mutationGeneration
        let session = sessionGeneration
        isSavingProfile = true
        profileUpdateErrorMessage = nil
        defer { if generation == mutationGeneration { isSavingProfile = false } }

        do {
            let trimmed = nickname.trimmingCharacters(in: .whitespacesAndNewlines)
            let response = try await updateProfile(
                ProfileUpdate(nickname: trimmed.isEmpty ? .clear : .value(trimmed))
            )
            guard acceptsResult(session: session, identity: identity),
                  generation == mutationGeneration, !Task.isCancelled else { return false }
            applyProfile(response)
            return true
        } catch {
            guard acceptsResult(session: session, identity: identity),
                  generation == mutationGeneration, !Self.isCancellation(error) else { return false }
            profileUpdateErrorMessage = Self.message(for: error)
            return false
        }
    }

    /// Clears data from a previous identity before a root page can render it.
    func synchronizeAuthentication() {
        _ = synchronizeSession()
    }

    func loadProfile() async {
        guard !Task.isCancelled, synchronizeSession() != nil, !isLoggingOut else { return }
        logoutErrorMessage = nil
        async let accountLoad: Void = loadAccountSection()
        async let calendarLoad: Void = loadCalendarSection()
        _ = await (accountLoad, calendarLoad)
    }

    func retryAccount() async { await loadAccountSection() }
    func retryCalendar() async { await loadCalendarSection() }

    @discardableResult
    func logout() async -> Bool {
        guard !Task.isCancelled, let identity = synchronizeSession(), !isLoggingOut else { return false }
        // 退出开始即使在途分区和修改失效；失败仍保留已有个人数据，允许独立重试。
        invalidateRequests()
        let generation = logoutGeneration
        isLoggingOut = true
        errorMessage = nil
        logoutErrorMessage = nil
        defer { if generation == logoutGeneration { isLoggingOut = false } }

        do {
            try await revokeSession()
            guard generation == logoutGeneration, !Task.isCancelled else { return false }
            // AccountService 可先清理同一会话；仍在线时必须确认没有切换到另一身份。
            guard !authSession.isLoggedIn || authSession.cacheIdentity == identity else {
                _ = synchronizeSession()
                return false
            }
            if authSession.isLoggedIn { authSession.logout() }
            clearPersonalData()
            sessionIdentity = nil
            isLoggedIn = false
            let clearedGeneration = sessionGeneration
            await clearCachedResponses()
            return !Task.isCancelled && sessionGeneration == clearedGeneration && !authSession.isLoggedIn
        } catch {
            guard generation == logoutGeneration,
                  acceptsResult(session: sessionGeneration, identity: identity),
                  !Self.isCancellation(error) else { return false }
            let message = Self.message(for: error)
            errorMessage = message
            logoutErrorMessage = message
            return false
        }
    }

    private func loadAccountSection() async {
        guard !Task.isCancelled, let identity = synchronizeSession(), !isLoggingOut else { return }
        accountGeneration += 1
        let generation = accountGeneration
        let session = sessionGeneration
        isAccountLoading = true
        accountErrorMessage = nil
        errorMessage = nil
        defer { if generation == accountGeneration { isAccountLoading = false } }
        do {
            let response = try await loadAccount()
            guard acceptsResult(session: session, identity: identity),
                  generation == accountGeneration, !Task.isCancelled else { return }
            account = response
        } catch {
            guard acceptsResult(session: session, identity: identity),
                  generation == accountGeneration, !Self.isCancellation(error) else { return }
            let message = Self.message(for: error)
            accountErrorMessage = message
            errorMessage = message
        }
    }

    private func loadCalendarSection() async {
        guard !Task.isCancelled, let identity = synchronizeSession(), !isLoggingOut else { return }
        calendarGeneration += 1
        let generation = calendarGeneration
        let session = sessionGeneration
        isCalendarLoading = true
        calendarErrorMessage = nil
        defer { if generation == calendarGeneration { isCalendarLoading = false } }
        do {
            let response = try await loadCalendar()
            guard acceptsResult(session: session, identity: identity),
                  generation == calendarGeneration, !Task.isCancelled else { return }
            tripCalendar = response
        } catch {
            guard acceptsResult(session: session, identity: identity),
                  generation == calendarGeneration, !Self.isCancellation(error) else { return }
            calendarErrorMessage = Self.message(for: error)
        }
    }

    private func synchronizeSession() -> String? {
        let identity = authSession.isLoggedIn ? authSession.cacheIdentity : nil
        if identity != sessionIdentity {
            // AccountService may publish its successful logout before revokeSession returns.
            // Clear personal reads immediately, but let that same logout finish cache cleanup.
            invalidateRequests(preservingLogout: isLoggingOut && identity == nil)
            clearPersonalData()
            sessionIdentity = identity
        }
        isLoggedIn = identity != nil
        return identity
    }

    private func acceptsResult(session: Int, identity: String) -> Bool {
        guard session == sessionGeneration else { return false }
        guard authSession.isLoggedIn, authSession.cacheIdentity == identity else {
            _ = synchronizeSession()
            return false
        }
        return true
    }

    private func invalidateRequests(preservingLogout: Bool = false) {
        sessionGeneration += 1
        accountGeneration += 1
        calendarGeneration += 1
        mutationGeneration += 1
        isAccountLoading = false
        isCalendarLoading = false
        isAvatarUpdating = false
        isSavingProfile = false
        if !preservingLogout {
            logoutGeneration += 1
            isLoggingOut = false
        }
    }

    private func clearPersonalData() {
        account = nil
        tripCalendar = nil
        errorMessage = nil
        accountErrorMessage = nil
        calendarErrorMessage = nil
        logoutErrorMessage = nil
        avatarErrorMessage = nil
        profileUpdateErrorMessage = nil
    }

    private func applyProfile(_ response: ProfileResponse) {
        guard let account else { return }
        // 保存后，先前发出的账号读取不得把新资料覆盖回旧版本。
        accountGeneration += 1
        isAccountLoading = false
        accountErrorMessage = nil
        errorMessage = nil
        self.account = AccountResponse(account: account.account, profile: response.profile)
    }

    private static func isCancellation(_ error: Error) -> Bool {
        if Task.isCancelled || error is CancellationError { return true }
        if let apiError = error as? APIClientError, case .transport(.cancelled) = apiError { return true }
        return false
    }

    private static func message(for error: Error) -> String {
        if let localized = error as? LocalizedError,
           let description = localized.errorDescription {
            return description
        }
        return "加载失败：\(error.localizedDescription)"
    }
}
