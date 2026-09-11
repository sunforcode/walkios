import SwiftUI

public enum AppTab: String, CaseIterable, Identifiable, Hashable {
    case home
    case routes
    case profile

    public var id: Self { self }

    public var title: String {
        switch self {
        case .home: "首页"
        case .routes: "路线"
        case .profile: "我的"
        }
    }

    public var systemImage: String {
        switch self {
        case .home: "house"
        case .routes: "map"
        case .profile: "person"
        }
    }
}


import SwiftUI

public struct PrimaryTabBarItem: Identifiable, Equatable {
     public let tab: AppTab

     public var id: AppTab { tab }
     public var title: String { tab.title }
     public var systemImage: String { tab.systemImage }

    public init(
        tab: AppTab
    ) {
        self.tab = tab
    }
}

public struct PrimaryTabBar: View {
     public let selectedTab: AppTab
     public let onSelect: (AppTab) -> Void

     public static let height: CGFloat = 64
     public static let cornerRadius: CGFloat = 22

    private let items = AppTab.allCases.map(PrimaryTabBarItem.init(tab:))

    public init(
        selectedTab: AppTab,
        onSelect: @escaping (AppTab) -> Void
    ) {
        self.selectedTab = selectedTab
        self.onSelect = onSelect
    }

     public var body: some View {
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
                    .frame(maxWidth: .infinity, minHeight: 44)
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
