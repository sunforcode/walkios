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
extension TransportOptionSelectionProjection {
    static let unselected = TransportOptionSelectionProjection(
        selectionID: "selection-1",
        options: [
            TransportOptionProjection(
                transportOptionID: "transport-1",
                transferCount: .available("换乘 2 次"),
                estimatedArrivalAt: .available("当日 18:20"),
                estimatedDuration: .available("约 8.5 小时"),
                verificationItems: ["康定客运站换乘时刻", "高原段接驳车辆需提前预约"]
            ),
            TransportOptionProjection(
                transportOptionID: "transport-2",
                transferCount: .available("换乘 1 次"),
                estimatedArrivalAt: .available("次日 09:10"),
                estimatedDuration: .available("约 15 小时"),
                verificationItems: ["夜宿康定的住宿确认", "次日早班客运班次需复核"]
            ),
            TransportOptionProjection(
                transportOptionID: "transport-3",
                transferCount: .available("换乘 0 次"),
                estimatedArrivalAt: .available("当日 16:40"),
                estimatedDuration: .available("约 7 小时"),
                verificationItems: ["包车同行人数与费用分摊"]
            ),
        ],
        selectedTransportOptionID: nil
    )

    static let selected = TransportOptionSelectionProjection(
        selectionID: "selection-1",
        options: [
            TransportOptionProjection(
                transportOptionID: "transport-1",
                transferCount: .available("换乘 2 次"),
                estimatedArrivalAt: .available("当日 18:20"),
                estimatedDuration: .available("约 8.5 小时"),
                verificationItems: ["康定客运站换乘时刻", "高原段接驳车辆需提前预约"]
            ),
            TransportOptionProjection(
                transportOptionID: "transport-2",
                transferCount: .available("换乘 1 次"),
                estimatedArrivalAt: .available("次日 09:10"),
                estimatedDuration: .available("约 15 小时"),
                verificationItems: ["夜宿康定的住宿确认"]
            ),
        ],
        selectedTransportOptionID: "transport-2"
    )

    static let partial = TransportOptionSelectionProjection(
        selectionID: "selection-1",
        options: [
            TransportOptionProjection(
                transportOptionID: "transport-1",
                transferCount: .available("换乘 2 次"),
                estimatedArrivalAt: .unavailable("到达时间待核验"),
                estimatedDuration: .available("约 8.5 小时"),
                verificationItems: ["康定客运站换乘时刻"]
            ),
            TransportOptionProjection(
                transportOptionID: "transport-2",
                transferCount: .unavailable("换乘次数未知"),
                estimatedArrivalAt: .available("次日 09:10"),
                estimatedDuration: .unavailable("用时不可用"),
                verificationItems: ["夜宿康定的住宿确认", "次日早班客运班次需复核"]
            ),
        ],
        selectedTransportOptionID: nil
    )

    static let long = TransportOptionSelectionProjection(
        selectionID: "selection-1",
        options: [
            TransportOptionProjection(
                transportOptionID: "transport-1",
                transferCount: .available("换乘 3 次"),
                estimatedArrivalAt: .available("次日 11:40，含中途休整"),
                estimatedDuration: .available("约 17.5 小时"),
                verificationItems: [
                    "首段高铁班次需在出发当日复核",
                    "中转城市客运站换乘间隔预留 50 分钟",
                    "高原段夜间禁行，需在康定过夜",
                    "末段接驳车辆需提前一日确认司机与车牌",
                    "备选返程班次在雨季可能取消"
                ]
            ),
            TransportOptionProjection(
                transportOptionID: "transport-2",
                transferCount: .available("换乘 1 次"),
                estimatedArrivalAt: .available("次日 09:10"),
                estimatedDuration: .available("约 15 小时"),
                verificationItems: ["夜宿康定的住宿确认", "次日早班客运班次需复核"]
            ),
        ],
        selectedTransportOptionID: nil
    )
}

#Preview("TransportOptionSelection.unselected") {
    BusinessComponentPreviewHost {
        SharedBusinessComponents.TransportOptionSelection(
            projection: TransportOptionSelectionProjection.unselected,
            onSelectTransportOption: { _ in }
        )
    }
}

#Preview("TransportOptionSelection.selected") {
    BusinessComponentPreviewHost {
        SharedBusinessComponents.TransportOptionSelection(
            projection: TransportOptionSelectionProjection.selected,
            onSelectTransportOption: { _ in }
        )
    }
}

#Preview("TransportOptionSelection.partial") {
    BusinessComponentPreviewHost {
        SharedBusinessComponents.TransportOptionSelection(
            projection: TransportOptionSelectionProjection.partial,
            onSelectTransportOption: { _ in }
        )
    }
}

#Preview("TransportOptionSelection.longContent") {
    BusinessComponentPreviewHost {
        SharedBusinessComponents.TransportOptionSelection(
            projection: TransportOptionSelectionProjection.long,
            onSelectTransportOption: { _ in }
        )
    }
}
#endif
