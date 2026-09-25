import SwiftUI
import WalkData
import WalkDesignSystem

enum TripHeatmapLevel: Int, Equatable {
    case empty = 0
    case low = 1
    case medium = 2
    case high = 3

    var color: Color {
        switch self {
        case .empty: AppColors.heatmapEmpty
        case .low: AppColors.heatmapLow
        case .medium: AppColors.heatmapMedium
        case .high: AppColors.heatmapHigh
        }
    }
}

struct TripHeatmapDayProjection: Identifiable, Equatable {
    let businessDate: String
    let level: TripHeatmapLevel

    var id: String { businessDate }
}

extension SharedBusinessComponents {
    struct HeatmapCalendar: View {
        static let requiredDayCount = 365
        let days: [TripHeatmapDayProjection]

        @ViewBuilder
        var body: some View {
            if days.count == Self.requiredDayCount {
                calendar
            } else {
                Text("行程日历数据不完整")
                    .font(.appCaption)
                    .foregroundStyle(AppColors.textWeak)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isStaticText)
            }
        }

        private var calendar: some View {
            let rows = Array(repeating: GridItem(.fixed(4), spacing: 2), count: 7)
            return LazyHGrid(rows: rows, spacing: 2) {
                ForEach(days) { day in
                    RoundedRectangle(cornerRadius: 1, style: .continuous)
                        .fill(day.level.color)
                        .frame(width: 4, height: 4)
                        .accessibilityHidden(true)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 40, alignment: .leading)
            .clipped()
            .allowsHitTesting(false)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("行程日历，过去 365 天有 \(activeDayCount) 天存在行程")
            .accessibilityAddTraits(.isImage)
        }

        private var activeDayCount: Int {
            days.reduce(into: 0) { count, day in
                if day.level != .empty { count += 1 }
            }
        }
    }
}

#if DEBUG
#Preview("HeatmapCalendar.default") {
    BusinessComponentPreviewHost {
        SharedBusinessComponents.HeatmapCalendar(
            days: BusinessComponentPreviewFixtures.heatmapDefault
        )
    }
}

#Preview("HeatmapCalendar.empty") {
    BusinessComponentPreviewHost {
        SharedBusinessComponents.HeatmapCalendar(
            days: BusinessComponentPreviewFixtures.heatmapEmpty
        )
    }
}
#endif
