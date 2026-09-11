import SwiftUI

public struct MetricItemModel: Identifiable, Equatable {
     public let id: String
     public let value: String?
     public let unit: String?
     public let label: String

     public var isAvailable: Bool { value != nil }

     public init(id: String, value: String?, unit: String? = nil, label: String) {
        self.id = id
        self.value = value
        self.unit = unit
        self.label = label
    }
}

public enum MetricItemVariant {
    case `default`
    case inlineCompact
    case gridCompact
}

public struct MetricItem: View {
     public let model: MetricItemModel
     public var variant: MetricItemVariant = .default

     public init(model: MetricItemModel, variant: MetricItemVariant = .default) {
        self.model = model
        self.variant = variant
    }

     public init(value: String, label: String, variant: MetricItemVariant = .default) {
        self.model = MetricItemModel(id: label, value: value, label: label)
        self.variant = variant
    }

     public var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            HStack(alignment: .firstTextBaseline, spacing: Spacing.xs) {
                Text(model.value ?? "—")
                    .font(valueFont)
                    .foregroundStyle(AppColors.textPrimary)

                if model.isAvailable, let unit = model.unit {
                    Text(unit)
                        .font(.metricUnit)
                        .foregroundStyle(AppColors.textSecondary)
                }
            }

            Text(model.label)
                .font(labelFont)
                .foregroundStyle(AppColors.textWeak)
        }
        .fixedSize(horizontal: variant == .inlineCompact, vertical: true)
        .frame(maxWidth: variant == .gridCompact ? .infinity : nil, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
    }

    private var accessibilityText: String {
        guard let value = model.value else { return "\(model.label)未提供" }
        let unit = model.unit.map { " \($0)" } ?? ""
        return "\(model.label)，\(value)\(unit)"
    }

    private var valueFont: Font {
        switch variant {
        case .default: .metricValue
        case .inlineCompact: .metricCompactValue
        case .gridCompact: .metricGridValue
        }
    }

    private var labelFont: Font {
        switch variant {
        case .default: .metricLabel
        case .inlineCompact: .metricCompactLabel
        case .gridCompact: .metricGridLabel
        }
    }
}

#if DEBUG
#Preview("default") {
    MetricItem(model: MetricPreviewFixtures.completeMetrics[0])
        .padding()
        .background(AppColors.pageBase)
}

#Preview("missing") {
    MetricItem(
        model: MetricPreviewFixtures.missingMetrics[1],
        variant: .inlineCompact
    )
    .padding()
    .background(AppColors.pageBase)
}

#Preview("gridCompact") {
    MetricItem(
        model: MetricPreviewFixtures.completeMetrics[2],
        variant: .gridCompact
    )
    .padding()
    .background(AppColors.pageBase)
}
#endif
