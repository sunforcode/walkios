import SwiftUI

public struct MetricGroup: View {
     public let items: [MetricItemModel]
     public var variant: MetricGroupVariant = .inline

    private let compatibilityContent: AnyView?
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

     public init(items: [MetricItemModel], variant: MetricGroupVariant = .inline) {
        self.items = items
        self.variant = variant
        self.compatibilityContent = nil
    }

    init<Content: View>(
        spacing: CGFloat = Spacing.xl,
        usesGrid: Bool = false,
        @ViewBuilder content: () -> Content
    ) {
        self.items = []
        self.variant = usesGrid ? .grid : .inline
        let content = content()
        if usesGrid {
            self.compatibilityContent = AnyView(
                LazyVGrid(
                    columns: Array(repeating: GridItem(.flexible(), spacing: spacing), count: 2),
                    alignment: .leading,
                    spacing: spacing
                ) {
                    content
                }
            )
        } else {
            self.compatibilityContent = AnyView(
                HStack(alignment: .top, spacing: spacing) {
                    content
                }
            )
        }
    }

    @ViewBuilder
     public var body: some View {
        if let compatibilityContent {
            compatibilityContent
                .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            switch variant {
            case .grid:
                grid(spacing: Spacing.sm)
            case .inline:
                if dynamicTypeSize.isAccessibilitySize {
                    grid(spacing: Spacing.lg)
                } else {
                    ViewThatFits(in: .horizontal) {
                        HStack(alignment: .top, spacing: Spacing.xl) {
                            itemsView
                        }
                        grid(spacing: Spacing.lg)
                    }
                }
            }
        }
    }

    private var itemsView: some View {
        ForEach(items) { item in
            MetricItem(model: item, variant: itemVariant)
        }
    }

    private var itemVariant: MetricItemVariant {
        switch variant {
        case .inline: .inlineCompact
        case .grid: .gridCompact
        }
    }

    private func grid(spacing: CGFloat) -> some View {
        LazyVGrid(
            columns: Array(repeating: GridItem(.flexible(), spacing: spacing), count: 2),
            alignment: .leading,
            spacing: spacing
        ) {
            itemsView
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

public enum MetricGroupVariant {
    case inline
    case grid
}

#if DEBUG
#Preview("default") {
    MetricGroup(items: MetricPreviewFixtures.completeMetrics)
        .padding()
        .background(AppColors.pageBase)
}

#Preview("missingMetric") {
    MetricGroup(items: MetricPreviewFixtures.missingMetrics)
        .padding()
        .background(AppColors.pageBase)
}

#Preview("grid") {
    MetricGroup(
        items: MetricPreviewFixtures.completeMetrics,
        variant: .grid
    )
    .padding()
    .background(AppColors.pageBase)
}

#Preview("accessibility") {
    MetricGroup(items: MetricPreviewFixtures.completeMetrics)
        .padding()
        .background(AppColors.pageBase)
        .environment(\.dynamicTypeSize, .accessibility3)
}
#endif
