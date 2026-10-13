import SwiftUI
import WalkData
import WalkDesignSystem

struct ProfileView: View {
    private let viewModel: ProfileViewModel
    private let onNavigate: (AppDestination) -> Void
    private let onOpenAccountMenu: () -> Void
    private let onAuthenticate: (PendingAuthIntent) -> Void
    private let onLoggedOut: () -> Void

    init(
        viewModel: ProfileViewModel,
        onNavigate: @escaping (AppDestination) -> Void = { _ in },
        onOpenAccountMenu: @escaping () -> Void = {},
        onAuthenticate: @escaping (PendingAuthIntent) -> Void = { _ in },
        onLoggedOut: @escaping () -> Void = {}
    ) {
        self.viewModel = viewModel
        self.onNavigate = onNavigate
        self.onOpenAccountMenu = onOpenAccountMenu
        self.onAuthenticate = onAuthenticate
        self.onLoggedOut = onLoggedOut
    }

    var body: some View {
        PageShell(
            title: "我的",
            description: "行程日历与账户",
            background: {
                ZStack {
                    AppColors.pageMiddle
                    if viewModel.isLoggedIn {
                        Image("MePageBackground")
                            .resizable()
                            .scaledToFill()
                        MePageBackgroundOverlay()
                    }
                }
            },
            titleTrailing: {
                avatarHeaderContent
            }
        ) {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    if viewModel.isLoggedIn {
                        signedInContent
                    } else {
                        guestContent
                            .frame(maxWidth: .infinity)
                    }
                }
                .padding(.bottom, 88)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .toolbar(.hidden, for: .navigationBar)
        .task { await viewModel.loadProfile() }
    }

    @ViewBuilder
    private var avatarHeaderContent: some View {
        if !viewModel.isLoggedIn {
            EmptyView()
        } else if viewModel.isAccountLoading && viewModel.account == nil {
            AvatarButton(
                variant: .pageHeader,
                state: .loading,
                accessibilityLabel: "账号信息加载中"
            ) {}
        } else if let profile = viewModel.account?.profile {
            AvatarButton(
                avatarLabel: profile.nickname,
                variant: .pageHeader,
                accessibilityLabel: "打开个人与设置"
            ) {
                onOpenAccountMenu()
            }
        } else {
            AvatarButton(
                variant: .pageHeader,
                state: .unavailable,
                accessibilityLabel: "账号信息加载失败，重试"
            ) {
                Task { await viewModel.retryAccount() }
            }
        }
    }

    private var guestContent: some View {
        EmptyStateView(
            title: "登录后查看行程日历与账户",
            message: "登录后可以查看行程日历并管理个人资料。",
            icon: "person.crop.circle",
            actionTitle: "登录",
            action: { onAuthenticate(.profile) }
        )
        .frame(maxWidth: .infinity)
        .frame(minHeight: 440)
    }

    private var signedInContent: some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            VStack(alignment: .leading, spacing: Spacing.md) {
                tripCalendarSection
            }
        }
        .padding(.horizontal, Spacing.pageHorizontal)
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
            SharedBusinessComponents.TripCalendarCard(
                projection: ProfileCalendarPresentation(calendar: calendar).tripCalendarCardProjection,
                onActivate: { onNavigate(.tripList) }
            )
        }
    }

}
