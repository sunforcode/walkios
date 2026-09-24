import Foundation
import WalkData

/// 测试用的服务身份构造。
///
/// 生产装配由 App 依据最终配置提供；测试显式注入，不读取个人 Debug 设置。
extension APIServiceIdentity {
    static func testService(
        environment: String,
        baseURL: URL = URL(string: "https://api.example.test/api/v1")!
    ) -> APIServiceIdentity {
        APIServiceIdentity(environmentName: environment, baseURL: baseURL)
    }
}
