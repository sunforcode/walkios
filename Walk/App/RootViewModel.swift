import SwiftUI

enum DrawerUserDisplay: Equatable {
    case loggedOut
    case loading
    case user(User)
}

@MainActor
final class RootViewModel: ObservableObject {
    @Published private(set) var drawerUserDisplay: DrawerUserDisplay = .loading

    private let isLoggedIn: () -> Bool
    private let loadUser: () async throws -> User

    init(
        authManager: AuthManager = .shared,
        userService: UserService = UserService()
    ) {
        self.isLoggedIn = { authManager.isLoggedIn }
        self.loadUser = { try await userService.getCurrentUser() }
    }

    init(
        isLoggedIn: @escaping () -> Bool,
        loadUser: @escaping () async throws -> User
    ) {
        self.isLoggedIn = isLoggedIn
        self.loadUser = loadUser
    }

    func loadDrawerUser() async {
        guard isLoggedIn() else {
            drawerUserDisplay = .loggedOut
            return
        }

        drawerUserDisplay = .loading
        do {
            drawerUserDisplay = .user(try await loadUser())
        } catch {
            drawerUserDisplay = .loggedOut
        }
    }
}
