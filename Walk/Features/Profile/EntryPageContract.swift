import Foundation

/// 入口表单页的已批准字段清单，由 Profile 域的设置与资料页消费。
enum EntryPageContract {
    static let profileFields = ["昵称", "脱敏手机号", "头像"]
    static let notificationOptions = ["通知总开关", "行程提醒", "天气提醒"]
    static let privacyOptions = ["资料可见性", "位置共享", "匿名分析"]
    static let feedbackFields = ["反馈分类", "反馈内容"]
    static let tripFields = ["出发城市", "开始日期", "装备清单（可选）"]
    static let equipmentFields = ["名称", "拥有数量", "单件克重（可选）"]
}
