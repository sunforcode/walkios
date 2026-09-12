import SwiftUI
import WalkData
import WalkDesignSystem

/// PAGE-ACCOUNT-MENU：账户菜单，以底部模态 Sheet（ModalBottomSheet）承载，不进入任务栈。
/// 设置项经父级任务栈承接：onNavigate 前由宿主先关闭本模态。
struct AccountMenuView: View {
    @ObservedObject private var viewModel: ProfileViewModel
    private let onClose: () -> Void
    private let onNavigate: (AppDestination) -> Void
    private let onLoggedOut: () -> Void

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
        ModalBottomSheet(onDismiss: onClose, isCloseActionPresented: true) {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                if let profile = viewModel.account?.profile {
                    identityHeader(profile)
                    settingsGroup(title: "账户与设置", items: accountSettings(profile))
                    settingsGroup(title: "支持", items: supportSettings)

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
        .task {
            if viewModel.account == nil {
                await viewModel.loadProfile()
            }
        }
        .onChange(of: viewModel.isLoggedIn) { isLoggedIn in
            guard !isLoggedIn else { return }
            onLoggedOut()
        }
    }

    private func identityHeader(_ profile: ProfileProjection) -> some View {
        AccountEquipmentBusinessComponents.ProfileIdentityHeader(profile: profile)
    }

    private func accountSettings(_ profile: ProfileProjection) -> [SettingItem] {
        [
            SettingItem(id: .profile, label: "个人资料", action: .navigate(.profileDetails)),
            SettingItem(
                id: .accountSecurity,
                label: "账号与安全",
                description: profile.maskedPhone,
                action: .navigate(.accountSecurity)
            ),
            SettingItem(id: .notifications, label: "通知设置", action: .navigate(.notificationSettings)),
            SettingItem(id: .privacy, label: "隐私设置", action: .navigate(.privacySettings)),
        ]
    }

    private var supportSettings: [SettingItem] {
        [
            SettingItem(id: .helpAndFeedback, label: "帮助与反馈", action: .navigate(.helpAndFeedback)),
            SettingItem(id: .about, label: "关于 Walk", action: .navigate(.about)),
        ]
    }

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
                            if case let .navigate(destination) = item.action {
                                onNavigate(destination)
                            }
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
    enum AccountMenuSettingID: String, Hashable, CaseIterable {
        case profile
        case accountSecurity
        case notifications
        case privacy
        case helpAndFeedback
        case about
    }

    struct SettingItem: Identifiable {
        enum Action {
            case navigate(AppDestination)
        }

        let id: AccountMenuSettingID
        let label: String
        var description: String? = nil
        var action: Action = .navigate(.profileDetails)
    }
}

#if DEBUG
#Preview("AccountMenuView.modalSheet") {
    AccountMenuView(
        viewModel: ProfileViewModel(
            accountService: PreviewHelpers.accountService,
            tripService: PreviewHelpers.personalTripService,
            equipmentService: PreviewHelpers.equipmentService
        ),
        onClose: {},
        onNavigate: { _ in },
        onLoggedOut: {}
    )
    .background(AppColors.pageBase)
}
#endif
