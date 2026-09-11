import SwiftUI
import WalkData
import WalkDesignSystem

enum AccountMenuSettingID: String, Hashable, CaseIterable {
    case profile
    case accountSecurity
    case notifications
    case privacy
    case helpAndFeedback
    case about
}

struct AccountMenuSheet: View {
    let profile: ProfileProjection
    var avatarImage: Image? = nil
    var isLoggingOut = false
    var logoutError: String? = nil
    let onDismiss: () -> Void
    let onSelectSetting: (AccountMenuSettingID) -> Void
    let onLogout: () -> Void

    var body: some View {
        ModalBottomSheet(onDismiss: onDismiss) {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                identityHeader

                settingsGroup(title: "账户与设置", items: accountSettings)
                settingsGroup(title: "支持", items: supportSettings)

                if let logoutError {
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
                    isLoading: isLoggingOut,
                    fillsWidth: true,
                    action: onLogout
                )
                .padding(.top, Spacing.md)
            }
        }
    }

    private var identityHeader: some View {
        ZStack(alignment: .topTrailing) {
            AccountEquipmentBusinessComponents.ProfileIdentityHeader(
                profile: profile,
                avatarImage: avatarImage
            )
            .padding(.trailing, 40)

            IconButton(
                systemName: "xmark",
                accessibilityLabel: "关闭账号菜单",
                variant: .compactClose,
                action: onDismiss
            )
        }
    }

    private var accountSettings: [SettingItem] {
        [
            SettingItem(id: .profile, label: "个人资料"),
            SettingItem(id: .accountSecurity, label: "账号与安全", description: profile.maskedPhone),
            SettingItem(id: .notifications, label: "通知设置"),
            SettingItem(id: .privacy, label: "隐私设置"),
        ]
    }

    private var supportSettings: [SettingItem] {
        [
            SettingItem(id: .helpAndFeedback, label: "帮助与反馈"),
            SettingItem(id: .about, label: "关于 Walk"),
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
                        onActivate: onSelectSetting
                    )
                }
            }
            .background(AppColors.surfacePrimary)
            .clipShape(RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                    .stroke(AppColors.borderSubtle, lineWidth: 1)
            }
        }
    }
}

#if DEBUG
private struct AccountMenuSheetPreviewHost: View {
    let profile: ProfileProjection
    var avatarImage: Image? = nil
    var isLoggingOut = false
    var logoutError: String? = nil

    var body: some View {
        ZStack {
            AppColors.pageBase
                .ignoresSafeArea()
            AccountMenuSheet(
                profile: profile,
                avatarImage: avatarImage,
                isLoggingOut: isLoggingOut,
                logoutError: logoutError,
                onDismiss: {},
                onSelectSetting: { _ in },
                onLogout: {}
            )
        }
    }
}
#endif

private extension AccountMenuSheet {
    struct SettingItem {
        let id: AccountMenuSettingID
        let label: String
        var description: String? = nil
    }
}

#if DEBUG
#Preview("AccountMenuSheet.default") {
    AccountMenuSheetPreviewHost(
        profile: BusinessComponentPreviewFixtures.profileWithAvatar,
        avatarImage: Image(systemName: "person.crop.circle.fill")
    )
}

#Preview("AccountMenuSheet.logoutFailed") {
    AccountMenuSheetPreviewHost(
        profile: BusinessComponentPreviewFixtures.profileDefault,
        logoutError: BusinessComponentPreviewFixtures.operationError
    )
}
#endif
