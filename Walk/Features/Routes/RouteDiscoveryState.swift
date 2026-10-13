import WalkData

struct RouteDiscoveryState {
    enum Phase: Equatable {
        case idle
        case loading
        case ready
        case failed(String)
    }

    var routes: [PublicRouteBrowseSummary] = []
    var phase: Phase = .idle

    var isLoading: Bool { phase == .loading }
    var errorMessage: String? {
        guard case .failed(let message) = phase else { return nil }
        return message
    }
}

struct RouteSearchState {
    enum Phase: Equatable {
        case initial
        case loading
        case ready
        case failed(String)
    }

    struct Completion {
        let query: String
        let result: PublicRouteSearchResult
    }

    var query: String?
    var phase: Phase = .initial
    /// 只保存最近一次真实成功响应；仅在当前 query 匹配且 ready 时有展示资格。
    var lastCompletion: Completion?

    var result: PublicRouteSearchResult? {
        guard phase == .ready, lastCompletion?.query == query else { return nil }
        return lastCompletion?.result
    }

    var errorMessage: String? {
        guard case .failed(let message) = phase else { return nil }
        return message
    }
}
