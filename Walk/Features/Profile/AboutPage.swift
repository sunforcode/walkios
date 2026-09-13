import SwiftUI
import WalkData
import WalkDesignSystem

// MARK: - 关于页（任务栈页 + 共享内容）

struct AboutView: View {
    var body: some View {
        UtilityPage(title: "关于 Walk") {
            AboutContent()
        }
    }
}

struct AboutContent: View {
    private var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "开发版本"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            SurfaceElevated {
                Text("Walk 是一款面向徒步爱好者的行程规划应用，覆盖路线发现、行程创建与装备清单管理。")
                    .font(.appBody)
                    .foregroundStyle(AppColors.textPrimary)
                    .padding(Spacing.lg)
            }

            SurfaceElevated {
                Text("版本 \(version)")
                    .font(.appBody)
                    .foregroundStyle(AppColors.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
        }
    }
}
