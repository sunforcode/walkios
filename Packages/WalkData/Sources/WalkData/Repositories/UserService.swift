import Foundation

public protocol AccountServicing {
    func sendVerificationCode(phone: String) async throws -> VerificationCodeResponse
    func createSession(verificationID: String, code: String) async throws -> AuthSessionResponse
    func currentAccount() async throws -> AccountResponse
    func updateProfile(_ update: ProfileUpdate) async throws -> ProfileResponse
    func uploadAvatar(data: Data, contentType: String) async throws -> AvatarMediaResponse
    func logout() async throws
}

public final class AccountService: AccountServicing {
    private let apiClient: any APIClient
    private let authManager: AuthManager

     public init(apiClient: any APIClient, authManager: AuthManager = .shared) {
        self.apiClient = apiClient
        self.authManager = authManager
    }

     public func sendVerificationCode(phone: String) async throws -> VerificationCodeResponse {
        try await apiClient.execute(AccountAPI.SendVerificationCode(phone: phone))
    }

     public func createSession(verificationID: String, code: String) async throws -> AuthSessionResponse {
        let response = try await apiClient.execute(AccountAPI.CreateSession(verificationID: verificationID, code: code))
        authManager.saveSession(accessToken: response.accessToken)
        return response
    }

     public func currentAccount() async throws -> AccountResponse {
        try await apiClient.execute(AccountAPI.Current())
    }

     public func updateProfile(_ update: ProfileUpdate) async throws -> ProfileResponse {
        try await apiClient.execute(AccountAPI.UpdateProfile(update: update))
    }

     public func uploadAvatar(data: Data, contentType: String) async throws -> AvatarMediaResponse {
        try await apiClient.execute(AccountAPI.UploadAvatar(data: data, contentType: contentType))
    }

     public func logout() async throws {
        let response = try await apiClient.execute(AccountAPI.Logout())
        guard response.loggedOut else { throw APIClientError.invalidResponse }
        authManager.logout()
    }
}
