import SwiftUI

struct DateInput: View {
    @Binding var value: Date
    let label: String
    var error: String? = nil
    var isDisabled = false

    var body: some View {
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
}
