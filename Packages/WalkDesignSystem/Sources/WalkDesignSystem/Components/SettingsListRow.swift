import SwiftUI

public struct SettingsListRow<ID: Hashable>: View {
     public let id: ID
     public let label: String
     public var description: String? = nil
     public var showsDivider = true
     public let onActivate: (ID) -> Void

     public var body: some View {
        Button {
            onActivate(id)
        } label: {
            HStack(alignment: .center, spacing: Spacing.md) {
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text(label)
                        .font(.label)
                        .foregroundStyle(AppColors.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)

                    if let description {
                        Text(description)
                            .font(.metricCompactLabel)
                            .foregroundStyle(AppColors.textWeak)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Image(systemName: "chevron.right")
                    .font(.appCaption)
                    .foregroundStyle(AppColors.textWeak)
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.sm)
            .frame(maxWidth: .infinity, minHeight: 52, alignment: .leading)
            .contentShape(Rectangle())
            .overlay(alignment: .bottom) {
                if showsDivider {
                    Rectangle()
                        .fill(AppColors.surfaceDivider)
                        .frame(height: 1)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
    }

    public init(
        id: ID,
        label: String,
        description: String? = nil,
        showsDivider: Bool = true,
        onActivate: @escaping (ID) -> Void
    ) {
        self.id = id
        self.label = label
        self.description = description
        self.showsDivider = showsDivider
        self.onActivate = onActivate
    }
}
