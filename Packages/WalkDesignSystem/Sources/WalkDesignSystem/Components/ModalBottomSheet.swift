import SwiftUI

public struct ModalBottomSheet<Content: View>: View {
     public let onDismiss: () -> Void
    private let isCloseActionPresented: Bool
    private let content: Content

    @State private var dragOffset: CGFloat = 0
    @State private var isDragFollowing = false
    @State private var dragStartTime: Date?
    @State private var scrollOffset: CGFloat = 0

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
                    // 表面覆盖到屏幕底边：安全区只由内部 bottomInset 垫高内容，不在 Sheet 下方露出遮罩间距。
                    .ignoresSafeArea(edges: .bottom)
                    .offset(y: dragOffset)
                    .simultaneousGesture(dragToDismissGesture)
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
                        .background(
                            // 在滚动内容坐标系内测量偏移：0 表示内容处于顶部，负值表示已向上滚动。
                            GeometryReader { scrollProxy in
                                Color.clear.preference(
                                    key: SheetScrollOffsetKey.self,
                                    value: scrollProxy.frame(in: .named("modalBottomSheetScroll")).minY
                                )
                            }
                        )
                }
                .coordinateSpace(name: "modalBottomSheetScroll")
                .scrollBounceBehaviorBasedOnSizeIfAvailable()
                .frame(maxHeight: maxHeight)
            }
        }
        .onPreferenceChange(SheetScrollOffsetKey.self) { scrollOffset = $0 }
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

    /// 交互式下拉关闭：向下拖动跟手；仅当内容处于滚动顶部时接管手势，避免与内部滚动冲突。
    /// 松手时超过关闭距离或速度则 dismiss，否则回位到原位。
    private var dragToDismissGesture: some Gesture {
        DragGesture(minimumDistance: 10)
            .onChanged { value in
                guard value.translation.height > 0 else { return }
                // 只在内容顶部（或已开始跟随）时接管；已向上滚动的内容让位给 ScrollView。
                guard isDragFollowing || scrollOffset >= -1 else { return }
                if !isDragFollowing {
                    isDragFollowing = true
                    dragStartTime = Date()
                }
                dragOffset = value.translation.height
            }
            .onEnded { value in
                guard isDragFollowing else { return }
                isDragFollowing = false

                let elapsed = dragStartTime.map { Date().timeIntervalSince($0) } ?? 0
                let velocity = elapsed > 0 ? value.translation.height / CGFloat(elapsed) : 0
                let shouldDismiss = value.translation.height > ModalBottomSheetGesture.closeDistanceThreshold
                    || velocity > ModalBottomSheetGesture.closeVelocityThreshold

                dragStartTime = nil
                if shouldDismiss {
                    // 直接交给父层关闭动画；不回弹 offset，避免回弹与消失动画叠加造成闪烁。
                    onDismiss()
                } else {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                        dragOffset = 0
                    }
                }
            }
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

private enum ModalBottomSheetGesture {
    /// 下拉关闭阈值：拖动超过该距离，或松手速度超过该值（逻辑点/秒）即关闭。
    static let closeDistanceThreshold: CGFloat = 120
    static let closeVelocityThreshold: CGFloat = 800
}

private struct SheetScrollOffsetKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = min(value, nextValue())
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
#Preview("ModalBottomSheet.dragToDismiss") {
    struct DragToDismissDemo: View {
        @State private var isPresented = true

        var body: some View {
            ZStack {
                AppColors.pageBase.ignoresSafeArea()

                if isPresented {
                    ModalBottomSheet(onDismiss: { isPresented = false }) {
                        VStack(alignment: .leading, spacing: Spacing.lg) {
                            Text("可下拉关闭的底部面板")
                                .font(.sectionTitle)
                                .foregroundStyle(AppColors.textPrimary)

                            Text("向下拖动把手或内容：超过关闭距离或速度后关闭，未达到则回位。内容处于顶部时才接管拖动手势。")
                                .font(.appBody)
                                .foregroundStyle(AppColors.textSecondary)
                        }
                    }
                }
            }
        }
    }

    return DragToDismissDemo()
}

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
