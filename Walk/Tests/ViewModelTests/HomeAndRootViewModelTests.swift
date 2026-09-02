import XCTest
@testable import Walk

@MainActor
final class HomeAndRootViewModelTests: XCTestCase {
    func testHomeStartsLoadingAndUsesServerFocusWithoutListOrRouteResolution() async {
        var focusCallCount = 0
        let focusedTrip = PersonalTripTestFixtures.summary(id: "focus", status: .inProgress)
        let sut = HomeViewModel(loadFocus: {
            focusCallCount += 1
            return PersonalTripFocus(trip: focusedTrip)
        })

        XCTAssertEqual(sut.state, .loading)

        await sut.load()

        XCTAssertEqual(focusCallCount, 1)
        XCTAssertEqual(sut.focusedTrip?.tripID, "focus")
        XCTAssertEqual(sut.state, .ready)
    }

    func testHomeLoadsWeatherForFocusedTripAndPublishesMatchingRevision() async {
        var weatherTripIDs: [String] = []
        let focusedTrip = PersonalTripTestFixtures.summary(id: "focus", status: .inProgress)
        let weather = PersonalTripWeather(
            tripID: "focus",
            revision: focusedTrip.revision,
            routeName: focusedTrip.routeName,
            startDate: focusedTrip.startDate,
            endDate: focusedTrip.endDate,
            days: [],
            weatherOverview: QualifiedString(value: "多云，午后有雨", confidence: nil)
        )
        let sut = HomeViewModel(
            loadFocus: { PersonalTripFocus(trip: focusedTrip) },
            loadWeather: { tripID in
                weatherTripIDs.append(tripID)
                return weather
            }
        )

        await sut.load()

        XCTAssertEqual(weatherTripIDs, ["focus"])
        XCTAssertEqual(sut.weatherSummary?.text, "多云，午后有雨")
        XCTAssertEqual(sut.state, .ready)
    }

    func testHomeDoesNotMixWeatherFromAnotherRevision() async {
        let focusedTrip = PersonalTripTestFixtures.summary(id: "focus", status: .planned)
        let staleWeather = PersonalTripWeather(
            tripID: "focus",
            revision: "stale-revision",
            routeName: focusedTrip.routeName,
            startDate: focusedTrip.startDate,
            endDate: focusedTrip.endDate,
            days: [],
            weatherOverview: QualifiedString(value: "晴", confidence: nil)
        )
        let sut = HomeViewModel(
            loadFocus: { PersonalTripFocus(trip: focusedTrip) },
            loadWeather: { _ in staleWeather }
        )

        await sut.load()

        XCTAssertNil(sut.weatherSummary)
        XCTAssertEqual(sut.state, .ready)
    }

    func testHomeUsesServerNilFocusAsEmptyAndRequestsRouteDiscovery() async {
        var routeDiscoveryCount = 0
        let sut = HomeViewModel(
            loadFocus: { PersonalTripFocus(trip: nil) },
            onNoFocus: { routeDiscoveryCount += 1 }
        )

        await sut.load()

        XCTAssertNil(sut.focusedTrip)
        XCTAssertEqual(sut.state, .empty)
        XCTAssertEqual(routeDiscoveryCount, 1)
    }

    func testRefreshFailureKeepsExistingFocusVisible() async {
        let focusedTrip = PersonalTripTestFixtures.summary(id: "focus", status: .planned)
        var shouldFail = false
        let sut = HomeViewModel(loadFocus: {
            if shouldFail { throw APIClientError.invalidResponse }
            return PersonalTripFocus(trip: focusedTrip)
        })
        await sut.load()
        shouldFail = true

        await sut.load()

        XCTAssertEqual(sut.focusedTrip?.tripID, "focus")
        XCTAssertEqual(sut.state, .ready)
        XCTAssertEqual(sut.refreshError, "当前行程刷新失败")
    }

    func testGuestHomeDoesNotRequestPersonalFocus() async {
        var focusCallCount = 0
        let sut = HomeViewModel(
            isLoggedIn: { false },
            loadFocus: {
                focusCallCount += 1
                return PersonalTripFocus(trip: nil)
            }
        )

        await sut.load()

        XCTAssertEqual(sut.state, .guest)
        XCTAssertEqual(focusCallCount, 0)
    }

    func testLoginSendCodeStoresVerificationIdentity() async {
        let expires = Date(timeIntervalSince1970: 1_800_000_000)
        let sut = LoginViewModel(
            sendCode: { phone in
                XCTAssertEqual(phone, "+8613800138000")
                return VerificationCodeResponse(
                    verificationId: "verification-1",
                    expiresAt: expires,
                    resendAvailableAt: expires
                )
            },
            createSession: { _, _ in XCTFail("session must not be created yet") },
            loadAccount: { throw APIClientError.invalidResponse }
        )
        sut.phone = "+8613800138000"

        await sut.sendVerificationCode()

        XCTAssertEqual(sut.verificationID, "verification-1")
        XCTAssertEqual(sut.phase, .verificationCode)
    }

    func testLoginNormalizesDomesticMainlandPhoneToE164() {
        XCTAssertEqual(LoginViewModel.normalizedPhone("13800138000"), "+8613800138000")
        XCTAssertEqual(LoginViewModel.normalizedPhone(" 13800138000 "), "+8613800138000")
        XCTAssertEqual(LoginViewModel.normalizedPhone("+8613800138000"), "+8613800138000")
        XCTAssertEqual(LoginViewModel.normalizedPhone("+14155550123"), "+14155550123")
        XCTAssertNil(LoginViewModel.normalizedPhone("12345"))
        XCTAssertNil(LoginViewModel.normalizedPhone("23800138000"))
        XCTAssertNil(LoginViewModel.normalizedPhone(""))
    }

    func testLoginSendCodeAcceptsDomesticFormatAndSendsNormalizedPhone() async {
        var sentPhones: [String] = []
        let expires = Date(timeIntervalSince1970: 1_800_000_000)
        let sut = LoginViewModel(
            sendCode: { phone in
                sentPhones.append(phone)
                return VerificationCodeResponse(
                    verificationId: "verification-2",
                    expiresAt: expires,
                    resendAvailableAt: expires
                )
            },
            createSession: { _, _ in },
            loadAccount: { throw APIClientError.invalidResponse }
        )
        sut.phone = "13800138000"
        XCTAssertTrue(sut.canSendCode)

        await sut.sendVerificationCode()

        XCTAssertEqual(sentPhones, ["+8613800138000"])
        XCTAssertEqual(sut.phase, .verificationCode)
        XCTAssertNil(sut.errorMessage)
    }

    func testLoginSendCodeShowsGuidanceForInvalidPhone() async {
        let sut = LoginViewModel(
            sendCode: { _ in
                XCTFail("must not send for invalid phone")
                struct UnexpectedSend: Error {}
                throw UnexpectedSend()
            },
            createSession: { _, _ in },
            loadAccount: { throw APIClientError.invalidResponse }
        )
        sut.phone = "12345"

        await sut.sendVerificationCode()

        XCTAssertNotNil(sut.errorMessage)
        XCTAssertNil(sut.verificationID)
        XCTAssertEqual(sut.phase, LoginViewModel.Phase.phone)
    }

    func testLoginCreatesSessionThenLoadsAccount() async {
        var calls: [String] = []
        let account = AccountResponse(
            account: AccountProjection(identity: "account-1"),
            profile: ProfileProjection(identity: "profile-1", maskedPhone: "+86 138****8000", nickname: nil, avatar: nil)
        )
        let sut = LoginViewModel(
            sendCode: { _ in throw APIClientError.invalidResponse },
            createSession: { verificationID, code in
                calls.append("session:\(verificationID):\(code)")
            },
            loadAccount: {
                calls.append("account")
                return account
            }
        )
        sut.verificationID = "verification-1"
        sut.phase = .verificationCode
        sut.code = "012345"

        await sut.login()

        XCTAssertEqual(calls, ["session:verification-1:012345", "account"])
        XCTAssertEqual(sut.account, account)
        XCTAssertTrue(sut.didAuthenticate)
    }

    func testHomeLayoutKeepsContentInLowerSafeArea() {
        XCTAssertEqual(HomeLayout.heroHorizontalPadding, Spacing.pageHorizontal)
        XCTAssertEqual(HomeLayout.emptyHorizontalPadding, 28)
        XCTAssertEqual(HomeLayout.contentBottomPadding, 24)
    }

    func testGuestHomeExposesOnlyApprovedStartAction() throws {
        let source = try productionSource(at: "Features/Home/HomeView.swift")
        let guestStart = try XCTUnwrap(source.range(of: "private struct GuestHomeView"))
        let focusStart = try XCTUnwrap(source.range(of: "private struct TripHomeView"))
        let guestSource = String(source[guestStart.lowerBound..<focusStart.lowerBound])

        XCTAssertTrue(guestSource.contains("开启一次新的徒步行程"))
        XCTAssertFalse(guestSource.contains("登录并开始"))
        XCTAssertFalse(guestSource.contains("探索路线"))
    }

    func testHomeFailureOnlyOffersRetry() throws {
        let source = try productionSource(at: "Features/Home/HomeView.swift")
        let errorStart = try XCTUnwrap(source.range(of: "private struct ErrorHomeView"))
        let buttonStart = try XCTUnwrap(source.range(of: "private struct HomeGlassButton"))
        let errorSource = String(source[errorStart.lowerBound..<buttonStart.lowerBound])

        XCTAssertTrue(errorSource.contains("重试"))
        XCTAssertFalse(errorSource.contains("探索路线"))
    }

    private func productionSource(at relativePath: String) throws -> String {
        let testFileURL = URL(fileURLWithPath: #filePath)
        let walkRoot = testFileURL
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        return try String(contentsOf: walkRoot.appendingPathComponent(relativePath), encoding: .utf8)
    }
}
