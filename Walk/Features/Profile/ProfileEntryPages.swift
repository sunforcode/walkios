import SwiftUI
import PhotosUI

@MainActor
final class ProfileDetailsViewModel: ObservableObject {
    @Published private(set) var profile: ProfileProjection?
    @Published var nickname = ""
    @Published private(set) var isLoading = false
    @Published private(set) var isSaving = false
    @Published var errorMessage: String?

    private let accountService: any AccountServicing

    init(accountService: any AccountServicing) {
        self.accountService = accountService
    }

    func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let account = try await accountService.currentAccount()
            apply(account.profile)
        } catch {
            errorMessage = Self.message(for: error)
        }
    }

    func saveNickname() async {
        let trimmed = nickname.trimmingCharacters(in: .whitespacesAndNewlines)
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }
        do {
            let response = try await accountService.updateProfile(
                ProfileUpdate(nickname: trimmed.isEmpty ? .clear : .value(trimmed))
            )
            apply(response.profile)
        } catch {
            errorMessage = Self.message(for: error)
        }
    }

    func updateAvatar(data: Data, contentType: String) async {
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }
        do {
            let media = try await accountService.uploadAvatar(data: data, contentType: contentType)
            let response = try await accountService.updateProfile(
                ProfileUpdate(avatar: .value(media.mediaReference))
            )
            apply(response.profile)
        } catch {
            errorMessage = Self.message(for: error)
        }
    }

    private func apply(_ profile: ProfileProjection) {
        self.profile = profile
        nickname = profile.nickname ?? ""
    }

    private static func message(for error: Error) -> String {
        (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
    }
}

struct ProfileDetailsView: View {
    @StateObject private var viewModel: ProfileDetailsViewModel
    @State private var selectedPhoto: PhotosPickerItem?

    init(accountService: any AccountServicing) {
        _viewModel = StateObject(wrappedValue: ProfileDetailsViewModel(accountService: accountService))
    }

    var body: some View {
        EntryFormPage(title: "个人资料", notice: "昵称和头像保存到当前账号；脱敏手机号只读。") {
            EntryTextField(title: EntryPageContract.profileFields[0], text: $viewModel.nickname)

            VStack(alignment: .leading, spacing: Spacing.sm) {
                Text(EntryPageContract.profileFields[1])
                    .font(.appCaption)
                    .foregroundStyle(AppColors.textSecondary)
                Text(viewModel.profile?.maskedPhone ?? "加载中")
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(Spacing.md)
                    .foregroundStyle(AppColors.textSecondary)
                    .background(AppColors.surfaceElevated, in: RoundedRectangle(cornerRadius: Radius.md))
            }

            VStack(alignment: .leading, spacing: Spacing.sm) {
                Text(EntryPageContract.profileFields[2])
                    .font(.appCaption)
                    .foregroundStyle(AppColors.textSecondary)
                if let avatar = viewModel.profile?.avatar {
                    Text(avatar)
                        .font(.appCaption)
                        .foregroundStyle(AppColors.textWeak)
                        .textSelection(.enabled)
                } else {
                    Text("头像未设置")
                        .foregroundStyle(AppColors.textWeak)
                }
                PhotosPicker(selection: $selectedPhoto, matching: .images) {
                    Text("选择头像图片")
                }
                .buttonStyle(.bordered)
                .disabled(viewModel.isSaving)
            }

            Button("保存昵称") { Task { await viewModel.saveNickname() } }
                .buttonStyle(.borderedProminent)
                .tint(AppColors.interactionPrimary)
                .disabled(viewModel.isSaving || viewModel.isLoading)

            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
                    .font(.appCaption)
                    .foregroundStyle(AppColors.danger)
            }
        }
        .task { await viewModel.load() }
        .onChange(of: selectedPhoto) { item in
            guard let item else { return }
            Task {
                guard let data = try? await item.loadTransferable(type: Data.self) else {
                    viewModel.errorMessage = "无法读取所选头像"
                    return
                }
                await viewModel.updateAvatar(data: data, contentType: "image/jpeg")
            }
        }
    }
}

struct AccountSecurityView: View {
    @State private var maskedPhone: String?
    @State private var errorMessage: String?
    private let accountService: any AccountServicing

    init(accountService: any AccountServicing) {
        self.accountService = accountService
    }

    var body: some View {
        EntryFormPage(title: "账号与安全", notice: "手机号由服务端脱敏后展示。") {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                Text("手机号")
                    .font(.appCaption)
                    .foregroundStyle(AppColors.textSecondary)
                Text(maskedPhone ?? "加载中")
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(Spacing.md)
                    .foregroundStyle(AppColors.textPrimary)
                    .background(AppColors.surfaceElevated, in: RoundedRectangle(cornerRadius: Radius.md))
            }
            if let errorMessage {
                Text(errorMessage)
                    .font(.appCaption)
                    .foregroundStyle(AppColors.danger)
            }
        }
        .task {
            do {
                maskedPhone = try await accountService.currentAccount().profile.maskedPhone
            } catch {
                errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            }
        }
    }
}

struct NotificationSettingsView: View {
    @State private var notificationsEnabled = false
    @State private var tripRemindersEnabled = false
    @State private var weatherRemindersEnabled = false

    var body: some View {
        EntryFormPage(title: "通知设置", notice: "这些偏好当前不会保存。") {
            EntryToggle(title: EntryPageContract.notificationOptions[0], isOn: $notificationsEnabled)
            EntryToggle(title: EntryPageContract.notificationOptions[1], isOn: $tripRemindersEnabled)
                .disabled(!notificationsEnabled)
            EntryToggle(title: EntryPageContract.notificationOptions[2], isOn: $weatherRemindersEnabled)
                .disabled(!notificationsEnabled)
        }
    }
}

struct PrivacySettingsView: View {
    @State private var profileVisible = true
    @State private var locationSharingEnabled = false
    @State private var anonymousAnalyticsEnabled = false

    var body: some View {
        EntryFormPage(title: "隐私设置", notice: "这些偏好当前不会保存。") {
            EntryToggle(title: EntryPageContract.privacyOptions[0], isOn: $profileVisible)
            EntryToggle(title: EntryPageContract.privacyOptions[1], isOn: $locationSharingEnabled)
            EntryToggle(title: EntryPageContract.privacyOptions[2], isOn: $anonymousAnalyticsEnabled)
        }
    }
}

struct HelpAndFeedbackView: View {
    @State private var category = "功能建议"
    @State private var feedback = ""

    private let categories = ["功能建议", "使用问题", "内容反馈", "其他"]

    var body: some View {
        EntryFormPage(title: "帮助与反馈", notice: "反馈内容仅保留在本页面，当前不会提交。") {
            VStack(alignment: .leading, spacing: Spacing.md) {
                Text("常见问题")
                    .font(.navTitle)
                    .foregroundStyle(AppColors.textPrimary)
                Text("路线、行程和装备数据以当前页面显示为准；尚未开放的能力会明确标记。")
                    .font(.appBody)
                    .foregroundStyle(AppColors.textSecondary)
            }

            VStack(alignment: .leading, spacing: Spacing.sm) {
                Text(EntryPageContract.feedbackFields[0])
                    .font(.appCaption)
                    .foregroundStyle(AppColors.textSecondary)
                Picker(EntryPageContract.feedbackFields[0], selection: $category) {
                    ForEach(categories, id: \.self) { Text($0) }
                }
                .pickerStyle(.menu)
                .tint(AppColors.interactionPrimary)
            }

            EntryTextEditor(title: EntryPageContract.feedbackFields[1], text: $feedback)
        }
    }
}

struct AboutView: View {
    private var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "开发版本"
    }

    var body: some View {
        EntryFormPage(
            title: "关于",
            notice: "Walk 户外徒步旅行助手",
            pageTitle: "关于 Walk"
        ) {
            VStack(alignment: .leading, spacing: Spacing.md) {
                Label("路线、行程与装备规划", systemImage: "figure.hiking")
                Text("版本 \(version)")
                    .foregroundStyle(AppColors.textSecondary)
            }
            .foregroundStyle(AppColors.textPrimary)
        }
    }
}

struct EntryFormPage<Content: View>: View {
    let title: String
    let notice: String
    let guide: String?
    let pageTitle: String?
    let fieldSpacing: CGFloat
    @ViewBuilder let content: Content

    init(
        title: String,
        notice: String,
        guide: String? = nil,
        pageTitle: String? = nil,
        fieldSpacing: CGFloat = Spacing.lg,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.notice = notice
        self.guide = guide
        self.pageTitle = pageTitle
        self.fieldSpacing = fieldSpacing
        self.content = content()
    }

    var body: some View {
        UtilityPage {
            PageTitleBlock(
                title: pageTitle ?? title,
                kicker: guide,
                description: notice
            )

            WalkPanel(variant: .default) {
                VStack(alignment: .leading, spacing: fieldSpacing) {
                    content
                }
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct EntryTextField: View {
    let title: String
    @Binding var text: String
    var keyboardType: UIKeyboardType = .default

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text(title)
                .font(.appCaption)
                .foregroundStyle(AppColors.textSecondary)
            TextField(title, text: $text)
                .font(.appBody)
                .keyboardType(keyboardType)
                .textInputAutocapitalization(keyboardType == .emailAddress ? .never : .sentences)
                .padding(Spacing.md)
                .foregroundStyle(AppColors.textPrimary)
                .background(AppColors.surfaceInput, in: RoundedRectangle(cornerRadius: Radius.md))
                .accessibilityLabel(title)
        }
    }
}

struct EntryTextEditor: View {
    let title: String
    @Binding var text: String

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text(title)
                .font(.appCaption)
                .foregroundStyle(AppColors.textSecondary)
            TextEditor(text: $text)
                .scrollContentBackground(.hidden)
                .frame(minHeight: 120)
                .padding(Spacing.sm)
                .foregroundStyle(AppColors.textPrimary)
                .background(AppColors.surfaceElevated, in: RoundedRectangle(cornerRadius: Radius.md))
                .accessibilityLabel(title)
        }
    }
}

struct EntryToggle: View {
    let title: String
    @Binding var isOn: Bool

    var body: some View {
        Toggle(title, isOn: $isOn)
            .tint(AppColors.interactionPrimary)
            .foregroundStyle(AppColors.textPrimary)
            .frame(minHeight: RootNavigation.toolButtonHitSize)
            .accessibilityLabel(title)
    }
}
