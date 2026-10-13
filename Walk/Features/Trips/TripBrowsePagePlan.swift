import WalkData

// MARK: - 分页模型

/// 逐日阅读分页：一个自然日一页；页内容量超出时由页内滚动完整呈现，不拆页。
struct TripBrowsePage: Identifiable, Equatable {
    let tripDayID: String
    let dayNumber: Int
    let date: String
    let primaryStage: String
    var hikingDayNumber: Int?
    var totalTrekDays: Int = 0
    let blocks: [TripDayContentBlock]
    /// 该日是否存在实际内容（行动、点位或天气）；无内容按 dayUnavailable 表达。
    let hasContent: Bool

    var id: String { tripDayID }
}

// MARK: - 分页计划

/// 分页计划纯函数：自然日 → 整日内容块，按 `dayNumber` 顺序一页一日；
/// 不按字符数或设备型号补造业务分页。
enum TripBrowsePagePlan {
    static func plan(days: PersonalTripDays) -> [TripBrowsePage] {
        days.days
            .sorted { $0.dayNumber < $1.dayNumber }
            .map { day in
                TripBrowsePage(
                    tripDayID: day.identity,
                    dayNumber: day.dayNumber,
                    date: "\(day.date.month)月\(day.date.day)日",
                    primaryStage: day.primaryStage,
                    hikingDayNumber: day.hikingDayNumber,
                    totalTrekDays: days.hikingDayCount,
                    blocks: blocks(for: day),
                    hasContent: TripDayPresentation(day: day).hasDayContent
                )
            }
    }

    /// 自然日 → 内容块：去程接驳 → 徒步 → 返程接驳 → 当日天气；
    /// 行动说明并入所属块，沿途点位并入徒步块（无徒步日并入去程块）。
    static func blocks(for day: PersonalTripDay) -> [TripDayContentBlock] {
        let presentation = TripDayPresentation(day: day)
        let transportActions = day.actions.filter {
            ["long_distance_transport", "route_transfer"].contains($0.actionType)
        }
        let hikeActions = day.actions.filter { $0.actionType == "hike" }
        let hasHike = !hikeActions.isEmpty
        let hikeSequences = hikeActions.map(\.sequence)

        func details(for actions: [PersonalTripAction]) -> [TripTimelineItemProjection] {
            let sequences = Set(actions.map(\.sequence))
            return presentation.presentationItems
                .filter { sequences.contains($0.sequence) }
                .map { item in
                    TripTimelineItemProjection(
                        id: String(item.sequence),
                        time: item.action.keyTimes?.value?.first,
                        title: TripDetailPresentation.actionTitle(item.action),
                        details: item.details,
                        notices: item.statusNotices.map(\.message)
                    )
                }
        }

        let pointProjections = presentation.pointItems.map { item in
            TripPointProjection(
                id: String(item.sequence),
                title: item.point.name ?? item.point.type,
                details: pointDetails(item),
                trailing: item.point.type
            )
        }

        var blocks: [TripDayContentBlock] = []

        // 去程：首段徒步之前的交通；无徒步日则承载全部交通行动。
        let outbound: [PersonalTripAction]
        if let firstHike = hikeSequences.min() {
            outbound = transportActions.filter { $0.sequence < firstHike }
        } else {
            outbound = transportActions
        }
        if let summary = TripDetailPresentation.transportProjection(from: outbound, direction: .outbound) {
            var outboundDetails = details(for: outbound)
            var outboundPoints: [TripPointProjection] = []
            if !hasHike {
                outboundPoints = pointProjections
                outboundDetails = []
            }
            blocks.append(.transport(summary, details: outboundDetails))
            if !hasHike, !outboundPoints.isEmpty {
                blocks.append(contentsOf: pointFallbackBlocks(outboundPoints))
            }
        }

        // 徒步：段落摘要 + 行动说明 + 沿途点位。
        if hasHike {
            let hikeDetails = details(for: hikeActions)
            if let summary = TripDetailPresentation.hikeProjection(from: day.actions) {
                blocks.append(.hike(summary, details: hikeDetails, points: pointProjections))
            }
        }

        // 返程：末段徒步之后的交通。
        if let lastHike = hikeSequences.max() {
            let returnActions = transportActions.filter { $0.sequence > lastHike }
            if let summary = TripDetailPresentation.transportProjection(
                from: returnActions,
                direction: .return
            ) {
                blocks.append(.transport(summary, details: details(for: returnActions)))
            }
        }

        // 已冻结的日级参考资料独立承载，不填进实际徒步指标或行动序列。
        if let guide = presentation.routeGuideProjection {
            blocks.append(.routeGuide(guide))
        }

        // 当日天气：字段缺失按局部状态表达，不省略块。
        let weather = TripWeatherDayComponentPresentation(
            day: PersonalTripWeatherDay(
                tripDayID: day.identity,
                dayNumber: day.dayNumber,
                date: day.date,
                primaryStage: day.primaryStage,
                hikingDayNumber: day.hikingDayNumber,
                weather: day.weather
            )
        ).projection.weather
        blocks.append(.weather(weather))

        return blocks
    }

    /// 点位详情：距离、说明与状态提示，保持后端 sequence 原序，不补造。
    private static func pointDetails(_ item: TripPointPresentation) -> [String] {
        var details: [String] = []
        if let meters = item.point.distance?.value?.meters {
            details.append("距离 \(distanceText(meters))")
        }
        if let value = item.point.details?.value?
            .trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty {
            details.append(value)
        }
        details.append(contentsOf: item.statusNotices.map(\.message))
        return details
    }

    private static func distanceText(_ meters: Double) -> String {
        meters >= 1_000
            ? "\((meters / 1_000).formatted(.number.precision(.fractionLength(0...1)))) km"
            : "\(Int(meters.rounded())) m"
    }

    /// 无徒步日且无交通摘要时的点位兜底块：还原为徒步块形态承载点位。
    private static func pointFallbackBlocks(
        _ points: [TripPointProjection]
    ) -> [TripDayContentBlock] {
        guard !points.isEmpty else { return [] }
        let summary = TripDayHikeSummaryProjection(
            segment: "沿途",
            distance: nil,
            ascent: nil,
            duration: nil,
            nodes: []
        )
        return [.hike(summary, details: [], points: points)]
    }
}
