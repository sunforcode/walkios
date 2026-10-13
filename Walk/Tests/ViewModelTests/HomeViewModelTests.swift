import XCTest
import WalkData
import WalkDesignSystem
@testable import Walk

@MainActor
final class HomeViewModelTests: XCTestCase {
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

    func testHomeLayoutUsesApprovedSpacingTokens() {
    XCTAssertEqual(Spacing.pageHorizontal, 16)
    XCTAssertEqual(Spacing.navBarHeight, 44)
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

    func testHomeIgnoresOlderFocusResponse() async {
        let started = expectation(description: "older focus started")
        let gate = HomeAsyncGate()
        var calls = 0
        let sut = HomeViewModel(loadFocus: {
            calls += 1
            if calls == 1 {
                started.fulfill()
                await gate.wait()
                return PersonalTripFocus(trip: PersonalTripTestFixtures.summary(id: "old", status: .planned))
            }
            return PersonalTripFocus(trip: PersonalTripTestFixtures.summary(id: "new", status: .planned))
        })
        let first = Task { await sut.load() }
        await fulfillment(of: [started], timeout: 1)
        await sut.load()
        await gate.open()
        await first.value
        XCTAssertEqual(sut.focusedTrip?.tripID, "new")
    }

    func testHomeDoesNotRestoreFocusAfterIdentityChanges() async {
        let started = expectation(description: "focus started")
        let gate = HomeAsyncGate()
        var identity = "first"
        let sut = HomeViewModel(
            currentIdentity: { identity },
            loadFocus: {
                started.fulfill()
                await gate.wait()
                return PersonalTripFocus(trip: PersonalTripTestFixtures.summary(id: "old", status: .planned))
            }
        )
        let task = Task { await sut.load() }
        await fulfillment(of: [started], timeout: 1)
        identity = "second"
        await gate.open()
        await task.value
        XCTAssertNil(sut.focusedTrip)
        XCTAssertNil(sut.refreshError)
    }

    func testHomeCancelledRefreshKeepsFocusWithoutError() async {
        var cancelled = false
        let sut = HomeViewModel(loadFocus: {
            if cancelled { throw APIClientError.transport(.cancelled) }
            return PersonalTripFocus(trip: PersonalTripTestFixtures.summary(id: "focus", status: .planned))
        })
        await sut.load()
        cancelled = true
        await sut.load()
        XCTAssertEqual(sut.focusedTrip?.tripID, "focus")
        XCTAssertEqual(sut.state, .ready)
        XCTAssertNil(sut.refreshError)
    }

    func testHomeFirstCancellationRemainsUnresolvedAndCanImmediatelyReload() async {
        let errors: [Error] = [CancellationError(), APIClientError.transport(.cancelled)]
        for error in errors {
            var attempts = 0
            let sut = HomeViewModel(loadFocus: {
                attempts += 1
                if attempts == 1 { throw error }
                return PersonalTripFocus(trip: nil)
            })

            await sut.load()
            XCTAssertEqual(sut.state, .loading, "未取得结果只能保留占位，不能发布 noFocus")
            XCTAssertFalse(sut.isLoading, "占位不代表仍有有效请求")
            XCTAssertNil(sut.focusedTrip)
            XCTAssertNil(sut.refreshError)

            await sut.load()
            XCTAssertEqual(attempts, 2)
            XCTAssertEqual(sut.state, .ready, "仅真实成功返回 nil 才能发布 noFocus")
            XCTAssertFalse(sut.isLoading)
        }
    }

    func testHomeReentrantCancellationRestoresLastSettledStateInsteadOfInFlightLoading() async {
        let settledStates: [HomeState] = [.ready, .error("当前行程加载失败")]
        for settledState in settledStates {
            let started = expectation(description: "older refresh started")
            let gate = HomeAsyncGate()
            var attempts = 0
            let sut = HomeViewModel(loadFocus: {
                attempts += 1
                switch attempts {
                case 1:
                    if settledState != .ready { throw APIClientError.invalidResponse }
                    return PersonalTripFocus(trip: nil)
                case 2:
                    started.fulfill()
                    await gate.wait()
                    return PersonalTripFocus(trip: PersonalTripTestFixtures.summary(id: "stale", status: .planned))
                case 3:
                    throw APIClientError.transport(.cancelled)
                default:
                    return PersonalTripFocus(trip: nil)
                }
            })
            await sut.load()
            XCTAssertEqual(sut.state, settledState)
            let older = Task { await sut.load() }
            await fulfillment(of: [started], timeout: 1)
            XCTAssertEqual(sut.state, .loading)
            XCTAssertTrue(sut.isLoading)

            await sut.load()
            XCTAssertEqual(sut.state, settledState, "重入取消必须恢复最后稳定态，而非旧请求的 loading")
            XCTAssertFalse(sut.isLoading)
            XCTAssertNil(sut.refreshError)
            await gate.open()
            await older.value
            XCTAssertEqual(sut.state, settledState)
            XCTAssertNil(sut.focusedTrip, "已失效的旧响应不得发布焦点")

            await sut.load()
            XCTAssertEqual(attempts, 4)
            XCTAssertEqual(sut.state, .ready)
            XCTAssertFalse(sut.isLoading)
        }
    }

    func testHomeFirstTaskCancellationRejectsLateSuccessAndAllowsReload() async {
        let started = expectation(description: "initial focus started")
        let gate = HomeAsyncGate()
        var attempts = 0
        let sut = HomeViewModel(loadFocus: {
            attempts += 1
            if attempts == 1 {
                started.fulfill()
                await gate.wait()
            }
            return PersonalTripFocus(trip: nil)
        })
        let first = Task { await sut.load() }
        await fulfillment(of: [started], timeout: 1)
        XCTAssertTrue(sut.isLoading)
        first.cancel()
        await gate.open()
        await first.value
        XCTAssertEqual(sut.state, .loading)
        XCTAssertFalse(sut.isLoading)
        XCTAssertNil(sut.refreshError)
        await sut.load()
        XCTAssertEqual(attempts, 2)
        XCTAssertEqual(sut.state, .ready)
    }

    func testGuestHomeIsGuestBeforeFirstLifecycleTask() {
        let sut = HomeViewModel(isLoggedIn: { false }, loadFocus: {
            XCTFail("guest must not request focus")
            return PersonalTripFocus(trip: nil)
        })
        XCTAssertEqual(sut.state, .guest)
    }

    func testLeavingHomeInvalidatesNonCooperativeRetryResponse() async {
        let started = expectation(description: "focus started")
        let gate = HomeAsyncGate()
        let sut = HomeViewModel(loadFocus: {
            started.fulfill()
            await gate.wait()
            return PersonalTripFocus(trip: PersonalTripTestFixtures.summary(id: "late", status: .planned))
        })
        let task = Task { await sut.load() }
        await fulfillment(of: [started], timeout: 1)
        sut.cancelPendingOperations()
        XCTAssertFalse(sut.isLoading)
        await gate.open()
        await task.value
        XCTAssertNil(sut.focusedTrip)
        XCTAssertNil(sut.refreshError)
        XCTAssertEqual(sut.state, .loading)
    }

    func testHomeLogoutClearsFocusAndRejectsPendingResponse() async {
        let started = expectation(description: "refresh started")
        let gate = HomeAsyncGate()
        var loggedIn = true
        var calls = 0
        let sut = HomeViewModel(isLoggedIn: { loggedIn }, loadFocus: {
            calls += 1
            if calls == 2 { started.fulfill(); await gate.wait() }
            return PersonalTripFocus(trip: PersonalTripTestFixtures.summary(id: "account-a", status: .planned))
        })
        await sut.load()
        let refresh = Task { await sut.load() }
        await fulfillment(of: [started], timeout: 1)
        loggedIn = false
        await sut.load()
        XCTAssertEqual(sut.state, .guest)
        XCTAssertNil(sut.focusedTrip)
        await gate.open()
        await refresh.value
        XCTAssertEqual(sut.state, .guest)
        XCTAssertNil(sut.focusedTrip)
        XCTAssertEqual(calls, 2)
    }

    private func productionSource(at relativePath: String) throws -> String {
        let walkRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        return try String(contentsOf: walkRoot.appendingPathComponent(relativePath), encoding: .utf8)
    }
}

private actor HomeAsyncGate {
    private var isOpen = false
    private var continuation: CheckedContinuation<Void, Never>?
    func wait() async {
        guard !isOpen else { return }
        await withCheckedContinuation { continuation = $0 }
    }
    func open() {
        isOpen = true
        continuation?.resume()
        continuation = nil
    }
}
