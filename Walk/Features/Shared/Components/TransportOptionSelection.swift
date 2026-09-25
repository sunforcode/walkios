import SwiftUI
import WalkData
import WalkDesignSystem

enum TransportOptionFactState: Equatable {
    case available(String)
    case unavailable(String)

    var displayText: String? {
        switch self {
        case .available(let value): value
        case .unavailable: nil
        }
    }

    var unavailableLabel: String? {
        switch self {
        case .available: nil
        case .unavailable(let label): label
        }
    }
}

struct TransportOptionProjection: Equatable, Identifiable {
    let transportOptionID: String
    let transferCount: TransportOptionFactState
    let estimatedArrivalAt: TransportOptionFactState
    let estimatedDuration: TransportOptionFactState
    let verificationItems: [String]

    var id: String { transportOptionID }
}

struct TransportOptionSelectionProjection: Equatable {
    let selectionID: String
    let options: [TransportOptionProjection]
    let selectedTransportOptionID: String?
}

extension SharedBusinessComponents {
    struct TransportOptionSelection: View {
        let projection: TransportOptionSelectionProjection
        let onSelectTransportOption: (String) -> Void

        var body: some View {
            VStack(alignment: .leading, spacing: Spacing.md) {
                NoticeView(
                    message: "服务端返回多个不可忽略的衔接方案，选择一个后继续生成。",
                    title: "需要选择交通方案",
                    tone: .warning
                )

                VStack(spacing: Spacing.sm) {
                    ForEach(Array(projection.options.enumerated()), id: \.element.id) { index, option in
                        optionCard(index: index, option: option)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .contain)
        }

        private func optionCard(index: Int, option: TransportOptionProjection) -> some View {
            let isSelected = projection.selectedTransportOptionID == option.transportOptionID
            return SelectableOptionCard(
                isSelected: isSelected,
                action: { onSelectTransportOption(option.transportOptionID) }
            ) {
                HStack(alignment: .top, spacing: Spacing.md) {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.navTitle)
                        .foregroundStyle(AppColors.interactionPrimary)
                        .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        Text("交通方案 \(index + 1)")
                            .font(.cardTitle)
                            .foregroundStyle(AppColors.textPrimary)
                            .accessibilityAddTraits(.isHeader)

                        factLine(label: "预计到达", value: option.estimatedArrivalAt)
                        factLine(label: "预计用时", value: option.estimatedDuration)
                        factLine(label: "换乘次数", value: option.transferCount)

                        if !option.verificationItems.isEmpty {
                            VStack(alignment: .leading, spacing: Spacing.xs) {
                                Text("待核验")
                                    .font(.micro)
                                    .foregroundStyle(AppColors.textWeak)
                                ForEach(Array(option.verificationItems.enumerated()), id: \.offset) { _, item in
                                    Text("· \(item)")
                                        .font(.appCaption)
                                        .foregroundStyle(AppColors.textSecondary)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }

        @ViewBuilder
        private func factLine(label: String, value: TransportOptionFactState) -> some View {
            if let displayText = value.displayText {
                HStack(alignment: .firstTextBaseline, spacing: Spacing.xs) {
                    Text(label)
                        .font(.micro)
                        .foregroundStyle(AppColors.textWeak)
                    Text(displayText)
                        .font(.appCaption)
                        .foregroundStyle(AppColors.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            } else if let status = value.unavailableLabel {
                HStack(alignment: .firstTextBaseline, spacing: Spacing.xs) {
                    Text(label)
                        .font(.micro)
                        .foregroundStyle(AppColors.textWeak)
                    Text(status)
                        .font(.appCaption)
                        .foregroundStyle(AppColors.warning)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }
}

#if DEBUG
#Preview("TransportOptionSelection.unselected") {
    BusinessComponentPreviewHost {
        SharedBusinessComponents.TransportOptionSelection(
            projection: BusinessComponentPreviewFixtures.transportSelectionUnselected,
            onSelectTransportOption: { _ in }
        )
    }
}

#Preview("TransportOptionSelection.selected") {
    BusinessComponentPreviewHost {
        SharedBusinessComponents.TransportOptionSelection(
            projection: BusinessComponentPreviewFixtures.transportSelectionSelected,
            onSelectTransportOption: { _ in }
        )
    }
}

#Preview("TransportOptionSelection.partial") {
    BusinessComponentPreviewHost {
        SharedBusinessComponents.TransportOptionSelection(
            projection: BusinessComponentPreviewFixtures.transportSelectionPartial,
            onSelectTransportOption: { _ in }
        )
    }
}

#Preview("TransportOptionSelection.longContent") {
    BusinessComponentPreviewHost {
        SharedBusinessComponents.TransportOptionSelection(
            projection: BusinessComponentPreviewFixtures.transportSelectionLong,
            onSelectTransportOption: { _ in }
        )
    }
}
#endif
