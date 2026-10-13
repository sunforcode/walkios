import Foundation
import Observation
import WalkData
import WalkDesignSystem

struct HomeWeatherSummary: Equatable {
    let conclusion: String
    let impact: String
}

enum HomeState: Equatable {
    case guest
    case loading
    case error(String)
    case ready
}

@MainActor
@Observable
final class HomeViewModel {
    private(set) var state: HomeState = .loading
    private(set) var focusedTrip: PersonalTripSummary?
    private(set) var weatherSummary: HomeWeatherSummary?
    private(set) var refreshError: String?
    // 当前有效代次是否在请求中；首次取消后的 loading 仅为未取得结果的占位。
    private(set) var isLoading = false

    private let isLoggedIn: () -> Bool
    private let currentIdentity: () -> String
    private let loadFocus: () async throws -> PersonalTripFocus
    private var loadGeneration = 0
    private var loadedIdentity: String?
    // 只记录已结束的结果，不从其他在途请求的 loading 捕获恢复快照。
    private var lastSettledState: HomeState?
    private var isStatic = false

    init(
        service: any PersonalTripServicing,
        authSession: any AuthSession
    ) {
        self.isLoggedIn = { authSession.isLoggedIn }
        self.currentIdentity = { authSession.cacheIdentity }
        self.loadFocus = { try await service.focus() }
        self.state = authSession.isLoggedIn ? .loading : .guest
    }

    init(
        isLoggedIn: @escaping () -> Bool = { true },
        currentIdentity: @escaping () -> String = { "injected-session" },
        loadFocus: @escaping () async throws -> PersonalTripFocus
    ) {
        self.isLoggedIn = isLoggedIn
        self.currentIdentity = currentIdentity
        self.loadFocus = loadFocus
        self.state = isLoggedIn() ? .loading : .guest
    }

    init(
        staticState: HomeState,
        focusedTrip: PersonalTripSummary? = nil,
        weatherSummary: HomeWeatherSummary? = nil,
        refreshError: String? = nil
    ) {
        self.state = staticState
        self.focusedTrip = focusedTrip
        self.weatherSummary = weatherSummary
        self.refreshError = refreshError
        self.isLoggedIn = { staticState != .guest }
        self.currentIdentity = { "static-preview" }
        self.loadFocus = { PersonalTripFocus(trip: focusedTrip) }
        self.isStatic = true
    }

    func load() async {
        guard !isStatic, !Task.isCancelled else { return }
        loadGeneration += 1
        let generation = loadGeneration
        guard isLoggedIn() else {
            clearFocus(state: .guest)
            return
        }

        let identity = currentIdentity()
        if loadedIdentity != identity {
            clearFocus(state: .loading)
            loadedIdentity = identity
        }
        let hadFocus = focusedTrip != nil
        if !hadFocus { state = .loading }
        refreshError = nil
        isLoading = true
        defer { if generation == loadGeneration { isLoading = false } }

        do {
            let focus = try await loadFocus()
            guard acceptsResult(generation: generation, identity: identity) else { return }
            guard !Task.isCancelled else {
                state = lastSettledState ?? .loading
                return
            }
            // 无焦点行程：停留在首页空态，进入全部路线由用户主动发起（app-flow）。
            focusedTrip = focus.trip
            weatherSummary = nil
            state = .ready
            lastSettledState = state
        } catch {
            guard acceptsResult(generation: generation, identity: identity) else { return }
            guard !Self.isCancellation(error) else {
                state = lastSettledState ?? .loading
                return
            }
            if hadFocus {
                state = .ready
                refreshError = "当前行程刷新失败"
            } else {
                state = .error("当前行程加载失败")
            }
            lastSettledState = state
        }
    }

    func retry() async { await load() }

    /// Lifecycle invalidation also covers retry tasks whose service ignores cancellation.
    func cancelPendingOperations() {
        guard !isStatic else { return }
        loadGeneration += 1
        isLoading = false
        guard isLoggedIn() else {
            clearFocus(state: .guest)
            return
        }
        guard loadedIdentity == currentIdentity() else {
            clearFocus(state: .loading)
            return
        }
        state = lastSettledState ?? .loading
    }

    private func acceptsResult(generation: Int, identity: String) -> Bool {
        guard generation == loadGeneration else { return false }
        guard isLoggedIn(), currentIdentity() == identity else {
            clearFocus(state: isLoggedIn() ? .loading : .guest)
            return false
        }
        return true
    }

    private func clearFocus(state: HomeState) {
        focusedTrip = nil
        weatherSummary = nil
        refreshError = nil
        loadedIdentity = nil
        lastSettledState = state == .loading ? nil : state
        isLoading = false
        self.state = state
    }

    private static func isCancellation(_ error: Error) -> Bool {
        if Task.isCancelled || error is CancellationError { return true }
        if let apiError = error as? APIClientError, case .transport(.cancelled) = apiError { return true }
        return false
    }
}
