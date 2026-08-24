import SwiftUI

/// 统计卡片组件
struct StatCardView: View {
    let title: String
    let value: String
    let icon: String?
    let trend: String?

    init(title: String, value: String, icon: String? = nil, trend: String? = nil) {
        self.title = title
        self.value = value
        self.icon = icon
        self.trend = trend
    }

    var body: some View {
        WalkPanel {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                HStack(spacing: Spacing.sm) {
                    if let icon {
                        Image(systemName: icon)
                            .foregroundStyle(AppColors.accent)
                            .font(.nav)
                    }
                    Text(title)
                        .font(.label)
                        .foregroundStyle(AppColors.textSecondary)
                }

                Text(value)
                    .font(.section)
                    .foregroundStyle(AppColors.textPrimary)

                if let trend {
                    Text(trend)
                        .font(.caption)
                        .foregroundStyle(AppColors.statusProgress)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .appShadow(AppShadow.floating)
    }
}

#Preview {
    UtilityPageContainer {
        StatCardView(title: "总行程", value: "12", icon: "map", trend: "+2 本月")
            .padding()
    }
}
