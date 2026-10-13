import XCTest
@testable import Walk

/// W4-4：认证编排。
///
/// 从 RootView 提取的状态机，只负责「需要认证的意图何时登录、登录后回到哪里、如何继续」。
/// 依据 openspec/specs/account-access 与 app-flow：
/// - 已登录时直接执行意图；未登录时呈现登录，不丢弃当前任务栈；
/// - 登录完成后在发起时的 tab 继续执行原意图；取消登录丢弃意图；
/// - 被动重新认证（会话失效）总是呈现登录；
/// - 普通认证完成直接回到发起的 Tab，不依赖焦点行程。
final class AuthenticationFlowTests: XCTestCase {
    func testLoggedInIntentExecutesImmediatelyWithoutLogin() {
        var flow = AuthenticationFlow()

        let effect = flow.request(.createTrip(routeID: "r1"), from: .routes, isLoggedIn: true)

        XCTAssertEqual(effect, .execute(.createTrip(routeID: "r1"), in: .routes))
        XCTAssertNil(flow.pending)
    }

    func testLoggedOutIntentPresentsLoginAndRemembersSource() {
        var flow = AuthenticationFlow()

        let effect = flow.request(.createTrip(routeID: "r1"), from: .routes, isLoggedIn: false)

        XCTAssertEqual(effect, .presentLogin)
        XCTAssertEqual(flow.pending, .init(intent: .createTrip(routeID: "r1"), tab: .routes))
    }

    func testCompletionContinuesInOriginatingTabEvenIfSelectionChanged() {
        var flow = AuthenticationFlow()
        _ = flow.request(.createTrip(routeID: "r1"), from: .routes, isLoggedIn: false)

        let effect = flow.complete(currentTab: .trips)

        XCTAssertEqual(effect, .execute(.createTrip(routeID: "r1"), in: .routes))
        XCTAssertNil(flow.pending)
    }

    func testCancellationDropsPendingIntent() {
        var flow = AuthenticationFlow()
        _ = flow.request(.equipment, from: .equipment, isLoggedIn: false)

        flow.cancel()

        XCTAssertNil(flow.pending)
        XCTAssertEqual(flow.complete(currentTab: .equipment), .none, "取消后再完成不得执行旧意图")
    }

    /// 会话失效时即使本地仍显示已登录，也必须重新登录。
    func testReauthenticationAlwaysPresentsLogin() {
        var flow = AuthenticationFlow()

        let effect = flow.request(.reauthenticate, from: .equipment, isLoggedIn: true, force: true)

        XCTAssertEqual(effect, .presentLogin)
        XCTAssertEqual(flow.complete(currentTab: .equipment), .execute(.reauthenticate, in: .equipment))
    }

    func testPersonalRootsContinueDirectlyAfterAuthentication() {
        for (intent, tab): (PendingAuthIntent, AppTab) in [
            (.trips, .trips), (.equipment, .equipment), (.profile, .profile)
        ] {
            var flow = AuthenticationFlow()
            XCTAssertEqual(flow.request(intent, from: tab, isLoggedIn: false), .presentLogin)
            XCTAssertEqual(flow.complete(currentTab: .routes), .execute(intent, in: tab))
            XCTAssertNil(flow.pending)
            XCTAssertEqual(flow.complete(currentTab: .routes), .none)
        }
    }
}
