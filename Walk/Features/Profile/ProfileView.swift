import SwiftUI
import WalkData
import WalkDesignSystem

enum ProfileLayout {
    static let avatarSize = RootNavigation.minimumHitSize
}

struct ProfileView: View {
    @StateObject private var viewModel: ProfileViewModel
    @State private var isSettingsPresented = false
    @State private var settingsDestination: AppDestination?
    private let onNavigate: (AppDestination) -> Void
    private let onAuthenticate: (PendingAuthIntent) -> Void
    private let onLoggedOut: () -> Void

    init(
        onNavigate: @escaping (AppDestination) -> Void = { _ in },
        onAuthenticate: @escaping (PendingAuthIntent) -> Void = { _ in },
        accountService: any AccountServicing,
        tripService: any PersonalTripServicing,
        equipmentService: any EquipmentServicing,
        apiStorage: (any APIStorage)? = nil,
        storageGeneration: APIStorageGeneration? = nil,
        onLoggedOut: @escaping () -> Void = {}
    ) {
        self.onNavigate = onNavigate
        self.onAuthenticate = onAuthenticate
        self.onLoggedOut = onLoggedOut
        _viewModel = StateObject(wrappedValue: ProfileViewModel(
            accountService: accountService,
            tripService: tripService,
            equipmentService: equipmentService,
            clearCachedResponses: {
                await storageGeneration?.invalidate()
                try? await apiStorage?.removeAll()
            }
        ))
    }

    init(
        viewModel: ProfileViewModel,
        onNavigate: @escaping (AppDestination) -> Void = { _ in },
        onAuthenticate: @escaping (PendingAuthIntent) -> Void = { _ in },
        onLoggedOut: @escaping () -> Void = {}
    ) {
        _viewModel = StateObject(wrappedValue: viewModel)
        self.onNavigate = onNavigate
        self.onAuthenticate = onAuthenticate
        self.onLoggedOut = onLoggedOut
    }

    var body: some View {
        UtilityPageContainer {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: Spacing.lg) {
                    if viewModel.isLoggedIn {
                        signedInPageHeader
                        signedInContent
                    } else {
                        PageTitleBlock(
                            title: "我的",
                            description: "登录后管理行程与徒步装备"
                        )
                        guestContent
                    }
                }
                .frame(maxWidth: 600, alignment: .topLeading)
                .frame(maxWidth: .infinity, alignment: .top)
                .padding(.horizontal, Spacing.pageHorizontal)
                .padding(.top, Spacing.lg)
                .padding(.bottom, 88)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .task { await viewModel.loadProfile() }
        .onChange(of: viewModel.isLoggedIn) { isLoggedIn in
            if !isLoggedIn {
                isSettingsPresented = false
            }
        }
        .fullScreenCover(isPresented: $isSettingsPresented, onDismiss: completeSettingsNavigation) {
            if let account = viewModel.account {
                AccountMenuSheet(
                    profile: account.profile,
                    avatarImage: nil,
                    isLoggingOut: viewModel.isLoggingOut,
                    logoutError: viewModel.logoutErrorMessage,
                    onDismiss: { isSettingsPresented = false },
                    onSelectSetting: { settingID in
                        settingsDestination = destination(for: settingID)
                        isSettingsPresented = false
                    },
                    onLogout: {
                        Task {
                            await viewModel.logout()
                            if !viewModel.isLoggedIn {
                                isSettingsPresented = false
                            }
                        }
                    }
                )
            }
        }
    }

    private var signedInPageHeader: some View {
        HStack(alignment: .center, spacing: Spacing.lg) {
            Text("我的")
                .font(.ornament(31, weight: .bold))
                .foregroundStyle(AppColors.textPrimary)
                .lineLimit(1)

            Spacer(minLength: Spacing.lg)

            if viewModel.isLoggedIn {
                avatarHeaderContent
            }
        }
        .frame(minHeight: 44)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var avatarHeaderContent: some View {
        if viewModel.isAccountLoading && viewModel.account == nil {
            ProgressView()
                .tint(AppColors.interactionPrimary)
                .frame(width: 44, height: 44)
                .accessibilityLabel("账号信息加载中")
        } else if let profile = viewModel.account?.profile {
            AvatarButton(
                avatarLabel: profile.nickname,
                variant: .pageHeader,
                accessibilityLabel: "个人与设置"
            ) {
                isSettingsPresented = true
            }
        } else {
            IconButton(
                systemName: "arrow.clockwise",
                accessibilityLabel: "重新加载账号信息"
            ) {
                Task { await viewModel.retryAccount() }
            }
            .accessibilityHint(viewModel.accountErrorMessage ?? "账号信息加载失败")
        }
    }

    private var guestContent: some View {
        EmptyStateView(
            title: "你的徒步记录，都在这里",
            message: "登录后可以查看最近一年的行程分布，维护长期个人装备与装备清单。",
            icon: "person.crop.circle",
            actionTitle: "登录",
            action: { onAuthenticate(.profile) }
        )
        .frame(maxWidth: .infinity, minHeight: 420)
    }

    private var signedInContent: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            tripCalendarSection
            equipmentSection
        }
    }

    @ViewBuilder
    private var tripCalendarSection: some View {
        if viewModel.isCalendarLoading && viewModel.tripCalendar == nil {
            LoadingView(message: "正在加载行程日历", variant: .section)
                .frame(minHeight: 96)
        } else if let error = viewModel.calendarErrorMessage {
            ErrorView(
                message: error,
                title: "行程日历加载失败",
                variant: .section,
                retry: { Task { await viewModel.retryCalendar() } }
            )
        } else if let calendar = viewModel.tripCalendar {
            TripBusinessComponents.TripCalendarCard(
                projection: ProfileCalendarPresentation(calendar: calendar).tripCalendarCardProjection,
                onActivate: { onNavigate(.tripList) }
            )
        }
    }

    @ViewBuilder
    private var equipmentSection: some View {
        if viewModel.isEquipmentLoading && viewModel.equipmentSummary == nil {
            LoadingView(message: "正在加载装备概况", variant: .section)
                .frame(minHeight: 96)
        } else if let error = viewModel.equipmentErrorMessage {
            ErrorView(
                message: error,
                title: "装备概况加载失败",
                variant: .section,
                retry: { Task { await viewModel.retryEquipment() } }
            )
        } else if let summary = viewModel.equipmentSummary {
            PersonalEquipmentSummaryCard(
                summary: summary,
                onActivate: { onNavigate(.personalEquipment) }
            )
        }
    }

    private func completeSettingsNavigation() {
        if let destination = settingsDestination {
            settingsDestination = nil
            onNavigate(destination)
        } else if !viewModel.isLoggedIn {
            onLoggedOut()
        }
    }

    private func destination(for settingID: AccountMenuSettingID) -> AppDestination {
        switch settingID {
        case .profile: .profileDetails
        case .accountSecurity: .accountSecurity
        case .notifications: .notificationSettings
        case .privacy: .privacySettings
        case .helpAndFeedback: .helpAndFeedback
        case .about: .about
        }
    }
}
