import SwiftUI
import WalkData
import WalkDesignSystem

struct GenerationWaitingProjection: Equatable {
    let title: String
    let description: String
}

extension SharedBusinessComponents {
    struct GenerationWaitingView: View {
        @Environment(\.accessibilityReduceMotion) private var environmentReduceMotion
        let projection: GenerationWaitingProjection
        var reduceMotionOverride: Bool? = nil

        private var reduceMotion: Bool {
            reduceMotionOverride ?? environmentReduceMotion
        }

        var body: some View {
            VStack(spacing: Spacing.md) {
                waitingMark

                Text("正在生成个人行程")
                    .font(.appCaption)
                    .foregroundStyle(AppColors.interactionPrimary)

                Text(projection.title)
                    .font(.pageTitle)
                    .foregroundStyle(AppColors.textPrimary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                Text(projection.description)
                    .font(.appBody)
                    .foregroundStyle(AppColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: 300)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.horizontal, Spacing.xl)
            .accessibilityElement(children: .combine)
        }

        private var waitingMark: some View {
            ZStack {
                Circle().fill(AppColors.interactionBackground)
                Circle()
                    .stroke(AppColors.interactionPrimary.opacity(0.45), lineWidth: 1)
                    .padding(15)
                Circle()
                    .trim(from: 0.08, to: 0.72)
                    .stroke(
                        AppColors.interactionPrimary,
                        style: StrokeStyle(lineWidth: 1, lineCap: .round)
                    )
                    .rotationEffect(.degrees(reduceMotion ? 0 : 24))
                    .padding(30)
                Circle()
                    .fill(AppColors.interactionPrimary)
                    .frame(width: 18, height: 18)
            }
            .frame(width: 112, height: 112)
            .accessibilityHidden(true)
        }
    }
}

#if DEBUG
extension GenerationWaitingProjection {
    static let `default` = GenerationWaitingProjection(
        title: "正在整理贡嘎西南坡环线",
        description: "请稍候，个人行程结果形成后会在当前流程中继续展示。"
    )
}

#Preview("GenerationWaitingView.default") {
    BusinessComponentPreviewHost {
        SharedBusinessComponents.GenerationWaitingView(
            projection: GenerationWaitingProjection.default
        )
        .frame(minHeight: 560)
    }
}

#Preview("GenerationWaitingView.reduceMotion") {
    BusinessComponentPreviewHost {
        SharedBusinessComponents.GenerationWaitingView(
            projection: GenerationWaitingProjection.default,
            reduceMotionOverride: true
        )
        .frame(minHeight: 560)
    }
}
#endif
