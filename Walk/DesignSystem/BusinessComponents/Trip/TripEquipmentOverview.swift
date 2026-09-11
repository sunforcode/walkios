import SwiftUI

struct TripEquipmentOverviewProjection: Equatable {
    let itemCount: Int
    let knownTotalWeightGrams: Int
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
#Preview("TripEquipmentOverview.default") {
    BusinessComponentPreviewHost {
        TripBusinessComponents.TripEquipmentOverview(
            projection: BusinessComponentPreviewFixtures.tripEquipmentOverviewDefault
        )
    }
}

#Preview("TripEquipmentOverview.partialWeight") {
    BusinessComponentPreviewHost {
        TripBusinessComponents.TripEquipmentOverview(
            projection: BusinessComponentPreviewFixtures.tripEquipmentOverviewPartialWeight
        )
    }
}

#Preview("TripEquipmentOverview.empty") {
    BusinessComponentPreviewHost {
        TripBusinessComponents.TripEquipmentOverview(
            projection: BusinessComponentPreviewFixtures.tripEquipmentOverviewEmpty
        )
    }
}

#Preview("TripEquipmentOverview.longValues") {
    BusinessComponentPreviewHost {
        TripBusinessComponents.TripEquipmentOverview(
            projection: BusinessComponentPreviewFixtures.tripEquipmentOverviewLong
        )
    }
}
#endif
