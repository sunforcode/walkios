import Foundation

/// 认证编排状态机。
///
/// 从 RootView 提取，只负责「需要认证的意图何时登录、登录后回到哪里继续」，不做呈现与导航。
/// RootView 把返回的 `Effect` 翻译成呈现登录或执行意图。
/// 依据 openspec/specs/account-access 与 app-flow：登录作为 Modal 任务，不丢弃当前任务栈；
/// 普通认证成功后直接承接原任务。
struct AuthenticationFlow: Equatable {
    struct Pending: Equatable {
        let intent: PendingAuthIntent
        let tab: AppTab
    }

    enum Effect: Equatable {
        case none
        case presentLogin
        case execute(PendingAuthIntent, in: AppTab)
    }

    private(set) var pending: Pending?

    /// 请求执行需要认证的意图。`force` 用于会话失效后的被动重新认证。
    mutating func request(
        _ intent: PendingAuthIntent,
        from tab: AppTab,
        isLoggedIn: Bool,
        force: Bool = false
    ) -> Effect {
        if isLoggedIn && !force {
            return .execute(intent, in: tab)
        }
        pending = Pending(intent: intent, tab: tab)
        return .presentLogin
    }

    /// 登录完成：在发起时的 tab 继续原意图；没有待处理意图时回到当前 tab 不做事。
    mutating func complete(currentTab: AppTab) -> Effect {
        guard let pending else { return .none }
        self.pending = nil
        return .execute(pending.intent, in: pending.tab)
    }

    mutating func cancel() {
        pending = nil
    }
}
