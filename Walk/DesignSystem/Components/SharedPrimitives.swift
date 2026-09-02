import SwiftUI

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

struct WalkPanel<Content: View>: View {
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(Spacing.md)
            .background(AppColors.surfacePrimary)
            .clipShape(RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
            .shadow(color: AppColors.shadowCard, radius: 8, x: 0, y: 2)
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
                Capsule().stroke(AppColors.borderPrimary, lineWidth: 1)
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
                .background(backgroundColor)
                .clipShape(Circle())
                .overlay {
                    Circle().stroke(AppColors.borderPrimary, lineWidth: 1)
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
            AppColors.pageBase.ignoresSafeArea()
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
