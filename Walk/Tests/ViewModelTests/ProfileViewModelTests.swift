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
                equipmentItemCount: 0,
                equipmentListCount: 2,
                knownTotalWeight: EquipmentWeight(grams: 0),
                missingWeightItemCount: 0
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
        XCTAssertEqual(sut.tripCalendar, calendar)
        XCTAssertEqual(sut.equipmentSummary, equipment.summary)
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
    }

    func testProfileCalendarBuildsFullServerWindowWithNonInteractiveCells() {
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
        XCTAssertFalse(presentation.cellsAreInteractive)
    }

    func testProfileSourceKeepsTripsBehindCalendarAndRoutesLogoutToRoutesTab() throws {
        let source = try productionSource(at: "Features/Profile/ProfileView.swift")
        let rootSource = try productionSource(at: "App/RootView.swift")
        let calendarStart = try XCTUnwrap(source.range(of: "private var tripCalendarSection"))
        let equipmentStart = try XCTUnwrap(source.range(of: "private var equipmentSection"))
        let calendarSource = String(source[calendarStart.lowerBound..<equipmentStart.lowerBound])

        XCTAssertTrue(calendarSource.contains("onNavigate(.tripList)"))
        XCTAssertFalse(source.contains("我的全部行程"))
        XCTAssertTrue(source.contains("onNavigate(.accountSecurity)"))
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
            .appendingPathComponent("Features/Profile/UserService.swift")
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
