import SwiftUI

public struct DateInput: View {
    @Binding var value: Date
     public let label: String
     public var error: String? = nil
     public var isDisabled = false

     public var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text(label)
                .font(.label)
                .foregroundStyle(AppColors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            DatePicker(label, selection: $value, displayedComponents: .date)
                .labelsHidden()
                .datePickerStyle(.compact)
                .tint(AppColors.interactionPrimary)
                .foregroundStyle(isDisabled ? AppColors.textDisabled : AppColors.textPrimary)
                .padding(.horizontal, Spacing.lg)
                .frame(maxWidth: .infinity, minHeight: Spacing.xxl + Spacing.md, alignment: .leading)
                .background(AppColors.surfaceInput)
                .clipShape(RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                        .stroke(error == nil ? AppColors.borderSubtle : AppColors.danger, lineWidth: 1)
                }
                .disabled(isDisabled)
                .accessibilityLabel(label)

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
        value: Binding<Date>,
        label: String,
        error: String? = nil,
        isDisabled: Bool = false
    ) {
        self._value = value
        self.label = label
        self.error = error
        self.isDisabled = isDisabled
    }
}
