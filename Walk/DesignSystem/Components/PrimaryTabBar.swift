import SwiftUI

struct PrimaryTabBarItem: Identifiable, Equatable {
    let tab: AppTab

    var id: AppTab { tab }
    var title: String { tab.title }
    var systemImage: String { tab.systemImage }
}

struct PrimaryTabBar: View {
    let selectedTab: AppTab
    let onSelect: (AppTab) -> Void

    static let height: CGFloat = 64
    static let cornerRadius: CGFloat = 22

    private let items = AppTab.allCases.map(PrimaryTabBarItem.init(tab:))

    var body: some View {
        HStack(spacing: 0) {
            ForEach(items) { item in
                Button {
                    onSelect(item.tab)
                } label: {
                    VStack(spacing: Spacing.xs) {
                        Image(systemName: item.systemImage)
                            .font(.navTitle)
                        Text(item.title)
                            .font(.tabLabel)
                    }
                    .foregroundStyle(item.tab == selectedTab ? AppColors.interactionPrimary : AppColors.textWeak)
                    .frame(maxWidth: .infinity, minHeight: RootNavigation.minimumHitSize)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(item.title)，标签页")
                .accessibilityAddTraits(item.tab == selectedTab ? [.isSelected] : [])
            }
        }
        .frame(height: Self.height)
        .background(
            AppColors.surfaceNavigation,
            in: RoundedRectangle(cornerRadius: Self.cornerRadius, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: Self.cornerRadius, style: .continuous)
                .stroke(AppColors.borderNavigation, lineWidth: 1)
        }
        .appShadow(AppShadow.navigation)
        .accessibilityElement(children: .contain)
    }
}

#if DEBUG
#Preview("home") {
    PrimaryTabBar(selectedTab: .home, onSelect: { _ in })
        .padding()
        .background(AppColors.pageBase)
}

#Preview("routes") {
    PrimaryTabBar(selectedTab: .routes, onSelect: { _ in })
        .padding()
        .background(AppColors.pageBase)
}

#Preview("me") {
    PrimaryTabBar(selectedTab: .profile, onSelect: { _ in })
        .padding()
        .background(AppColors.pageBase)
}
#endif
