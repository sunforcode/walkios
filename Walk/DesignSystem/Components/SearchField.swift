import SwiftUI
import UIKit

struct SearchField: View {
    @Binding var text: String
    let placeholder: String
    var label = "搜索"
    var isDisabled = false
    var onQueryChange: ((String) -> Void)? = nil
    var onSubmit: (() -> Void)? = nil
    var onClear: (() -> Void)? = nil

    init(
        text: Binding<String>,
        placeholder: String,
        label: String = "搜索",
        isDisabled: Bool = false,
        onQueryChange: ((String) -> Void)? = nil,
        onSubmit: (() -> Void)? = nil,
        onClear: (() -> Void)? = nil
    ) {
        self._text = text
        self.placeholder = placeholder
        self.label = label
        self.isDisabled = isDisabled
        self.onQueryChange = onQueryChange
        self.onSubmit = onSubmit
        self.onClear = onClear
    }

    var body: some View {
        TextInput(
            text: $text,
            label: label,
            placeholder: placeholder,
            isDisabled: isDisabled,
            showsLabel: false,
            submitLabel: .search,
            horizontalPadding: Spacing.md,
            minimumHeight: Spacing.xxxl,
            onSubmit: { _ in onSubmit?() }
        ) {
            Image(systemName: "magnifyingglass")
                .font(.navTitle)
                .foregroundStyle(AppColors.textWeak)
                .accessibilityHidden(true)
        } trailing: {
            if !text.isEmpty {
                Button(action: clearQuery) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.action)
                        .foregroundStyle(AppColors.textWeak)
                        .frame(width: Spacing.navBarHeight, height: Spacing.navBarHeight)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(isDisabled)
                .accessibilityLabel("清除搜索")
            }
        }
        .onChange(of: text) { value in
            onQueryChange?(value)
        }
    }

    private func clearQuery() {
        text = ""
        onClear?()
        UIAccessibility.post(notification: .announcement, argument: "搜索已清除")
    }
}

#if DEBUG
#Preview("SearchField.empty") {
    SearchField(
        text: .constant(""),
        placeholder: ComponentPreviewFixtures.searchPlaceholder,
        onSubmit: {}
    )
    .padding(Spacing.lg)
    .background(AppColors.pageBase)
}

#Preview("SearchField.editing") {
    SearchField(
        text: .constant(ComponentPreviewFixtures.searchQuery),
        placeholder: ComponentPreviewFixtures.searchPlaceholder,
        onQueryChange: { _ in }
    )
    .padding(Spacing.lg)
    .background(AppColors.pageBase)
}

#Preview("SearchField.submitting") {
    SearchField(
        text: .constant(ComponentPreviewFixtures.searchQuery),
        placeholder: ComponentPreviewFixtures.searchPlaceholder,
        onSubmit: {}
    )
    .padding(Spacing.lg)
    .background(AppColors.pageBase)
}

#Preview("SearchField.long") {
    SearchField(
        text: .constant(ComponentPreviewFixtures.longSearchQuery),
        placeholder: ComponentPreviewFixtures.searchPlaceholder,
        onSubmit: {}
    )
    .padding(Spacing.lg)
    .background(AppColors.pageBase)
}
#endif
