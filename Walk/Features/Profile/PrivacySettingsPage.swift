import SwiftUI
import WalkData
import WalkDesignSystem

// MARK: - 隐私设置页（任务栈页 + 共享内容）

struct PrivacySettingsView: View {
    var body: some View {
        UtilityPage(title: "隐私设置") {
            PrivacySettingsContent()
        }
    }
}

struct PrivacySettingsContent: View {
    @State private var profileVisible = true
    @State private var locationSharingEnabled = false
    @State private var anonymousAnalyticsEnabled = false

    var body: some View {
        SurfaceElevated {
            EntryToggle(title: EntryPageContract.privacyOptions[0], isOn: $profileVisible)
                .padding(.horizontal, Spacing.lg)
            Rectangle()
                .fill(AppColors.surfaceDivider)
                .frame(height: 1)
            EntryToggle(title: EntryPageContract.privacyOptions[1], isOn: $locationSharingEnabled)
                .padding(.horizontal, Spacing.lg)
            Rectangle()
                .fill(AppColors.surfaceDivider)
                .frame(height: 1)
            EntryToggle(title: EntryPageContract.privacyOptions[2], isOn: $anonymousAnalyticsEnabled)
                .padding(.horizontal, Spacing.lg)
        }
    }
}
