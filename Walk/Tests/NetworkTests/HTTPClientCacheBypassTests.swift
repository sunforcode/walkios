import XCTest
import Alamofire
import WalkData

/// W6 验收发现：real 模式下 URLSession 自带 HTTP 缓存按 `Cache-Control: max-age` 直接返回旧响应，
/// 请求未到达服务端。
///
/// 依据 specs/README.md：R-CACHE-POLICY「首版读取顺序为网络优先」；R-STORAGE「HTTP 客户端不得另外
/// 绕过所选策略返回缓存」。响应复用只由应用响应缓存按端点资格与策略决定，因此任何模式下
/// HTTP 客户端都不得启用自己的响应缓存。
final class HTTPClientCacheBypassTests: XCTestCase {
    func testEveryModeSessionDisablesHTTPResponseCache() {
        for policy in [APIResponseCachePolicy.enabled, .disabled] {
            let configuration = AlamofireRemoteAPIClient.makeDefaultSession(responseCachePolicy: policy)
                .sessionConfiguration
            XCTAssertNil(configuration.urlCache, "\(policy)：HTTP 客户端不得持有响应缓存")
            XCTAssertEqual(
                configuration.requestCachePolicy,
                .reloadIgnoringLocalCacheData,
                "\(policy)：读取必须网络优先，不得由 HTTP 缓存返回"
            )
        }
    }
}
