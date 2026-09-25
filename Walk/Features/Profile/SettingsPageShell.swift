import SwiftUI
import WalkData
import WalkDesignSystem

// MARK: - 二级设置共享行控件（栈页与 Modal 内部层级共用同一生产实现）
// 页面骨架由 WalkDesignSystem 统一壳 `UtilityPage` 承载，本文件仅保留行控件与表面。

/// 二级设置页浅层 Section 表面：比页面背景浅的填充 + 细描边，圆角卡片。
struct SurfaceElevated<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) { content }
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                    .fill(AppColors.surfaceElevated)
            )
            .clipShape(RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                    .stroke(AppColors.borderSubtle, lineWidth: 1)
            }
    }
}

/// 左右信息行：左侧标题、右侧内容；`showsDivider` 在行底绘制横线分隔。
/// 传 `value` 时右侧展示文本，否则展示自定义 `trailing` 内容。
struct EntrySettingsRow<Trailing: View>: View {
    let title: String
    var showsDivider: Bool = false
    private let valueText: String?
    @ViewBuilder let trailing: () -> Trailing

    init(
        title: String,
        value: String? = nil,
        showsDivider: Bool = false,
        @ViewBuilder trailing: @escaping () -> Trailing
    ) {
        self.title = title
        self.showsDivider = showsDivider
        self.valueText = value
        self.trailing = trailing
    }

    init(title: String, value: String?, showsDivider: Bool = false) where Trailing == EmptyView {
        self.init(title: title, value: value, showsDivider: showsDivider) {
            EmptyView()
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: Spacing.md) {
                Text(title)
                    .font(.appBody)
                    .foregroundStyle(AppColors.textPrimary)
                Spacer()
                if let valueText, !valueText.isEmpty {
                    Text(valueText)
                        .font(.appBody)
                        .foregroundStyle(AppColors.textSecondary)
                        .multilineTextAlignment(.trailing)
                } else {
                    trailing()
                }
            }
            .padding(.horizontal, Spacing.lg)
            .frame(minHeight: HitTarget.minimum)

            if showsDivider {
                Rectangle()
                    .fill(AppColors.surfaceDivider)
                    .frame(height: 1)
            }
        }
    }
}

struct EntryTextField: View {
    let title: String
    @Binding var text: String
    var keyboardType: UIKeyboardType = .default

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text(title)
                .font(.appCaption)
                .foregroundStyle(AppColors.textSecondary)
            TextField(title, text: $text)
                .font(.appBody)
                .keyboardType(keyboardType)
                .textInputAutocapitalization(keyboardType == .emailAddress ? .never : .sentences)
                .padding(Spacing.md)
                .foregroundStyle(AppColors.textPrimary)
                .background(AppColors.surfaceInput, in: RoundedRectangle(cornerRadius: Radius.md))
                .accessibilityLabel(title)
        }
    }
}

struct EntryTextEditor: View {
    let title: String
    @Binding var text: String

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text(title)
                .font(.appCaption)
                .foregroundStyle(AppColors.textSecondary)
            TextEditor(text: $text)
                .scrollContentBackground(.hidden)
                .frame(minHeight: 120)
                .padding(Spacing.sm)
                .foregroundStyle(AppColors.textPrimary)
                .background(AppColors.surfaceElevated, in: RoundedRectangle(cornerRadius: Radius.md))
                .accessibilityLabel(title)
        }
    }
}

struct EntryToggle: View {
    let title: String
    @Binding var isOn: Bool

    var body: some View {
        Toggle(title, isOn: $isOn)
            .tint(AppColors.interactionPrimary)
            .foregroundStyle(AppColors.textPrimary)
            .frame(minHeight: HitTarget.minimum)
            .accessibilityLabel(title)
    }
}
