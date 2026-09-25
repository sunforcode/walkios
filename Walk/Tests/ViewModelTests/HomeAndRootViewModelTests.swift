import XCTest
import WalkData
import WalkDesignSystem
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

    func testHomeOmitsWeatherUntilIndependentTripWeatherAssociationExists() async {
        let focusedTrip = PersonalTripTestFixtures.summary(id: "focus", status: .inProgress)
        let sut = HomeViewModel(
            loadFocus: { PersonalTripFocus(trip: focusedTrip) }
        )

        await sut.load()

        XCTAssertNil(sut.weatherSummary)
        XCTAssertEqual(sut.state, .ready)
    }

    func testHomeShowsNoFocusEmptyStateWhenServerReturnsNilFocus() async {
        let sut = HomeViewModel(
            loadFocus: { PersonalTripFocus(trip: nil) }
        )

        await sut.load()

        XCTAssertNil(sut.focusedTrip)
        XCTAssertEqual(sut.state, .ready, "无焦点行程停留在首页空态，不自动进入全部路线")
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
        XCTAssertNil(sut.weatherSummary)
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

    func testStaticHomeViewModelKeepsPreviewStateWhenTaskLoads() async {
        let trip = PersonalTripTestFixtures.summary(id: "preview-focus", status: .inProgress)
        let weather = HomeWeatherSummary(conclusion: "16°·多云", impact: "山脊4级风")
        let sut = HomeViewModel(
            staticState: .ready,
            focusedTrip: trip,
            weatherSummary: weather
        )

        await sut.load()

        XCTAssertEqual(sut.state, .ready)
        XCTAssertEqual(sut.focusedTrip, trip)
        XCTAssertEqual(sut.weatherSummary, weather)
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

    // account-api：phone SHALL 是 ^\+[1-9][0-9]{1,14}$ 国际格式；PAGE-LOGIN 校准状态：页面不自动补 +86。
    // 因此 normalizedPhone 只接受已是国际格式的输入，不为国内裸号补 +86。
    func testLoginAcceptsInternationalE164PhoneOnly() {
        XCTAssertEqual(LoginViewModel.normalizedPhone("+8613800138000"), "+8613800138000")
        XCTAssertEqual(LoginViewModel.normalizedPhone("+14155550123"), "+14155550123")
        XCTAssertNil(LoginViewModel.normalizedPhone("13800138000"), "不自动补 +86")
        XCTAssertNil(LoginViewModel.normalizedPhone(" 13800138000 "), "不自动补 +86")
        XCTAssertNil(LoginViewModel.normalizedPhone("23800138000"))
        XCTAssertNil(LoginViewModel.normalizedPhone("12345"))
        XCTAssertNil(LoginViewModel.normalizedPhone(""))
    }

    // PAGE-LOGIN：不自动补 +86；客户端按用户输入的国际格式手机号原样发送。
    func testLoginSendCodeSendsInternationalE164PhoneAsEntered() async {
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
        sut.phone = "+8613800138000"
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

    func testLoginSendThrottlePreservesRetryTimeAndBlocksPrematureResend() async {
        let retryAt = Date(timeIntervalSinceNow: 300)
        var sendCount = 0
        let sut = LoginViewModel(
            sendCode: { _ in
                sendCount += 1
                throw APIClientError.api(
                    code: "verification_send_throttled",
                    message: "发送受限",
                    retryable: true,
                    details: APIErrorDetails(retryAvailableAt: retryAt)
                )
            },
            createSession: { _, _ in },
            loadAccount: { throw APIClientError.invalidResponse }
        )
        sut.phone = "+8613800138000"

        await sut.sendVerificationCode()
        await sut.sendVerificationCode()

        XCTAssertEqual(sendCount, 1)
        XCTAssertEqual(sut.retryAvailableAt, retryAt)
        XCTAssertNil(sut.errorMessage, "限流应由 AuthPanel.throttled 投影呈现，不与发送失败态叠加")
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

    // account-api：code 是 NonEmptyText，保留前导零按文本校验；PAGE-LOGIN：不固定验证码长度。
    // canLogin 只要求已取得 verificationID 且验证码非空，不固定位数。
    func testLoginRequiresVerificationIDAndNonEmptyCode() {
        let sut = LoginViewModel(
            sendCode: { _ in throw APIClientError.invalidResponse },
            createSession: { _, _ in },
            loadAccount: { throw APIClientError.invalidResponse }
        )
        sut.code = "012345"
        XCTAssertFalse(sut.canLogin, "无 verificationID 不可登录")

        sut.verificationID = "verification-1"
        sut.code = ""
        XCTAssertFalse(sut.canLogin, "空验证码不可登录")

        // 不固定验证码长度：任意非空数字验证码均可提交。
        for validCode in ["1", "12345", "1234567", "012345"] {
            sut.code = validCode
            XCTAssertTrue(sut.canLogin, "\(validCode) 应允许登录")
        }
    }

    func testSessionSuccessAuthenticatesEvenWhenAccountProjectionFails() async {
        var calls: [String] = []
        let sut = LoginViewModel(
            sendCode: { _ in throw APIClientError.invalidResponse },
            createSession: { _, _ in calls.append("session") },
            loadAccount: {
                calls.append("account")
                throw APIClientError.api(
                    code: "account_temporarily_unavailable",
                    message: "账号资料暂不可用",
                    retryable: true
                )
            }
        )
        sut.verificationID = "verification-1"
        sut.phase = .verificationCode
        sut.code = "012345"

        await sut.login()

        XCTAssertEqual(calls, ["session", "account"])
        XCTAssertTrue(sut.didAuthenticate)
        XCTAssertNil(sut.account)
        XCTAssertNil(sut.errorMessage)
    }

    func testSessionSuccessPublishesAuthenticationBeforeAccountProjectionCompletes() async {
        let accountReadStarted = expectation(description: "account read started")
        let gate = AsyncGate()
        let sut = LoginViewModel(
            sendCode: { _ in throw APIClientError.invalidResponse },
            createSession: { _, _ in },
            loadAccount: {
                accountReadStarted.fulfill()
                await gate.wait()
                throw APIClientError.invalidResponse
            }
        )
        sut.verificationID = "verification-1"
        sut.phase = .verificationCode
        sut.code = "012345"

        let loginTask = Task { await sut.login() }
        await fulfillment(of: [accountReadStarted], timeout: 1)

        XCTAssertTrue(sut.didAuthenticate)
        await gate.open()
        await loginTask.value
    }

    func testLoginReceivesPendingRootIntentForSourceContext() throws {
        let rootSource = try productionSource(at: "App/RootView.swift")
        let loginSource = try productionSource(at: "Features/Profile/LoginView.swift")

        XCTAssertTrue(rootSource.contains("intent: authFlow.pending?.intent"))
        XCTAssertTrue(loginSource.contains("let intent: PendingAuthIntent?"))
        XCTAssertTrue(loginSource.contains("case .homeStart"))
        XCTAssertTrue(loginSource.contains("case .createTrip"))
        XCTAssertTrue(loginSource.contains("case .profile"))
    }

    // account-access「认证成功承接原任务」：homeStart 登录后先确认焦点行程，
    // 确认成功才发布 didAuthenticate；失败进入 focusError 且不发布认证完成。
    func testLoginConfirmsFocusTripAfterSessionBeforeAuthenticating() async {
        var order: [String] = []
        let sut = LoginViewModel(
            sendCode: { _ in throw APIClientError.invalidResponse },
            createSession: { _, _ in order.append("session") },
            loadAccount: {
                order.append("account")
                throw APIClientError.invalidResponse
            },
            confirmFocusTrip: {
                order.append("focus")
                return true
            }
        )
        sut.verificationID = "verification-1"
        sut.phase = .verificationCode
        sut.code = "123456"

        await sut.login()

        XCTAssertEqual(order, ["session", "focus", "account"])
        XCTAssertTrue(sut.didAuthenticate)
        XCTAssertEqual(sut.phase, .confirmingFocus, "确认成功后阶段停留 confirmingFocus，面板随认证完成关闭")
    }

    func testLoginFocusTripConfirmationFailureEntersFocusErrorWithoutAuthenticating() async {
        let sut = LoginViewModel(
            sendCode: { _ in throw APIClientError.invalidResponse },
            createSession: { _, _ in },
            loadAccount: { throw APIClientError.invalidResponse },
            confirmFocusTrip: { throw APIClientError.api(code: "focus_unavailable", message: "无法确认", retryable: true) }
        )
        sut.verificationID = "verification-1"
        sut.phase = .verificationCode
        sut.code = "123456"

        await sut.login()

        XCTAssertFalse(sut.didAuthenticate, "无法确认焦点行程时不得发布认证完成")
        XCTAssertEqual(sut.phase, .focusError)
        XCTAssertNotNil(sut.focusErrorMessage)
    }

    func testLoginFocusTripConfirmationRetrySucceedsAndAuthenticates() async {
        var attempts = 0
        let sut = LoginViewModel(
            sendCode: { _ in throw APIClientError.invalidResponse },
            createSession: { _, _ in },
            loadAccount: { throw APIClientError.invalidResponse },
            confirmFocusTrip: {
                attempts += 1
                if attempts == 1 { throw APIClientError.invalidResponse }
                return false
            }
        )
        sut.verificationID = "verification-1"
        sut.phase = .verificationCode
        sut.code = "123456"

        await sut.login()
        XCTAssertEqual(sut.phase, .focusError)
        XCTAssertFalse(sut.didAuthenticate)

        await sut.retryFocusTripConfirmation()
        XCTAssertTrue(sut.didAuthenticate, "重试确认成功后发布认证完成")
        XCTAssertNil(sut.focusErrorMessage)
    }

    func testLoginFocusTripConfirmationRejectsConcurrentRetries() async {
        let retryStarted = expectation(description: "first retry started")
        let gate = AsyncGate()
        var attempts = 0
        let sut = LoginViewModel(
            sendCode: { _ in throw APIClientError.invalidResponse },
            createSession: { _, _ in },
            loadAccount: { throw APIClientError.invalidResponse },
            confirmFocusTrip: {
                attempts += 1
                if attempts == 1 { throw APIClientError.invalidResponse }
                if attempts == 2 {
                    retryStarted.fulfill()
                    await gate.wait()
                }
                return true
            }
        )
        sut.verificationID = "verification-1"
        sut.phase = .verificationCode
        sut.code = "123456"
        await sut.login()

        let firstRetry = Task { await sut.retryFocusTripConfirmation() }
        await fulfillment(of: [retryStarted], timeout: 1)
        let duplicateRetry = Task { await sut.retryFocusTripConfirmation() }
        await duplicateRetry.value

        XCTAssertEqual(attempts, 2, "确认请求进行中时不得启动第二个重试")
        await gate.open()
        await firstRetry.value
    }

    func testCancelledFocusTripConfirmationDoesNotAuthenticate() async {
        let retryStarted = expectation(description: "retry started")
        let gate = AsyncGate()
        var attempts = 0
        let sut = LoginViewModel(
            sendCode: { _ in throw APIClientError.invalidResponse },
            createSession: { _, _ in },
            loadAccount: { throw APIClientError.invalidResponse },
            confirmFocusTrip: {
                attempts += 1
                if attempts == 1 { throw APIClientError.invalidResponse }
                retryStarted.fulfill()
                await gate.wait()
                return true
            }
        )
        sut.verificationID = "verification-1"
        sut.phase = .verificationCode
        sut.code = "123456"
        await sut.login()

        let retry = Task { await sut.retryFocusTripConfirmation() }
        await fulfillment(of: [retryStarted], timeout: 1)
        sut.cancelPendingOperations()
        await gate.open()
        await retry.value

        XCTAssertFalse(sut.didAuthenticate, "页面退出后迟到的焦点确认不得发布认证完成")
    }

    func testDefaultMockFixturesSupportTypedLoginAndLogout() async throws {
        let client = MockAPIClient(fixtures: DefaultMockFixtures.accountFixtures())

        let verification = try await client.execute(AccountAPI.SendVerificationCode(phone: "+8613800138000"))
        let session = try await client.execute(AccountAPI.CreateSession(
            verificationID: verification.verificationId,
            code: "123456"
        ))
        let logout = try await client.execute(AccountAPI.Logout())

        XCTAssertFalse(verification.verificationId.isEmpty)
        XCTAssertEqual(session.tokenType, "Bearer")
        XCTAssertFalse(session.accessToken.isEmpty)
        XCTAssertTrue(logout.loggedOut)
    }

func testHomeLayoutUsesApprovedSpacingTokens() {
    XCTAssertEqual(Spacing.pageHorizontal, 16)
    XCTAssertEqual(Spacing.navBarHeight, 44)
}

    func testSystemTabBarVisibilityTracksTheSelectedNavigationPath() {
        var sut = AppShellState()
        XCTAssertTrue(sut.showsGlobalNavigation)

        sut.setPath([.tripDetail("trip-1")], for: .home)
        XCTAssertFalse(sut.showsGlobalNavigation)

        sut.selectTab(.routes)
        XCTAssertTrue(sut.showsGlobalNavigation)

        sut.setPath([.routeList], for: .routes)
        XCTAssertFalse(sut.showsGlobalNavigation)
    }

    func testRootUsesSystemTabBarOnlyOnRootPages() throws {
        let navigationSource = try productionSource(at: "App/RootNavigation.swift")
        let rootSource = try productionSource(at: "App/RootView.swift")

        XCTAssertFalse(navigationSource.contains("UITabBar.appearance().isHidden = true"))
        XCTAssertFalse(rootSource.contains("PrimaryTabBar("))
        XCTAssertTrue(rootSource.contains(".toolbar(.hidden, for: .tabBar)"))
    }

    func testGuestHomeExposesOnlyApprovedStartAction() throws {
        let source = try productionSource(at: "Features/Home/HomeView.swift")
        let guestStart = try XCTUnwrap(source.range(of: "private struct GuestHomeContent"))
        let loadingStart = try XCTUnwrap(source.range(of: "private struct HomeLoadingContent"))
        let guestSource = String(source[guestStart.lowerBound..<loadingStart.lowerBound])

        XCTAssertTrue(guestSource.contains("开启一次新的徒步行程"))
        XCTAssertFalse(guestSource.contains("登录并开始"))
        XCTAssertFalse(guestSource.contains("探索路线"))
    }

    func testHomeFailureOnlyOffersRetry() throws {
        let source = try productionSource(at: "Features/Home/HomeView.swift")
        let errorStart = try XCTUnwrap(source.range(of: "case .error(let message):"))
        let readyStart = try XCTUnwrap(source.range(
            of: "case .ready:",
            range: errorStart.upperBound..<source.endIndex
        ))
        let errorSource = String(source[errorStart.lowerBound..<readyStart.lowerBound])

        XCTAssertTrue(errorSource.contains("ErrorView"))
        XCTAssertTrue(errorSource.contains("viewModel.retry()"))
        XCTAssertFalse(errorSource.contains("onNavigate"))
    }

    func testHomeProductionSourceDoesNotAttachWeatherBeforeAssociationIsDefined() throws {
        let viewSource = try productionSource(at: "Features/Home/HomeView.swift")
        let viewModelSource = try productionSource(at: "Features/Home/HomeViewModel.swift")

        XCTAssertFalse(viewSource.contains("refreshError"))
        XCTAssertFalse(viewModelSource.contains("loadWeather"))
        XCTAssertFalse(viewModelSource.contains("weatherImpact"))
        XCTAssertFalse(viewModelSource.contains("TEMP(FIELD-HOME-001)"))
        XCTAssertFalse(viewModelSource.contains("16° · 多云"))
        XCTAssertFalse(viewModelSource.contains("山脊 4 级风"))
    }

    /// 6.2 修订（H1）：weather 整体省略时 FocusTripSummary 仍渲染 WeatherSummary
    /// 两个中性槽位（「本次未提供天气摘要」/「行程其他内容仍可查看」），
    /// 不得把字段省略解释为 unavailable。
    func testFocusTripSummaryRendersNeutralWeatherSlotsWhenModelHasNoWeather() throws {
        let source = try productionSource(at: "Features/Home/Components/FocusTripSummary.swift")

        XCTAssertFalse(source.contains("if let weather = model.weather"), "省略不再整体跳过 WeatherSummary")
        XCTAssertTrue(source.contains("WeatherSummary(model: resolvedWeather)"))
        XCTAssertTrue(source.contains("本次未提供天气摘要"))
        XCTAssertTrue(source.contains("行程其他内容仍可查看"))
        XCTAssertTrue(source.contains("state: .omitted"), "省略是独立中性态，不是 unavailable")
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

private actor AsyncGate {
    private var isOpen = false
    private var continuation: CheckedContinuation<Void, Never>?

    func wait() async {
        guard !isOpen else { return }
        await withCheckedContinuation { continuation in
            self.continuation = continuation
        }
    }

    func open() {
        isOpen = true
        continuation?.resume()
        continuation = nil
    }
}
