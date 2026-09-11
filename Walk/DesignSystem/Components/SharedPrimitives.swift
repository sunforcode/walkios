import SwiftUI

// MARK: - Shared presentation variants

enum StatePresentationVariant {
    case page
    case section
    case form
    case scene

    var isFullPage: Bool { self == .page }
    var alignment: HorizontalAlignment { self == .page || self == .scene ? .center : .leading }
    var textAlignment: TextAlignment { self == .page || self == .scene ? .center : .leading }
}

// MARK: - Page shells and headers

struct PageHeroHeader: View {
    static let titleLineLimit = 2
    static let subtitleLineLimit = 1

    let title: String
    let subtitle: String

    var body: some View {
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
}

struct UtilityPage<Content: View>: View {
    private let content: Content

    init(showsIndicators _: Bool = false, @ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        UtilityPageContainer {
            content
        }
    }
}

struct PageTitleBlock: View {
    let title: String
    var kicker: String? = nil
    var description: String? = nil

    var body: some View {
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
}

struct UtilityPageContainer<Content: View>: View {
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
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

struct ImmersivePageContainer<Content: View>: View {
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
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

enum IconButtonVariant {
    case `default`
    case overlay
    case compactClose

    var iconSize: CGFloat { self == .default ? 24 : 20 }
    var usesOverlaySurface: Bool { self != .default }
}

struct IconButton: View {
    let systemName: String
    let accessibilityLabel: String
    var variant: IconButtonVariant = .default
    var isDisabled = false
    let action: () -> Void

    var body: some View {
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
}

/// Compatibility wrapper for existing call sites. New code should use `IconButton`.
struct GlassIconButton: View {
    let systemName: String
    var size: CGFloat = Spacing.navBarHeight
    var backgroundColor: Color = AppColors.surfaceGlass
    let action: () -> Void

    var body: some View {
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
}

private struct WalkPressButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.985 : 1)
            .opacity(configuration.isPressed ? 0.88 : 1)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

enum PrimaryActionVariant {
    case `default`
    case compact
}

struct PrimaryAction: View {
    let title: String
    var systemImage: String? = nil
    var variant: PrimaryActionVariant = .default
    var isLoading = false
    var isDisabled = false
    var fillsWidth = false
    let action: () -> Void

    var body: some View {
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
}

enum SecondaryActionVariant {
    case `default`
    case inline
    case overlayCompact

    var horizontalPadding: CGFloat {
        switch self {
        case .default: Spacing.lg
        case .inline, .overlayCompact: Spacing.md
        }
    }

    var verticalPadding: CGFloat {
        switch self {
        case .default: Spacing.md
        case .inline, .overlayCompact: Spacing.sm
        }
    }
}

struct SecondaryAction: View {
    let title: String
    var systemImage: String? = nil
    var variant: SecondaryActionVariant = .default
    var isLoading = false
    var isDisabled = false
    var fillsWidth = false
    let action: () -> Void

    var body: some View {
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
}

struct DangerAction: View {
    let title: String
    var systemImage: String? = nil
    var isLoading = false
    var isDisabled = false
    var fillsWidth = false
    let action: () -> Void

    var body: some View {
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
}

// MARK: - Panels, cards, and sections

enum WalkPanelVariant {
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

enum WalkPanelSurface {
    case primary
    case glass

    var color: Color {
        switch self {
        case .primary: AppColors.surfacePrimary
        case .glass: AppColors.surfacePanelGlass
        }
    }
}

struct WalkPanel<Content: View>: View {
    private let variant: WalkPanelVariant
    private let surface: WalkPanelSurface
    private let content: Content

    init(variant: WalkPanelVariant = .default, @ViewBuilder content: () -> Content) {
        self.variant = variant
        self.surface = variant == .glass ? .glass : .primary
        self.content = content()
    }

    init(surface: WalkPanelSurface = .primary, @ViewBuilder content: () -> Content) {
        self.variant = surface == .glass ? .glass : .default
        self.surface = surface
        self.content = content()
    }

    @ViewBuilder
    var body: some View {
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
    let topRadius: CGFloat
    let bottomRadius: CGFloat

    func path(in rect: CGRect) -> Path {
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

enum WalkCardVariant {
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

struct WalkCard<Content: View>: View {
    var variant: WalkCardVariant = .default
    var isSelected = false
    private let content: Content

    init(
        variant: WalkCardVariant = .default,
        isSelected: Bool = false,
        @ViewBuilder content: () -> Content
    ) {
        self.variant = variant
        self.isSelected = isSelected
        self.content = content()
    }

    var body: some View {
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

struct SelectableOptionCard<Content: View>: View {
    let isSelected: Bool
    var isEnabled = true
    let action: () -> Void
    private let content: Content

    init(
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

    var body: some View {
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

struct SectionHeader: View {
    let title: String
    var subtitle: String? = nil
    private let trailing: AnyView?

    init(title: String, subtitle: String? = nil) {
        self.title = title
        self.subtitle = subtitle
        self.trailing = nil
    }

    init<Trailing: View>(
        title: String,
        subtitle: String? = nil,
        @ViewBuilder trailing: () -> Trailing
    ) {
        self.title = title
        self.subtitle = subtitle
        self.trailing = AnyView(trailing())
    }

    var body: some View {
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

struct SheetHandle: View {
    var body: some View {
        Capsule()
            .fill(AppColors.surfaceHandle)
            .frame(width: 40, height: 4)
            .frame(maxWidth: .infinity)
            .accessibilityHidden(true)
    }
}

struct FixedActionArea<Content: View>: View {
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
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

struct WalkPill<Content: View>: View {
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
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

enum ListRowVariant {
    case standalone
    case grouped
}

struct ListRow<Content: View>: View {
    var variant: ListRowVariant = .standalone
    var showsDivider = false
    var action: (() -> Void)? = nil
    private let content: Content

    init(
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
    var body: some View {
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

struct RouteThumbnailPlaceholder: View {
    var systemImage = "photo"

    var body: some View {
        ZStack {
            AppColors.surfaceElevated
            Image(systemName: systemImage)
                .font(.ornament(20, weight: .medium))
                .foregroundStyle(AppColors.textWeak)
        }
        .accessibilityHidden(true)
    }
}

struct RouteListRow<Thumbnail: View, Metadata: View>: View {
    let title: String
    var showsDisclosure = true
    private let thumbnail: Thumbnail
    private let metadata: Metadata

    init(
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

    var body: some View {
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

struct SegmentedControlOption<Value: Hashable>: Identifiable {
    let value: Value
    let title: String
    var id: Value { value }
}

struct SegmentedControl<Value: Hashable>: View {
    let options: [SegmentedControlOption<Value>]
    @Binding var selection: Value

    var body: some View {
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
}

// MARK: - Status and information

enum InfoTagTone {
    case info
    case warning
    case neutral
    case overlay

    var foregroundColor: Color {
        switch self {
        case .info: AppColors.info
        case .warning: AppColors.warning
        case .neutral: AppColors.textSecondary
        case .overlay: AppColors.textPrimary
        }
    }

    var backgroundColor: Color {
        switch self {
        case .info: AppColors.infoBackground
        case .warning: AppColors.warningBackground
        case .neutral: AppColors.surfaceElevated
        case .overlay: AppColors.surfaceControlOverlay
        }
    }
}

struct InfoTag: View {
    let title: String
    var systemImage: String? = nil
    var tone: InfoTagTone = .neutral

    var body: some View {
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
}

enum NoticeTone {
    case info
    case warning
    case stale
    case danger
    case readonly

    var foregroundColor: Color {
        switch self {
        case .info: AppColors.interactionPrimary
        case .warning, .stale: AppColors.warning
        case .danger: AppColors.danger
        case .readonly: AppColors.textSecondary
        }
    }

    var backgroundColor: Color {
        switch self {
        case .info: AppColors.interactionBackground
        case .warning, .stale: AppColors.warningBackground
        case .danger: AppColors.dangerBackground
        case .readonly: AppColors.surfaceElevated
        }
    }

    var borderColor: Color {
        switch self {
        case .info: AppColors.interactionPrimary.opacity(0.18)
        case .warning, .stale: AppColors.warning.opacity(0.25)
        case .danger: AppColors.dangerBorder
        case .readonly: AppColors.borderSubtle
        }
    }
}

struct NoticeView: View {
    let message: String
    var title: String? = nil
    var icon: String = "info.circle"
    var tone: NoticeTone = .info
    var variant: StatePresentationVariant = .section

    var body: some View {
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
}

enum UnavailableStateVariant {
    case inline
    case block
}

struct UnavailableStateView: View {
    let title: String
    var message: String? = nil
    var icon: String? = "exclamationmark.circle"
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil
    var variant: UnavailableStateVariant = .inline

    init(
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

    init(
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

    var body: some View {
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

typealias Notice = NoticeView
typealias UnavailableState = UnavailableStateView

// MARK: - Timeline and weather

struct Timeline<Data: RandomAccessCollection, ItemContent: View>: View where Data.Element: Identifiable {
    let items: Data
    let time: (Data.Element) -> String?
    let content: (Data.Element) -> ItemContent

    init(
        _ items: Data,
        time: @escaping (Data.Element) -> String,
        @ViewBuilder content: @escaping (Data.Element) -> ItemContent
    ) {
        self.items = items
        self.time = { time($0) }
        self.content = content
    }

    init(
        _ items: Data,
        optionalTime: @escaping (Data.Element) -> String?,
        @ViewBuilder content: @escaping (Data.Element) -> ItemContent
    ) {
        self.items = items
        self.time = optionalTime
        self.content = content
    }

    var body: some View {
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

struct TimelineItem<Content: View>: View {
    let time: String?
    var isLast = false
    private let content: Content

    init(time: String?, isLast: Bool = false, @ViewBuilder content: () -> Content) {
        self.time = time
        self.isLast = isLast
        self.content = content()
    }

    var body: some View {
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

struct DailyWeatherCard: View {
    let dayLabel: String
    var phase: String? = nil
    let date: String
    let condition: String?
    let temperature: String?
    let precipitation: String?
    let wind: String?
    var systemImage = "cloud.sun"

    var body: some View {
        WalkCard {
            VStack(alignment: .leading, spacing: Spacing.md) {
                HStack(alignment: .top, spacing: Spacing.md) {
                    VStack(alignment: .leading, spacing: Spacing.xs) {
                        Text([dayLabel, phase].compactMap { $0 }.joined(separator: " · "))
                            .font(.cardTitle)
                            .foregroundStyle(AppColors.textPrimary)
                        Text(date)
                            .font(.appCaption)
                            .foregroundStyle(AppColors.textSecondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    Image(systemName: systemImage)
                        .font(.ornament(24, weight: .medium))
                        .foregroundStyle(AppColors.interactionPrimary)
                }

                weatherValue(label: "天气", value: condition)
                HStack(alignment: .top, spacing: Spacing.md) {
                    weatherValue(label: "温度", value: temperature)
                    weatherValue(label: "降水", value: precipitation)
                    weatherValue(label: "风力", value: wind)
                }
            }
        }
    }

    private func weatherValue(label: String, value: String?) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text(label)
                .font(.micro)
                .foregroundStyle(AppColors.textWeak)
            Text(value ?? "信息不可用")
                .font(.appCaption)
                .foregroundStyle(value == nil ? AppColors.warning : AppColors.textPrimary)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct SourceNote: View {
    var source: String? = nil
    var updatedAt: String? = nil

    var body: some View {
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
}

// MARK: - Profile and collection primitives

enum AvatarButtonVariant {
    case pageHeader
    case sheetHeader

    var size: CGFloat { self == .pageHeader ? 44 : 48 }
}

enum AvatarButtonState {
    case ready
    case loading
    case unavailable
}

struct AvatarButton: View {
    var image: Image? = nil
    var avatarLabel: String? = nil
    var fallbackSystemImage = "circle"
    var variant: AvatarButtonVariant = .pageHeader
    var state: AvatarButtonState = .ready
    let accessibilityLabel: String
    let action: () -> Void

    var body: some View {
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
}

struct ProfileIdentityHeader: View {
    let username: String
    let accountSummary: String
    var image: Image? = nil

    var body: some View {
        VStack(spacing: Spacing.sm) {
            Group {
                if let image {
                    image
                        .resizable()
                        .scaledToFill()
                } else {
                    Image(systemName: "person.fill")
                        .font(.ornament(24, weight: .semibold))
                        .foregroundStyle(AppColors.interactionPrimary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(AppColors.interactionBackground)
                }
            }
            .frame(width: 48, height: 48)
            .clipShape(Circle())

            Text(username)
                .font(.cardTitle)
                .foregroundStyle(AppColors.textPrimary)
                .lineLimit(2)
                .multilineTextAlignment(.center)

            Text(accountSummary)
                .font(.appCaption)
                .foregroundStyle(AppColors.textSecondary)
                .lineLimit(2)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }
}

struct ProfileSheet<Content: View>: View {
    let username: String
    let accountSummary: String
    var image: Image? = nil
    let onClose: () -> Void
    private let content: Content

    init(
        username: String,
        accountSummary: String,
        image: Image? = nil,
        onClose: @escaping () -> Void,
        @ViewBuilder content: () -> Content
    ) {
        self.username = username
        self.accountSummary = accountSummary
        self.image = image
        self.onClose = onClose
        self.content = content()
    }

    var body: some View {
        WalkPanel(variant: .bottomOverlay) {
            VStack(spacing: Spacing.lg) {
                SheetHandle()
                    .overlay(alignment: .topTrailing) {
                        IconButton(
                            systemName: "xmark",
                            accessibilityLabel: "关闭",
                            variant: .compactClose,
                            action: onClose
                        )
                    }

                ProfileIdentityHeader(
                    username: username,
                    accountSummary: accountSummary,
                    image: image
                )

                Rectangle()
                    .fill(AppColors.surfaceDivider)
                    .frame(height: 1)

                content
            }
        }
    }
}

enum HeatmapLevel {
    case empty
    case low
    case medium
    case high

    var color: Color {
        switch self {
        case .empty: AppColors.heatmapEmpty
        case .low: AppColors.heatmapLow
        case .medium: AppColors.heatmapMedium
        case .high: AppColors.heatmapHigh
        }
    }
}

struct HeatmapCell: Identifiable {
    let id: String
    let level: HeatmapLevel
    var isPlaceholder = false
    var accessibilityLabel: String? = nil
}

struct HeatmapCalendar: View {
    let cells: [HeatmapCell]
    var cellSize: CGFloat = 4
    var accessibilityLabel = "行程日历"
    var action: (() -> Void)? = nil

    @ViewBuilder
    var body: some View {
        if let action {
            Button(action: action) {
                calendar
            }
            .buttonStyle(.plain)
            .accessibilityLabel(accessibilityLabel)
        } else {
            calendar
                .accessibilityElement(children: .contain)
                .accessibilityLabel(accessibilityLabel)
        }
    }

    private var calendar: some View {
        let size = min(max(cellSize, 3), 5)
        let rows = Array(repeating: GridItem(.fixed(size), spacing: 2), count: 7)
        return ScrollView(.horizontal, showsIndicators: false) {
            LazyHGrid(rows: rows, spacing: 2) {
                ForEach(cells) { cell in
                    RoundedRectangle(cornerRadius: 1, style: .continuous)
                        .fill(cell.isPlaceholder ? AppColors.surfacePrimary.opacity(0) : cell.level.color)
                        .frame(width: size, height: size)
                        .accessibilityLabel(cell.accessibilityLabel ?? "")
                        .accessibilityHidden(cell.isPlaceholder || cell.accessibilityLabel == nil)
                }
            }
        }
        .frame(minHeight: size * 7 + 12)
    }
}

struct Checklist<Summary: View, Content: View>: View {
    @Binding var isExpanded: Bool
    private let summary: Summary
    private let content: Content

    init(
        isExpanded: Binding<Bool>,
        @ViewBuilder summary: () -> Summary,
        @ViewBuilder content: () -> Content
    ) {
        self._isExpanded = isExpanded
        self.summary = summary()
        self.content = content()
    }

    var body: some View {
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

struct QuantityStepper: View {
    @Binding var value: Int
    let minimum: Int
    var maximum: Int? = nil
    var isEnabled = true
    var accessibilityLabel = "数量"

    var body: some View {
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
}
