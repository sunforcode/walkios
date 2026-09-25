import Foundation
import WalkData

/// 行程生成资格的展示文案。路线详情与创建行程两处共用，确保缺失原因的文案一致。
struct RouteGenerationEligibilityPresentation: Equatable {
    let unavailableMessage: String?

    init(eligibility: RouteGenerationEligibility) {
        guard !eligibility.eligible else {
            unavailableMessage = nil
            return
        }
        let labels = (eligibility.missingReasons ?? []).map { reason in
            switch reason {
            case .name: "路线名称"
            case .region: "所在地区"
            case .estimatedDuration: "预计用时"
            case .start: "起点"
            case .end: "终点"
            case .validMainTrack: "有效主轨迹"
            }
        }
        unavailableMessage = labels.isEmpty
            ? "当前路线资料不足，暂不能生成行程"
            : "缺少：\(labels.joined(separator: "、"))"
    }
}
