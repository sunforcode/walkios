#if DEBUG
import Foundation

/// 时间线组件预览样例条目。
 public struct TimelinePreviewItem: Identifiable {
    public let id: String
    public let time: String?
    public let title: String
    public let details: [String]

    public init(id: String, time: String?, title: String, details: [String]) {
        self.id = id
        self.time = time
        self.title = title
        self.details = details
    }
}

/// 通用组件预览与组件目录共用的固定样例文案与数据。
 public enum ComponentPreviewFixtures {
    public static let shortTitle = "组件标题"
    public static let supportingText = "这是一段固定的辅助说明，用于展示组件默认内容。"
    public static let longTitle = "需要完整展示并允许自然换行的较长组件标题内容"
    public static let longSupportingText = "这是一段固定的长内容，用于确认在较窄宽度和较大字体下仍然完整换行，不依赖网络、随机值或当前时间。"
    public static let source = "来源：户外信息服务与当地管理部门联合发布的固定示例"
    public static let updatedAt = "更新时间：2026-09-18 08:30"
    public static let fixedDate = Date(timeIntervalSince1970: 1_789_689_600)

    public static let sectionTitle = "行程准备信息"
    public static let formLabel = "装备名称"
    public static let formPlaceholder = "输入装备名称"
    public static let formValue = "轻量防风外套"
    public static let formHelper = "用于当前行程的固定辅助说明。"
    public static let formError = "请检查输入内容后重试。"
    public static let errorTitle = "内容加载失败"
    public static let errorMessage = "暂时无法读取内容，请稍后重试。"
    public static let confirmationTitle = "确认本次操作？"
    public static let confirmationMessage = "确认后将继续执行当前操作，请核对信息。"
    public static let confirmationError = "操作未完成，请保留当前确认层后重试。"
    public static let searchPlaceholder = "搜索路线名称或地区"
    public static let searchQuery = "云岭"
    public static let longSearchQuery = "云岭山脊日出观景与高山草甸连续徒步路线"

    public static let selectOptions: [SelectInputOption] = [
        SelectInputOption(value: "easy", label: "轻松"),
        SelectInputOption(value: "moderate", label: "适中"),
        SelectInputOption(value: "challenging", label: "挑战"),
    ]

    public static let segmentOptions: [SegmentedControlOption] = [
        SegmentedControlOption(value: "overview", title: "概要"),
        SegmentedControlOption(value: "details", title: "详情"),
    ]

    public static let timelineItems: [TimelinePreviewItem] = [
        TimelinePreviewItem(id: "start", time: "08:30", title: "从集合点出发", details: ["核对随身装备和饮用水。"]),
        TimelinePreviewItem(id: "ridge", time: nil, title: "通过连续山脊路段", details: [longSupportingText]),
        TimelinePreviewItem(id: "finish", time: "15:40", title: "返回终点", details: []),
    ]
}
#endif
