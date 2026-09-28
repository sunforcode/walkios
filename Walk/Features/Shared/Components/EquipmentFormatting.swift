import Foundation

/// 装备重量展示格式。Equipment、Profile、Trips 三个域共用。
enum AccountEquipmentFormatting {
    /// 不给整数附加 .0，保留已有表单的整数输入兼容性。
    static func decimalText(_ grams: Double) -> String {
        let text = String(grams)
        return text.hasSuffix(".0") ? String(text.dropLast(2)) : text
    }

    static func weightParts(grams: Double) -> (value: String, unit: String) {
        guard grams >= 1_000 else { return (decimalText(grams), "g") }
        let kilograms = Double(grams) / 1_000
        return (kilograms.formatted(.number.precision(.fractionLength(0...1))), "kg")
    }

    static func weightText(grams: Double) -> String {
        let parts = weightParts(grams: grams)
        return "\(parts.value) \(parts.unit)"
    }
}
