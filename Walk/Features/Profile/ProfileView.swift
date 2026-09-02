import SwiftUI

enum ProfileLayout {
    static let avatarSize = RootNavigation.minimumHitSize
}

struct ProfileView: View {
    @StateObject private var viewModel: ProfileViewModel
    @State private var isSettingsPresented = false
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
                LazyVStack(alignment: .leading, spacing: Spacing.xl) {
                    profileHeader
                    if !viewModel.isLoggedIn {
                        guestContent
                    } else if viewModel.isLoading && viewModel.account == nil {
                        LoadingView().frame(minHeight: 220)
                    } else {
                        loggedInContent
                    }
                }
                .padding(.horizontal, Spacing.pageHorizontal)
                .padding(.top, Spacing.xl)
                .padding(.bottom, Spacing.xxl)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .task { await viewModel.loadProfile() }
        .sheet(isPresented: $isSettingsPresented) {
            ProfileSettingsPanel(
                account: viewModel.account,
                onNavigate: {
                    isSettingsPresented = false
                    onNavigate($0)
                },
                onLogout: {
                    Task {
                        await viewModel.logout()
                        if !viewModel.isLoggedIn { onLoggedOut() }
                    }
                }
            )
            .presentationDetents([.large])
        }
    }

    private var profileHeader: some View {
        HStack(alignment: .top, spacing: Spacing.md) {
            PageHeroHeader(
                title: "我的",
                subtitle: viewModel.isLoggedIn ? "管理你的行程与徒步装备" : "登录后管理个人行程与徒步装备"
            )
            if viewModel.isLoggedIn {
                Button { isSettingsPresented = true } label: { profileAvatar }
                    .buttonStyle(.plain)
                    .disabled(viewModel.account == nil)
                    .accessibilityLabel("个人与设置")
            }
        }
    }

    private var guestContent: some View {
        WalkPanel {
            VStack(alignment: .leading, spacing: Spacing.md) {
                Text("登录后可查看行程日历、个人装备和账号资料。")
                    .foregroundStyle(AppColors.textSecondary)
                Button("登录") { onAuthenticate(.profile) }
                    .buttonStyle(.borderedProminent)
                    .tint(AppColors.interactionPrimary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var loggedInContent: some View {
        VStack(alignment: .leading, spacing: Spacing.xl) {
            if let errorMessage = viewModel.errorMessage {
                ErrorView(message: errorMessage) {
                    Task { await viewModel.loadProfile() }
                }
            }
            tripCalendarSection
            equipmentSection
        }
    }

    private var tripCalendarSection: some View {
        Button { onNavigate(.tripList) } label: {
            WalkPanel {
                VStack(alignment: .leading, spacing: Spacing.md) {
                    HStack {
                        Text("行程日历").font(.sectionTitle)
                        Spacer()
                        Image(systemName: "chevron.right").foregroundStyle(AppColors.textWeak)
                    }
                    if let calendar = viewModel.tripCalendar {
                        ProfileCalendarHeatmap(calendar: calendar)
                        Text("\(calendar.windowStartDate.description) 至 \(calendar.windowEndDate.description)")
                            .font(.caption)
                            .foregroundStyle(AppColors.textWeak)
                    } else if let error = viewModel.calendarErrorMessage {
                        Text(error)
                            .foregroundStyle(AppColors.statusCancelled)
                    } else {
                        ProfileCalendarHeatmap(calendar: ProfileCalendarHeatmap.emptyCalendar)
                        Text("最近 365 天暂无行程")
                            .foregroundStyle(AppColors.textWeak)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .buttonStyle(.plain)
    }

    private var equipmentSection: some View {
        Button { onNavigate(.personalEquipment) } label: {
            WalkPanel {
                VStack(alignment: .leading, spacing: Spacing.md) {
                    HStack {
                        Text("我的装备").font(.sectionTitle)
                        Spacer()
                        Image(systemName: "chevron.right").foregroundStyle(AppColors.textWeak)
                    }
                    if let summary = viewModel.equipmentSummary {
                        Text("\(summary.equipmentItemCount) 类装备 · \(summary.equipmentListCount) 份清单")
                            .foregroundStyle(AppColors.textSecondary)
                        Text("已知总重量 \(profileWeightText(summary.knownTotalWeight.grams)) · \(summary.missingWeightItemCount) 类重量未填写")
                            .font(.caption)
                            .foregroundStyle(AppColors.textWeak)
                    } else if let error = viewModel.equipmentErrorMessage {
                        Text(error)
                            .foregroundStyle(AppColors.statusCancelled)
                    } else {
                        Text("0 类装备 · 0 份清单")
                            .foregroundStyle(AppColors.textSecondary)
                        Text("已知总重量 0 g · 0 类重量未填写")
                            .font(.caption)
                            .foregroundStyle(AppColors.textWeak)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var profileAvatar: some View {
        if let value = viewModel.account?.profile.avatar, let url = URL(string: value) {
            AsyncImage(url: url) { phase in
                if let image = phase.image { image.resizable().scaledToFill() } else { defaultAvatar }
            }
            .frame(width: ProfileLayout.avatarSize, height: ProfileLayout.avatarSize)
            .clipShape(Circle())
        } else {
            defaultAvatar
        }
    }

    private var defaultAvatar: some View {
        Image(systemName: "person.fill")
            .font(.nav)
            .foregroundStyle(AppColors.textSecondary)
            .frame(width: ProfileLayout.avatarSize, height: ProfileLayout.avatarSize)
            .background(AppColors.surfacePrimary, in: Circle())
    }
}

private struct ProfileCalendarHeatmap: View {
    let calendar: PersonalTripCalendar
    private let rows = Array(repeating: GridItem(.fixed(10), spacing: 3), count: 7)

    static var emptyCalendar: PersonalTripCalendar {
        let end = LocalDate(date: BusinessCalendar.startOfToday(), calendar: .business)
        let startDate = end.dateAtStartOfDay.flatMap {
            Calendar.business.date(byAdding: .day, value: -364, to: $0)
        } ?? BusinessCalendar.startOfToday()
        return PersonalTripCalendar(
            windowStartDate: LocalDate(date: startDate, calendar: .business),
            windowEndDate: end,
            days: []
        )
    }

    var body: some View {
        let presentation = ProfileCalendarPresentation(calendar: calendar)
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHGrid(rows: rows, spacing: 3) {
                ForEach(presentation.days) { day in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(day.tripCount == 0
                              ? AppColors.surfaceDivider
                              : AppColors.interactionPrimary.opacity(min(1, 0.35 + Double(day.tripCount) * 0.2)))
                        .frame(width: 10, height: 10)
                        .accessibilityLabel("\(day.date.description)，\(day.tripCount) 趟行程")
                }
            }
        }
        .frame(height: 88)
        .allowsHitTesting(false)
        .accessibilityElement(children: .contain)
    }
}

private struct ProfileSettingsPanel: View {
    let account: AccountResponse?
    let onNavigate: (AppDestination) -> Void
    let onLogout: () -> Void

    var body: some View {
        NavigationStack {
            List {
                if let profile = account?.profile {
                    Section {
                        Text(profile.nickname ?? "昵称未填写")
                        Text(profile.maskedPhone).foregroundStyle(AppColors.textSecondary)
                    }
                    Section("账户与设置") {
                        SettingsRow(icon: "person.crop.circle", title: "个人资料") { onNavigate(.profileDetails) }
                        SettingsRow(icon: "lock.shield", title: "账号与安全") { onNavigate(.accountSecurity) }
                        SettingsRow(icon: "bell", title: "通知设置") { onNavigate(.notificationSettings) }
                        SettingsRow(icon: "lock", title: "隐私设置") { onNavigate(.privacySettings) }
                    }
                }
                Section("支持") {
                    SettingsRow(icon: "questionmark.circle", title: "帮助与反馈") { onNavigate(.helpAndFeedback) }
                    SettingsRow(icon: "info.circle", title: "关于") { onNavigate(.about) }
                }
                Section {
                    SettingsRow(
                        icon: "rectangle.portrait.and.arrow.right",
                        title: "退出登录",
                        showChevron: false,
                        titleColor: AppColors.statusCancelled,
                        action: onLogout
                    )
                }
            }
            .scrollContentBackground(.hidden)
            .background(AppColors.pageBase)
            .navigationTitle("个人与设置")
        }
    }
}

struct SettingsRow: View {
    let icon: String
    let title: String
    let showChevron: Bool
    let titleColor: Color
    let action: () -> Void

    init(
        icon: String,
        title: String,
        showChevron: Bool = true,
        titleColor: Color = AppColors.textPrimary,
        action: @escaping () -> Void
    ) {
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
                    .foregroundStyle(AppColors.textSecondary)
                    .frame(width: 20)
                Text(title).foregroundStyle(titleColor)
                Spacer()
                if showChevron {
                    Image(systemName: "chevron.right")
                        .foregroundStyle(AppColors.textWeak)
                        .font(.caption)
                }
            }
            .frame(minHeight: RootNavigation.toolButtonHitSize)
        }
        .buttonStyle(.plain)
    }
}

private func profileWeightText(_ grams: Int) -> String {
    grams >= 1_000
        ? "\((Double(grams) / 1_000).formatted(.number.precision(.fractionLength(0...2)))) kg"
        : "\(grams) g"
}
