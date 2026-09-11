import SwiftUI

enum LoadingStateVariant {
    case scene
    case page
    case section
    case rowSkeleton
}

struct LoadingView: View {
    var message: String = "加载中..."
    var detail: String? = nil
    var variant: LoadingStateVariant = .page

    var body: some View {
        stateContainer {
            VStack(spacing: Spacing.md) {
                if variant == .rowSkeleton {
                    RoundedRectangle(cornerRadius: Radius.sm, style: .continuous)
                        .fill(AppColors.surfaceElevated)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .accessibilityHidden(true)
                } else {
                    ProgressView()
                        .tint(AppColors.interactionPrimary)
                        .scaleEffect(variant == .section ? 1 : 1.25)

                    VStack(spacing: Spacing.xs) {
                        Text(message)
                            .font(.action)
                            .foregroundStyle(AppColors.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                        if let detail {
                            Text(detail)
                                .font(.appCaption)
                                .foregroundStyle(AppColors.textSecondary)
                                .multilineTextAlignment(.center)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }
            .padding(variant == .page ? Spacing.xl : Spacing.md)
            .frame(maxWidth: .infinity, maxHeight: variant == .page || variant == .scene ? .infinity : nil)
            .accessibilityElement(children: .combine)
            .accessibilityLabel(variant == .rowSkeleton ? message : [message, detail].compactMap { $0 }.joined(separator: "，"))
        }
    }

    @ViewBuilder
    private func stateContainer<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        switch variant {
        case .page:
            content()
        case .scene, .section, .rowSkeleton:
            content()
        }
    }
}

typealias LoadingState = LoadingView

#Preview {
    LoadingView()
}
