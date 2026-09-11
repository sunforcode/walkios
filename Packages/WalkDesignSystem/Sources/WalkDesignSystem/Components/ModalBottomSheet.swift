import SwiftUI

public struct ModalBottomSheet<Content: View>: View {
     public let onDismiss: () -> Void
    private let content: Content

     public init(onDismiss: @escaping () -> Void, @ViewBuilder content: () -> Content) {
        self.onDismiss = onDismiss
        self.content = content()
    }

     public var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .bottom) {
                Rectangle()
                    .fill(AppColors.surfaceModalScrim)
                    .background(AppColors.surfaceOverlay)
                    .ignoresSafeArea()
                    .contentShape(Rectangle())
                    .onTapGesture(perform: onDismiss)

                sheet(maxHeight: max(proxy.size.height - 54, 0), bottomInset: proxy.safeAreaInsets.bottom)
            }
        }
        .accessibilityAddTraits(.isModal)
    }

    private func sheet(maxHeight: CGFloat, bottomInset: CGFloat) -> some View {
        let shape = ModalBottomSheetShape(radius: Radius.xl)

        return VStack(spacing: Spacing.md) {
            SheetHandle()

            ScrollView(.vertical, showsIndicators: false) {
                content
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.top, Spacing.sm)
        .padding(.horizontal, Spacing.lg)
        .padding(.bottom, Spacing.xl + bottomInset)
        .frame(maxWidth: .infinity, maxHeight: maxHeight, alignment: .top)
        .background {
            LinearGradient(
                colors: [AppColors.surfacePrimary, AppColors.sceneMountainFront],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        .clipShape(shape)
        .contentShape(shape)
        .overlay {
            shape
                .stroke(AppColors.interactionPrimary.opacity(0.2), lineWidth: 1)
                .mask(alignment: .top) {
                    Rectangle().frame(height: 1)
                }
        }
        .appShadow(AppShadow.overlay)
    }
}

private struct ModalBottomSheetShape: Shape {
     public let radius: CGFloat

     public func path(in rect: CGRect) -> Path {
        let radius = min(radius, min(rect.width / 2, rect.height))
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + radius))
        path.addQuadCurve(
            to: CGPoint(x: rect.minX + radius, y: rect.minY),
            control: CGPoint(x: rect.minX, y: rect.minY)
        )
        path.addLine(to: CGPoint(x: rect.maxX - radius, y: rect.minY))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: rect.minY + radius),
            control: CGPoint(x: rect.maxX, y: rect.minY)
        )
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

#if DEBUG
#Preview("ModalBottomSheet.default") {
    ModalBottomSheet(onDismiss: {}) {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            Text("底部面板标题")
                .font(.sectionTitle)
                .foregroundStyle(AppColors.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            Text("这是一段用于预览的较长说明文案，用于验证底部面板在多行内容下的排版与滚动表现。")
                .font(.appBody)
                .foregroundStyle(AppColors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            PrimaryAction(title: "确认", fillsWidth: true, action: {})
        }
    }
    .background(AppColors.pageBase)
}
#endif
