import Foundation

/// 攻略服务
/// Debug 模式下返回 Mock 数据，Release 模式调用真实 API
final class GuideService {
    private let client = LegacyAPIClient.shared

    /// 获取攻略列表
    func getGuides(page: Int = 0, size: Int = 20) async throws -> [Guide] {
        #if DEBUG
            try await Task.sleep(nanoseconds: 500_000_000)
            return Array(MockData.guides.prefix(size))
        #else
            let guides: [Guide] = try await client.request(
                APIEndpoints.guides,
                method: .get,
                parameters: ["page": page, "size": size]
            )
            return guides
        #endif
    }

    /// 获取攻略详情
    func getGuideDetail(id: String) async throws -> Guide {
        #if DEBUG
            try await Task.sleep(nanoseconds: 300_000_000)
            guard let guide = MockData.guides.first(where: { $0.id == id }) else {
                throw APIError(code: "NOT_FOUND", details: "攻略不存在", field: nil, timestamp: nil)
            }
            return guide
        #else
            let guide: Guide = try await client.request(
                APIEndpoints.guideDetail(id),
                method: .get
            )
            return guide
        #endif
    }

    /// 搜索攻略
    func searchGuides(keyword: String) async throws -> [Guide] {
        #if DEBUG
            try await Task.sleep(nanoseconds: 300_000_000)
            return MockData.guides.filter { guide in
                guide.title?.contains(keyword) == true || guide.summary?.contains(keyword) == true
            }
        #else
            let guides: [Guide] = try await client.request(
                APIEndpoints.guides,
                method: .get,
                parameters: ["keyword": keyword]
            )
            return guides
        #endif
    }

    /// 点赞攻略
    func likeGuide(id: String) async throws -> Bool {
        #if DEBUG
            try await Task.sleep(nanoseconds: 200_000_000)
            return true
        #else
            let _: Guide = try await client.request(
                "/guides/\(id)/like",
                method: .post
            )
            return true
        #endif
    }
}
