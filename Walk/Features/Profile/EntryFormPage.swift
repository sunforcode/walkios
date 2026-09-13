import SwiftUI
import WalkData
import WalkDesignSystem

// MARK: - 登录 modal 同款页面壳（任务栈二级页）

struct EntryFormPage<Content: View>: View {
    let title: String
    let notice: String
    let guide: String?
    let pageTitle: String?
    let fieldSpacing: CGFloat
    @ViewBuilder let content: Content

    init(
        title: String,
        notice: String,
        guide: String? = nil,
        pageTitle: String? = nil,
        fieldSpacing: CGFloat = Spacing.lg,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.notice = notice
        self.guide = guide
        self.pageTitle = pageTitle
        self.fieldSpacing = fieldSpacing
        self.content = content()
    }

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// 登录 modal 同款背景：山脊底色层 + 极光呼吸动画（Reduce Motion 时不渲染动画层）。
    private var ridgeSceneBackground: some View {
        ZStack {
            NightRidgePaletteScene()

            if !reduceMotion {
                LoginAmbientAnimation()
            }
        }
        .ignoresSafeArea()
    }

    var body: some View {
        // 个人设置入口页与登录 modal 共用同一夜景山脊配色与极光呼吸层，观感完全对齐。
        // 标题区含 kicker（guide），由页面自带 PageTitleBlock 表达，壳的 title 插槽留空。
        UtilityPage(background: { ridgeSceneBackground }) {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                PageTitleBlock(
                    title: pageTitle ?? title,
                    kicker: guide,
                    description: notice
                )

                WalkPanel(variant: .default) {
                    VStack(alignment: .leading, spacing: fieldSpacing) {
                        content
                    }
                }
            }
            .frame(maxWidth: 600, alignment: .topLeading)
            .frame(maxWidth: .infinity, alignment: .top)
        }
    }
}
