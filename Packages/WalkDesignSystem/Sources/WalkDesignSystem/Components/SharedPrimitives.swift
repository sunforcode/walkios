import SwiftUI

// MARK: - Shared presentation variants

public enum StatePresentationVariant {
    case page
    case section
    case form
    case scene

     public var isFullPage: Bool { self == .page }
     public var alignment: HorizontalAlignment { self == .page || self == .scene ? .center : .leading }
     public var textAlignment: TextAlignment { self == .page || self == .scene ? .center : .leading }
}

// MARK: - Page shells and headers

public struct PageHeroHeader: View {
     public static let titleLineLimit = 2
     public static let subtitleLineLimit = 1

     public let title: String
     public let subtitle: String

     public var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text(title)
                .font(.heroTitle)
                .tracking(-1.4)
                .lineLimit(Self.titleLineLimit)

            Text(subtitle)
                .font(.heroSubtitle)
                .foregroundStyle(AppColors.textSecondary)
                .lineLimit(Self.subtitleLineLimit)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    public init(
        title: String,
        subtitle: String
    ) {
        self.title = title
        self.subtitle = subtitle
    }
}

public struct UtilityPage<Content: View>: View {
    private let content: Content

     public init(showsIndicators _: Bool = false, @ViewBuilder content: () -> Content) {
        self.content = content()
    }

     public var body: some View {
        UtilityPageContainer {
            content
        }
    }
}

public struct PageTitleBlock: View {
     public let title: String
     public var kicker: String? = nil
     public var description: String? = nil

     public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let kicker {
                Text(kicker)
                    .font(.appCaption)
                    .foregroundStyle(AppColors.interactionPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.bottom, Spacing.sm)
            }

            Text(title)
                .font(.pageTitle)
                .foregroundStyle(AppColors.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)

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

    public init(
        title: String,
        kicker: String? = nil,
        description: String? = nil
    ) {
        self.title = title
        self.kicker = kicker
        self.description = description
    }
}

public struct UtilityPageContainer<Content: View>: View {
    private let content: Content

     public init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

     public var body: some View {
        ZStack {
            LinearGradient(
                colors: [AppColors.pageMiddle, AppColors.pageBase],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            content
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .foregroundStyle(AppColors.textPrimary)
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

/// Compatibility wrapper for existing call sites. New code should use `IconButton`.
public struct GlassIconButton: View {
     public let systemName: String
     public var size: CGFloat = Spacing.navBarHeight
     public var backgroundColor: Color = AppColors.surfaceGlass
     public let action: () -> Void

     public var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.navTitle)
                .foregroundStyle(AppColors.textPrimary)
                .frame(width: size, height: size)
                .background(backgroundColor)
                .clipShape(Circle())
                .overlay {
                    Circle().stroke(AppColors.borderPrimary, lineWidth: 1)
                }
                .frame(minWidth: 44, minHeight: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(WalkPressButtonStyle())
    }

    public init(
        systemName: String,
        size: CGFloat = Spacing.navBarHeight,
        backgroundColor: Color = AppColors.surfaceGlass,
        action: @escaping () -> Void
    ) {
        self.systemName = systemName
        self.size = size
        self.backgroundColor = backgroundColor
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

public struct WalkPill<Content: View>: View {
    private let content: Content

     public init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

     public var body: some View {
        content
            .font(.label)
            .foregroundStyle(AppColors.textSecondary)
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.sm)
            .background(AppColors.surfaceGlass)
            .clipShape(Capsule())
            .overlay {
                Capsule().stroke(AppColors.borderPrimary, lineWidth: 1)
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

public struct RouteThumbnailPlaceholder: View {
     public var systemImage = "photo"

     public var body: some View {
        ZStack {
            AppColors.surfaceElevated
            Image(systemName: systemImage)
                .font(.ornament(20, weight: .medium))
                .foregroundStyle(AppColors.textWeak)
        }
        .accessibilityHidden(true)
    }

    public init(
        systemImage: String = "photo"
    ) {
        self.systemImage = systemImage
    }
}

public struct RouteListRow<Thumbnail: View, Metadata: View>: View {
     public let title: String
     public var showsDisclosure = true
    private let thumbnail: Thumbnail
    private let metadata: Metadata

     public init(
        title: String,
        showsDisclosure: Bool = true,
        @ViewBuilder thumbnail: () -> Thumbnail,
        @ViewBuilder metadata: () -> Metadata
    ) {
        self.title = title
        self.showsDisclosure = showsDisclosure
        self.thumbnail = thumbnail()
        self.metadata = metadata()
    }

     public var body: some View {
        ListRow {
            HStack(spacing: Spacing.md) {
                thumbnail
                    .frame(width: 82, height: 84)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: Radius.md, style: .continuous))

                VStack(alignment: .leading, spacing: Spacing.sm) {
                    Text(title)
                        .font(.listTitle)
                        .foregroundStyle(AppColors.textPrimary)
                        .lineLimit(2)

                    metadata
                        .font(.micro)
                        .foregroundStyle(AppColors.textSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                if showsDisclosure {
                    Image(systemName: "chevron.right")
                        .font(.contextTitle)
                        .foregroundStyle(AppColors.textWeak)
                        .frame(width: 18)
                }
            }
            .frame(minHeight: 84)
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

public struct NoticeView: View {
     public let message: String
     public var title: String? = nil
     public var icon: String = "info.circle"
     public var tone: NoticeTone = .info
     public var variant: StatePresentationVariant = .section

     public var body: some View {
        statusContainer {
            HStack(alignment: .top, spacing: Spacing.sm) {
                Image(systemName: icon)
                    .font(.ornament(13, weight: .semibold))
                    .foregroundStyle(tone.foregroundColor)
                    .frame(width: 22, height: 22)
                    .background(AppColors.surfaceSubtle, in: Circle())
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
            .padding(Spacing.md)
            .background(tone.backgroundColor, in: RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                    .stroke(tone.borderColor, lineWidth: 1)
            }
            .accessibilityElement(children: .combine)
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
        variant: StatePresentationVariant = .section
    ) {
        self.message = message
        self.title = title
        self.icon = icon
        self.tone = tone
        self.variant = variant
    }
}

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

public struct Timeline<Data: RandomAccessCollection, ItemContent: View>: View where Data.Element: Identifiable {
     public let items: Data
     public let time: (Data.Element) -> String?
     public let content: (Data.Element) -> ItemContent

     public init(
        _ items: Data,
        time: @escaping (Data.Element) -> String,
        @ViewBuilder content: @escaping (Data.Element) -> ItemContent
    ) {
        self.items = items
        self.time = { time($0) }
        self.content = content
    }

     public init(
        _ items: Data,
        optionalTime: @escaping (Data.Element) -> String?,
        @ViewBuilder content: @escaping (Data.Element) -> ItemContent
    ) {
        self.items = items
        self.time = optionalTime
        self.content = content
    }

     public var body: some View {
        let lastID = items.last?.id
        VStack(alignment: .leading, spacing: Spacing.md) {
            ForEach(items) { item in
                TimelineItem(time: time(item), isLast: item.id == lastID) {
                    content(item)
                }
            }
        }
    }
}

public struct TimelineItem<Content: View>: View {
     public let time: String?
     public var isLast = false
    private let content: Content

     public init(time: String?, isLast: Bool = false, @ViewBuilder content: () -> Content) {
        self.time = time
        self.isLast = isLast
        self.content = content()
    }

     public var body: some View {
        HStack(alignment: .top, spacing: Spacing.md) {
            if let time, !time.isEmpty {
                Text(time)
                    .font(.timelineTime)
                    .monospacedDigit()
                    .foregroundStyle(AppColors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(minWidth: 52, alignment: .leading)
            }

            VStack(spacing: 0) {
                Circle()
                    .fill(AppColors.interactionPrimary)
                    .frame(width: 8, height: 8)
                if !isLast {
                    Rectangle()
                        .fill(AppColors.borderPrimary)
                        .frame(width: 1)
                        .frame(maxHeight: .infinity)
                }
            }
            .frame(width: 8)
            .accessibilityHidden(true)

            content
                .font(.appCaption)
                .foregroundStyle(AppColors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(minHeight: 44, alignment: .top)
        .accessibilityElement(children: .combine)
    }
}

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

public struct Checklist<Summary: View, Content: View>: View {
    @Binding var isExpanded: Bool
    private let summary: Summary
    private let content: Content

     public init(
        isExpanded: Binding<Bool>,
        @ViewBuilder summary: () -> Summary,
        @ViewBuilder content: () -> Content
    ) {
        self._isExpanded = isExpanded
        self.summary = summary()
        self.content = content()
    }

     public var body: some View {
        WalkPanel(variant: .default) {
            VStack(alignment: .leading, spacing: Spacing.md) {
                Button {
                    isExpanded.toggle()
                } label: {
                    HStack(spacing: Spacing.md) {
                        summary
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.dateTitle)
                            .foregroundStyle(AppColors.textWeak)
                            .frame(width: 44, height: 44)
                    }
                }
                .buttonStyle(.plain)
                .accessibilityValue(isExpanded ? "已展开" : "已折叠")

                if isExpanded {
                    Rectangle()
                        .fill(AppColors.surfaceDivider)
                        .frame(height: 1)
                    content
                }
            }
        }
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
