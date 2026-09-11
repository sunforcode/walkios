import SwiftUI

struct ErrorView: View {
    let message: String
    let retryAction: (() -> Void)?
    var title: String
    var variant: StatePresentationVariant

    init(
        message: String,
        title: String = "加载失败",
        variant: StatePresentationVariant = .page,
        retry: (() -> Void)? = nil
    ) {
        self.message = message
        self.retryAction = retry
        self.title = title
        self.variant = variant
    }

    var body: some View {
        stateContainer {
            VStack(alignment: variant.alignment, spacing: Spacing.md) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.ornament(48, weight: .regular))
                    .foregroundStyle(AppColors.danger)
                    .accessibilityHidden(true)

                VStack(alignment: variant.alignment, spacing: Spacing.sm) {
                    Text(title)
                        .font(variant == .page ? .sectionTitle : .action)
                        .foregroundStyle(AppColors.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(message)
                        .font(.appCaption)
                        .foregroundStyle(AppColors.textSecondary)
                        .multilineTextAlignment(variant.textAlignment)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if let retryAction {
                    SecondaryAction(
                        title: "重试",
                        variant: variant == .page ? .default : .inline,
                        action: retryAction
                    )
                }
            }
            .padding(variant == .page ? Spacing.xl : Spacing.md)
            .frame(maxWidth: variant == .page ? 320 : .infinity, alignment: variant == .page ? .center : .leading)
            .background {
                if variant == .form {
                    RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                        .fill(AppColors.dangerBackground)
                }
            }
            .accessibilityElement(children: .contain)
        }
    }

    @ViewBuilder
    private func stateContainer<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        if variant == .page {
            UtilityPageContainer {
                content()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        } else {
            content()
        }
    }
}

struct LocalErrorView: View {
    let message: String
    let retryAction: () -> Void

    init(message: String, retry: @escaping () -> Void) {
        self.message = message
        self.retryAction = retry
    }

    var body: some View {
        ErrorView(message: message, title: "局部内容加载失败", variant: .section, retry: retryAction)
    }
}

typealias ErrorState = ErrorView

#if DEBUG
#Preview("ErrorView.page") {
    ErrorView(message: ComponentPreviewFixtures.errorMessage, retry: {})
}

#Preview("ErrorView.section") {
    ErrorView(
        message: ComponentPreviewFixtures.errorMessage,
        title: ComponentPreviewFixtures.errorTitle,
        variant: .section,
        retry: {}
    )
    .padding(Spacing.lg)
    .background(AppColors.pageBase)
}

#Preview("ErrorView.form") {
    ErrorView(
        message: ComponentPreviewFixtures.formError,
        title: "保存失败",
        variant: .form
    )
    .padding(Spacing.lg)
    .background(AppColors.pageBase)
}

#Preview("ErrorView.scene") {
    ErrorView(
        message: ComponentPreviewFixtures.errorMessage,
        title: ComponentPreviewFixtures.errorTitle,
        variant: .scene,
        retry: {}
    )
    .frame(maxWidth: .infinity, minHeight: 240)
    .background(AppColors.pageBase)
}
#endif
