#if DEBUG
import Foundation

enum ComponentPreviewFixtures {
    static let shortTitle = "组件标题"
    static let supportingText = "这是一段固定的辅助说明，用于展示组件默认内容。"
    static let longTitle = "需要完整展示并允许自然换行的较长组件标题内容"
    static let longSupportingText = "这是一段固定的长内容，用于确认在较窄宽度和较大字体下仍然完整换行，不依赖网络、随机值或当前时间。"
    static let source = "来源：户外信息服务与当地管理部门联合发布的固定示例"
    static let updatedAt = "更新时间：2026-09-18 08:30"
    static let fixedDate = Date(timeIntervalSince1970: 1_789_689_600)

    static let navigationTitle = "全部路线"
    static let longNavigationTitle = "需要完整展示并允许自然换行的工具页面标题"
    static let sectionTitle = "行程准备信息"
    static let formLabel = "装备名称"
    static let formPlaceholder = "输入装备名称"
    static let formValue = "轻量防风外套"
    static let formHelper = "用于当前行程的固定辅助说明。"
    static let formError = "请检查输入内容后重试。"
    static let searchPlaceholder = "搜索路线名称或地区"
    static let searchQuery = "云岭"
    static let longSearchQuery = "云岭山脊日出观景与高山草甸连续徒步路线"
    static let sheetTitle = "底部模态任务"
    static let sheetAction = "完成"
    static let confirmationTitle = "确认本次操作？"
    static let confirmationMessage = "确认后将继续执行当前操作，请核对信息。"
    static let confirmationError = "操作未完成，请保留当前确认层后重试。"
    static let errorTitle = "内容加载失败"
    static let errorMessage = "暂时无法读取内容，请稍后重试。"

    static let selectOptions = [
        SelectInputOption(value: "easy", label: "轻松"),
        SelectInputOption(value: "moderate", label: "适中"),
        SelectInputOption(value: "challenging", label: "挑战"),
    ]

    static let segmentOptions = [
        SegmentedControlOption(value: "overview", title: "概要"),
        SegmentedControlOption(value: "details", title: "详情"),
    ]

    static let timelineItems = [
        TimelinePreviewItem(id: "start", time: "08:30", title: "从集合点出发", details: ["核对随身装备和饮用水。"]),
        TimelinePreviewItem(id: "ridge", time: nil, title: "通过连续山脊路段", details: [longSupportingText]),
        TimelinePreviewItem(id: "finish", time: "15:40", title: "返回终点", details: []),
    ]
}

struct TimelinePreviewItem: Identifiable {
    let id: String
    let time: String?
    let title: String
    let details: [String]
}
#endif
