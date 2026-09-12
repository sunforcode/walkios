import SwiftUI
import WalkData
import WalkDesignSystem

enum ProfileLayout {
    static let avatarSize = RootNavigation.minimumHitSize
}

struct ProfileView: View {
    @ObservedObject private var viewModel: ProfileViewModel
    private let onNavigate: (AppDestination) -> Void
    private let onAuthenticate: (PendingAuthIntent) -> Void
    private let onLoggedOut: () -> Void

    init(
        viewModel: ProfileViewModel,
        onNavigate: @escaping (AppDestination) -> Void = { _ in },
        onAuthenticate: @escaping (PendingAuthIntent) -> Void = { _ in },
        onLoggedOut: @escaping () -> Void = {}
    ) {
        self.viewModel = viewModel
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
    }

    private var signedInPageHeader: some View {
        HStack(alignment: .center, spacing: Spacing.lg) {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text("我的")
                    .font(.pageTitle)
                    .foregroundStyle(AppColors.textPrimary)
                    .lineLimit(1)

                Text("行程、装备与账户，都在这里")
                    .font(.appBody)
                    .foregroundStyle(AppColors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: Spacing.lg)

            if viewModel.isLoggedIn {
                avatarHeaderContent
            }
        }
        .frame(minHeight: 44, alignment: .center)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var avatarHeaderContent: some View {
        if viewModel.isAccountLoading && viewModel.account == nil {
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
                onNavigate(.accountMenu)
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
            title: "你的徒步记录，都在这里",
            message: "登录后查看个人行程、行程日历、个人装备和装备清单。",
            icon: "person.crop.circle",
            actionTitle: "登录",
            action: { onAuthenticate(.profile) }
        )
        .frame(maxWidth: .infinity, minHeight: 440)
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
}
