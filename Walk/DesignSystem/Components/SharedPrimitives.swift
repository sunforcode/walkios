import SwiftUI

struct WalkPanel<Content: View>: View {
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(Spacing.md)
            .background(AppColors.surfaceCard)
            .clipShape(RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                    .stroke(AppColors.border, lineWidth: 1)
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
            .padding(.horizontal, Spacing.s12)
            .padding(.vertical, Spacing.sm)
            .background(AppColors.surfaceGlass)
            .clipShape(Capsule())
            .overlay {
                Capsule().stroke(AppColors.border, lineWidth: 1)
            }
    }
}

struct GlassIconButton: View {
    let systemName: String
    var size: CGFloat = Spacing.navBarHeight
    var backgroundColor: Color = AppColors.surfaceGlass
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.nav)
                .foregroundStyle(AppColors.textPrimary)
                .frame(width: size, height: size)
                .background(.ultraThinMaterial)
                .background(backgroundColor)
                .clipShape(Circle())
                .overlay {
                    Circle().stroke(AppColors.border, lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
    }
}

struct UtilityPageContainer<Content: View>: View {
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        ZStack {
            AppColors.bgBase.ignoresSafeArea()
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
                colors: [AppColors.routeOuter, AppColors.routeMiddle, AppColors.routeInner],
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
