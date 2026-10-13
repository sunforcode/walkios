import SwiftUI
import WalkData
import WalkDesignSystem

struct CreateTripRouteSummaryPresentation: Equatable {
    let title: String
    let facts: [String]
    let generationUnavailableMessage: String?
    let componentProjection: GenerationRouteSummaryProjection

    init(route: PersonalTripGenerationRoute) {
        let routeType = route.routeType == "one_day" ? "一日路线" : "多日路线"
        let distance = route.distance.map { meters in
            meters.meters >= 1_000
                ? "\((meters.meters / 1_000).formatted(.number.precision(.fractionLength(0...1)))) km"
                : "\(Int(meters.meters.rounded())) m"
        }
        let estimatedDuration = route.estimatedDuration.map {
            "\(($0.seconds / 3_600).formatted(.number.precision(.fractionLength(0...1)))) 小时"
        }
        let generationUnavailableMessage = RouteGenerationEligibilityPresentation(
            eligibility: route.generationEligibility
        ).unavailableMessage

        title = route.name ?? "已选路线"
        facts = [
            route.versionLabel,
            routeType,
            route.region,
            route.difficulty,
            route.start.flatMap { start in route.end.map { "\(start.name) → \($0.name)" } },
            distance,
            estimatedDuration,
        ].compactMap { $0 }
        self.generationUnavailableMessage = generationUnavailableMessage
        componentProjection = GenerationRouteSummaryProjection(
            routeType: routeType,
            generationEligibility: generationUnavailableMessage == nil
                ? .eligible(label: "可生成")
                : .ineligible(label: "资料不足"),
            name: route.name,
            versionLabel: route.versionLabel,
            region: route.region,
            start: route.start?.name,
            end: route.end?.name,
            difficulty: route.difficulty,
            distance: distance,
            estimatedDuration: estimatedDuration
        )
    }
}

struct CreateTripEquipmentListPresentation: Equatable {
    let text: String

    init(option: PersonalTripGenerationEquipmentListOption) {
        let summary = option.summary
        text = "\(option.name) · \(summary.itemCount) 类 · 已知总重量 \(AccountEquipmentFormatting.decimalText(summary.knownTotalWeight.grams)) 克 · \(summary.missingWeightItemCount) 类未计入重量"
    }
}

struct CreateTripView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: CreateTripViewModel
    @State private var submissionTask: Task<Void, Never>?
    @State private var isVisible = false
    @FocusState private var isDepartureCityFocused: Bool
    private let onManagePersonalEquipment: () -> Void
    private let onTripCreated: (String) -> Void

    init(
        routeID: String,
        service: any PersonalTripServicing,
        onManagePersonalEquipment: @escaping () -> Void = {},
        onTripCreated: @escaping (String) -> Void = { _ in }
    ) {
        _viewModel = State(initialValue: CreateTripViewModel(
            routeID: routeID,
            service: service
        ))
        self.onManagePersonalEquipment = onManagePersonalEquipment
        self.onTripCreated = onTripCreated
    }

    init(
        viewModel: CreateTripViewModel,
        onManagePersonalEquipment: @escaping () -> Void = {},
        onTripCreated: @escaping (String) -> Void = { _ in }
    ) {
        _viewModel = State(initialValue: viewModel)
        self.onManagePersonalEquipment = onManagePersonalEquipment
        self.onTripCreated = onTripCreated
    }

    var body: some View {
        Group {
            if viewModel.isSubmitting && viewModel.createdTripID == nil {
                generatingView
            } else if let context = viewModel.context {
                if context.route.generationEligibility.eligible {
                    inputPage(context: context)
                } else {
                    ineligiblePage(context: context)
                }
            } else {
                initialStatePage
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .task { await viewModel.handleAppearance() }
        .onAppear { isVisible = true }
        .onDisappear {
            isVisible = false
            submissionTask?.cancel()
        }
    }

    private func submitTrip() {
        guard isVisible, submissionTask == nil, viewModel.canSubmit else { return }
        // Button tasks are unstructured: disappearance cancels explicitly, but
        // the handle and model write lock stay held until the request returns.
        submissionTask = Task { @MainActor in
            defer { submissionTask = nil }
            await viewModel.submit()
            guard !Task.isCancelled, isVisible, let tripID = viewModel.createdTripID else { return }
            onTripCreated(tripID)
        }
    }

    private var generatingView: some View {
        UtilityPageContainer {
            SharedBusinessComponents.GenerationWaitingView(
                projection: GenerationWaitingProjection(
                    title: "正在组织你的出行信息",
                    description: "请稍候，完成后将直接进入个人行程。"
                )
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var initialStatePage: some View {
        UtilityPage(title: "生成行程") {
            Group {
                if viewModel.isLoading {
                    LoadingView(message: "正在准备生成上下文", variant: .page)
                } else if viewModel.errorMessage != nil {
                    ErrorView(
                        message: "没有把失败当作空装备或不可生成路线。",
                        title: "暂时无法准备生成",
                        variant: .page,
                        retry: { Task { await viewModel.load() } }
                    )
                }
            }
            .frame(maxWidth: 600, minHeight: 320)
        }
    }

    private func ineligiblePage(context: PersonalTripGenerationContext) -> some View {
        UtilityPage(title: "生成行程") {
            VStack(alignment: .leading, spacing: Spacing.md) {
                SharedBusinessComponents.GenerationRouteSummaryCard(
                    projection: CreateTripRouteSummaryPresentation(route: context.route).componentProjection
                )
                ForEach(Array((context.route.generationEligibility.missingReasons ?? []).enumerated()), id: \.offset) { _, reason in
                    NoticeView(
                        message: generationMissingReasonText(reason),
                        title: "路线暂不可生成",
                        tone: .warning
                    )
                }
            }
            .frame(maxWidth: 600, alignment: .topLeading)
            .frame(maxWidth: .infinity, alignment: .top)
        }
    }

    private func inputPage(context: PersonalTripGenerationContext) -> some View {
        UtilityPage(
            title: "生成行程",
            bottomFixed: {
                PrimaryAction(
                    title: submitTitle,
                    isDisabled: !viewModel.canSubmit,
                    fillsWidth: true,
                    action: submitTrip
                )
            }
        ) {
            VStack(alignment: .leading, spacing: Spacing.xl) {
                SharedBusinessComponents.GenerationRouteSummaryCard(
                    projection: CreateTripRouteSummaryPresentation(route: context.route).componentProjection
                )
                requiredInputs(routeType: context.route.routeType)
                equipmentSection(context)

                if let selection = viewModel.transportSelection {
                    transportSection(selection)
                }

                if viewModel.isVersionConflict {
                    versionConflictRegion
                    if let error = viewModel.errorMessage {
                        ErrorView(
                            message: error,
                            title: "暂时无法读取最新版本",
                            variant: .form
                        )
                    }
                } else if let error = viewModel.errorMessage {
                    ErrorView(
                        message: "\(error)\n已保留本次填写内容。",
                        title: "生成未完成",
                        variant: .form,
                        retry: submitTrip
                    )
                }
            }
            .frame(maxWidth: 600, alignment: .topLeading)
            .frame(maxWidth: .infinity, alignment: .top)
        }
    }

    private func requiredInputs(routeType: String) -> some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            FormField(
                label: "出发城市",
                requirement: .required,
                error: viewModel.departureCityError,
                isFocused: isDepartureCityFocused
            ) {
                TextField("输入出发城市", text: Binding(get: { viewModel.departureCity }, set: viewModel.updateDepartureCity))
                    .textInputAutocapitalization(.words)
                    .submitLabel(.done)
                    .focused($isDepartureCityFocused)
                    .tint(AppColors.interactionPrimary)
            }

            FormField(label: "从出发城市启程的日期", requirement: .required) {
                DatePicker(
                    "从出发城市启程的日期",
                    selection: Binding(get: { viewModel.startDate }, set: viewModel.updateStartDate),
                    displayedComponents: .date
                )
                .labelsHidden()
                .environment(\.calendar, .business)
                .environment(\.timeZone, BusinessCalendar.timeZone)
                .tint(AppColors.interactionPrimary)
            }

            NoticeView(
                message: routeType == "one_day"
                    ? "一日路线固定只生成 \(shortStartDate) 一个自然日，去程、徒步和返程都在 D1 内完成。"
                    : "多日路线的实际自然日和结束日期由生成结果返回，生成前不根据建议天数或参考分日推算。",
                title: "完整日期由生成结果确定",
                tone: .info
            )
        }
    }

    /// VersionConflictRegion：只承载两个恢复动作 refreshRouteVersion / viewCurrentRoute，
    /// 不静默更新路线版本；恢复前主动作禁用。
    private var versionConflictRegion: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            NoticeView(
                message: "路线已更新到新版本，生成前需要确认使用最新公开路线版本。",
                title: "路线版本已更新",
                icon: "arrow.triangle.2.circlepath",
                tone: .warning
            )
            ViewThatFits(in: .horizontal) {
                HStack(spacing: Spacing.sm) {
                    conflictRecoveryActions
                }
                VStack(spacing: Spacing.sm) {
                    conflictRecoveryActions
                }
            }
        }
    }

    private var conflictRecoveryActions: some View {
        Group {
            SecondaryAction(
                title: "重新读取最新版本",
                isDisabled: viewModel.isLoading,
                fillsWidth: true,
                action: { refreshRouteVersion() }
            )
            SecondaryAction(
                title: "返回路线详情",
                isDisabled: viewModel.isLoading,
                fillsWidth: true,
                action: { viewCurrentRoute() }
            )
        }
    }

    private func refreshRouteVersion() {
        Task { await viewModel.load() }
    }

    private func viewCurrentRoute() {
        dismiss()
    }

    private var shortStartDate: String {
        DateCopy.shortDate(LocalDate(date: viewModel.startDate, calendar: .business).description)
    }

    private func equipmentSection(_ context: PersonalTripGenerationContext) -> some View {
        let summary = context.personalEquipmentSummary
        return SharedBusinessComponents.GenerationEquipmentSelection(
            projection: GenerationEquipmentSelectionProjection(
                equipmentItemCount: summary.equipmentItemCount,
                equipmentListCount: summary.equipmentListCount,
                knownTotalWeightGrams: summary.knownTotalWeight.grams,
                missingWeightItemCount: summary.missingWeightItemCount,
                equipmentLists: context.equipmentLists.map { list in
                    GenerationEquipmentListOptionProjection(
                        equipmentListID: list.equipmentListID,
                        name: list.name,
                        itemCount: list.summary.itemCount,
                        knownTotalWeightGrams: list.summary.knownTotalWeight.grams,
                        missingWeightItemCount: list.summary.missingWeightItemCount
                    )
                },
                selectedEquipmentListID: viewModel.selectedEquipmentListID
            ),
            onManageEquipment: {
                viewModel.prepareForPersonalEquipment()
                onManagePersonalEquipment()
            },
            onSelectEquipmentList: viewModel.selectEquipmentList
        )
    }

    private func transportSection(_ selection: PersonalTripTransportSelection) -> some View {
        SharedBusinessComponents.TransportOptionSelection(
            projection: TransportOptionSelectionProjection(
                selectionID: selection.selectionID,
                options: selection.options.map { option in
                    TransportOptionProjection(
                        transportOptionID: option.transportOptionID,
                        transferCount: transferCountFact(option.transferCount),
                        estimatedArrivalAt: estimatedArrivalFact(option.estimatedArrivalAt),
                        estimatedDuration: estimatedDurationFact(option.estimatedDuration),
                        verificationItems: option.verificationItems
                    )
                },
                selectedTransportOptionID: viewModel.selectedTransportOptionID
            ),
            onSelectTransportOption: { viewModel.selectTransportOption($0) }
        )
    }

    private func transferCountFact(_ qualified: QualifiedInteger) -> TransportOptionFactState {
        if let count = qualified.value {
            return .available("换乘 \(count) 次")
        }
        return .unavailable("换乘次数未知")
    }

    private func estimatedArrivalFact(_ qualified: QualifiedInstant) -> TransportOptionFactState {
        if let arrival = qualified.value {
            return .available(arrival.rawValue)
        }
        return .unavailable("到达时间待核验")
    }

    private func estimatedDurationFact(_ qualified: QualifiedDuration) -> TransportOptionFactState {
        if let duration = qualified.value {
            let hours = (duration.seconds / 3_600).formatted(.number.precision(.fractionLength(0...1)))
            return .available("约 \(hours) 小时")
        }
        return .unavailable("用时不可用")
    }

    private var submitTitle: String {
        if viewModel.transportSelection != nil && viewModel.selectedTransportOptionID == nil {
            return "请选择交通方案"
        }
        if viewModel.errorMessage != nil { return "重试生成" }
        if viewModel.transportSelection != nil { return "使用所选方案继续生成" }
        return "生成我的行程"
    }

    private func generationMissingReasonText(_ reason: RouteGenerationMissingReason) -> String {
        switch reason {
        case .name: "缺少路线名称"
        case .region: "缺少所在地区"
        case .estimatedDuration: "缺少预计用时"
        case .start: "缺少起点"
        case .end: "缺少终点"
        case .validMainTrack: "缺少有效主轨迹"
        }
    }
}
