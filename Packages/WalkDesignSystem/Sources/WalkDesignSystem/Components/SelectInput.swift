import SwiftUI

public struct SelectInputOption<Value: Hashable>: Identifiable {
     public let value: Value
     public let label: String

     public var id: Value { value }

    public init(
        value: Value,
        label: String
    ) {
        self.value = value
        self.label = label
    }
}

public struct SelectInput<Value: Hashable>: View {
    @Binding var selection: Value?
     public let label: String
     public let placeholder: String
     public let options: [SelectInputOption<Value>]
     public var error: String? = nil
     public var isDisabled = false

     public var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text(label)
                .font(.label)
                .foregroundStyle(AppColors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            Picker(label, selection: $selection) {
                Text(placeholder)
                    .tag(Optional<Value>.none)
                ForEach(options) { option in
                    Text(option.label)
                        .tag(Optional(option.value))
                }
            }
            .pickerStyle(.menu)
            .font(.appBody)
            .tint(isDisabled ? AppColors.textDisabled : AppColors.interactionPrimary)
            .padding(.horizontal, Spacing.lg)
            .frame(maxWidth: .infinity, minHeight: Spacing.xxl + Spacing.md, alignment: .leading)
            .background(AppColors.surfaceInput)
            .clipShape(RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                    .stroke(error == nil ? AppColors.borderSubtle : AppColors.danger, lineWidth: 1)
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

    public init(
        selection: Binding<Value?>,
        label: String,
        placeholder: String,
        options: [SelectInputOption<Value>],
        error: String? = nil,
        isDisabled: Bool = false
    ) {
        self._selection = selection
        self.label = label
        self.placeholder = placeholder
        self.options = options
        self.error = error
        self.isDisabled = isDisabled
    }
}
