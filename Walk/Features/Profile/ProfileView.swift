import SwiftUI

/// 个人中心页
struct ProfileView: View {
    @StateObject private var viewModel: ProfileViewModel

    init(
        tripRepository: any TripRepository,
        apiStorage: (any APIStorage)? = nil,
        storageGeneration: APIStorageGeneration? = nil
    ) {
        _viewModel = StateObject(wrappedValue: ProfileViewModel(
            tripRepository: tripRepository,
            clearCachedResponses: {
                await storageGeneration?.invalidate()
                try? await apiStorage?.removeAll()
            }
        ))
    }

    var body: some View {
        Group {
            if viewModel.isLoading {
                LoadingView()
            } else if let error = viewModel.errorMessage {
                ErrorView(message: error) {
                    Task { await viewModel.loadProfile() }
                }
            } else {
                profileContent
            }
        }
        .navigationTitle("我的")
    }

    private var profileContent: some View {
        ScrollView {
            VStack(spacing: Spacing.legacyMd) {
                // 用户信息卡片
                userInfoCard

                // 统计信息
                statsSection

                // 设置菜单
                settingsSection
            }
            .padding(.horizontal, Spacing.legacyMd)
            .padding(.vertical, Spacing.sm)
        }
        .background(Color.groupedBackground)
        .task {
            await viewModel.loadProfile()
        }
    }

    private var userInfoCard: some View {
        HStack(spacing: Spacing.legacyMd) {
            // 头像
            Circle()
                .fill(Color.cardBackground)
                .frame(width: 64, height: 64)
                .overlay(
                    Image(systemName: "person.fill")
                        .foregroundColor(.textSecondary)
                        .font(.title)
                )

            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(viewModel.user?.displayName ?? "游客")
                    .font(.headline)
                    .foregroundColor(.textPrimary)

                if let email = viewModel.user?.email {
                    Text(email)
                        .font(.caption)
                        .foregroundColor(.textSecondary)
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .foregroundColor(.textTertiary)
                .font(.caption)
        }
        .padding(Spacing.legacyMd)
        .background(Color.cardBackground)
        .cornerRadius(12)
    }

    private var statsSection: some View {
        HStack(spacing: Spacing.legacyMd) {
            StatCardView(
                title: "行程",
                value: "\(viewModel.tripCount)",
                icon: "map"
            )
            StatCardView(
                title: "路线",
                value: "\(viewModel.routeCount)",
                icon: "point.topleft.down.curvedto.point.bottomright.up"
            )
            StatCardView(
                title: "里程",
                value: "\(viewModel.totalDistance)",
                icon: "figure.hiking"
            )
        }
    }

    private var settingsSection: some View {
        VStack(spacing: 0) {
            SettingsRow(icon: "bell", title: "通知设置", showChevron: true) {
                // TODO: 跳转通知设置
            }

            Divider().padding(.leading, 44)

            SettingsRow(icon: "lock", title: "隐私设置", showChevron: true) {
                // TODO: 跳转隐私设置
            }

            Divider().padding(.leading, 44)

            SettingsRow(icon: "questionmark.circle", title: "帮助与反馈", showChevron: true) {
                // TODO: 跳转帮助
            }

            Divider().padding(.leading, 44)

            SettingsRow(icon: "info.circle", title: "关于", showChevron: true) {
                // TODO: 跳转关于页
            }

            if viewModel.isLoggedIn {
                Divider().padding(.leading, 44)

                SettingsRow(icon: "rectangle.portrait.and.arrow.right", title: "退出登录", showChevron: false, titleColor: .red) {
                    Task { await viewModel.logout() }
                }
            }
        }
        .background(Color.cardBackground)
        .cornerRadius(12)
    }
}

/// 设置行组件
struct SettingsRow: View {
    let icon: String
    let title: String
    let showChevron: Bool
    let titleColor: Color
    let action: () -> Void

    init(icon: String, title: String, showChevron: Bool = true, titleColor: Color = .textPrimary, action: @escaping () -> Void) {
        self.icon = icon
        self.title = title
        self.showChevron = showChevron
        self.titleColor = titleColor
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: Spacing.legacyMd) {
                Image(systemName: icon)
                    .foregroundColor(.textSecondary)
                    .frame(width: 20)

                Text(title)
                    .font(.body)
                    .foregroundColor(titleColor)

                Spacer()

                if showChevron {
                    Image(systemName: "chevron.right")
                        .foregroundColor(.textTertiary)
                        .font(.caption)
                }
            }
            .padding(Spacing.legacyMd)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#if DEBUG
#Preview("Profile - Logged In") {
    NavigationStack {
        ProfileView(tripRepository: PreviewTripRepository())
    }
}
#endif

#Preview("Profile - Guest") {
    NavigationStack {
        ScrollView {
            VStack(spacing: Spacing.legacyMd) {
                // Guest user info
                HStack(spacing: Spacing.legacyMd) {
                    Circle()
                        .fill(Color.cardBackground)
                        .frame(width: 64, height: 64)
                        .overlay(
                            Image(systemName: "person.fill")
                                .foregroundColor(.textSecondary)
                                .font(.title)
                        )
                    VStack(alignment: .leading) {
                        Text("游客")
                            .font(.headline)
                    }
                    Spacer()
                }
                .padding(Spacing.legacyMd)
                .background(Color.cardBackground)
                .cornerRadius(12)

                // Stats
                HStack(spacing: Spacing.legacyMd) {
                    StatCardView(title: "行程", value: "0", icon: "map")
                    StatCardView(title: "路线", value: "0", icon: "point.topleft.down.curvedto.point.bottomright.up")
                    StatCardView(title: "里程", value: "0", icon: "figure.hiking")
                }
            }
            .padding()
        }
        .background(Color.groupedBackground)
        .navigationTitle("我的")
    }
}
