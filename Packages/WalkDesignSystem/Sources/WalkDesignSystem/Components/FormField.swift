import SwiftUI

public enum FormFieldRequirement {
    case none
    case required
    case optional

     public var label: String? {
        switch self {
        case .none: nil
        case .required: "必填"
        case .optional: "选填"
        }
    }
}

public struct FormField<Control: View>: View {
     public let label: String
     public var requirement: FormFieldRequirement = .none
     public var assistiveText: String? = nil
     public var error: String? = nil
     public var isFocused = false
    private let control: Control

     public init(
        label: String,
        requirement: FormFieldRequirement = .none,
        assistiveText: String? = nil,
        error: String? = nil,
        isFocused: Bool = false,
        @ViewBuilder control: () -> Control
    ) {
        self.label = label
        self.requirement = requirement
        self.assistiveText = assistiveText
        self.error = error
        self.isFocused = isFocused
        self.control = control()
    }

     public var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack(spacing: Spacing.xs) {
                Text(label)
                    .font(.label)
                    .foregroundStyle(AppColors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                if let requirementLabel = requirement.label {
                    Text(requirementLabel)
                        .font(.micro)
                        .foregroundStyle(requirement == .required ? AppColors.warning : AppColors.textWeak)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            control
                .font(.appBody)
                .foregroundStyle(AppColors.textPrimary)
                .padding(.horizontal, Spacing.lg)
                .frame(maxWidth: .infinity, minHeight: Spacing.xxxl, alignment: .leading)
                .background(AppColors.surfaceInput)
                .clipShape(RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                        .stroke(borderColor, lineWidth: error == nil && isFocused ? 1.5 : 1)
                }

            if let error {
                Text(error)
                    .font(.appCaption)
                    .foregroundStyle(AppColors.danger)
                    .fixedSize(horizontal: false, vertical: true)
            } else if let assistiveText {
                Text(assistiveText)
                    .font(.appCaption)
                    .foregroundStyle(AppColors.textWeak)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var borderColor: Color {
        if error != nil { return AppColors.danger }
        if isFocused { return AppColors.interactionFocus }
        return AppColors.borderSubtle
    }
}

#if DEBUG
#Preview("FormField.default") {
    FormField(label: ComponentPreviewFixtures.formLabel, requirement: .required) {
        TextField(ComponentPreviewFixtures.formPlaceholder, text: .constant(""))
    }
    .padding(Spacing.lg)
    .background(AppColors.pageBase)
}

#Preview("FormField.helper") {
    FormField(
        label: ComponentPreviewFixtures.formLabel,
        requirement: .optional,
        assistiveText: ComponentPreviewFixtures.formHelper
    ) {
        TextField(ComponentPreviewFixtures.formPlaceholder, text: .constant(ComponentPreviewFixtures.formValue))
    }
    .padding(Spacing.lg)
    .background(AppColors.pageBase)
}

#Preview("FormField.focused") {
    FormField(
        label: ComponentPreviewFixtures.formLabel,
        requirement: .required,
        assistiveText: ComponentPreviewFixtures.formHelper,
        isFocused: true
    ) {
        TextField(ComponentPreviewFixtures.formPlaceholder, text: .constant(ComponentPreviewFixtures.formValue))
    }
    .padding(Spacing.lg)
    .background(AppColors.pageBase)
}

#Preview("FormField.error") {
    FormField(
        label: ComponentPreviewFixtures.formLabel,
        requirement: .required,
        error: ComponentPreviewFixtures.formError
    ) {
        TextField(ComponentPreviewFixtures.formPlaceholder, text: .constant(""))
    }
    .padding(Spacing.lg)
    .background(AppColors.pageBase)
}
#endif
