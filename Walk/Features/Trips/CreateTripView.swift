import SwiftUI

struct CreateTripRouteSummaryPresentation: Equatable {
    let title: String
    let facts: [String]

    init(route: PersonalTripGenerationRoute) {
        title = route.name ?? "已选路线"
        var values: [String] = []
        if let version = route.versionLabel { values.append(version) }
        values.append(route.routeType == "one_day" ? "一日路线" : "多日路线")
        if let region = route.region { values.append(region) }
        if let difficulty = route.difficulty { values.append(difficulty) }
        if let start = route.start?.name, let end = route.end?.name {
            values.append("\(start) → \(end)")
        }
        if let meters = route.distance?.meters {
            values.append(meters >= 1_000
                          ? "\((meters / 1_000).formatted(.number.precision(.fractionLength(0...1)))) km"
                          : "\(Int(meters.rounded())) m")
        }
        if let seconds = route.estimatedDuration?.seconds {
            values.append("\((seconds / 3_600).formatted(.number.precision(.fractionLength(0...1)))) 小时")
        }
        facts = values
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
    @StateObject private var viewModel: CreateTripViewModel
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
        UtilityPageContainer {
            Group {
                if viewModel.isLoading && viewModel.context == nil {
                    LoadingView()
                } else if let error = viewModel.errorMessage, viewModel.context == nil {
                    ErrorView(message: error) { Task { await viewModel.load() } }
                } else if let context = viewModel.context {
                    form(context: context)
                }
            }
        }
        .navigationTitle("生成行程")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { Task { await viewModel.handleAppearance() } }
        .onChange(of: viewModel.createdTripID) { tripID in
            if let tripID { onTripCreated(tripID) }
        }
    }

    private func form(context: PersonalTripGenerationContext) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.xl) {
                routeSummary(context.route)
                inputPanel(context)

                if let selection = viewModel.transportSelection {
                    transportPanel(selection)
                }

                if let error = viewModel.errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(AppColors.statusCancelled)
                }

                Button {
                    Task { await viewModel.submit() }
                } label: {
                    Group {
                        if viewModel.isSubmitting {
                            ProgressView().tint(AppColors.pageBase)
                        } else {
                            Text(viewModel.transportSelection == nil ? "生成我的行程" : "继续生成")
                        }
                    }
                    .font(.headline)
                    .frame(maxWidth: .infinity, minHeight: RootNavigation.toolButtonHitSize)
                    .foregroundStyle(viewModel.canSubmit ? AppColors.pageBase : AppColors.textWeak)
                    .background(
                        viewModel.canSubmit ? AppColors.interactionPrimary : AppColors.surfaceElevated,
                        in: RoundedRectangle(cornerRadius: Radius.md)
                    )
                }
                .buttonStyle(.plain)
                .disabled(!viewModel.canSubmit || viewModel.isSubmitting)
            }
            .padding(.horizontal, Spacing.pageHorizontal)
            .padding(.vertical, Spacing.xl)
        }
    }

    private func routeSummary(_ route: PersonalTripGenerationRoute) -> some View {
        let presentation = CreateTripRouteSummaryPresentation(route: route)
        return WalkPanel {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                Text(presentation.title)
                    .font(.sectionTitle)
                    .foregroundStyle(AppColors.textPrimary)
                ForEach(presentation.facts, id: \.self) { fact in
                    Text(fact)
                        .font(.body)
                        .foregroundStyle(AppColors.textSecondary)
                }
                if !route.generationEligibility.eligible {
                    Text("当前路线资料不足，暂时无法生成行程")
                        .font(.caption)
                        .foregroundStyle(AppColors.statusCancelled)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func inputPanel(_ context: PersonalTripGenerationContext) -> some View {
        WalkPanel {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                EntryTextField(title: EntryPageContract.tripFields[0], text: $viewModel.departureCity)

                DatePicker(
                    EntryPageContract.tripFields[1],
                    selection: $viewModel.startDate,
                    in: BusinessCalendar.startOfToday()...,
                    displayedComponents: .date
                )
                .environment(\.calendar, .business)
                .environment(\.timeZone, BusinessCalendar.timeZone)
                .tint(AppColors.interactionPrimary)
                .foregroundStyle(AppColors.textPrimary)

                VStack(alignment: .leading, spacing: Spacing.sm) {
                    Text(EntryPageContract.tripFields[2])
                        .font(.caption)
                        .foregroundStyle(AppColors.textSecondary)
                    Picker("装备清单（可选）", selection: $viewModel.selectedEquipmentListID) {
                        Text("不选择").tag(String?.none)
                        ForEach(context.equipmentLists) { list in
                            Text("\(list.name) · \(list.summary.itemCount) 类")
                                .tag(Optional(list.equipmentListID))
                        }
                    }
                    .pickerStyle(.menu)
                    .tint(AppColors.textPrimary)
                    Button("管理我的装备") {
                        viewModel.prepareForPersonalEquipment()
                        onManagePersonalEquipment()
                    }
                    .buttonStyle(.bordered)
                }

                Text(equipmentSummary(context.personalEquipmentSummary))
                    .font(.caption)
                    .foregroundStyle(AppColors.textWeak)
            }
        }
    }

    private func transportPanel(_ selection: PersonalTripTransportSelection) -> some View {
        WalkPanel {
            VStack(alignment: .leading, spacing: Spacing.md) {
                Text("选择交通方案")
                    .font(.sectionTitle)
                    .foregroundStyle(AppColors.textPrimary)
                ForEach(selection.options) { option in
                    Button {
                        viewModel.selectedTransportOptionID = option.transportOptionID
                    } label: {
                        HStack(alignment: .top, spacing: Spacing.md) {
                            Image(systemName: viewModel.selectedTransportOptionID == option.id
                                  ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(AppColors.interactionPrimary)
                            VStack(alignment: .leading, spacing: Spacing.xs) {
                                Text("方案 \(option.id)")
                                    .foregroundStyle(AppColors.textPrimary)
                                Text(transportDescription(option))
                                    .font(.caption)
                                    .foregroundStyle(AppColors.textSecondary)
                            }
                            Spacer()
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func equipmentSummary(_ summary: PersonalEquipmentSummary) -> String {
        "已读取 \(summary.equipmentItemCount) 类个人装备，已知总重量 \(summary.knownTotalWeight.grams) 克，\(summary.missingWeightItemCount) 类未计入重量。"
    }

    private func transportDescription(_ option: PersonalTripTransportOption) -> String {
        var parts: [String] = []
        if let count = option.transferCount.value { parts.append("换乘 \(count) 次") }
        if let arrival = option.estimatedArrivalAt.value { parts.append("预计到达 \(arrival)") }
        if let duration = option.estimatedDuration.value?.seconds {
            parts.append("约 \((duration / 3_600).formatted(.number.precision(.fractionLength(0...1)))) 小时")
        }
        if !option.verificationItems.isEmpty {
            parts.append(option.verificationItems.joined(separator: "、"))
        }
        return parts.isEmpty ? "方案信息待核验" : parts.joined(separator: " · ")
    }
}
