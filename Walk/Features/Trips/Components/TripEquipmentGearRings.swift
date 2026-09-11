import SwiftUI
import WalkData
import WalkDesignSystem

/// 业务组合 TripEquipmentGearRings（L2c）：三圆环并列展示清单、已有与未确认计数。
/// 视觉合同见 docs/ui/components/business/composites/trip-equipment-gear-rings/spec.md。
struct TripEquipmentGearRingsProjection: Equatable {
    let itemCount: Int
    let ownedItemCount: Int
    let unconfirmedOwnedItemCount: Int

    var rings: [GearRingProjection] {
        [
            GearRingProjection(value: itemCount, total: itemCount, tone: .neutral, label: "清单"),
            GearRingProjection(value: ownedItemCount, total: itemCount, tone: .mint, label: "已有"),
            GearRingProjection(
                value: unconfirmedOwnedItemCount,
                total: itemCount,
                tone: .orange,
                label: "未确认"
            ),
        ]
    }
}

extension TripBusinessComponents {
    struct TripEquipmentGearRings: View {
        let projection: TripEquipmentGearRingsProjection

        var body: some View {
            HStack(alignment: .center, spacing: 8) {
                ForEach(Array(projection.rings.enumerated()), id: \.offset) { _, ring in
                    TripBusinessComponents.GearRing(projection: ring)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(
                "清单 \(projection.itemCount)，已有 \(projection.ownedItemCount)，未确认 \(projection.unconfirmedOwnedItemCount)"
            )
        }
    }
}

#if DEBUG
#Preview("TripEquipmentGearRings.default") {
    BusinessComponentPreviewHost {
        TripBusinessComponents.TripEquipmentGearRings(
            projection: TripEquipmentGearRingsProjection(
                itemCount: 12,
                ownedItemCount: 9,
                unconfirmedOwnedItemCount: 3
            )
        )
        .padding(Spacing.lg)
    }
}

#Preview("TripEquipmentGearRings.allOwned") {
    BusinessComponentPreviewHost {
        TripBusinessComponents.TripEquipmentGearRings(
            projection: TripEquipmentGearRingsProjection(
                itemCount: 10,
                ownedItemCount: 10,
                unconfirmedOwnedItemCount: 0
            )
        )
        .padding(Spacing.lg)
    }
}

#Preview("TripEquipmentGearRings.empty") {
    BusinessComponentPreviewHost {
        TripBusinessComponents.TripEquipmentGearRings(
            projection: TripEquipmentGearRingsProjection(
                itemCount: 0,
                ownedItemCount: 0,
                unconfirmedOwnedItemCount: 0
            )
        )
        .padding(Spacing.lg)
    }
}
#endif
