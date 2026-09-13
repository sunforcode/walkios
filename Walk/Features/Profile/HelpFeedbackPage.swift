import SwiftUI
import WalkData
import WalkDesignSystem

// MARK: - 帮助与反馈页（任务栈页 + 共享内容）

struct HelpAndFeedbackView: View {
    var body: some View {
        UtilityPage(title: "帮助与反馈") {
            HelpFeedbackContent()
        }
    }
}

/// 反馈页只保留反馈内容与提交：空白禁用提交；提交后显示本地成功反馈并清空，
/// 不发起任何网络请求。
struct HelpFeedbackContent: View {
    @State private var feedback = ""
    @State private var feedbackSubmitted = false

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            SurfaceElevated {
                EntryTextEditor(title: "反馈内容", text: $feedback)
                    .padding(Spacing.lg)
            }

            PrimaryAction(
                title: "提交",
                isDisabled: feedback.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                fillsWidth: true
            ) {
                feedbackSubmitted = true
                feedback = ""
            }

            if feedbackSubmitted {
                Text("反馈已提交，感谢你的反馈。")
                    .font(.appCaption)
                    .foregroundStyle(AppColors.interactionPrimary)
            }
        }
    }
}
