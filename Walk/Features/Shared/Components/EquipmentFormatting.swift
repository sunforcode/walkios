import Foundation

/// 装备重量展示格式。Equipment、Profile、Trips 三个域共用。
enum AccountEquipmentFormatting {
    static func weightParts(grams: Int) -> (value: String, unit: String) {
        guard grams >= 1_000 else { return ("\(grams)", "g") }
        let kilograms = Double(grams) / 1_000
        return (kilograms.formatted(.number.precision(.fractionLength(0...1))), "kg")
    }

    static func weightText(grams: Int) -> String {
        let parts = weightParts(grams: grams)
        return "\(parts.value) \(parts.unit)"
    }
}
