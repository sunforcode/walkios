import Foundation
#if canImport(Alamofire)
import Alamofire
#endif

/// 重试策略 - 指数退避
/// 仅在网络错误时重试，4xx/5xx 不重试
struct APIRetryPolicy: RequestRetrier {
    let maximumRetryCount: Int
    let retryInterval: TimeInterval

    init(maximumRetryCount: Int = 2, retryInterval: TimeInterval = 1.0) {
        self.maximumRetryCount = maximumRetryCount
        self.retryInterval = retryInterval
    }

    func retry(_ request: Request, for session: Session, dueTo error: Error, completion: @escaping (RetryResult) -> Void) {
        // 检查重试次数
        guard request.retryCount < maximumRetryCount else {
            completion(.doNotRetry)
            return
        }

        // 仅网络错误重试
        if let urlError = error as? URLError {
            switch urlError.code {
            case .timedOut, .notConnectedToInternet, .networkConnectionLost, .cannotConnectToHost:
                // 指数退避: 1s -> 2s -> 4s...
                let delay = retryInterval * pow(2.0, Double(request.retryCount))
                completion(.retryWithDelay(delay))
            default:
                completion(.doNotRetry)
            }
        } else {
            completion(.doNotRetry)
        }
    }
}
