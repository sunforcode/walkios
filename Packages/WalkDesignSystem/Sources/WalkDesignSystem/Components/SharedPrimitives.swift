import SwiftUI

// MARK: - Shared presentation variants

public enum StatePresentationVariant {
    case page
    case section
    case form
    case scene

     public var isFullPage: Bool { self == .page }
     public var alignment: HorizontalAlignment { self == .form ? .leading : .center }
     public var textAlignment: TextAlignment { self == .form ? .leading : .center }
}

// MARK: - Page shells and headers

/// 任务栈二级页唯一骨架（合同见 `docs/ui/components/common/utility-page/spec.md`）：
/// 拥有背景承载、导航行（内嵌 `UtilityNavigationHeader`）、可选标题区（`PageTitleBlock`）、
/// 内容滚动所有权与固定底部动作区（`FixedActionArea`）。
/// 页面差异仅允许通过 background / hero / title & description / bottomFixed /
/// showsBackEntry 五个插槽表达；返回控件形态、导航行结构、标题排版不可自定义。
private struct UtilityPageScrollBounceModifier: ViewModifier {
    /// 页面级滚动回弹开关：内容不超出视口时不回弹，超出的长内容仍保留系统原生边界回弹。
    let disabled: Bool

    func body(content: Content) -> some View {
        if disabled {
            content.scrollBounceBehavior(.basedOnSize)
        } else {
            content
        }
    }
}

public struct UtilityPage<Content: View>: View {
    @Environment(\.dismiss) private var dismiss

    private let title: String?
    private let description: String?
    private let showsBackEntry: Bool
    private let leading: IconButtonConfiguration?
    private let trailing: IconButtonConfiguration?
    private let onBack: (() -> Void)?
    private let background: AnyView?
    private let hero: AnyView?
    private let bottomFixed: AnyView?
    private let disablesScrollBounce: Bool
    private let content: Content

    public init(
        title: String? = nil,
        description: String? = nil,
        showsBackEntry: Bool = true,
        leading: IconButtonConfiguration? = nil,
        trailing: IconButtonConfiguration? = nil,
        onBack: (() -> Void)? = nil,
        disablesScrollBounce: Bool = false,
        @ViewBuilder background: () -> some View = { EmptyView() },
        @ViewBuilder hero: () -> some View = { EmptyView() },
        @ViewBuilder bottomFixed: () -> some View = { EmptyView() },
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.description = description
        self.showsBackEntry = showsBackEntry
        self.leading = leading
        self.trailing = trailing
        self.onBack = onBack
        self.disablesScrollBounce = disablesScrollBounce

        let resolvedBackground = background()
        self.background = Self.isEmptySlot(resolvedBackground) ? nil : AnyView(resolvedBackground)

        let resolvedHero = hero()
        self.hero = Self.isEmptySlot(resolvedHero) ? nil : AnyView(resolvedHero)

        let resolvedBottomFixed = bottomFixed()
        self.bottomFixed = Self.isEmptySlot(resolvedBottomFixed) ? nil : AnyView(resolvedBottomFixed)

        self.content = content()
    }

    /// ViewBuilder 的条件分支（`if` 无 else）在条件为假时产出 `.none` Optional
    /// 而非 `EmptyView`，需一并视为空插槽，避免空插槽仍渲染占位容器。
    private static func isEmptySlot(_ view: some View) -> Bool {
        if view is EmptyView { return true }
        let mirror = Mirror(reflecting: view)
        return mirror.displayStyle == .optional && mirror.children.isEmpty
    }

    /// 返回入口可见性由到达方式决定（`app-flow`）；缺省动作为任务栈 dismiss。
    private var resolvedLeading: IconButtonConfiguration? {
        guard showsBackEntry else { return nil }
        if let leading { return leading }
        return IconButtonConfiguration(
            systemName: "chevron.left",
            accessibilityLabel: "返回",
            action: {
                if let onBack {
                    onBack()
                } else {
                    dismiss()
                }
            }
        )
    }

    private var navRow: some View {
        UtilityNavigationHeader(
            leading: resolvedLeading,
            trailing: trailing
        )
    }

    /// 标题区随内容滚动，置于导航行下方；`title` 为空时标题由 hero 承载且全页唯一。
    /// - Parameter topContentMargin: 滚动内容顶部留白——非 hero 页让出悬浮导航行高度；
    ///   留白必须加在滚动内容上，不能加在 ScrollView 外，否则视口整体下移、
    ///   退化为导航行独占布局，滚动内容无法从导航行下方穿过。
    private func scrollArea(topContentMargin: CGFloat) -> some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                if let title {
                    PageTitleBlock(title: title, description: description)
                }
                content
            }
            .frame(maxWidth: 600, alignment: .topLeading)
            .frame(maxWidth: .infinity, alignment: .top)
            .padding(.horizontal, Spacing.pageHorizontal)
            .padding(.top, Spacing.md + topContentMargin)
            .padding(.bottom, Spacing.xxl)
        }
        // 滚动所有权归壳：键盘随滚动交互收起对全部二级页统一生效。
        .scrollDismissesKeyboard(.interactively)
        .modifier(UtilityPageScrollBounceModifier(disabled: disablesScrollBounce))
    }

    public var body: some View {
        UtilityPageContainer(background: { resolvedBackground }) {
            // 导航行统一悬浮于内容之上：内容滚动时从导航行下方穿过；
            // hero 沉浸页由 hero 占据顶部，标准页经内容留白自导航行下方起始。
            ZStack(alignment: .top) {
                if let hero {
                    VStack(spacing: 0) {
                        hero
                        scrollArea(topContentMargin: 0)
                    }
                } else {
                    scrollArea(topContentMargin: Spacing.navBarHeight)
                }
                if let hero {
                    navRow
                } else {
                    navRow
                        .background {
                            // 悬浮导航行可读性遮罩：状态栏与导航行区域实色、向下渐隐，
                            // 内容滚过时按钮不与正文混叠；hero 封面页保持透明悬浮。
                            LinearGradient(
                                stops: [
                                    .init(color: AppColors.pageBase, location: 0),
                                    .init(color: AppColors.pageBase, location: 0.55),
                                    .init(color: AppColors.pageBase.opacity(0), location: 1),
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                            .ignoresSafeArea(edges: .top)
                            .allowsHitTesting(false)
                        }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if let bottomFixed {
                    FixedActionArea { bottomFixed }
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .toolbar(.hidden, for: .tabBar)
        }
    }

    @ViewBuilder
    private var resolvedBackground: some View {
        if let background {
            background
        } else {
            LinearGradient(
                colors: [AppColors.pageMiddle, AppColors.pageBase],
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }
}

public struct PageTitleBlock<Trailing: View>: View {
     public let title: String
     public var kicker: String? = nil
     public var description: String? = nil
     private let trailing: Trailing

    public init(
        title: String,
        kicker: String? = nil,
        description: String? = nil,
        @ViewBuilder trailing: () -> Trailing = { EmptyView() }
    ) {
        self.title = title
        self.kicker = kicker
        self.description = description
        self.trailing = trailing()
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let kicker {
                Text(kicker)
                    .font(.appCaption)
                    .foregroundStyle(AppColors.interactionPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.bottom, Spacing.sm)
            }

            HStack(alignment: .center, spacing: Spacing.md) {
                Text(title)
                    .font(.pageTitle)
                    .foregroundStyle(AppColors.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                    // 标题行自带 44pt 触控目标高度：trailing 控件不反向决定页头高度，
                    // 四个一级根 Page 的标题与副标题起始位置保持一致。
                    .frame(minHeight: 44, alignment: .leading)
                    .accessibilityAddTraits(.isHeader)

                Spacer(minLength: Spacing.md)

                trailing
            }

            if let description {
                Text(description)
                    .font(.appBody)
                    .foregroundStyle(AppColors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, Spacing.sm)
            }
        }
        .padding(.bottom, Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

public struct UtilityPageContainer<Background: View, Content: View>: View {
    private let background: Background
    private let content: Content

    public init(
        @ViewBuilder background: () -> Background,
        @ViewBuilder content: () -> Content
    ) {
        self.background = background()
        self.content = content()
    }

    public var body: some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            // 背景用 .background 垫底，不参与布局：内容始终在安全区内排布，
            // 背景自身再延伸出安全区。
            .background {
                background
                    .ignoresSafeArea()
            }
            .foregroundStyle(AppColors.textPrimary)
    }
}

/// 一级根 Page 统一页面骨架：背景固定 + 标题在流内 + 内容自然滚动。
/// 背景经 `.background` 垫底，不参与布局：内容始终在安全区内排布，
/// 背景自身再延伸出安全区；自然尺寸不受控的背景（如位图）不会撑爆容器。
/// `PageTitleBlock` 在滚动内容顶部左下，跟随内容一起滚动；
/// 内容区由调用者自行决定布局（沉底信息块、列表、全屏卡片均可）。
public struct PageShell<Background: View, Content: View, TitleTrailing: View>: View {
    private let title: String
    private let description: String?
    private let background: Background
    private let content: Content
    private let titleTrailing: TitleTrailing

    @State private var pinnedSafeAreaInsets = EdgeInsets()

    public init(
        title: String,
        description: String? = nil,
        @ViewBuilder background: () -> Background,
        @ViewBuilder titleTrailing: () -> TitleTrailing = { EmptyView() },
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.description = description
        self.background = background()
        self.titleTrailing = titleTrailing()
        self.content = content()
    }

    public var body: some View {
        // 外层保留系统安全区，取得 Tab 容器实际要求的底部避让。
        // UIWindow 的 bottom 只含屏幕安全区，不包含系统 Tab 栏高度。
        GeometryReader { proxy in
            VStack(alignment: .leading, spacing: 0) {
                PageTitleBlock(title: title, description: description, trailing: { titleTrailing })
                    .padding(.top, pinnedSafeAreaInsets.top)
                    .padding(.horizontal, Spacing.pageHorizontal)
                    .padding(.bottom, Spacing.lg)

                content
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(.bottom, max(pinnedSafeAreaInsets.bottom, proxy.safeAreaInsets.bottom))
            // 顶部仍使用固定窗口 inset，避免 push/pop 导航栏造成的安全区尖峰；
            // 底部跟随当前系统容器，让固定操作区和内容共同避开 Tab 栏。
            .ignoresSafeArea()
        }
        .background {
            background
                .ignoresSafeArea()
        }
        .foregroundStyle(AppColors.textPrimary)
        // 窗口安全区常量在视图挂载后解析：视图 init / body 求值事务内读
        // UIWindow 会在 iOS 26 触发 AttributeGraph 循环锁死更新管道。
        // 首帧以零 inset 布局（push 首帧在屏幕外，用户不可见），onAppear 后
        // 一次性修正为常量；State 保留使后续转场不再重算。
        .onAppear {
            if pinnedSafeAreaInsets == EdgeInsets() {
                pinnedSafeAreaInsets = PinnedWindowSafeAreaInsets.current
            }
        }
    }

    /// 首次布局时的窗口安全区。只取窗口级 inset（状态栏/主屏幕指示器），键盘等
    /// SwiftUI 动态 inset 不在此列，不会影响根页面布局。
    /// 实现共享于 `PinnedWindowSafeAreaInsets`。
    private static var windowSafeAreaInsets: EdgeInsets { PinnedWindowSafeAreaInsets.current }
}

/// 固定窗口安全区常量：push/pop 转场期间系统会临时插回导航栏高度，动态安全区
/// 尖峰（实测 62→168→116）会把顶部锚定内容顶跳。根页面的窗口安全区在运行期
/// 恒定（竖屏 iPhone），根容器在首次布局取一次常量后不再跟随动态安全区变化。
/// 只取窗口级 inset（状态栏/tab 栏）；键盘等 SwiftUI 动态 inset 不在此列。
/// 读值只能在视图生命周期回调（onAppear/task）中调用，严禁在视图 init 或
/// body 求值事务中调用：iOS 26 上在 SwiftUI 更新事务内访问 UIWindow 层级
/// 会触发 AttributeGraph 循环，锁死整个更新管道（实测 @State mutation
/// 不再触发任何视图重算）。
public enum PinnedWindowSafeAreaInsets {
    public static var current: EdgeInsets {
        let insets = UIApplication.shared.connectedScenes
            .compactMap { ($0 as? UIWindowScene)?.keyWindow }
            .first?
            .safeAreaInsets ?? .zero
        return EdgeInsets(top: insets.top, leading: insets.left, bottom: insets.bottom, trailing: insets.right)
    }
}

extension UtilityPageContainer where Background == LinearGradient {
    public init(@ViewBuilder content: () -> Content) {
        self.init(
            background: {
                LinearGradient(
                    colors: [AppColors.pageMiddle, AppColors.pageBase],
                    startPoint: .top,
                    endPoint: .bottom
                )
            },
            content: content
        )
    }
}

private struct ImmersiveBottomContentPaddingKey: EnvironmentKey {
    static let defaultValue: CGFloat = 0
}

private extension EnvironmentValues {
    var immersiveBottomContentPadding: CGFloat {
        get { self[ImmersiveBottomContentPaddingKey.self] }
        set { self[ImmersiveBottomContentPaddingKey.self] = newValue }
    }
}

private struct ImmersiveBottomContentPaddingModifier: ViewModifier {
    @Environment(\.immersiveBottomContentPadding) private var systemAreaPadding
    let base: CGFloat

    func body(content: Content) -> some View {
        content.padding(.bottom, base + systemAreaPadding)
    }
}

public extension View {
    /// 在尚未忽略安全区的页面根部读取系统区域，并以语义化环境值下发给沉浸式内容。
    func immersiveSystemAreaContext() -> some View {
        GeometryReader { proxy in
            self.environment(\.immersiveBottomContentPadding, proxy.safeAreaInsets.bottom)
        }
    }

    /// 为沉浸式页面底部内容叠加系统区域避让；Feature 不接触物理 inset。
    func immersiveBottomContentPadding(_ base: CGFloat = 0) -> some View {
        modifier(ImmersiveBottomContentPaddingModifier(base: base))
    }
}

public struct ImmersivePageContainer<Content: View>: View {
    private let content: Content

    public init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    public var body: some View {
        ZStack {
            RadialGradient(
                colors: [AppColors.pageOuter, AppColors.pageMiddle, AppColors.pageBase],
                center: .top,
                startRadius: 0,
                endRadius: 700
            )
            .ignoresSafeArea()

            content
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .foregroundStyle(AppColors.textPrimary)
    }
}

// MARK: - Buttons

public enum IconButtonVariant {
    case `default`
    case overlay
    case compactClose

     public var iconSize: CGFloat { self == .default ? 24 : 20 }
     public var usesOverlaySurface: Bool { self != .default }
}

public struct IconButton: View {
     public let systemName: String
     public let accessibilityLabel: String
     public var variant: IconButtonVariant = .default
     public var isDisabled = false
     public let action: () -> Void

     public var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.ornament(variant.iconSize, weight: .semibold))
                .foregroundStyle(AppColors.textPrimary)
                .frame(width: 44, height: 44)
                .background {
                    if variant.usesOverlaySurface {
                    Circle().fill(AppColors.surfaceGlass)
                    Circle().fill(AppColors.surfaceControlOverlay)
                    }
                }
                .overlay {
                    if variant.usesOverlaySurface {
                        Circle().stroke(AppColors.borderOverlay, lineWidth: 1)
                    }
                }
                .contentShape(Rectangle())
        }
        .appShadow(variant.usesOverlaySurface ? AppShadow.floating : ShadowToken(opacity: 0, radius: 0, x: 0, y: 0))
        .buttonStyle(WalkPressButtonStyle())
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.45 : 1)
        .accessibilityLabel(accessibilityLabel)
    }

    public init(
        systemName: String,
        accessibilityLabel: String,
        variant: IconButtonVariant = .default,
        isDisabled: Bool = false,
        action: @escaping () -> Void
    ) {
        self.systemName = systemName
        self.accessibilityLabel = accessibilityLabel
        self.variant = variant
        self.isDisabled = isDisabled
        self.action = action
    }
}

private struct WalkPressButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

     public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.985 : 1)
            .opacity(configuration.isPressed ? 0.88 : 1)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

public enum PrimaryActionVariant {
    case `default`
    case compact
}

public struct PrimaryAction: View {
     public let title: String
     public var systemImage: String? = nil
     public var variant: PrimaryActionVariant = .default
     public var isLoading = false
     public var isDisabled = false
     public var fillsWidth = false
     public let action: () -> Void

     public var body: some View {
        Button(action: action) {
            HStack(spacing: Spacing.sm) {
                if isLoading {
                    ProgressView()
                        .tint(AppColors.pageBase)
                } else if let systemImage {
                    Image(systemName: systemImage)
                        .font(variant == .compact ? .dateTitle : .contextTitle)
                }

                Text(title)
                    .font(.action)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .foregroundStyle(AppColors.interactionOnPrimary)
            .padding(.horizontal, variant == .compact ? 22 : Spacing.lg)
            .padding(.vertical, variant == .compact ? 13 : 14)
            .frame(maxWidth: fillsWidth ? .infinity : nil)
            .frame(minHeight: variant == .compact ? 44 : 48)
            .background(AppColors.interactionPrimary)
            .clipShape(RoundedRectangle(cornerRadius: variant == .compact ? Radius.full : Radius.md, style: .continuous))
            .appShadow(variant == .compact ? AppShadow.compactAction : ShadowToken(opacity: 0, radius: 0, x: 0, y: 0))
        }
        .buttonStyle(WalkPressButtonStyle())
        .disabled(isDisabled || isLoading)
        .opacity(isDisabled ? 0.62 : 1)
        .accessibilityValue(isLoading ? "进行中" : "")
    }

    public init(
        title: String,
        systemImage: String? = nil,
        variant: PrimaryActionVariant = .default,
        isLoading: Bool = false,
        isDisabled: Bool = false,
        fillsWidth: Bool = false,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.systemImage = systemImage
        self.variant = variant
        self.isLoading = isLoading
        self.isDisabled = isDisabled
        self.fillsWidth = fillsWidth
        self.action = action
    }
}

public enum SecondaryActionVariant {
    case `default`
    case inline
    case overlayCompact

     public var horizontalPadding: CGFloat {
        switch self {
        case .default: Spacing.lg
        case .inline, .overlayCompact: Spacing.md
        }
    }

     public var verticalPadding: CGFloat {
        switch self {
        case .default: Spacing.md
        case .inline, .overlayCompact: Spacing.sm
        }
    }
}

public struct SecondaryAction: View {
     public let title: String
     public var systemImage: String? = nil
     public var variant: SecondaryActionVariant = .default
     public var isLoading = false
     public var isDisabled = false
     public var fillsWidth = false
     public let action: () -> Void

     public var body: some View {
        Button(action: action) {
            HStack(spacing: Spacing.sm) {
                if isLoading {
                    ProgressView().tint(foregroundColor)
                } else if let systemImage {
                    Image(systemName: systemImage)
                        .font(.dateTitle)
                }
                Text(title)
                    .font(titleFont)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .foregroundStyle(foregroundColor)
            .padding(.horizontal, variant.horizontalPadding)
            .padding(.vertical, variant.verticalPadding)
            .frame(maxWidth: fillsWidth ? .infinity : nil)
            .frame(minHeight: 44)
            .background {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(backgroundColor)
                if variant == .overlayCompact {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(AppColors.surfaceGlass)
                        .opacity(0.24)
                }
            }
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(borderColor, lineWidth: borderWidth)
            }
        }
        .buttonStyle(WalkPressButtonStyle())
        .disabled(isDisabled || isLoading)
        .opacity(isDisabled ? 0.62 : 1)
        .accessibilityValue(isLoading ? "进行中" : "")
    }

    private var foregroundColor: Color {
        variant == .overlayCompact ? AppColors.textPrimary : AppColors.interactionPrimary
    }

    private var backgroundColor: Color {
        switch variant {
        case .default: AppColors.surfacePrimary
        case .inline: AppColors.surfaceSubtle
        case .overlayCompact: AppColors.surfaceControlOverlay
        }
    }

    private var borderColor: Color {
        switch variant {
        case .default: AppColors.borderPrimary
        case .inline: AppColors.borderSubtle
        case .overlayCompact: AppColors.borderOverlay
        }
    }

    private var borderWidth: CGFloat { 1 }

    private var cornerRadius: CGFloat {
        variant == .overlayCompact ? Radius.full : Radius.md
    }

    private var titleFont: Font {
        switch variant {
        case .default: .action
        case .inline: .label
        case .overlayCompact: .tag
        }
    }

    public init(
        title: String,
        systemImage: String? = nil,
        variant: SecondaryActionVariant = .default,
        isLoading: Bool = false,
        isDisabled: Bool = false,
        fillsWidth: Bool = false,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.systemImage = systemImage
        self.variant = variant
        self.isLoading = isLoading
        self.isDisabled = isDisabled
        self.fillsWidth = fillsWidth
        self.action = action
    }
}

public struct DangerAction: View {
     public let title: String
     public var systemImage: String? = nil
     public var isLoading = false
     public var isDisabled = false
     public var fillsWidth = false
     public let action: () -> Void

     public var body: some View {
        Button(action: action) {
            HStack(spacing: Spacing.sm) {
                if isLoading {
                    ProgressView().tint(AppColors.danger)
                } else if let systemImage {
                    Image(systemName: systemImage)
                        .font(.dateTitle)
                }
                Text(title)
                    .font(.action)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .foregroundStyle(AppColors.danger)
            .padding(.horizontal, Spacing.lg)
            .padding(.vertical, Spacing.md)
            .frame(maxWidth: fillsWidth ? .infinity : nil)
            .frame(minHeight: 48)
            .background(AppColors.dangerBackground)
            .clipShape(RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                    .stroke(AppColors.dangerBorder, lineWidth: 1)
            }
        }
        .buttonStyle(WalkPressButtonStyle())
        .disabled(isDisabled || isLoading)
        .opacity(isDisabled ? 0.58 : 1)
        .accessibilityValue(isLoading ? "进行中" : "")
    }

    public init(
        title: String,
        systemImage: String? = nil,
        isLoading: Bool = false,
        isDisabled: Bool = false,
        fillsWidth: Bool = false,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.systemImage = systemImage
        self.isLoading = isLoading
        self.isDisabled = isDisabled
        self.fillsWidth = fillsWidth
        self.action = action
    }
}

// MARK: - Panels, cards, and sections

public enum WalkPanelVariant {
    case `default`
    case glass
    case edgeAttached
    case section
    case bottomOverlay

    fileprivate var backgroundColor: Color {
        switch self {
        case .default, .section, .edgeAttached, .bottomOverlay: AppColors.surfacePrimary
        case .glass: AppColors.surfacePanelGlass
        }
    }

    fileprivate var insets: EdgeInsets {
        switch self {
        case .default, .glass, .section:
            EdgeInsets(top: Spacing.lg, leading: Spacing.lg, bottom: Spacing.lg, trailing: Spacing.lg)
        case .edgeAttached:
            EdgeInsets(top: Spacing.md, leading: Spacing.lg, bottom: Spacing.lg, trailing: Spacing.lg)
        case .bottomOverlay:
            EdgeInsets(top: Spacing.md, leading: 20, bottom: 20, trailing: 20)
        }
    }

    fileprivate var topRadius: CGFloat {
        switch self {
        case .default, .section: Radius.lg
        case .glass, .edgeAttached, .bottomOverlay: Radius.xl
        }
    }

    fileprivate var bottomRadius: CGFloat {
        switch self {
        case .edgeAttached, .bottomOverlay: Radius.none
        case .default, .section: Radius.lg
        case .glass: Radius.xl
        }
    }

    fileprivate var shadow: ShadowToken? {
        switch self {
        case .default, .section, .edgeAttached: nil
        case .glass: AppShadow.panel
        case .bottomOverlay: AppShadow.navigation
        }
    }
}

public enum WalkPanelSurface {
    case primary
    case glass

     public var color: Color {
        switch self {
        case .primary: AppColors.surfacePrimary
        case .glass: AppColors.surfacePanelGlass
        }
    }
}

public struct WalkPanel<Content: View>: View {
    private let variant: WalkPanelVariant
    private let surface: WalkPanelSurface
    private let content: Content

     public init(variant: WalkPanelVariant = .default, @ViewBuilder content: () -> Content) {
        self.variant = variant
        self.surface = variant == .glass ? .glass : .primary
        self.content = content()
    }

     public init(surface: WalkPanelSurface = .primary, @ViewBuilder content: () -> Content) {
        self.variant = surface == .glass ? .glass : .default
        self.surface = surface
        self.content = content()
    }

    @ViewBuilder
     public var body: some View {
        panelBody
    }

    private var panelBody: some View {
        let shape = WalkPanelShape(topRadius: variant.topRadius, bottomRadius: variant.bottomRadius)
        return content
            .padding(Spacing.lg)
            .background(surface.color)
            .appShadow(AppShadow.panel)
            .background {
                if variant == .glass {
                    shape.fill(AppColors.surfaceGlass)
                    shape.fill(variant.backgroundColor)
                } else {
                    shape.fill(variant.backgroundColor)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
            .overlay {
                switch variant {
                case .edgeAttached:
                    shape.stroke(AppColors.borderSubtle, lineWidth: 1)
                        .mask(alignment: .top) {
                            Rectangle().frame(height: 1)
                        }
                case .glass:
                    shape.stroke(AppColors.interactionPrimary.opacity(0.16), lineWidth: 1)
                case .default, .section:
                    shape.stroke(AppColors.borderSubtle, lineWidth: 1)
                case .bottomOverlay:
                    shape.stroke(AppColors.borderSubtle, lineWidth: 1)
                        .mask(alignment: .top) {
                            Rectangle().frame(height: 1)
                        }
                }
            }
    }
}

private struct WalkPanelShape: Shape {
     public let topRadius: CGFloat
     public let bottomRadius: CGFloat

     public func path(in rect: CGRect) -> Path {
        let top = min(topRadius, min(rect.width, rect.height) / 2)
        let bottom = min(bottomRadius, min(rect.width, rect.height) / 2)
        var path = Path()
        path.move(to: CGPoint(x: rect.minX + top, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - top, y: rect.minY))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: rect.minY + top),
            control: CGPoint(x: rect.maxX, y: rect.minY)
        )
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - bottom))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX - bottom, y: rect.maxY),
            control: CGPoint(x: rect.maxX, y: rect.maxY)
        )
        path.addLine(to: CGPoint(x: rect.minX + bottom, y: rect.maxY))
        path.addQuadCurve(
            to: CGPoint(x: rect.minX, y: rect.maxY - bottom),
            control: CGPoint(x: rect.minX, y: rect.maxY)
        )
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + top))
        path.addQuadCurve(
            to: CGPoint(x: rect.minX + top, y: rect.minY),
            control: CGPoint(x: rect.minX, y: rect.minY)
        )
        path.closeSubpath()
        return path
    }
}

public enum WalkCardVariant {
    case `default`
    case compact
    case selectable

    fileprivate var radius: CGFloat {
        switch self {
        case .default, .selectable: Radius.lg
        case .compact: Radius.md
        }
    }

    fileprivate var padding: CGFloat {
        switch self {
        case .default, .selectable: Spacing.lg
        case .compact: Spacing.md
        }
    }
}

public struct WalkCard<Content: View>: View {
     public var variant: WalkCardVariant = .default
     public var isSelected = false
    private let content: Content

     public init(
        variant: WalkCardVariant = .default,
        isSelected: Bool = false,
        @ViewBuilder content: () -> Content
    ) {
        self.variant = variant
        self.isSelected = isSelected
        self.content = content()
    }

     public var body: some View {
        let shape = RoundedRectangle(cornerRadius: variant.radius, style: .continuous)
        content
            .padding(variant.padding)
            .background(AppColors.surfacePrimary)
            .clipShape(shape)
            .overlay {
                shape.stroke(
                    isSelected && variant == .selectable ? AppColors.interactionPrimary : AppColors.borderSubtle,
                    lineWidth: 1
                )
            }
    }
}

public struct SelectableOptionCard<Content: View>: View {
     public let isSelected: Bool
     public var isEnabled = true
     public let action: () -> Void
    private let content: Content

     public init(
        isSelected: Bool,
        isEnabled: Bool = true,
        action: @escaping () -> Void,
        @ViewBuilder content: () -> Content
    ) {
        self.isSelected = isSelected
        self.isEnabled = isEnabled
        self.action = action
        self.content = content()
    }

     public var body: some View {
        Button(action: action) {
            WalkCard(variant: .selectable, isSelected: isSelected) {
                content
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .buttonStyle(WalkPressButtonStyle())
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.45)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

public struct SectionHeader: View {
     public let title: String
     public var subtitle: String? = nil
    private let trailing: AnyView?

     public init(title: String, subtitle: String? = nil) {
        self.title = title
        self.subtitle = subtitle
        self.trailing = nil
    }

    public init<Trailing: View>(
        title: String,
        subtitle: String? = nil,
        @ViewBuilder trailing: () -> Trailing
    ) {
        self.title = title
        self.subtitle = subtitle
        self.trailing = AnyView(trailing())
    }

     public var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: Spacing.md) {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(title)
                    .font(.sectionTitle)
                    .foregroundStyle(AppColors.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
                if let subtitle {
                    Text(subtitle)
                        .font(.appCaption)
                        .foregroundStyle(AppColors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if let trailing {
                trailing
            }
        }
    }
}

public struct SheetHandle: View {
    public init() {}

     public var body: some View {
        Capsule()
            .fill(AppColors.surfaceHandle)
            .frame(width: 40, height: 4)
            .frame(maxWidth: .infinity)
            .accessibilityHidden(true)
    }
}

public struct FixedActionArea<Content: View>: View {
    private let content: Content

     public init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

     public var body: some View {
        VStack(spacing: 0) {
            LinearGradient(
                colors: [AppColors.pageBase.opacity(0), AppColors.pageBase],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: Spacing.xl)

            content
                .padding(.horizontal, Spacing.pageHorizontal)
                .padding(.top, Spacing.md)
                .padding(.bottom, Spacing.lg)
                .frame(maxWidth: .infinity)
                .background(AppColors.pageBase)
        }
    }
}

// MARK: - Rows

public enum ListRowVariant {
    case standalone
    case grouped
}

public struct ListRow<Content: View>: View {
     public var variant: ListRowVariant = .standalone
     public var showsDivider = false
     public var action: (() -> Void)? = nil
    private let content: Content

     public init(
        variant: ListRowVariant = .standalone,
        showsDivider: Bool = false,
        action: (() -> Void)? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.variant = variant
        self.showsDivider = showsDivider
        self.action = action
        self.content = content()
    }

    @ViewBuilder
     public var body: some View {
        if let action {
            Button(action: action) {
                rowContent
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .combine)
        } else {
            rowContent
                .accessibilityElement(children: .combine)
        }
    }

    private var rowContent: some View {
        content
            .padding(.vertical, Spacing.md)
            .frame(maxWidth: .infinity, minHeight: 56, alignment: .leading)
            .background(AppColors.surfacePrimary.opacity(0))
            .overlay(alignment: .bottom) {
                if showsDivider {
                    Rectangle()
                        .fill(AppColors.surfaceDivider)
                        .frame(height: 1)
                }
            }
    }
}

// MARK: - Form controls

public struct SegmentedControlOption<Value: Hashable>: Identifiable {
     public let value: Value
     public let title: String
     public var id: Value { value }

    public init(
        value: Value,
        title: String
    ) {
        self.value = value
        self.title = title
    }
}

public struct SegmentedControl<Value: Hashable>: View {
     public let options: [SegmentedControlOption<Value>]
    @Binding var selection: Value

     public var body: some View {
        HStack(spacing: Spacing.xs) {
            ForEach(options) { option in
                Button {
                    selection = option.value
                } label: {
                    Text(option.title)
                        .font(.action)
                        .foregroundStyle(selection == option.value ? AppColors.interactionPrimary : AppColors.textWeak)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, minHeight: 42)
                        .background(
                            selection == option.value ? AppColors.interactionBackground : AppColors.surfacePrimary.opacity(0),
                            in: RoundedRectangle(cornerRadius: Radius.sm, style: .continuous)
                        )
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selection == option.value ? .isSelected : [])
            }
        }
        .padding(Spacing.xs)
        .background(AppColors.surfacePrimary)
        .clipShape(RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                .stroke(AppColors.borderSubtle, lineWidth: 1)
        }
    }

    public init(
        options: [SegmentedControlOption<Value>],
        selection: Binding<Value>
    ) {
        self.options = options
        self._selection = selection
    }
}

// MARK: - Status and information

public enum InfoTagTone {
    case info
    case warning
    case neutral
    case overlay

     public var foregroundColor: Color {
        switch self {
        case .info: AppColors.info
        case .warning: AppColors.warning
        case .neutral: AppColors.textSecondary
        case .overlay: AppColors.textPrimary
        }
    }

     public var backgroundColor: Color {
        switch self {
        case .info: AppColors.infoBackground
        case .warning: AppColors.warningBackground
        case .neutral: AppColors.surfaceElevated
        case .overlay: AppColors.surfaceControlOverlay
        }
    }
}

public struct InfoTag: View {
     public let title: String
     public var systemImage: String? = nil
     public var tone: InfoTagTone = .neutral

     public var body: some View {
        Group {
            if let systemImage {
                Label(title, systemImage: systemImage)
            } else {
                Text(title)
            }
        }
        .font(.tag)
        .foregroundStyle(tone.foregroundColor)
        .fixedSize(horizontal: false, vertical: true)
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm)
        .background(tone.backgroundColor, in: Capsule())
        .overlay {
            if tone == .overlay {
                Capsule().stroke(AppColors.borderOverlay, lineWidth: 1)
            }
        }
    }

    public init(
        title: String,
        systemImage: String? = nil,
        tone: InfoTagTone = .neutral
    ) {
        self.title = title
        self.systemImage = systemImage
        self.tone = tone
    }
}

public enum NoticeTone {
    case info
    case warning
    case stale
    case danger
    case readonly

     public var foregroundColor: Color {
        switch self {
        case .info: AppColors.interactionPrimary
        case .warning, .stale: AppColors.warning
        case .danger: AppColors.danger
        case .readonly: AppColors.textSecondary
        }
    }

     public var backgroundColor: Color {
        switch self {
        case .info: AppColors.interactionBackground
        case .warning, .stale: AppColors.warningBackground
        case .danger: AppColors.dangerBackground
        case .readonly: AppColors.surfaceElevated
        }
    }

     public var borderColor: Color {
        switch self {
        case .info: AppColors.interactionPrimary.opacity(0.18)
        case .warning, .stale: AppColors.warning.opacity(0.25)
        case .danger: AppColors.dangerBorder
        case .readonly: AppColors.borderSubtle
        }
    }
}

public enum NoticePresentation {
    case standard
    case inline
}

public struct NoticeView: View {
     public let message: String
     public var title: String? = nil
     public var icon: String = "info.circle"
     public var tone: NoticeTone = .info
     public var variant: StatePresentationVariant = .section
     public var presentation: NoticePresentation = .standard

     public var body: some View {
        statusContainer {
            if presentation == .inline {
                noticeContent
                    .accessibilityElement(children: .combine)
            } else {
                noticeContent
                    .padding(Spacing.md)
                    .background(tone.backgroundColor, in: RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                            .stroke(tone.borderColor, lineWidth: 1)
                    }
                    .accessibilityElement(children: .combine)
            }
        }
    }

    private var noticeContent: some View {
        HStack(alignment: .top, spacing: Spacing.sm) {
            Image(systemName: icon)
                .font(.ornament(13, weight: .semibold))
                .foregroundStyle(tone.foregroundColor)
                .frame(width: 22, height: 22)
                .background {
                    if presentation == .standard {
                        Circle().fill(AppColors.surfaceSubtle)
                    }
                }
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: Spacing.xs) {
                if let title {
                    Text(title)
                        .font(.listTitle)
                        .foregroundStyle(tone == .info || tone == .readonly ? AppColors.textPrimary : tone.foregroundColor)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Text(message)
                    .font(.appCaption)
                    .foregroundStyle(AppColors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder
    private func statusContainer<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        if variant.isFullPage {
            UtilityPageContainer {
                content()
                    .frame(maxWidth: 600)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(Spacing.xl)
            }
        } else {
            content()
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    public init(
        message: String,
        title: String? = nil,
        icon: String = "info.circle",
        tone: NoticeTone = .info,
        variant: StatePresentationVariant = .section,
        presentation: NoticePresentation = .standard
    ) {
        self.message = message
        self.title = title
        self.icon = icon
        self.tone = tone
        self.variant = variant
        self.presentation = presentation
    }
}

#if DEBUG
#Preview("Notice.inline") {
    NoticeView(
        message: ComponentPreviewFixtures.longSupportingText,
        title: "出发前核验",
        icon: "exclamationmark.triangle",
        tone: .warning,
        presentation: .inline
    )
    .padding(Spacing.lg)
    .frame(width: 320)
    .background(AppColors.pageBase)
}
#endif

public enum UnavailableStateVariant {
    case inline
    case block
}

public struct UnavailableStateView: View {
     public let title: String
     public var message: String? = nil
     public var icon: String? = "exclamationmark.circle"
     public var actionTitle: String? = nil
     public var action: (() -> Void)? = nil
     public var variant: UnavailableStateVariant = .inline

     public init(
        title: String,
        message: String? = nil,
        icon: String? = "exclamationmark.circle",
        actionTitle: String? = nil,
        action: (() -> Void)? = nil,
        variant: UnavailableStateVariant = .inline
    ) {
        self.title = title
        self.message = message
        self.icon = icon
        self.actionTitle = actionTitle
        self.action = action
        self.variant = variant
    }

     public init(
        title: String,
        message: String? = nil,
        icon: String? = "exclamationmark.circle",
        actionTitle: String? = nil,
        action: (() -> Void)? = nil,
        variant: StatePresentationVariant
    ) {
        self.init(
            title: title,
            message: message,
            icon: icon,
            actionTitle: actionTitle,
            action: action,
            variant: variant == .section || variant == .form ? .block : .inline
        )
    }

     public var body: some View {
        Group {
            if variant == .inline {
                HStack(alignment: .top, spacing: Spacing.sm) {
                    stateIcon
                    stateCopy
                }
            } else {
                VStack(alignment: .leading, spacing: Spacing.md) {
                    HStack(alignment: .top, spacing: Spacing.sm) {
                        stateIcon
                        stateCopy
                    }
                    if let actionTitle, let action {
                        SecondaryAction(title: actionTitle, variant: .inline, action: action)
                    }
                }
                .padding(Spacing.md)
                .background(AppColors.warningBackground, in: RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                        .stroke(AppColors.warning.opacity(0.25), lineWidth: 1)
                }
            }
        }
        .frame(maxWidth: variant == .block ? .infinity : nil, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var stateIcon: some View {
        if let icon {
            Image(systemName: icon)
                .font(.dateTitle)
                .foregroundStyle(AppColors.warning)
                .frame(width: 20, height: 20)
                .accessibilityHidden(true)
        }
    }

    private var stateCopy: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text(title)
                .font(.label)
                .foregroundStyle(AppColors.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
            if let message {
                Text(message)
                    .font(.appCaption)
                    .foregroundStyle(AppColors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

public typealias Notice = NoticeView
public typealias UnavailableState = UnavailableStateView

// MARK: - Timeline and weather

public enum TimelinePresentation {
    case standard
    case compact
}

/// Timeline.compact 的两层内容槽位，不负责业务摘要生成或节点排序。
public struct TimelineSummaryContent: View {
    public let title: String
    public let subtitle: String?
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    public init(title: String, subtitle: String? = nil) {
        self.title = title
        let trimmed = subtitle?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.subtitle = trimmed?.isEmpty == false ? trimmed : nil
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text(title)
                .font(dynamicTypeSize.isAccessibilitySize ? .headline : .listTitle)
                .foregroundStyle(AppColors.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("timeline-item-title")
            if let subtitle {
                Text(subtitle)
                    .font(dynamicTypeSize.isAccessibilitySize ? .caption : .appCaption)
                    .foregroundStyle(AppColors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("timeline-item-subtitle")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

public struct Timeline<Data: RandomAccessCollection, ItemContent: View>: View where Data.Element: Identifiable {
     public let items: Data
     public let time: (Data.Element) -> String?
     public let presentation: TimelinePresentation
     public let timeColumnWidth: CGFloat
     public let sectionLabel: (Data.Element) -> String?
     public let content: (Data.Element) -> ItemContent

     public init(
        _ items: Data,
        time: @escaping (Data.Element) -> String,
        presentation: TimelinePresentation = .standard,
        timeColumnWidth: CGFloat = 52,
        sectionLabel: @escaping (Data.Element) -> String? = { _ in nil },
        @ViewBuilder content: @escaping (Data.Element) -> ItemContent
    ) {
        self.items = items
        self.time = { time($0) }
        self.presentation = presentation
        self.timeColumnWidth = timeColumnWidth
        self.sectionLabel = sectionLabel
        self.content = content
    }

     public init(
        _ items: Data,
        optionalTime: @escaping (Data.Element) -> String?,
        presentation: TimelinePresentation = .standard,
        timeColumnWidth: CGFloat = 52,
        sectionLabel: @escaping (Data.Element) -> String? = { _ in nil },
        @ViewBuilder content: @escaping (Data.Element) -> ItemContent
    ) {
        self.items = items
        self.time = optionalTime
        self.presentation = presentation
        self.timeColumnWidth = timeColumnWidth
        self.sectionLabel = sectionLabel
        self.content = content
    }

     public var body: some View {
        let lastID = items.last?.id
        VStack(alignment: .leading, spacing: presentation == .compact ? Spacing.sm : Spacing.md) {
            ForEach(items) { item in
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    if let label = sectionLabel(item), !label.isEmpty {
                        Text(label)
                            .font(.micro)
                            .foregroundStyle(AppColors.textWeak)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    TimelineItem(
                        time: time(item),
                        isLast: item.id == lastID,
                        presentation: presentation,
                        timeColumnWidth: timeColumnWidth
                    ) {
                        content(item)
                    }
                }
                    .accessibilityElement(children: .combine)
            }
        }
    }
}

public struct TimelineItem<Content: View>: View {
     public let time: String?
     public var isLast = false
     public let presentation: TimelinePresentation
     public let timeColumnWidth: CGFloat
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    private let content: Content

     public init(
        time: String?,
        isLast: Bool = false,
        presentation: TimelinePresentation = .standard,
        timeColumnWidth: CGFloat = 52,
        @ViewBuilder content: () -> Content
     ) {
        self.time = time
        self.isLast = isLast
        self.presentation = presentation
        self.timeColumnWidth = timeColumnWidth
        self.content = content()
    }

     public var body: some View {
        HStack(alignment: .top, spacing: presentation == .compact ? Spacing.sm : Spacing.md) {
            timeLabel

            VStack(spacing: 0) {
                Circle()
                    .fill(presentation == .compact ? AppColors.interactionPrimary.opacity(0.50) : AppColors.interactionPrimary)
                    .frame(width: nodeSize, height: nodeSize)
                if !isLast {
                    Rectangle()
                        .fill(presentation == .compact ? AppColors.borderSubtle : AppColors.borderPrimary)
                        .frame(width: 1)
                        .frame(maxHeight: .infinity)
                }
            }
            .frame(width: nodeSize)
            .accessibilityHidden(true)

            content
                .font(.appCaption)
                .foregroundStyle(AppColors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .fixedSize(horizontal: false, vertical: presentation == .compact)
        .frame(minHeight: presentation == .compact ? 36 : 44, alignment: .top)
        .accessibilityElement(children: .combine)
    }

    private var nodeSize: CGFloat { presentation == .compact ? 4 : 8 }

    @ViewBuilder
    private var timeLabel: some View {
        if presentation == .compact {
            if timeColumnWidth > 0 || time?.isEmpty == false {
                if dynamicTypeSize.isAccessibilitySize {
                    Text(time ?? "")
                        .font(.timelineTime)
                        .monospacedDigit()
                        .foregroundStyle(AppColors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(minWidth: max(timeColumnWidth, 0), alignment: .leading)
                } else {
                    Text(time ?? "")
                        .font(.timelineTime)
                        .monospacedDigit()
                        .foregroundStyle(AppColors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(width: max(timeColumnWidth, 0), alignment: .leading)
                }
            }
        } else if let time, !time.isEmpty {
            Text(time)
                .font(.timelineTime)
                .monospacedDigit()
                .foregroundStyle(AppColors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
                .frame(minWidth: 52, alignment: .leading)
        }
    }
}

#if DEBUG
public extension TimelinePreviewItem {
    static let compactDays: [TimelinePreviewItem] = [
        TimelinePreviewItem(id: "aug-30", time: "30", title: "抵达进山口", details: ["乘车抵达后核对进山登记。"], subtitle: "出发城市 → 进山口"),
        TimelinePreviewItem(id: "aug-31", time: "31", title: "沿河谷上行", details: ["穿过林线，前往高山营地。"], subtitle: "进山口 → 高山营地"),
        TimelinePreviewItem(id: "sep-1", time: "1", title: "翻越垭口", details: ["尽早通过暴露路段，沿山谷下撤。"], subtitle: "高山营地 → 终点"),
    ]

    static let titleOnly = [TimelinePreviewItem(id: "start", time: nil, title: "起点", details: [])]
    static let withoutTime = [
        TimelinePreviewItem(id: "start", time: nil, title: "进山口", details: []),
        TimelinePreviewItem(id: "pass", time: nil, title: "一号垭口", details: [], subtitle: "海拔 4700 m · 参考"),
        TimelinePreviewItem(id: "end", time: nil, title: "湖畔营地", details: [], subtitle: "当日终点"),
    ]
    static let longTitle = [
        TimelinePreviewItem(id: "long", time: nil, title: "需要完整显示的高山垭口与营地连接点名称", details: [], subtitle: "参考资料 · 待核验"),
    ]
    static let qualified = [
        TimelinePreviewItem(id: "pass", time: nil, title: "一号垭口", details: [], subtitle: "6 km处 · 待核验"),
        TimelinePreviewItem(id: "alternative", time: nil, title: "湖畔营地 · 备选", details: [], subtitle: "营地资料待核验"),
    ]

    static func compactSectionLabel(for item: TimelinePreviewItem) -> String? {
        switch item.id {
        case "aug-30": "8月"
        case "sep-1": "9月"
        default: nil
        }
    }
}

#Preview("Timeline.compact") {
    Timeline(
        Array(TimelinePreviewItem.compactDays.prefix(2)),
        optionalTime: { $0.time },
        presentation: .compact,
        timeColumnWidth: 28,
        sectionLabel: TimelinePreviewItem.compactSectionLabel
    ) { item in
        TimelineSummaryContent(title: item.title, subtitle: item.subtitle)
    }
    .padding(Spacing.lg)
    .frame(width: 320)
    .background(AppColors.pageBase)
}

#Preview("Timeline.compactCrossMonth") {
    Timeline(
        TimelinePreviewItem.compactDays,
        optionalTime: { $0.time },
        presentation: .compact,
        timeColumnWidth: 28,
        sectionLabel: TimelinePreviewItem.compactSectionLabel
    ) { item in
        TimelineSummaryContent(title: item.title, subtitle: item.subtitle)
    }
    .padding(Spacing.lg)
    .frame(width: 320)
    .background(AppColors.pageBase)
}

#Preview("Timeline.compactTime") {
    Timeline(ComponentPreviewFixtures.timelineItems, optionalTime: { $0.time }, presentation: .compact) { item in
        TimelineSummaryContent(title: item.title, subtitle: item.subtitle)
    }
    .padding(Spacing.lg)
    .frame(width: 320)
    .background(AppColors.pageBase)
}
#endif

public struct SourceNote: View {
     public var source: String? = nil
     public var updatedAt: String? = nil

     public var body: some View {
        if !text.isEmpty {
            Text(text)
                .font(.appCaption)
                .foregroundStyle(AppColors.textWeak)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityLabel(text)
        }
    }

    private var text: String {
        [source, updatedAt].compactMap { value in
            guard let value, !value.isEmpty else { return nil }
            return value
        }.joined(separator: " · ")
    }

    public init(
        source: String? = nil,
        updatedAt: String? = nil
    ) {
        self.source = source
        self.updatedAt = updatedAt
    }
}

// MARK: - Profile and collection primitives

public enum AvatarButtonVariant {
    case pageHeader
    case sheetHeader

     public var size: CGFloat { self == .pageHeader ? 44 : 48 }
}

public enum AvatarButtonState {
    case ready
    case loading
    case unavailable
}

public struct AvatarButton: View {
     public var image: Image? = nil
     public var avatarLabel: String? = nil
     public var fallbackSystemImage = "circle"
     public var variant: AvatarButtonVariant = .pageHeader
     public var state: AvatarButtonState = .ready
     public let accessibilityLabel: String
     public let action: () -> Void

     public var body: some View {
        Button(action: action) {
            Group {
                if state == .loading {
                    ProgressView()
                        .tint(AppColors.interactionPrimary)
                } else if state == .unavailable {
                    Text("!")
                        .font(.action)
                        .foregroundStyle(AppColors.interactionPrimary)
                } else if let image {
                    image
                        .resizable()
                        .scaledToFill()
                } else if let avatarLabel, !avatarLabel.isEmpty {
                    Text(String(avatarLabel.prefix(1)))
                        .font(.action)
                        .foregroundStyle(AppColors.interactionPrimary)
                } else {
                    Image(systemName: fallbackSystemImage)
                        .font(.action)
                        .foregroundStyle(AppColors.interactionPrimary)
                }
            }
            .frame(width: variant.size, height: variant.size)
            .background(AppColors.interactionBackground)
            .clipShape(Circle())
            .overlay {
                Circle().stroke(AppColors.interactionPrimary.opacity(0.32), lineWidth: 1)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(WalkPressButtonStyle())
        .disabled(state == .loading)
        .opacity(state == .loading ? 0.55 : 1)
        .accessibilityLabel(resolvedAccessibilityLabel)
    }

    private var resolvedAccessibilityLabel: String {
        switch state {
        case .ready, .loading:
            accessibilityLabel
        case .unavailable:
            "账号信息加载失败，重试"
        }
    }

    public init(
        image: Image? = nil,
        avatarLabel: String? = nil,
        fallbackSystemImage: String = "circle",
        variant: AvatarButtonVariant = .pageHeader,
        state: AvatarButtonState = .ready,
        accessibilityLabel: String,
        action: @escaping () -> Void
    ) {
        self.image = image
        self.avatarLabel = avatarLabel
        self.fallbackSystemImage = fallbackSystemImage
        self.variant = variant
        self.state = state
        self.accessibilityLabel = accessibilityLabel
        self.action = action
    }
}

public struct QuantityStepper: View {
    @Binding var value: Int
     public let minimum: Int
     public var maximum: Int? = nil
     public var isEnabled = true
     public var accessibilityLabel = "数量"

     public var body: some View {
        HStack(spacing: Spacing.sm) {
            stepButton(systemName: "minus", isDisabled: value <= minimum) {
                value = max(minimum, value - 1)
            }

            Text("\(value)")
                .font(.metricValue)
                .foregroundStyle(AppColors.textPrimary)
                .monospacedDigit()
                .frame(minWidth: 36)
                .accessibilityHidden(true)

            stepButton(systemName: "plus", isDisabled: maximum.map { value >= $0 } ?? false) {
                if let maximum {
                    value = min(maximum, value + 1)
                } else {
                    value += 1
                }
            }
        }
        .opacity(isEnabled ? 1 : 0.45)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityValue("\(value)")
    }

    private func stepButton(systemName: String, isDisabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.dateTitle)
                .foregroundStyle(AppColors.interactionPrimary)
                .frame(width: 44, height: 44)
                .background(AppColors.surfaceElevated)
                .clipShape(RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled || isDisabled)
        .opacity(isDisabled ? 0.35 : 1)
        .accessibilityLabel(systemName == "minus" ? "减少" : "增加")
    }

    public init(
        value: Binding<Int>,
        minimum: Int,
        maximum: Int? = nil,
        isEnabled: Bool = true,
        accessibilityLabel: String = "数量"
    ) {
        self._value = value
        self.minimum = minimum
        self.maximum = maximum
        self.isEnabled = isEnabled
        self.accessibilityLabel = accessibilityLabel
    }
}
