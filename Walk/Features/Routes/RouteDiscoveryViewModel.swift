import Foundation
import Observation
import WalkData

@MainActor
@Observable
final class RouteDiscoveryViewModel {
    private(set) var discovery = RouteDiscoveryState()
    private(set) var searchContext = RouteSearchState()

    var routes: [PublicRouteBrowseSummary] { discovery.routes }
    var isLoading: Bool { discovery.isLoading }
    var errorMessage: String? { discovery.errorMessage }
    var searchResults: [PublicRouteSearchSummary] { searchContext.result?.items ?? [] }
    var searchState: PublicRouteSearchState { searchContext.result?.state ?? .initial }
    var isSearching: Bool { searchContext.phase == .loading }
    var searchErrorMessage: String? { searchContext.errorMessage }
    var lastSearchQuery: String? { searchContext.lastCompletion?.query }

    private let service: any RouteDiscoveryServicing
    @ObservationIgnored private var discoveryGeneration = 0
    @ObservationIgnored private var searchGeneration = 0

    init(service: any RouteDiscoveryServicing) {
        self.service = service
    }

    func loadRoutes() async {
        guard !Task.isCancelled, !isLoading else { return }
        discoveryGeneration += 1
        let generation = discoveryGeneration
        let previousPhase = discovery.phase
        discovery.phase = .loading

        await withTaskCancellationHandler {
            do {
                let result = try await service.getFeaturedRoutes()
                guard generation == discoveryGeneration else { return }
                guard !Task.isCancelled else {
                    cancelDiscovery(generation: generation, restoring: previousPhase)
                    return
                }
                discovery.routes = result.items
                discovery.phase = .ready
            } catch {
                guard generation == discoveryGeneration else { return }
                if Task.isCancelled || error is CancellationError
                    || (error as? APIClientError) == .transport(.cancelled) {
                    cancelDiscovery(generation: generation, restoring: previousPhase)
                } else {
                    discovery.phase = .failed(Self.message(for: error))
                }
            }
        } onCancel: {
            Task { @MainActor [weak self] in
                self?.cancelDiscovery(generation: generation, restoring: previousPhase)
            }
        }
    }

    /// S4：change 防抖 300ms；submit 立即请求。S5：同 query 恢复包括真实空结果。
    func search(query: String?, immediate: Bool = false) async {
        guard !Task.isCancelled else { return }
        searchGeneration += 1
        let generation = searchGeneration

        guard let query, !Self.isEmptyQuery(query) else {
            searchContext = RouteSearchState()
            return
        }

        let canRestore = !immediate
            && searchContext.lastCompletion?.query == query
            && !(searchContext.query == query && searchErrorMessage != nil)
        searchContext.query = query
        if canRestore {
            searchContext.phase = .ready
            return
        }
        // 防抖开始即撤销旧 query 的展示资格，不把 A 的结果置于 B 的输入之下。
        searchContext.phase = .loading

        await withTaskCancellationHandler {
            do {
                if !immediate {
                    try await Task.sleep(nanoseconds: 300_000_000)
                }
                guard generation == searchGeneration else { return }
                try Task.checkCancellation()
                let result = try await service.searchRoutes(query: query)
                guard generation == searchGeneration else { return }
                try Task.checkCancellation()
                searchContext.lastCompletion = .init(query: query, result: result)
                searchContext.phase = .ready
            } catch {
                guard generation == searchGeneration else { return }
                if Task.isCancelled || error is CancellationError
                    || (error as? APIClientError) == .transport(.cancelled) {
                    cancelSearch(generation: generation)
                } else {
                    searchContext.phase = .failed(Self.message(for: error))
                }
            }
        } onCancel: {
            Task { @MainActor [weak self] in
                self?.cancelSearch(generation: generation)
            }
        }
    }

    /// public-route 的空白集合；非空 query 不 trim、不做 Unicode 归一化。
    static func isEmptyQuery(_ value: String) -> Bool {
        value.unicodeScalars.allSatisfy { scalar in
            switch scalar.value {
            case 0x20, 0x09, 0x0A, 0x0D, 0x3000: true
            default: false
            }
        }
    }

    func retry() async {
        await loadRoutes()
    }

    private func cancelDiscovery(generation: Int, restoring phase: RouteDiscoveryState.Phase) {
        guard generation == discoveryGeneration, isLoading else { return }
        discoveryGeneration += 1
        discovery.phase = phase
    }

    private func cancelSearch(generation: Int) {
        guard generation == searchGeneration, isSearching else { return }
        searchGeneration += 1
        searchContext.phase = searchContext.lastCompletion?.query == searchContext.query ? .ready : .initial
    }

    private static func message(for error: Error) -> String {
        if let error = error as? LocalizedError, let description = error.errorDescription {
            return description
        }
        return "加载失败：\(error.localizedDescription)"
    }
}

@MainActor
@Observable
final class RouteCollectionViewModel {
    private(set) var routes: [PublicRouteBrowseSummary] = []
    private(set) var isLoading = false
    private(set) var errorMessage: String?

    private let service: any RouteDiscoveryServicing
    @ObservationIgnored private var loadGeneration = 0

    init(service: any RouteDiscoveryServicing) {
        self.service = service
    }

    func loadRoutes() async {
        guard !Task.isCancelled, !isLoading else { return }
        loadGeneration += 1
        let generation = loadGeneration
        isLoading = true
        errorMessage = nil
        defer {
            if generation == loadGeneration { isLoading = false }
        }

        await withTaskCancellationHandler {
            do {
                let result = try await service.getRoutes()
                guard generation == loadGeneration else { return }
                try Task.checkCancellation()
                routes = result.items
            } catch {
                guard generation == loadGeneration else { return }
                if Task.isCancelled || error is CancellationError
                    || (error as? APIClientError) == .transport(.cancelled) {
                    cancelLoad(generation: generation)
                } else {
                    errorMessage = Self.message(for: error)
                }
            }
        } onCancel: {
            Task { @MainActor [weak self] in
                self?.cancelLoad(generation: generation)
            }
        }
    }

    func retry() async {
        await loadRoutes()
    }

    private func cancelLoad(generation: Int) {
        guard generation == loadGeneration, isLoading else { return }
        loadGeneration += 1
        isLoading = false
    }

    private static func message(for error: Error) -> String {
        if let error = error as? LocalizedError, let description = error.errorDescription {
            return description
        }
        return "加载失败：\(error.localizedDescription)"
    }
}
