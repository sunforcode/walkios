import SwiftUI
import WalkData
import WalkDesignSystem

struct TripEquipmentOverviewProjection: Equatable {
    let itemCount: Int
    let knownTotalWeightGrams: Double
    let missingWeightItemCount: Int
    let ownedItemCount: Int
    let unconfirmedOwnedItemCount: Int

    var isCompleteWeight: Bool { missingWeightItemCount == 0 }

    private var weightLabel: String { isCompleteWeight ? "预计总重量" : "已知重量" }

    var metrics: [MetricItemModel] {
        let weight = AccountEquipmentFormatting.weightParts(grams: knownTotalWeightGrams)
        return [
            MetricItemModel(id: "item-count", value: "\(itemCount)", unit: "项", label: "装备条目"),
            MetricItemModel(id: "known-weight", value: weight.value, unit: weight.unit, label: weightLabel),
            MetricItemModel(id: "owned-count", value: "\(ownedItemCount)", unit: "项", label: "已有"),
            MetricItemModel(id: "unconfirmed-owned", value: "\(unconfirmedOwnedItemCount)", unit: "项", label: "未确认已有"),
        ]
    }

    var weightAccessibilityText: String {
        let weight = AccountEquipmentFormatting.weightText(grams: knownTotalWeightGrams)
        if isCompleteWeight {
            return "\(weightLabel) \(weight)"
        }
        return "\(weightLabel) \(weight)，未计入 \(missingWeightItemCount) 项"
    }
}

extension TripBusinessComponents {
    struct TripEquipmentOverview: View {
        let projection: TripEquipmentOverviewProjection

        var body: some View {
            MetricGroup(items: projection.metrics, variant: .grid)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityElement(children: .contain)
                .accessibilityLabel(accessibilityText)
        }

        private var accessibilityText: String {
            "装备条目 \(projection.itemCount) 项，\(projection.weightAccessibilityText)，已有 \(projection.ownedItemCount) 项，未确认已有 \(projection.unconfirmedOwnedItemCount) 项"
        }
    }
}

#if DEBUG
extension TripEquipmentOverviewProjection {
    static let `default` = TripEquipmentOverviewProjection(
        itemCount: 12,
        knownTotalWeightGrams: 8420,
        missingWeightItemCount: 0,
        ownedItemCount: 10,
        unconfirmedOwnedItemCount: 2
    )

    static let partialWeight = TripEquipmentOverviewProjection(
        itemCount: 12,
        knownTotalWeightGrams: 7960,
        missingWeightItemCount: 2,
        ownedItemCount: 9,
        unconfirmedOwnedItemCount: 3
    )

    static let empty = TripEquipmentOverviewProjection(
        itemCount: 0,
        knownTotalWeightGrams: 0,
        missingWeightItemCount: 0,
        ownedItemCount: 0,
        unconfirmedOwnedItemCount: 0
    )

    static let long = TripEquipmentOverviewProjection(
        itemCount: 38,
        knownTotalWeightGrams: 126_400,
        missingWeightItemCount: 4,
        ownedItemCount: 31,
        unconfirmedOwnedItemCount: 7
    )
}

#Preview("TripEquipmentOverview.default") {
    BusinessComponentPreviewHost {
        TripBusinessComponents.TripEquipmentOverview(
            projection: TripEquipmentOverviewProjection.default
        )
    }
}

#Preview("TripEquipmentOverview.partialWeight") {
    BusinessComponentPreviewHost {
        TripBusinessComponents.TripEquipmentOverview(
            projection: TripEquipmentOverviewProjection.partialWeight
        )
    }
}

#Preview("TripEquipmentOverview.empty") {
    BusinessComponentPreviewHost {
        TripBusinessComponents.TripEquipmentOverview(
            projection: TripEquipmentOverviewProjection.empty
        )
    }
}

#Preview("TripEquipmentOverview.longValues") {
    BusinessComponentPreviewHost {
        TripBusinessComponents.TripEquipmentOverview(
            projection: TripEquipmentOverviewProjection.long
        )
    }
}
#endif
