import SwiftUI

struct SelectInputOption<Value: Hashable>: Identifiable {
    let value: Value
    let label: String

    var id: Value { value }
}

struct SelectInput<Value: Hashable>: View {
    @Binding var selection: Value?
    let label: String
    let placeholder: String
    let options: [SelectInputOption<Value>]
    var error: String? = nil
    var isDisabled = false

    var body: some View {
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
}
