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
        // 不自带 padding/背景/裁剪：详情页 sectionCard 已提供 Spacing.xl 内边距与卡片外观，
        // 此处再加会双重缩进（内容偏右），保留 clipShape 则圆角弧线会裁掉贴边内容。
        .frame(maxWidth: .infinity, alignment: .leading)
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
func routeNonEmpty(_ value: String?) -> String? {
    guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else {
        return nil
    }
    return value
}
