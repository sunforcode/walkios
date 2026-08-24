import SwiftUI

struct DrawerView: View {
    let userDisplay: DrawerUserDisplay
    let onNavigate: (RootDestination) -> Void
    let onProfile: () -> Void

    private let columns = Array(
        repeating: GridItem(.flexible(), spacing: DrawerStyle.gridGap),
        count: DrawerStyle.columnCount
    )

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            brand

            LazyVGrid(columns: columns, spacing: DrawerStyle.gridGap) {
                ForEach(DrawerItem.allCases) { item in
                    drawerCell(item)
                }
            }
            .padding(.horizontal, 16)

            Spacer(minLength: 16)

            Divider()
                .overlay(AppColors.border)
                .padding(.horizontal, 24)

            Button(action: onProfile) {
                HStack(spacing: 12) {
                    Circle()
                        .fill(AppColors.surfaceGlass)
                        .frame(width: 36, height: 36)
                        .overlay {
                            Image(systemName: "person.fill")
                                .font(.system(size: 15, weight: .semibold))
                        }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(userDisplay.title)
                            .font(.system(size: 14, weight: .semibold))
                        Text(userDisplay.subtitle)
                            .font(.system(size: 11))
                            .foregroundStyle(AppColors.textWeak)
                    }

                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppColors.textWeak)
                }
                .foregroundStyle(AppColors.textPrimary)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
            .accessibilityLabel(userDisplay.accessibilityLabel)
        }
        .frame(width: RootNavigation.drawerWidth)
        .background(DrawerStyle.backgroundColor)
        .foregroundStyle(AppColors.textPrimary)
    }

    private var brand: some View {
        VStack(alignment: .leading, spacing: DrawerStyle.brandSpacing) {
            Text(DrawerStyle.brandTitle)
                .font(.system(size: DrawerStyle.brandTitleFontSize, weight: DrawerStyle.brandTitleFontWeight))
                .tracking(2)
            Text(DrawerStyle.brandSubtitle)
                .font(.system(size: 12))
                .foregroundStyle(DrawerStyle.brandSubtitleColor)
        }
        .padding(.leading, 24)
        .padding(.top, 12)
        .padding(.bottom, 24)
    }

    private func drawerCell(_ item: DrawerItem) -> some View {
        Button {
            guard let destination = item.destination else { return }
            onNavigate(destination)
        } label: {
            VStack(spacing: 8) {
                Image(systemName: item.systemImage)
                    .font(.system(size: 20, weight: .medium))
                Text(item.title)
                    .font(.system(size: 12, weight: .medium))
                    .lineLimit(1)
            }
            .foregroundStyle(item.isAvailable ? AppColors.textPrimary : AppColors.textWeak)
            .frame(maxWidth: .infinity)
            .aspectRatio(DrawerStyle.cellAspectRatio, contentMode: .fit)
            .background(AppColors.surfaceCard)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(AppColors.border, lineWidth: DrawerStyle.cellBorderWidth)
            }
        }
        .buttonStyle(.plain)
        .disabled(!item.isAvailable)
        .accessibilityLabel(item.isAvailable ? item.title : "\(item.title)，即将推出")
    }
}

extension DrawerUserDisplay {
    var title: String {
        switch self {
        case .loggedOut: return "未登录"
        case .loading: return "加载中..."
        case let .user(user): return user.displayName
        }
    }

    var subtitle: String {
        switch self {
        case .loggedOut: return "登录后查看个人主页"
        case .loading: return "正在加载用户信息"
        case .user: return "查看个人主页"
        }
    }

    var accessibilityLabel: String {
        switch self {
        case .loggedOut: return "未登录"
        case .loading: return "正在加载用户信息"
        case let .user(user): return "个人主页，\(user.displayName)"
        }
    }
}
