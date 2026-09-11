import SwiftUI
import WalkData
import WalkDesignSystem

enum DrawerUserDisplay: Equatable {
    case loggedOut
    case loading
    case account(AccountResponse)
}

@MainActor
final class RootViewModel: ObservableObject {
    @Published private(set) var drawerUserDisplay: DrawerUserDisplay = .loading

    private let isLoggedIn: () -> Bool
    private let loadAccount: () async throws -> AccountResponse

    init(
        authManager: AuthManager = .shared,
        accountService: any AccountServicing
    ) {
        self.isLoggedIn = { authManager.isLoggedIn }
        self.loadAccount = { try await accountService.currentAccount() }
    }

    init(
        isLoggedIn: @escaping () -> Bool,
        loadAccount: @escaping () async throws -> AccountResponse
    ) {
        self.isLoggedIn = isLoggedIn
        self.loadAccount = loadAccount
    }

    func loadDrawerUser() async {
        guard isLoggedIn() else {
            drawerUserDisplay = .loggedOut
            return
        }

        drawerUserDisplay = .loading
        do {
            drawerUserDisplay = .account(try await loadAccount())
        } catch {
            drawerUserDisplay = .loggedOut
        }
    }
}
