import Foundation
#if canImport(Alamofire)
import Alamofire
#endif

/// 认证拦截器 - 在请求头注入 Bearer Token
final class AuthAdapter: RequestAdapter {
    func adapt(_ urlRequest: URLRequest, for session: Session, completion: @escaping (Result<URLRequest, Error>) -> Void) {
        var request = urlRequest

        // 注入 Bearer Token
        if let token = AuthManager.shared.currentToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        // 注入通用 Headers，但不覆盖请求声明的媒体 Content-Type。
        if request.httpBody != nil && request.value(forHTTPHeaderField: "Content-Type") == nil {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        if request.value(forHTTPHeaderField: "Accept") == nil {
            request.setValue("application/json", forHTTPHeaderField: "Accept")
        }
        request.setValue("Walk-iOS/1.0.0", forHTTPHeaderField: "User-Agent")

        completion(.success(request))
    }
}
