import SwiftUI
import WalkData
import WalkDesignSystem

enum AccountEquipmentBusinessComponents {
    /// 设置主页身份头部：左侧用户名（昵称缺失时显示身份）与必有脱敏手机号，
    /// 右侧 48 逻辑点圆形头像选择入口。只输出 selectAvatar，不解析身份、
    /// 不加载媒体、不决定导航；头像更新中禁用入口，失败保持兜底内容。
    struct ProfileIdentityHeader: View {
        enum AvatarState {
            case ready
            case updating
            case failed
        }

        let profile: ProfileProjection
        var avatarImage: Image? = nil
        var avatarState: AvatarState = .ready
        let onSelectAvatar: () -> Void

        var body: some View {
            HStack(alignment: .center, spacing: Spacing.md) {
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text(profile.nickname ?? "Walk 用户")
                        .font(.identityTitle)
                        .foregroundStyle(AppColors.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                        .lineLimit(1)

                    Text(profile.maskedPhone)
                        .font(.micro)
                        .foregroundStyle(AppColors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Button(action: onSelectAvatar) {
                    ZStack {
                        Circle()
                            .fill(AppColors.surfaceElevated)
                            .frame(width: 48, height: 48)

                        if avatarState == .updating {
                            ProgressView()
                                .tint(AppColors.textPrimary)
                        } else if let avatarImage {
                            avatarImage
                                .resizable()
                                .scaledToFill()
                                .frame(width: 48, height: 48)
                                .clipShape(Circle())
                        } else {
                            Image(systemName: "person.crop.circle")
                                .font(.ornament(24, weight: .regular))
                                .foregroundStyle(AppColors.textSecondary)
                        }
                    }
                    .overlay {
                        Circle().stroke(AppColors.borderSubtle, lineWidth: 1)
                    }
                    .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .disabled(avatarState == .updating)
                .opacity(avatarState == .updating ? 0.55 : 1)
                .accessibilityLabel("更换头像")
                .accessibilityHint(avatarState == .failed ? "上次头像更新失败，可重试" : "")
            }
        }
    }
}

#if DEBUG
#Preview("ProfileIdentityHeader.default") {
    BusinessComponentPreviewHost {
        AccountEquipmentBusinessComponents.ProfileIdentityHeader(
            profile: BusinessComponentPreviewFixtures.profileDefault,
            onSelectAvatar: {}
        )
    }
}

#Preview("ProfileIdentityHeader.minimal") {
    BusinessComponentPreviewHost {
        AccountEquipmentBusinessComponents.ProfileIdentityHeader(
            profile: BusinessComponentPreviewFixtures.profileMinimal,
            onSelectAvatar: {}
        )
    }
}
#endif
