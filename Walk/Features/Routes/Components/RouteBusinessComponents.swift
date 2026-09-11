import SwiftUI
import WalkData
import WalkDesignSystem

enum RouteBusinessComponents {}

enum RouteVisualStyle: Equatable {
    case forest
    case ridge
    case water
}

struct RouteDeterministicImageSurface: View {
    var style: RouteVisualStyle = .forest

    var body: some View {
        ZStack {
            LinearGradient(
                colors: backgroundColors,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Image(systemName: symbolName)
                .font(.sceneTitle)
                .foregroundStyle(AppColors.interactionPrimary.opacity(0.28))
        }
        .accessibilityHidden(true)
    }

    private var backgroundColors: [Color] {
        switch style {
        case .forest:
            [AppColors.sceneForestHighlight, AppColors.sceneMountainFront]
        case .ridge:
            [AppColors.sceneNeutralHighlight, AppColors.pageMiddle]
        case .water:
            [AppColors.infoBackground, AppColors.sceneMountainMiddle]
        }
    }

    private var symbolName: String {
        switch style {
        case .forest: "tree.fill"
        case .ridge: "mountain.2.fill"
        case .water: "water.waves"
        }
    }
}

struct RouteBusinessSection<Content: View>: View {
    let title: String
    private let content: Content

    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text(title)
                .font(.sectionTitle)
                .foregroundStyle(AppColors.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)

            content
        }
        .padding(15)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColors.surfacePrimary)
        .clipShape(RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                .stroke(AppColors.borderSubtle, lineWidth: 1)
        }
    }
}

struct RouteBookmark: View {
    let title: String
    var isSelected = false

    var body: some View {
        Text(title)
            .font(.microStrong)
            .foregroundStyle(isSelected ? AppColors.pageBase : AppColors.interactionPrimary)
            .frame(width: 28, height: 34)
            .background(isSelected ? AppColors.interactionPrimary : AppColors.interactionBackground)
            .clipShape(RouteBookmarkShape())
            .accessibilityHidden(true)
    }
}

private struct RouteBookmarkShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY + Radius.sm))
        path.addQuadCurve(
            to: CGPoint(x: rect.minX + Radius.sm, y: rect.minY),
            control: CGPoint(x: rect.minX, y: rect.minY)
        )
        path.addLine(to: CGPoint(x: rect.maxX - Radius.sm, y: rect.minY))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: rect.minY + Radius.sm),
            control: CGPoint(x: rect.maxX, y: rect.minY)
        )
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY - 7))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

struct RouteWrapLayout: Layout {
    var horizontalSpacing: CGFloat = Spacing.sm
    var verticalSpacing: CGFloat = Spacing.sm

    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) -> CGSize {
        let availableWidth = proposal.width ?? .infinity
        var lineWidth: CGFloat = 0
        var lineHeight: CGFloat = 0
        var totalHeight: CGFloat = 0
        var maximumWidth: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            let nextWidth = lineWidth == 0 ? size.width : lineWidth + horizontalSpacing + size.width
            if lineWidth > 0, nextWidth > availableWidth {
                maximumWidth = max(maximumWidth, lineWidth)
                totalHeight += lineHeight + verticalSpacing
                lineWidth = size.width
                lineHeight = size.height
            } else {
                lineWidth = nextWidth
                lineHeight = max(lineHeight, size.height)
            }
        }

        maximumWidth = max(maximumWidth, lineWidth)
        totalHeight += lineHeight
        return CGSize(width: proposal.width ?? maximumWidth, height: totalHeight)
    }

    func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) {
        var origin = bounds.origin
        var lineHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if origin.x > bounds.minX, origin.x + size.width > bounds.maxX {
                origin.x = bounds.minX
                origin.y += lineHeight + verticalSpacing
                lineHeight = 0
            }
            subview.place(at: origin, proposal: ProposedViewSize(size))
            origin.x += size.width + horizontalSpacing
            lineHeight = max(lineHeight, size.height)
        }
    }
}

func routeNonEmpty(_ value: String?) -> String? {
    guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else {
        return nil
    }
    return value
}
