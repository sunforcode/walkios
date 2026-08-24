import SwiftUI

/// 路线发现 ViewModel
@MainActor
final class RouteDiscoveryViewModel: ObservableObject {
    @Published var routes: [Route] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var selectedCategory: RouteCategory?

    private let service: RouteService

    init(service: RouteService) {
        self.service = service
    }

    func loadRoutes() async {
        isLoading = true
        errorMessage = nil

        do {
            routes = try await service.getRoutes(category: selectedCategory)
        } catch let error as APIError {
            errorMessage = error.errorDescription
        } catch let error as NetworkError {
            errorMessage = error.errorDescription
        } catch {
            errorMessage = "加载失败：\(error.localizedDescription)"
        }

        isLoading = false
    }

    func filterByCategory(_ category: RouteCategory?) async {
        selectedCategory = category
        await loadRoutes()
    }

    func retry() async {
        errorMessage = nil
        await loadRoutes()
    }
}
