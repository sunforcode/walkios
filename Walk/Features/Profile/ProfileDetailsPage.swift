import SwiftUI
import WalkData
import WalkDesignSystem

// MARK: - 个人资料设置页（任务栈页 + 共享内容）

struct ProfileDetailsView: View {
    @ObservedObject var viewModel: ProfileViewModel

    init(viewModel: ProfileViewModel) {
        self.viewModel = viewModel
    }

    var body: some View {
        UtilityPage(title: "个人资料") {
            ProfileSettingsContent(viewModel: viewModel)
        }
    }
}

/// 个人资料设置内容：头像、昵称、脱敏手机号按左右行排列；
/// 昵称保存与头像更新使用共享账号状态与既有账号接口。
struct ProfileSettingsContent: View {
    @ObservedObject var viewModel: ProfileViewModel
    @State private var nickname = ""
    @State private var didSyncNickname = false

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            SurfaceElevated {
                avatarRow
                nicknameRow
                EntrySettingsRow(
                    title: EntryPageContract.profileFields[1],
                    value: viewModel.account?.profile.maskedPhone ?? "加载中",
                    showsDivider: false
                )
            }

            PrimaryAction(
                title: "保存昵称",
                isLoading: viewModel.isSavingProfile,
                isDisabled: viewModel.isSavingProfile,
                fillsWidth: true
            ) {
                Task { await viewModel.updateNickname(nickname) }
            }

            if let error = viewModel.profileUpdateErrorMessage {
                errorText(error)
            }
            if let error = viewModel.avatarErrorMessage {
                errorText(error)
            }
        }
        .task {
            guard !didSyncNickname else { return }
            nickname = viewModel.account?.profile.nickname ?? ""
            didSyncNickname = true
        }
    }

    private var avatarRow: some View {
        EntrySettingsRow(title: EntryPageContract.profileFields[2], showsDivider: true) {
            if let avatar = viewModel.account?.profile.avatar {
                Text(avatar)
                    .font(.appCaption)
                    .foregroundStyle(AppColors.textWeak)
                    .lineLimit(1)
                    .truncationMode(.middle)
            } else {
                Text("头像未设置")
                    .font(.appCaption)
                    .foregroundStyle(AppColors.textWeak)
            }
        }
    }

    private var nicknameRow: some View {
        EntrySettingsRow(title: EntryPageContract.profileFields[0], showsDivider: true) {
            TextField(EntryPageContract.profileFields[0], text: $nickname)
                .font(.appBody)
                .multilineTextAlignment(.trailing)
                .foregroundStyle(AppColors.textPrimary)
                .textInputAutocapitalization(.sentences)
        }
    }

    private func errorText(_ message: String) -> some View {
        Text(message)
            .font(.appCaption)
            .foregroundStyle(AppColors.danger)
    }
}
