import SwiftUI
import PhotosUI
import WalkData
import WalkDesignSystem

/// PAGE-ACCOUNT-MENU：账户菜单，以底部模态 Sheet（ModalBottomSheet）承载，不进入任务栈。
/// 只承载设置主页；选择设置项时关闭菜单，由我的页任务栈推入对应设置内容页。
struct AccountMenuView: View {
    @ObservedObject private var viewModel: ProfileViewModel
    private let onClose: () -> Void
    private let onNavigate: (AppDestination) -> Void
    private let onLoggedOut: () -> Void

    @State private var selectedPhoto: PhotosPickerItem?
    @State private var isAvatarPickerPresented = false

    init(
        viewModel: ProfileViewModel,
        onClose: @escaping () -> Void = {},
        onNavigate: @escaping (AppDestination) -> Void = { _ in },
        onLoggedOut: @escaping () -> Void = {}
    ) {
        self.viewModel = viewModel
        self.onClose = onClose
        self.onNavigate = onNavigate
        self.onLoggedOut = onLoggedOut
    }

    var body: some View {
        ModalBottomSheet(onDismiss: onClose) {
            settingsHome
        }
        .task {
            if viewModel.account == nil {
                await viewModel.loadProfile()
            }
        }
        .onChange(of: viewModel.isLoggedIn) { isLoggedIn in
            guard !isLoggedIn else { return }
            onLoggedOut()
        }
        .onChange(of: selectedPhoto) { item in
            // 只选择图片；取消选择不关闭菜单，也不改变头像。
            guard let item else { return }
            Task {
                guard let data = try? await item.loadTransferable(type: Data.self) else {
                    viewModel.reportAvatarReadFailure()
                    return
                }
                await viewModel.updateAvatar(data: data, contentType: "image/jpeg")
            }
        }
        .photosPicker(
            isPresented: $isAvatarPickerPresented,
            selection: $selectedPhoto,
            matching: .images
        )
    }

    // MARK: - 设置主页

    private var settingsHome: some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            if let profile = viewModel.account?.profile {
                identityHeader(profile)
                settingsGroup(title: "账户与设置", items: accountSettings)
                settingsGroup(title: "支持", items: supportSettings)
                #if DEBUG
                settingsGroup(title: "开发者", items: developerSettings)
                #endif

                if let avatarError = viewModel.avatarErrorMessage {
                    ErrorView(
                        message: avatarError,
                        title: "头像更新失败",
                        variant: .section
                    )
                    .padding(.top, Spacing.md)
                }

                if let logoutError = viewModel.logoutErrorMessage {
                    ErrorView(
                        message: logoutError,
                        title: "退出登录失败",
                        variant: .section
                    )
                    .padding(.top, Spacing.md)
                }

                DangerAction(
                    title: "退出登录",
                    systemImage: "rectangle.portrait.and.arrow.right",
                    isLoading: viewModel.isLoggingOut,
                    fillsWidth: true,
                    action: {
                        Task { await viewModel.logout() }
                    }
                )
                .padding(.top, Spacing.md)
            }
        }
        .frame(maxWidth: .infinity, alignment: .top)
    }

    private func identityHeader(_ profile: ProfileProjection) -> some View {
        AccountEquipmentBusinessComponents.ProfileIdentityHeader(
            profile: profile,
            avatarState: avatarState,
            onSelectAvatar: { isAvatarPickerPresented = true }
        )
    }

    private var avatarState: AccountEquipmentBusinessComponents.ProfileIdentityHeader.AvatarState {
        if viewModel.isAvatarUpdating { return .updating }
        if viewModel.avatarErrorMessage != nil { return .failed }
        return .ready
    }

    private var accountSettings: [SettingItem] {
        [
            SettingItem(id: .profile, label: "个人资料", destination: .profileDetails),
            SettingItem(id: .notifications, label: "通知设置", destination: .notificationSettings),
            SettingItem(id: .privacy, label: "隐私设置", destination: .privacySettings),
        ]
    }

    private var supportSettings: [SettingItem] {
        [
            SettingItem(id: .helpAndFeedback, label: "帮助与反馈", destination: .helpAndFeedback),
            SettingItem(id: .about, label: "关于 Walk", destination: .about),
        ]
    }

    #if DEBUG
    private var developerSettings: [SettingItem] {
        [
            SettingItem(id: .debugEnvironment, label: "环境", destination: .debugEnvironment),
        ]
    }
    #endif

    private func settingsGroup(title: String, items: [SettingItem]) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text(title)
                .font(.metricCompactLabel)
                .fontWeight(.bold)
                .tracking(0.9)
                .foregroundStyle(AppColors.textWeak)
                .padding(.top, Spacing.md)

            VStack(spacing: 0) {
                ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                    SettingsListRow(
                        id: item.id,
                        label: item.label,
                        description: item.description,
                        showsDivider: index < items.count - 1,
                        onActivate: { _ in
                            onNavigate(item.destination)
                        }
                    )
                }
            }
            // 色块嵌套最多两层：Sheet 表面为第一层，分组为第二层（浅色填充 + 细描边）。
            .background(RoundedRectangle(cornerRadius: Radius.lg, style: .continuous).fill(AppColors.surfaceElevated))
            .clipShape(RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                    .stroke(AppColors.borderSubtle, lineWidth: 1)
            }
        }
    }
}

extension AccountMenuView {
    struct SettingItem: Identifiable {
        let id: AccountMenuSettingID
        let label: String
        var description: String? = nil
        let destination: AppDestination
    }

    enum AccountMenuSettingID: String, Hashable, CaseIterable {
        case profile
        case notifications
        case privacy
        case helpAndFeedback
        case about
        case debugEnvironment
    }
}

#if DEBUG
#Preview("AccountMenuView.modalSheet") {
    AccountMenuView(
        viewModel: ProfileViewModel(
            accountService: PreviewHelpers.accountService,
            tripService: PreviewHelpers.personalTripService,
            equipmentService: PreviewHelpers.equipmentService,
            authSession: PreviewHelpers.authManager
        ),
        onClose: {},
        onNavigate: { _ in },
        onLoggedOut: {}
    )
    .background(AppColors.pageBase)
}
#endif
