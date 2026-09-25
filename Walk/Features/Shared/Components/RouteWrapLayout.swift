import SwiftUI
import WalkDesignSystem

/// 按可用宽度自动换行的横向排布。路线域与共享生成组件共用；属于布局非组件，不建立组件身份。
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
