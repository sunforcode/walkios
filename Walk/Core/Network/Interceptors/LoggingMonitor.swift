import Foundation
#if canImport(Alamofire)
import Alamofire
#endif

/// 日志拦截器 - Debug 构建下输出请求/响应日志
final class LoggingMonitor: EventMonitor {
    func requestDidResume(_ request: Request) {
        #if DEBUG
        print("➡️ [Request] \(request.request?.httpMethod ?? "GET") \(request.request?.url?.absoluteString ?? "")")
        if let headers = request.request?.allHTTPHeaderFields, !headers.isEmpty {
            print("   Headers: \(headers)")
        }
        if let body = request.request?.httpBody,
           let bodyString = String(data: body, encoding: .utf8) {
            print("   Body: \(bodyString)")
        }
        #endif
    }

    func requestDidComplete(_ request: Request) {
        #if DEBUG
        if let response = request.response {
            let emoji = response.statusCode < 400 ? "✅" : "❌"
            print("\(emoji) [Response] \(response.statusCode) \(request.request?.url?.absoluteString ?? "")")
        }
        if let error = request.error {
            print("❌ [Error] \(error.localizedDescription)")
        }
        #endif
    }
}
