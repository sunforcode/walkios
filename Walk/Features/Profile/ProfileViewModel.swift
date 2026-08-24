import SwiftUI

/// 个人中心 ViewModel
@MainActor
final class ProfileViewModel: ObservableObject {
    @Published var user: User?
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var isLoggedIn = false
    @Published var tripCount = 0
    @Published var routeCount = 0
    @Published var totalDistance = 0

    private let loadUser: () async throws -> User
    private let clearCachedResponses: () async -> Void
    private let tripRepository: any TripRepository
    private let authSession: any AuthSession

    init(
        tripRepository: any TripRepository,
        authSession: any AuthSession = AuthManager.shared,
        loadUser: @escaping () async throws -> User = { try await UserService().getCurrentUser() },
        clearCachedResponses: @escaping () async -> Void = {}
    ) {
        self.tripRepository = tripRepository
        self.authSession = authSession
        self.loadUser = loadUser
        self.clearCachedResponses = clearCachedResponses
    }

    func loadProfile() async {
        isLoading = true
        errorMessage = nil
        isLoggedIn = authSession.isLoggedIn

        do {
            tripCount = try await tripRepository.fetchTrips().totalElements
            if isLoggedIn {
                user = try await loadUser()
            } else {
                user = nil
            }
            routeCount = 0
            totalDistance = 0
        } catch let error as LocalizedError {
            errorMessage = error.errorDescription ?? "加载失败，请稍后重试"
        } catch {
            errorMessage = "加载失败：\(error.localizedDescription)"
        }

        isLoading = false
    }

    func logout() async {
        // 先清认证，阻止新请求继续携带旧身份；随后失效并清理缓存。
        authSession.logout()
        await clearCachedResponses()
        isLoggedIn = false
        user = nil
        tripCount = 0
        routeCount = 0
        totalDistance = 0
    }
}
