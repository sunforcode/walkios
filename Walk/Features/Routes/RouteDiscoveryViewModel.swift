import Foundation
import WalkData
import WalkDesignSystem

@MainActor
final class RouteDiscoveryViewModel: ObservableObject {
    @Published var routes: [PublicRouteBrowseSummary] = []
    @Published private(set) var searchResults: [PublicRouteSearchSummary] = []
    @Published private(set) var searchState: PublicRouteSearchState = .initial
    @Published var isLoading = false
    @Published var errorMessage: String?
    /// S5：记录最近一次成功搜索的 query，返回恢复时避免同 query 重复请求。
    private(set) var lastSearchQuery: String?

    private let service: any RouteDiscoveryServicing
    private var searchGeneration = 0

    init(service: any RouteDiscoveryServicing) {
        self.service = service
    }

    func loadRoutes() async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            routes = try await service.getFeaturedRoutes().items
        } catch {
            errorMessage = Self.message(for: error)
        }
    }

    /// S4：非空输入 change 后先经短延时防抖（用户停手才提交）；submit 传 `immediate: true` 直通。
    /// `searchGeneration` 是 requestVersion 等价物，迟到的旧结果不会覆盖当前结果。
    func search(query: String?, immediate: Bool = false) async {
        searchGeneration += 1
        let generation = searchGeneration

        guard let query,
              !query.unicodeScalars.allSatisfy({ scalar in
                  switch scalar.value {
                  case 0x20, 0x09, 0x0A, 0x0D, 0x3000: true
                  default: false
                  }
              }) else {
            searchState = .initial
            searchResults = []
            errorMessage = nil
            isLoading = false
            return
        }

        if !immediate {
            // S5：返回恢复场景下同 query 已有结果且无错误，不重复请求。
            if query == lastSearchQuery, errorMessage == nil, !searchResults.isEmpty {
                return
            }
            try? await Task.sleep(nanoseconds: 300_000_000)
            guard generation == searchGeneration, !Task.isCancelled else { return }
        }

        isLoading = true
        errorMessage = nil

        do {
            let result = try await service.searchRoutes(query: query)
            guard generation == searchGeneration, !Task.isCancelled else { return }
            searchState = result.state
            searchResults = result.items
            lastSearchQuery = query
            isLoading = false
        } catch {
            guard generation == searchGeneration, !Task.isCancelled else { return }
            errorMessage = Self.message(for: error)
            isLoading = false
        }
    }

    func retry() async {
        await loadRoutes()
    }

    private static func message(for error: Error) -> String {
        if let error = error as? LocalizedError, let description = error.errorDescription {
            return description
        }
        return "加载失败：\(error.localizedDescription)"
    }
}

@MainActor
final class RouteCollectionViewModel: ObservableObject {
    @Published private(set) var routes: [PublicRouteBrowseSummary] = []
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?

    private let service: any RouteDiscoveryServicing

    init(service: any RouteDiscoveryServicing) {
        self.service = service
    }

    func loadRoutes() async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            routes = try await service.getRoutes().items
        } catch {
            errorMessage = Self.message(for: error)
        }
    }

    func retry() async {
        await loadRoutes()
    }

    private static func message(for error: Error) -> String {
        if let error = error as? LocalizedError, let description = error.errorDescription {
            return description
        }
        return "加载失败：\(error.localizedDescription)"
    }
}
