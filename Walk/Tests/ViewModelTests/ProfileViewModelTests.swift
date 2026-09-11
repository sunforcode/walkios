import XCTest
@testable import Walk

@MainActor
final class ProfileViewModelTests: XCTestCase {
    func testGuestProfileDoesNotRequestPersonalResources() async {
        let session = AuthSessionStub(isLoggedIn: false)
        var calls: [String] = []
        let sut = ProfileViewModel(
            authSession: session,
            loadAccount: { calls.append("account"); throw APIClientError.invalidResponse },
            loadCalendar: { calls.append("calendar"); throw APIClientError.invalidResponse },
            loadEquipment: { calls.append("equipment"); throw APIClientError.invalidResponse }
        )

        await sut.loadProfile()

        XCTAssertFalse(sut.isLoggedIn)
        XCTAssertTrue(calls.isEmpty)
        XCTAssertNil(sut.account)
        XCTAssertNil(sut.tripCalendar)
        XCTAssertNil(sut.equipmentSummary)
    }

    func testLoggedInProfileLoadsOnlyAccountCalendarAndEquipmentSummaries() async {
        let session = AuthSessionStub(isLoggedIn: true)
        var calls: [String] = []
        let account = AccountResponse(
            account: AccountProjection(identity: "account-1"),
            profile: ProfileProjection(
                identity: "profile-1",
                maskedPhone: "+86 138****8000",
                nickname: "行者",
                avatar: "media-avatar-1"
            )
        )
        let calendar = PersonalTripCalendar(
            windowStartDate: LocalDate(year: 2025, month: 9, day: 3),
            windowEndDate: LocalDate(year: 2026, month: 9, day: 2),
            days: [PersonalTripCalendarDay(date: LocalDate(year: 2026, month: 8, day: 25), tripCount: 1)]
        )
        let equipment = PersonalEquipmentCollection(
            items: [],
            summary: PersonalEquipmentSummary(
                equipmentItemCount: 12,
                equipmentListCount: 3,
                knownTotalWeight: EquipmentWeight(grams: 8_420),
                missingWeightItemCount: 2
            )
        )
        let sut = ProfileViewModel(
            authSession: session,
            loadAccount: { calls.append("account"); return account },
            loadCalendar: { calls.append("calendar"); return calendar },
            loadEquipment: { calls.append("equipment"); return equipment }
        )

        await sut.loadProfile()

        XCTAssertEqual(Set(calls), ["account", "calendar", "equipment"])
        XCTAssertEqual(sut.account, account)
        XCTAssertEqual(sut.account?.account.identity, "account-1")
        XCTAssertEqual(sut.account?.profile.identity, "profile-1")
        XCTAssertEqual(sut.account?.profile.maskedPhone, "+86 138****8000")
        XCTAssertEqual(sut.account?.profile.nickname, "行者")
        XCTAssertEqual(sut.account?.profile.avatar, "media-avatar-1")
        XCTAssertEqual(sut.tripCalendar, calendar)
        XCTAssertEqual(sut.equipmentSummary?.equipmentItemCount, 12)
        XCTAssertEqual(sut.equipmentSummary?.equipmentListCount, 3)
        XCTAssertEqual(sut.equipmentSummary?.knownTotalWeight.grams, 8_420)
        XCTAssertEqual(sut.equipmentSummary?.missingWeightItemCount, 2)
        let weight = AccountEquipmentFormatting.weightParts(grams: 8_420)
        XCTAssertEqual(weight.value, "8.4")
        XCTAssertEqual(weight.unit, "kg")
        XCTAssertNil(sut.errorMessage)
    }

    func testLogoutServerFailureKeepsLocalSessionAndProfile() async {
        let session = AuthSessionStub(isLoggedIn: true)
        let account = AccountResponse(
            account: AccountProjection(identity: "account-1"),
            profile: ProfileProjection(identity: "profile-1", maskedPhone: "+86 138****8000", nickname: nil, avatar: nil)
        )
        let sut = ProfileViewModel(
            authSession: session,
            loadAccount: { account },
            loadCalendar: { Self.emptyCalendar },
            loadEquipment: { Self.emptyEquipment },
            revokeSession: { throw APIClientError.api(code: "logout_failed", message: "退出失败", retryable: true) }
        )
        await sut.loadProfile()

        await sut.logout()

        XCTAssertTrue(session.isLoggedIn)
        XCTAssertFalse(session.didLogout)
        XCTAssertEqual(sut.account, account)
        XCTAssertEqual(sut.errorMessage, "退出失败")
        XCTAssertEqual(sut.logoutErrorMessage, "退出失败")
    }

    func testProfileCalendarMapsFullServerWindowAndSparseTripCounts() {
        let calendar = PersonalTripCalendar(
            windowStartDate: LocalDate(year: 2025, month: 9, day: 2),
            windowEndDate: LocalDate(year: 2026, month: 9, day: 1),
            days: [
                PersonalTripCalendarDay(
                    date: LocalDate(year: 2026, month: 9, day: 1),
                    tripCount: 2
                )
            ]
        )

        let presentation = ProfileCalendarPresentation(calendar: calendar)

        XCTAssertEqual(presentation.days.count, 365)
        XCTAssertEqual(presentation.days.first?.date, calendar.windowStartDate)
        XCTAssertEqual(presentation.days.last?.date, calendar.windowEndDate)
        XCTAssertEqual(presentation.days.last?.tripCount, 2)
        XCTAssertTrue(presentation.hasTrips)

        let componentProjection = presentation.tripCalendarCardProjection
        XCTAssertEqual(componentProjection.days.count, 365)
        XCTAssertEqual(componentProjection.days.first?.businessDate, calendar.windowStartDate.description)
        XCTAssertEqual(componentProjection.days.first?.level, .empty)
        XCTAssertEqual(componentProjection.days.last?.businessDate, calendar.windowEndDate.description)
        XCTAssertEqual(componentProjection.days.last?.level, .medium)
        XCTAssertNil(componentProjection.emptyHint)
    }

    func testSuccessfulEmptyCalendarMapsToProductionCardEmptyState() {
        let presentation = ProfileCalendarPresentation(calendar: Self.emptyCalendar)

        XCTAssertEqual(presentation.days.count, 365)
        XCTAssertFalse(presentation.hasTrips)
        XCTAssertEqual(presentation.tripCalendarCardProjection.days.count, 365)
        XCTAssertEqual(
            presentation.tripCalendarCardProjection.emptyHint,
            "过去 365 天还没有个人行程"
        )
    }

    func testCalendarProjectionDoesNotTruncateAnInvalidServerWindowIntoAValidCard() {
        let invalidCalendar = PersonalTripCalendar(
            windowStartDate: LocalDate(year: 2025, month: 9, day: 1),
            windowEndDate: LocalDate(year: 2026, month: 9, day: 1),
            days: []
        )

        let presentation = ProfileCalendarPresentation(calendar: invalidCalendar)

        XCTAssertEqual(presentation.days.count, 366)
        XCTAssertEqual(presentation.tripCalendarCardProjection.days.count, 366)
    }

    func testProfileSourceKeepsLocalSectionRetries() throws {
        let source = try productionSource(at: "Features/Profile/ProfileView.swift")

        XCTAssertTrue(source.contains("viewModel.retryCalendar()"))
        XCTAssertTrue(source.contains("viewModel.retryEquipment()"))
    }

    func testProfilePageUsesProductionComponentsWithoutPrivateDuplicatesOrMediaParsing() throws {
        let source = try productionSource(at: "Features/Profile/ProfileView.swift")
        let calendarComponentSource = try productionSource(
            at: "Features/Trips/Components/TripCalendarCard.swift"
        )
        let accountMenuSource = try productionSource(
            at: "Features/Profile/Components/AccountMenuSheet.swift"
        )
        let equipmentComponentSource = try productionSource(
            at: "Features/Profile/Components/PersonalEquipmentSummaryCard.swift"
        )

        XCTAssertTrue(source.contains("TripBusinessComponents.TripCalendarCard("))
        XCTAssertTrue(source.contains("PersonalEquipmentSummaryCard("))
        XCTAssertTrue(source.contains("AccountMenuSheet("))
        XCTAssertTrue(source.contains("profile: account.profile"))
        XCTAssertTrue(source.contains("avatarLabel: profile.nickname"))
        XCTAssertTrue(source.contains("avatarImage: nil"))
        XCTAssertTrue(source.contains("logoutError: viewModel.logoutErrorMessage"))
        XCTAssertTrue(calendarComponentSource.contains("TripBusinessComponents.HeatmapCalendar("))
        XCTAssertTrue(accountMenuSource.contains("AccountEquipmentBusinessComponents.ProfileIdentityHeader("))
        XCTAssertTrue(accountMenuSource.contains("SettingsListRow("))
        XCTAssertTrue(equipmentComponentSource.contains("summary.equipmentItemCount"))
        XCTAssertTrue(equipmentComponentSource.contains("summary.equipmentListCount"))
        XCTAssertTrue(equipmentComponentSource.contains("summary.knownTotalWeight.grams"))
        XCTAssertTrue(equipmentComponentSource.contains("summary.missingWeightItemCount"))
        XCTAssertFalse(equipmentComponentSource.contains("ownedQuantity"))
        XCTAssertFalse(source.contains("tripCalendarCardSurface"))
        XCTAssertFalse(source.contains("calendarCardBody"))
        XCTAssertFalse(source.contains("equipmentSummaryCardSurface"))
        XCTAssertFalse(source.contains("equipmentMetrics"))
        XCTAssertFalse(source.contains("ProfileSettingsOverlay"))
        XCTAssertFalse(source.contains("HeatmapCalendar("))
        XCTAssertFalse(source.contains("URL(string:"))
        XCTAssertFalse(source.contains("AsyncImage("))
    }

    func testProfileSourceKeepsTripsBehindCalendarAndRoutesLogoutToRoutesTab() throws {
        let source = try productionSource(at: "Features/Profile/ProfileView.swift")
        let rootSource = try productionSource(at: "App/RootView.swift")
        let calendarStart = try XCTUnwrap(source.range(of: "private var tripCalendarSection"))
        let equipmentStart = try XCTUnwrap(source.range(of: "private var equipmentSection"))
        let calendarSource = String(source[calendarStart.lowerBound..<equipmentStart.lowerBound])

        XCTAssertTrue(calendarSource.contains("onNavigate(.tripList)"))
        XCTAssertFalse(source.contains("我的全部行程"))
        XCTAssertTrue(source.contains("case .accountSecurity: .accountSecurity"))
        XCTAssertTrue(rootSource.contains("shell.showRouteDiscovery()"))
    }

    func testCalendarFailureDoesNotDiscardAccountOrEquipmentSummary() async {
        let session = AuthSessionStub(isLoggedIn: true)
        let account = AccountResponse(
            account: AccountProjection(identity: "account-1"),
            profile: ProfileProjection(identity: "profile-1", maskedPhone: "+86 138****8000", nickname: nil, avatar: nil)
        )
        let sut = ProfileViewModel(
            authSession: session,
            loadAccount: { account },
            loadCalendar: { throw APIClientError.invalidResponse },
            loadEquipment: { Self.emptyEquipment }
        )

        await sut.loadProfile()

        XCTAssertEqual(sut.account, account)
        XCTAssertEqual(sut.equipmentSummary, Self.emptyEquipment.summary)
        XCTAssertNotNil(sut.calendarErrorMessage)
        XCTAssertNil(sut.equipmentErrorMessage)
    }

    func testRetryCalendarOnlyReloadsFailedCalendarSection() async {
        let session = AuthSessionStub(isLoggedIn: true)
        var calendarAttempts = 0
        var equipmentLoads = 0
        let sut = ProfileViewModel(
            authSession: session,
            loadAccount: {
                AccountResponse(
                    account: AccountProjection(identity: "account-1"),
                    profile: ProfileProjection(identity: "profile-1", maskedPhone: "+86 138****8000", nickname: nil, avatar: nil)
                )
            },
            loadCalendar: {
                calendarAttempts += 1
                if calendarAttempts == 1 { throw APIClientError.invalidResponse }
                return Self.emptyCalendar
            },
            loadEquipment: {
                equipmentLoads += 1
                return Self.emptyEquipment
            }
        )
        await sut.loadProfile()

        await sut.retryCalendar()

        XCTAssertEqual(calendarAttempts, 2)
        XCTAssertEqual(equipmentLoads, 1)
        XCTAssertEqual(sut.tripCalendar, Self.emptyCalendar)
        XCTAssertNil(sut.calendarErrorMessage)
    }

    func testRetryEquipmentOnlyReloadsFailedEquipmentSection() async {
        let session = AuthSessionStub(isLoggedIn: true)
        var calendarLoads = 0
        var equipmentAttempts = 0
        let sut = ProfileViewModel(
            authSession: session,
            loadAccount: {
                AccountResponse(
                    account: AccountProjection(identity: "account-1"),
                    profile: ProfileProjection(identity: "profile-1", maskedPhone: "+86 138****8000", nickname: nil, avatar: nil)
                )
            },
            loadCalendar: {
                calendarLoads += 1
                return Self.emptyCalendar
            },
            loadEquipment: {
                equipmentAttempts += 1
                if equipmentAttempts == 1 { throw APIClientError.invalidResponse }
                return Self.emptyEquipment
            }
        )
        await sut.loadProfile()

        await sut.retryEquipment()

        XCTAssertEqual(calendarLoads, 1)
        XCTAssertEqual(equipmentAttempts, 2)
        XCTAssertEqual(sut.equipmentSummary, Self.emptyEquipment.summary)
        XCTAssertNil(sut.equipmentErrorMessage)
    }

    func testLogoutClearsLocalSessionAndCacheOnlyAfterServerSuccess() async {
        let session = AuthSessionStub(isLoggedIn: true)
        var events: [String] = []
        let sut = ProfileViewModel(
            authSession: session,
            loadAccount: {
                AccountResponse(
                    account: AccountProjection(identity: "account-1"),
                    profile: ProfileProjection(identity: "profile-1", maskedPhone: "+86 138****8000", nickname: nil, avatar: nil)
                )
            },
            loadCalendar: { Self.emptyCalendar },
            loadEquipment: { Self.emptyEquipment },
            revokeSession: { events.append("server") },
            clearCachedResponses: {
                events.append(session.isLoggedIn ? "cache-before-logout" : "cache-after-logout")
            }
        )
        await sut.loadProfile()

        await sut.logout()

        XCTAssertEqual(events, ["server", "cache-after-logout"])
        XCTAssertTrue(session.didLogout)
        XCTAssertFalse(sut.isLoggedIn)
        XCTAssertNil(sut.account)
    }

    func testAccountServiceDoesNotMapMaskedPhoneIntoLegacyEmail() throws {
        let testFileURL = URL(fileURLWithPath: #filePath)
        let sourceURL = testFileURL
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Data/Repositories/UserService.swift")
        let source = try String(contentsOf: sourceURL, encoding: .utf8)

        XCTAssertFalse(source.contains("email:"))
        XCTAssertFalse(source.contains("final class UserService"))
    }

    private static let emptyCalendar = PersonalTripCalendar(
        windowStartDate: LocalDate(year: 2025, month: 9, day: 3),
        windowEndDate: LocalDate(year: 2026, month: 9, day: 2),
        days: []
    )

    private func productionSource(at relativePath: String) throws -> String {
        let testFileURL = URL(fileURLWithPath: #filePath)
        let walkRoot = testFileURL
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        return try String(contentsOf: walkRoot.appendingPathComponent(relativePath), encoding: .utf8)
    }

    private static let emptyEquipment = PersonalEquipmentCollection(
        items: [],
        summary: PersonalEquipmentSummary(
            equipmentItemCount: 0,
            equipmentListCount: 0,
            knownTotalWeight: EquipmentWeight(grams: 0),
            missingWeightItemCount: 0
        )
    )
}

private final class AuthSessionStub: AuthSession {
    var isLoggedIn: Bool
    var cacheIdentity = "test-user"
    var didLogout = false

    init(isLoggedIn: Bool) {
        self.isLoggedIn = isLoggedIn
    }

    func logout() {
        didLogout = true
        isLoggedIn = false
    }
}
