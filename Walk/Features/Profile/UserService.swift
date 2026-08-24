import Foundation

/// 用户服务
/// Debug 模式下返回 Mock 数据，Release 模式调用真实 API
final class UserService {
    private let client = LegacyAPIClient.shared

    /// 获取当前用户信息
    func getCurrentUser() async throws -> User {
        #if DEBUG
            try await Task.sleep(nanoseconds: 300_000_000)
            return MockData.user
        #else
            let user: User = try await client.request(
                APIEndpoints.currentUser,
                method: .get
            )
            return user
        #endif
    }

    /// 获取用户详情
    func getUserDetail(id: String) async throws -> User {
        #if DEBUG
            try await Task.sleep(nanoseconds: 300_000_000)
            return MockData.user
        #else
            let user: User = try await client.request(
                APIEndpoints.userDetail(id),
                method: .get
            )
            return user
        #endif
    }

    /// 更新用户信息
    func updateUser(_ user: User) async throws -> User {
        #if DEBUG
            try await Task.sleep(nanoseconds: 300_000_000)
            return user
        #else
            let updated: User = try await client.request(
                APIEndpoints.userDetail(user.id),
                method: .put,
                parameters: [:]
            )
            return updated
        #endif
    }
}
