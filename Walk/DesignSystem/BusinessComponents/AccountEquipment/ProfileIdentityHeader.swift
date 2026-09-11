import SwiftUI

struct ProfileIdentityHeaderProjection: Equatable {
    let nickname: String?
    let maskedPhone: String
    let hasAvatar: Bool

    init(nickname: String?, maskedPhone: String, hasAvatar: Bool) {
        self.nickname = nickname
        self.maskedPhone = maskedPhone
        self.hasAvatar = hasAvatar
    }

    init(profile: ProfileProjection) {
        self.init(
            nickname: profile.nickname,
            maskedPhone: profile.maskedPhone,
            hasAvatar: profile.avatar != nil
        )
    }
}

enum AccountEquipmentBusinessComponents {
    struct ProfileIdentityHeader: View {
        let projection: ProfileIdentityHeaderProjection
        var avatarImage: Image? = nil

        init(projection: ProfileIdentityHeaderProjection, avatarImage: Image? = nil) {
            self.projection = projection
            self.avatarImage = avatarImage
        }

        init(profile: ProfileProjection, avatarImage: Image? = nil) {
            self.init(projection: ProfileIdentityHeaderProjection(profile: profile), avatarImage: avatarImage)
        }

        var body: some View {
            HStack(alignment: .center, spacing: Spacing.md) {
                if projection.hasAvatar, let avatarImage {
                    avatarImage
                        .resizable()
                        .scaledToFill()
                        .frame(width: 48, height: 48)
                        .clipShape(Circle())
                        .accessibilityHidden(true)
                }

                VStack(alignment: .leading, spacing: Spacing.xs) {
                    if let nickname = projection.nickname {
                        Text(nickname)
                            .font(.identityTitle)
                            .foregroundStyle(AppColors.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Text(projection.maskedPhone)
                        .font(.micro)
                        .foregroundStyle(AppColors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .accessibilityElement(children: .combine)
        }
    }
}

#if DEBUG
#Preview("ProfileIdentityHeader.default") {
    BusinessComponentPreviewHost {
        AccountEquipmentBusinessComponents.ProfileIdentityHeader(
            profile: BusinessComponentPreviewFixtures.profileDefault
        )
    }
}

#Preview("ProfileIdentityHeader.minimal") {
    BusinessComponentPreviewHost {
        AccountEquipmentBusinessComponents.ProfileIdentityHeader(
            profile: BusinessComponentPreviewFixtures.profileMinimal
        )
    }
}
#endif
