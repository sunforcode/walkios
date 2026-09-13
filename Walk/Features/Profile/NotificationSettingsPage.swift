import SwiftUI
import WalkData
import WalkDesignSystem

// MARK: - 通知设置页（任务栈页 + 共享内容）

struct NotificationSettingsView: View {
    var body: some View {
        UtilityPage(title: "通知设置") {
            NotificationSettingsContent()
        }
    }
}

struct NotificationSettingsContent: View {
    @State private var notificationsEnabled = false
    @State private var tripRemindersEnabled = false
    @State private var weatherRemindersEnabled = false

    var body: some View {
        SurfaceElevated {
            EntryToggle(title: EntryPageContract.notificationOptions[0], isOn: $notificationsEnabled)
                .padding(.horizontal, Spacing.lg)
            Rectangle()
                .fill(AppColors.surfaceDivider)
                .frame(height: 1)
            EntryToggle(title: EntryPageContract.notificationOptions[1], isOn: $tripRemindersEnabled)
                .disabled(!notificationsEnabled)
                .padding(.horizontal, Spacing.lg)
            Rectangle()
                .fill(AppColors.surfaceDivider)
                .frame(height: 1)
            EntryToggle(title: EntryPageContract.notificationOptions[2], isOn: $weatherRemindersEnabled)
                .disabled(!notificationsEnabled)
                .padding(.horizontal, Spacing.lg)
        }
    }
}
