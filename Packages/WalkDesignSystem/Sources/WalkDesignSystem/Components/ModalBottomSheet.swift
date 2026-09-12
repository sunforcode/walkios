import SwiftUI

public struct ModalBottomSheet<Content: View>: View {
     public let onDismiss: () -> Void
    private let isCloseActionPresented: Bool
    private let content: Content

     public init(
        onDismiss: @escaping () -> Void,
        isCloseActionPresented: Bool = false,
        @ViewBuilder content: () -> Content
    ) {
        self.onDismiss = onDismiss
        self.isCloseActionPresented = isCloseActionPresented
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

    // 高度贴合内容：内容不超出可用高度时无内部滚动与弹动，超出时才回退为受限高度的卡片内滚动。
    // 注意：不能在外层套 .frame(maxHeight:)，贪婪 frame 会把 Sheet 撑到上限并留出大片空白；
    // 高度上限只施加在 ScrollView 回退分支上。
    private func sheet(maxHeight: CGFloat, bottomInset: CGFloat) -> some View {
        let shape = ModalBottomSheetShape(radius: Radius.xl)

        return VStack(spacing: Spacing.md) {
            SheetHandle()

            ViewThatFits(in: .vertical) {
                content
                    .frame(maxWidth: .infinity, alignment: .leading)

                ScrollView(.vertical, showsIndicators: false) {
                    content
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .scrollBounceBehaviorBasedOnSizeIfAvailable()
                .frame(maxHeight: maxHeight)
            }
        }
        .padding(.top, Spacing.sm)
        .padding(.horizontal, Spacing.lg)
        .padding(.bottom, Spacing.xl + bottomInset)
        .frame(maxWidth: .infinity, alignment: .bottom)
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
        .overlay(alignment: .topTrailing) {
            if isCloseActionPresented {
                closeAction
                    .padding(.top, Spacing.md)
                    .padding(.trailing, Spacing.md)
            }
        }
        .appShadow(AppShadow.overlay)
    }

    /// CloseAction：32 × 32 圆形关闭按钮，位于 Sheet 右上角。
    private var closeAction: some View {
        Button(action: onDismiss) {
            Image(systemName: "xmark")
                .font(.ornament(14, weight: .semibold))
                .foregroundStyle(AppColors.textPrimary)
                .frame(width: 32, height: 32)
                .background {
                    Circle().fill(AppColors.surfaceGlass)
                    Circle().fill(AppColors.surfaceControlOverlay)
                }
                .overlay {
                    Circle().stroke(AppColors.borderOverlay, lineWidth: 1)
                }
                .contentShape(Circle())
        }
        .accessibilityLabel("关闭")
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

private extension View {
    /// iOS 16.4 起内容贴合时禁用滚动弹动；更低版本保持系统默认。
    @ViewBuilder
    func scrollBounceBehaviorBasedOnSizeIfAvailable() -> some View {
        if #available(iOS 16.4, *) {
            scrollBounceBehavior(.basedOnSize)
        } else {
            self
        }
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

#Preview("ModalBottomSheet.closeAction") {
    ModalBottomSheet(onDismiss: {}, isCloseActionPresented: true) {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            Text("带关闭入口的底部面板")
                .font(.sectionTitle)
                .foregroundStyle(AppColors.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            Text("关闭按钮位于右上角，遮罩点击与关闭按钮为同一 dismiss 语义。")
                .font(.appBody)
                .foregroundStyle(AppColors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
    .background(AppColors.pageBase)
}
#endif
