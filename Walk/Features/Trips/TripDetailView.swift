import SwiftUI

struct TripDetailView: View {
    let tripID: String
    let reloadRevision: String?
    @StateObject private var viewModel: TripDetailViewModel
    @State private var isCancelConfirmationPresented = false
    @State private var isMigrationConfirmationPresented = false
    private let onOpenRoute: (String) -> Void
    private let onOpenEquipment: () -> Void
    private let onOpenDay: (String) -> Void
    private let onOpenWeather: () -> Void

    init(
        tripID: String,
        service: any PersonalTripServicing,
        reloadRevision: String? = nil,
        onOpenRoute: @escaping (String) -> Void,
        onOpenEquipment: @escaping () -> Void,
        onOpenDay: @escaping (String) -> Void,
        onOpenWeather: @escaping () -> Void
    ) {
        self.tripID = tripID
        self.reloadRevision = reloadRevision
        self.onOpenRoute = onOpenRoute
        self.onOpenEquipment = onOpenEquipment
        self.onOpenDay = onOpenDay
        self.onOpenWeather = onOpenWeather
        _viewModel = StateObject(wrappedValue: TripDetailViewModel(service: service))
    }

    init(
        tripID: String,
        viewModel: TripDetailViewModel,
        reloadRevision: String? = nil,
        onOpenRoute: @escaping (String) -> Void = { _ in },
        onOpenEquipment: @escaping () -> Void = {},
        onOpenDay: @escaping (String) -> Void = { _ in },
        onOpenWeather: @escaping () -> Void = {}
    ) {
        self.tripID = tripID
        self.reloadRevision = reloadRevision
        self.onOpenRoute = onOpenRoute
        self.onOpenEquipment = onOpenEquipment
        self.onOpenDay = onOpenDay
        self.onOpenWeather = onOpenWeather
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        UtilityPageContainer {
            Group {
                if viewModel.isLoading && viewModel.trip == nil {
                    LoadingView()
                } else if let error = viewModel.errorMessage, viewModel.trip == nil {
                    ErrorView(message: error) {
                        Task { await viewModel.loadTrip(id: tripID) }
                    }
                } else if let detail = viewModel.trip,
                          let days = viewModel.days,
                          let weather = viewModel.weather {
                    let presentation = TripDetailPresentation(
                        detail: detail,
                        days: days,
                        weather: weather,
                        routeVersionStatus: viewModel.routeVersionStatus ?? detail.routeVersionStatus
                    )
                    tripDetailContent(presentation)
                }
            }
        }
        .navigationTitle(viewModel.trip?.trip.name ?? "个人行程")
        .navigationBarTitleDisplayMode(.inline)
        .task { await viewModel.loadTrip(id: tripID) }
        .onChange(of: reloadRevision) { revision in
            guard let revision, revision != viewModel.trip?.revision else { return }
            Task { await viewModel.loadTrip(id: tripID) }
        }
        .confirmationDialog(
            "确认取消这趟行程？",
            isPresented: $isCancelConfirmationPresented,
            titleVisibility: .visible
        ) {
            Button("取消行程", role: .destructive) {
                Task { await viewModel.cancelTrip(id: tripID) }
            }
            Button("返回", role: .cancel) {}
        } message: {
            Text("取消后行程会保留，但只能只读查看。")
        }
        .confirmationDialog(
            "确认整体迁移到当前公开新版？",
            isPresented: $isMigrationConfirmationPresented,
            titleVisibility: .visible
        ) {
            Button("整体迁移") {
                Task { await viewModel.migrateTrip(id: tripID) }
            }
            Button("返回", role: .cancel) {}
        } message: {
            Text("路线依据、逐日安排、天气、点位和装备快照将作为一个完整结果切换。")
        }
        .alert("操作未完成", isPresented: mutationErrorBinding) {
            Button("知道了") { viewModel.errorMessage = nil }
        } message: {
            Text(viewModel.errorMessage ?? "请稍后重试")
        }
    }

    private func tripDetailContent(_ presentation: TripDetailPresentation) -> some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.sectionGap) {
                    identitySummary(presentation.detail.trip)
                    daysSection(presentation.days)
                    routeSection(presentation.detail)
                    weatherSection(presentation.weather)
                    equipmentSection(presentation.detail.equipmentSnapshot.summary)
                    routeVersionSection(presentation.routeVersionStatus)
                    if !presentation.notices.isEmpty {
                        noticesSection(presentation.notices)
                    }
                }
                .padding(.horizontal, Spacing.pageHorizontal)
                .padding(.vertical, Spacing.md)
            }
            .refreshable { await viewModel.loadTrip(id: tripID) }

            if presentation.showsPageLevelCancel {
                pageLevelCancelAction
            }
        }
        .background(AppColors.pageBase)
    }

    private func identitySummary(_ trip: PersonalTripProjection) -> some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            detailHeader
            HStack(alignment: .firstTextBaseline) {
                Text(trip.name)
                    .font(.pageTitle)
                    .foregroundStyle(AppColors.textPrimary)
                Spacer()
                PersonalTripStatusBadge(status: trip.status)
            }
            Label("从 \(trip.departureCity) 出发", systemImage: "location")
                .font(.body)
                .foregroundStyle(AppColors.textSecondary)
            HStack {
                Label(dateRange(trip.startDate, trip.endDate), systemImage: "calendar")
                Spacer()
                Text("共 \(trip.totalDayCount) 天 · 徒步 \(trip.hikingDayCount) 天")
            }
            .font(.caption)
            .foregroundStyle(AppColors.textWeak)
        }
    }

    @ViewBuilder
    private var detailHeader: some View {
        if viewModel.isFrozenTrackUnavailable {
            ZStack {
                TripAtmosphericCover()
                VStack(spacing: Spacing.sm) {
                    Image(systemName: "map")
                    Text("生成时路线轨迹不可用")
                }
                .font(.body)
                .foregroundStyle(AppColors.textSecondary)
            }
            .frame(height: TripLayout.detailCoverHeight)
            .clipShape(RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                    .stroke(AppColors.borderPrimary, lineWidth: 1)
            }
        } else {
            RouteMapView(
                coordinates: viewModel.mapCoordinates,
                showsUserLocation: false,
                cameraPitch: 45
            )
                .frame(height: TripLayout.detailMapHeight)
                .clipShape(RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
        }
    }

    private func daysSection(_ result: PersonalTripDays) -> some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text("完整行程安排")
                .font(.sectionTitle)
                .foregroundStyle(AppColors.textPrimary)
            if result.days.isEmpty {
                WalkPanel {
                    Text("逐日安排暂不可用")
                        .foregroundStyle(AppColors.textWeak)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            } else {
                ForEach(result.days) { day in
                    Button { onOpenDay(day.identity) } label: {
                        daySummaryCard(day)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func daySummaryCard(_ day: PersonalTripDay) -> some View {
        WalkPanel {
            VStack(alignment: .leading, spacing: Spacing.md) {
                HStack(alignment: .firstTextBaseline) {
                    Text("D\(day.dayNumber)").font(.headline)
                    Text(day.date.description)
                        .font(.headline)
                        .foregroundStyle(AppColors.textSecondary)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(AppColors.textWeak)
                }
                Text(day.primaryStage)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(AppColors.textPrimary)

                ForEach(day.actions) { action in
                    tripActionSummary(action)
                }

                let weather = weatherLine(day.weather)
                if !weather.isEmpty {
                    Label(weather, systemImage: "cloud.sun")
                        .font(.caption)
                        .foregroundStyle(AppColors.textSecondary)
                }

                if let points = day.points, !points.isEmpty {
                    ForEach(points) { point in
                        Label(point.name ?? point.type, systemImage: "mappin")
                            .font(.caption)
                            .foregroundStyle(AppColors.textSecondary)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func tripActionSummary(_ action: PersonalTripAction) -> some View {
        let start = action.start?.value?.name ?? action.origin?.value?.name
        let end = action.end?.value?.name ?? action.destination?.value?.name
        let route = start.flatMap { start in end.map { "\(start) → \($0)" } }
        let title: String = switch action.actionType {
        case "long_distance_transport": "大交通"
        case "route_transfer": "路线接驳"
        case "hike": action.routeSectionSnapshot?.name ?? "徒步"
        default: action.actionType
        }
        return VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppColors.textPrimary)
            if let route {
                Text(route)
                    .font(.caption)
                    .foregroundStyle(AppColors.textSecondary)
            }
        }
    }

    private func routeSection(_ detail: PersonalTripDetail) -> some View {
        let route = detail.trip.frozenRouteBasis
        return Button { onOpenRoute(detail.routeReference.routeID) } label: {
            sectionPanel(title: "路线") {
                Text(route.routeName)
                    .font(.headline)
                    .foregroundStyle(AppColors.textPrimary)
                Text("生成时版本：\(route.versionLabel ?? detail.routeReference.adoptedRouteVersionID)")
                    .font(.caption)
                    .foregroundStyle(AppColors.textSecondary)
                Text(routeMetrics(route))
                    .font(.body)
                    .foregroundStyle(AppColors.textSecondary)
                HStack {
                    Text("查看当前公开路线")
                        .font(.caption)
                        .foregroundStyle(AppColors.interactionPrimary)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(AppColors.textWeak)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private func weatherSection(_ weather: PersonalTripWeather) -> some View {
        Button(action: onOpenWeather) {
            sectionPanel(title: "整趟天气") {
                if let overview = weather.weatherOverview?.value, !overview.isEmpty {
                    Text(overview).foregroundStyle(AppColors.textSecondary)
                }
                if weather.days.isEmpty {
                    Text("天气摘要暂不可用").foregroundStyle(AppColors.textWeak)
                } else {
                    ForEach(weather.days) { day in
                        VStack(alignment: .leading, spacing: 2) {
                            Text("D\(day.dayNumber) · \(day.date.description)")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(AppColors.textPrimary)
                            Text(weatherLine(day.weather))
                                .font(.caption)
                                .foregroundStyle(AppColors.textSecondary)
                        }
                    }
                }
            }
        }
        .buttonStyle(.plain)
    }

    private func equipmentSection(_ summary: PersonalTripEquipmentSummary) -> some View {
        Button(action: onOpenEquipment) {
            sectionPanel(title: "本次装备") {
                Text("已知总重量 \(weightText(summary.knownTotalWeight.grams))")
                    .font(.headline)
                    .foregroundStyle(AppColors.textPrimary)
                if summary.missingWeightItemCount > 0 {
                    Text("\(summary.missingWeightItemCount) 类未计入重量")
                        .font(.caption)
                        .foregroundStyle(AppColors.textWeak)
                }
                Text("\(summary.itemCount) 类 · 已有 \(summary.ownedItemCount) 类 · 未确认已有 \(summary.unconfirmedOwnedItemCount) 类")
                    .font(.caption)
                    .foregroundStyle(AppColors.textSecondary)
            }
        }
        .buttonStyle(.plain)
    }

    private func routeVersionSection(_ status: PersonalTripRouteVersionStatus) -> some View {
        sectionPanel(title: "路线版本") {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text(versionRelationshipTitle(status.versionRelationship))
                        .font(.headline)
                        .foregroundStyle(AppColors.textPrimary)
                    Text("行程采用：\(versionText(status.adoptedVersion))")
                        .font(.caption)
                        .foregroundStyle(AppColors.textSecondary)
                    if let current = status.currentPublicVersion {
                        Text("当前公开：\(versionText(current))")
                            .font(.caption)
                            .foregroundStyle(AppColors.textSecondary)
                    }
                }
                Spacer()
                Button("刷新") {
                    Task { await viewModel.refreshRouteVersionStatus(id: tripID) }
                }
                .font(.caption)
                .disabled(viewModel.isMutating)
            }

            switch status.versionRelationship {
            case .current:
                Text("这趟行程采用当前公开版本。")
                    .foregroundStyle(AppColors.textSecondary)
            case .currentPublicVersionUnavailable:
                Text("暂时无法取得当前公开版本，行程仍使用原冻结结果。")
                    .foregroundStyle(AppColors.textWeak)
            case .newerPublicVersionAvailable:
                if let difference = status.difference {
                    differenceContent(difference)
                } else {
                    Text("版本差异暂不可用。")
                        .foregroundStyle(AppColors.textWeak)
                }
                if viewModel.actionPolicy?.canMigrate == true {
                    Button("整体迁移到当前公开新版") {
                        isMigrationConfirmationPresented = true
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(AppColors.interactionPrimary)
                    .disabled(viewModel.isMutating)
                }
            }
        }
    }

    @ViewBuilder
    private func differenceContent(_ difference: PersonalTripRouteVersionDifference) -> some View {
        Text(comparisonStatusText(difference.minimumComparisonStatus))
            .font(.caption)
            .foregroundStyle(AppColors.textWeak)

        ForEach(PersonalTripRouteDifferenceCategory.allCases, id: \.self) { category in
            let changes = difference.differences.filter { $0.category == category }
            if difference.unavailableCategories.contains(category) || !changes.isEmpty {
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text(category.title)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(AppColors.textPrimary)
                    if difference.unavailableCategories.contains(category) {
                        Text("该类别暂不可比较")
                            .font(.caption)
                            .foregroundStyle(AppColors.textWeak)
                    } else {
                        ForEach(changes) { change in
                            VStack(alignment: .leading, spacing: 2) {
                                Text("\(change.changeType.title) · \(change.summary)")
                                    .font(.caption)
                                    .foregroundStyle(AppColors.textSecondary)
                                if let before = change.before?.value {
                                    Text("原：\(before)")
                                        .font(.caption2)
                                        .foregroundStyle(AppColors.textWeak)
                                }
                                if let after = change.after?.value {
                                    Text("新：\(after)")
                                        .font(.caption2)
                                        .foregroundStyle(AppColors.textWeak)
                                }
                            }
                        }
                    }
                }
            }
        }

        switch difference.otherRelevantChangeStatus {
        case .changed:
            ForEach(difference.otherRelevantChanges, id: \.self) { change in
                Text("其他相关变化：\(change)")
                    .font(.caption)
                    .foregroundStyle(AppColors.textSecondary)
            }
        case .unknown:
            Text("其他相关路线差异暂不可确认")
                .font(.caption)
                .foregroundStyle(AppColors.textWeak)
        case .none:
            EmptyView()
        }
    }

    private func noticesSection(_ notices: [PersonalTripImportantNotice]) -> some View {
        sectionPanel(title: "重要提醒") {
            ForEach(notices) { notice in
                if let content = notice.content.value {
                    Label(content, systemImage: "exclamationmark.triangle")
                        .foregroundStyle(AppColors.textSecondary)
                }
            }
        }
    }

    private var pageLevelCancelAction: some View {
        Button("取消行程", role: .destructive) {
            isCancelConfirmationPresented = true
        }
        .buttonStyle(.bordered)
        .disabled(viewModel.isMutating)
        .frame(maxWidth: .infinity)
        .padding(.horizontal, Spacing.pageHorizontal)
        .padding(.vertical, Spacing.md)
        .background(AppColors.surfacePrimary)
    }

    private func sectionPanel<Content: View>(
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        WalkPanel {
            VStack(alignment: .leading, spacing: Spacing.md) {
                Text(title)
                    .font(.sectionTitle)
                    .foregroundStyle(AppColors.textPrimary)
                content()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var mutationErrorBinding: Binding<Bool> {
        Binding(
            get: { viewModel.trip != nil && viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )
    }

    private func routeMetrics(_ route: FrozenRouteBasis) -> String {
        var values = [route.routeType, route.direction].compactMap { $0 }
        if let distance = distanceText(route.distance) { values.append(distance) }
        if let ascent = route.ascent?.meters { values.append("爬升 \(Int(ascent.rounded())) m") }
        values.append(durationText(route.estimatedDuration.seconds))
        return values.joined(separator: " · ")
    }

    private func versionRelationshipTitle(_ relationship: PersonalTripVersionRelationship) -> String {
        switch relationship {
        case .current: "当前版本"
        case .newerPublicVersionAvailable: "发现公开新版"
        case .currentPublicVersionUnavailable: "当前公开版本不可用"
        }
    }

    private func versionText(_ version: PersonalTripRouteVersionReference) -> String {
        version.versionLabel ?? version.routeVersionID
    }

    private func comparisonStatusText(_ status: PersonalTripRouteMinimumComparisonStatus) -> String {
        switch status {
        case .complete: "五类差异均已完成可靠比较"
        case .partial: "部分差异类别暂不可比较"
        case .unavailable: "五类最低差异暂不可比较"
        }
    }

    private func dateRange(_ start: LocalDate, _ end: LocalDate) -> String {
        start == end ? start.description : "\(start) - \(end)"
    }

    private func distanceText(_ distance: RouteDistance?) -> String? {
        guard let meters = distance?.meters else { return nil }
        return meters >= 1_000
            ? "\((meters / 1_000).formatted(.number.precision(.fractionLength(0...1)))) km"
            : "\(Int(meters.rounded())) m"
    }

    private func durationText(_ seconds: Double) -> String {
        let hours = seconds / 3_600
        return hours >= 24
            ? "\((hours / 24).formatted(.number.precision(.fractionLength(0...1)))) 天"
            : "\(hours.formatted(.number.precision(.fractionLength(0...1)))) 小时"
    }

    private func weightText(_ grams: Int) -> String {
        grams >= 1_000
            ? "\((Double(grams) / 1_000).formatted(.number.precision(.fractionLength(0...2)))) kg"
            : "\(grams) g"
    }
}
