import SwiftUI

public struct TextInput: View {
    @Binding var text: String
     public let label: String
     public let placeholder: String
     public var error: String? = nil
     public var isDisabled = false
     public var showsLabel = true
     public var submitLabel: SubmitLabel = .done
     public var horizontalPadding = Spacing.lg
     public var minimumHeight = Spacing.xxl + Spacing.md
    private let onSubmit: ((String) -> Void)?
    private let leading: AnyView?
    private let trailing: AnyView?

    @FocusState private var isFocused: Bool

     public init(
        text: Binding<String>,
        label: String,
        placeholder: String,
        error: String? = nil,
        isDisabled: Bool = false
    ) {
        self._text = text
        self.label = label
        self.placeholder = placeholder
        self.error = error
        self.isDisabled = isDisabled
        self.onSubmit = nil
        self.leading = nil
        self.trailing = nil
    }

    public init<Leading: View, Trailing: View>(
        text: Binding<String>,
        label: String,
        placeholder: String,
        error: String? = nil,
        isDisabled: Bool = false,
        showsLabel: Bool = true,
        submitLabel: SubmitLabel = .done,
        horizontalPadding: CGFloat = Spacing.lg,
        minimumHeight: CGFloat = Spacing.xxl + Spacing.md,
        onSubmit: ((String) -> Void)? = nil,
        @ViewBuilder leading: () -> Leading,
        @ViewBuilder trailing: () -> Trailing
    ) {
        self._text = text
        self.label = label
        self.placeholder = placeholder
        self.error = error
        self.isDisabled = isDisabled
        self.showsLabel = showsLabel
        self.submitLabel = submitLabel
        self.horizontalPadding = horizontalPadding
        self.minimumHeight = minimumHeight
        self.onSubmit = onSubmit
        self.leading = AnyView(leading())
        self.trailing = AnyView(trailing())
    }

     public var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            if showsLabel {
                Text(label)
                    .font(.label)
                    .foregroundStyle(AppColors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(spacing: Spacing.sm) {
                if let leading {
                    leading
                }

                TextField(placeholder, text: $text)
                    .font(.appBody)
                    .foregroundStyle(isDisabled ? AppColors.textDisabled : AppColors.textPrimary)
                    .tint(AppColors.interactionPrimary)
                    .focused($isFocused)
                    .submitLabel(submitLabel)
                    .onSubmit { onSubmit?(text) }
                    .accessibilityLabel(label)

                if let trailing {
                    trailing
                }
            }
            .padding(.horizontal, horizontalPadding)
            .frame(maxWidth: .infinity, minHeight: minimumHeight, alignment: .leading)
            .background(AppColors.surfaceInput)
            .clipShape(RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                    .stroke(borderColor, lineWidth: isFocused && error == nil ? 2 : 1)
            }
            .disabled(isDisabled)

            if let error {
                Text(error)
                    .font(.appCaption)
                    .foregroundStyle(AppColors.danger)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .opacity(isDisabled ? 0.55 : 1)
    }

    private var borderColor: Color {
        if error != nil { return AppColors.danger }
        if isFocused { return AppColors.interactionFocus }
        return AppColors.borderSubtle
    }
}
