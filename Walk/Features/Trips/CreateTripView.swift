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
        text = "\(option.name) · \(summary.itemCount) 类 · 已知总重量 \(summary.knownTotalWeight.grams) 克 · \(summary.missingWeightItemCount) 类未计入重量"
    }
}

@MainActor
final class CreateTripViewModel: ObservableObject {
    @Published private(set) var context: PersonalTripGenerationContext?
    @Published var departureCity = ""
    @Published var startDate = BusinessCalendar.startOfToday()
    @Published var selectedEquipmentListID: String?
    @Published private(set) var transportSelection: PersonalTripTransportSelection?
    @Published var selectedTransportOptionID: String?
    @Published private(set) var createdTripID: String?
    @Published var isLoading = false
    @Published var isSubmitting = false
    @Published var errorMessage: String?

    let routeID: String

    private let loadContext: (String) async throws -> PersonalTripGenerationContext
    private let createTrip: (
        PersonalTripCreateRequest,
        String
    ) async throws -> PersonalTripGenerationResult
    private let idempotencyKey: () -> String
    private var lastRequest: PersonalTripCreateRequest?
    private var lastIdempotencyKey: String?
    private var hasLoaded = false
    private var shouldRefreshContextOnAppearance = false

    init(routeID: String, service: any PersonalTripServicing) {
        self.routeID = routeID
        self.loadContext = { try await service.generationContext(routeID: $0) }
        self.createTrip = { try await service.create($0, idempotencyKey: $1) }
        self.idempotencyKey = { UUID().uuidString }
    }

    init(
        routeID: String,
        loadContext: @escaping (String) async throws -> PersonalTripGenerationContext,
        createTrip: @escaping (
            PersonalTripCreateRequest,
            String
        ) async throws -> PersonalTripGenerationResult,
        idempotencyKey: @escaping () -> String = { UUID().uuidString }
    ) {
        self.routeID = routeID
        self.loadContext = loadContext
        self.createTrip = createTrip
        self.idempotencyKey = idempotencyKey
    }

    var canSubmit: Bool {
        guard context?.route.generationEligibility.eligible == true,
              !departureCity.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return false
        }
        guard transportSelection != nil else { return true }
        return selectedTransportOptionID != nil
    }

    func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            context = try await loadContext(routeID)
            hasLoaded = true
            if let selectedEquipmentListID,
               context?.equipmentLists.contains(where: { $0.equipmentListID == selectedEquipmentListID }) != true {
                self.selectedEquipmentListID = nil
            }
        } catch let error as LocalizedError {
            errorMessage = error.errorDescription ?? error.localizedDescription
        } catch {
            errorMessage = "加载失败：\(error.localizedDescription)"
        }
    }

    func prepareForPersonalEquipment() {
        shouldRefreshContextOnAppearance = true
    }

    func handleAppearance() async {
        guard hasLoaded else {
            await load()
            return
        }
        guard shouldRefreshContextOnAppearance else { return }
        shouldRefreshContextOnAppearance = false
        await load()
    }

    func submit() async {
        guard let context else { return }
        let city = departureCity.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !city.isEmpty else { return }

        let selectedTransport = transportSelection.flatMap { selection in
            selectedTransportOptionID.map {
                PersonalTripTransportSelectionRequest(
                    selectionID: selection.selectionID,
                    transportOptionID: $0
                )
            }
        }
        if transportSelection != nil && selectedTransport == nil { return }

        let request = PersonalTripCreateRequest(
            routeID: routeID,
            routeVersionID: context.route.currentPublicRouteVersionID,
            departureCity: city,
            startDate: LocalDate(date: startDate, calendar: .business),
            equipmentListID: selectedEquipmentListID,
            transportSelection: selectedTransport
        )
        let key: String
        if lastRequest == request, let lastIdempotencyKey {
            key = lastIdempotencyKey
        } else {
            key = idempotencyKey()
            lastRequest = request
            lastIdempotencyKey = key
        }

        isSubmitting = true
        errorMessage = nil
        defer { isSubmitting = false }

        do {
            switch try await createTrip(request, key) {
            case .transportSelectionRequired(let selection):
                guard selection.options.count >= 2 else {
                    transportSelection = nil
                    selectedTransportOptionID = nil
                    throw APIClientError.invalidResponse
                }
                transportSelection = selection
                selectedTransportOptionID = nil
                lastRequest = nil
                lastIdempotencyKey = nil
            case .tripCreated(let detail):
                transportSelection = nil
                createdTripID = detail.trip.identity
            }
        } catch let error as LocalizedError {
            errorMessage = error.errorDescription ?? error.localizedDescription
        } catch {
            errorMessage = "生成失败：\(error.localizedDescription)"
        }
    }
}

struct CreateTripView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: CreateTripViewModel
    @FocusState private var isDepartureCityFocused: Bool
    private let onManagePersonalEquipment: () -> Void
    private let onTripCreated: (String) -> Void

    init(
        routeID: String,
        service: any PersonalTripServicing,
        onManagePersonalEquipment: @escaping () -> Void = {},
        onTripCreated: @escaping (String) -> Void = { _ in }
    ) {
        _viewModel = StateObject(wrappedValue: CreateTripViewModel(
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
        _viewModel = StateObject(wrappedValue: viewModel)
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
        .onAppear { Task { await viewModel.handleAppearance() } }
        .onChange(of: viewModel.createdTripID) { tripID in
            if let tripID { onTripCreated(tripID) }
        }
    }

    private var generatingView: some View {
        UtilityPageContainer {
            RouteBusinessComponents.GenerationWaitingView(
                projection: GenerationWaitingProjection(
                    title: "正在组织你的出行信息",
                    description: "请稍候，完成后将直接进入个人行程。"
                )
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var initialStatePage: some View {
        UtilityPageContainer {
            VStack(spacing: 0) {
                navigationHeader
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
                .frame(maxWidth: 600, maxHeight: .infinity)
                .padding(.horizontal, Spacing.pageHorizontal)
            }
        }
    }

    private func ineligiblePage(context: PersonalTripGenerationContext) -> some View {
        UtilityPageContainer {
            VStack(spacing: 0) {
                navigationHeader
                ScrollView {
                    VStack(alignment: .leading, spacing: Spacing.md) {
                        RouteBusinessComponents.GenerationRouteSummaryCard(
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
                    .padding(Spacing.xl)
                }
            }
        }
    }

    private func inputPage(context: PersonalTripGenerationContext) -> some View {
        UtilityPageContainer {
            VStack(spacing: 0) {
                navigationHeader

                ScrollView {
                    VStack(alignment: .leading, spacing: Spacing.xl) {
                        RouteBusinessComponents.GenerationRouteSummaryCard(
                            projection: CreateTripRouteSummaryPresentation(route: context.route).componentProjection
                        )
                        requiredInputs(routeType: context.route.routeType)
                        equipmentSection(context)

                        if let selection = viewModel.transportSelection {
                            transportSection(selection)
                        }

                        if let error = viewModel.errorMessage {
                            ErrorView(
                                message: "\(error)\n已保留本次填写内容。",
                                title: "生成未完成",
                                variant: .form,
                                retry: { Task { await viewModel.submit() } }
                            )
                        }
                    }
                    .frame(maxWidth: 600, alignment: .topLeading)
                    .frame(maxWidth: .infinity, alignment: .top)
                    .padding(.horizontal, Spacing.pageHorizontal)
                    .padding(.top, Spacing.lg)
                    .padding(.bottom, 108)
                }

                FixedActionArea {
                    PrimaryAction(
                        title: submitTitle,
                        isDisabled: !viewModel.canSubmit,
                        fillsWidth: true,
                        action: { Task { await viewModel.submit() } }
                    )
                }
            }
        }
    }

    private var navigationHeader: some View {
        UtilityNavigationHeader(
            title: "生成个人行程",
            leading: IconButtonConfiguration(
                systemName: "chevron.left",
                accessibilityLabel: "返回路线详情",
                action: { dismiss() }
            )
        )
    }

    private func requiredInputs(routeType: String) -> some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            SectionHeader(title: "必要信息")

            FormField(
                label: "出发城市",
                requirement: .required,
                error: departureCityError,
                isFocused: isDepartureCityFocused
            ) {
                TextField("输入出发城市", text: $viewModel.departureCity)
                    .textInputAutocapitalization(.words)
                    .submitLabel(.done)
                    .focused($isDepartureCityFocused)
                    .tint(AppColors.interactionPrimary)
            }

            FormField(label: "从出发城市启程的日期", requirement: .required) {
                DatePicker(
                    "从出发城市启程的日期",
                    selection: $viewModel.startDate,
                    displayedComponents: .date
                )
                .labelsHidden()
                .environment(\.calendar, .business)
                .environment(\.timeZone, BusinessCalendar.timeZone)
                .tint(AppColors.interactionPrimary)
            }

            NoticeView(
                message: routeType == "one_day"
                    ? "一日路线只形成 D1，去程、徒步和返程都在同一自然日。"
                    : "多日路线的自然日和结束日期由完整生成结果返回。",
                title: "完整日期由生成结果确定",
                tone: .info
            )
        }
    }

    private func equipmentSection(_ context: PersonalTripGenerationContext) -> some View {
        let summary = context.personalEquipmentSummary
        return RouteBusinessComponents.GenerationEquipmentSelection(
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
            onSelectEquipmentList: { viewModel.selectedEquipmentListID = $0 }
        )
    }

    private func transportSection(_ selection: PersonalTripTransportSelection) -> some View {
        RouteBusinessComponents.TransportOptionSelection(
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
            onSelectTransportOption: { viewModel.selectedTransportOptionID = $0 }
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

    private var departureCityError: String? {
        guard viewModel.departureCity.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }
        return "请输入出发城市"
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
