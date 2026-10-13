import Foundation
import WalkData
import WalkDesignSystem

/// 仅持有详情页的局部浏览位置，不改变行程或自然日事实。
enum TripExpeditionSelection: Equatable, Hashable {
    case overview
    case day(Int)

    @discardableResult
    mutating func selectDay(_ dayNumber: Int, availableDays: [PersonalTripDay]) -> Bool {
        guard availableDays.contains(where: { $0.dayNumber == dayNumber }), self != .day(dayNumber) else {
            return false
        }
        self = .day(dayNumber)
        return true
    }

    @discardableResult
    mutating func enterFirstDay(in days: [PersonalTripDay]) -> Bool {
        guard case .overview = self, let first = days.min(by: { $0.dayNumber < $1.dayNumber }) else {
            return false
        }
        return selectDay(first.dayNumber, availableDays: days)
    }

    @discardableResult
    mutating func move(by offset: Int, in days: [PersonalTripDay]) -> Bool {
        guard case let .day(number) = self, offset != 0 else { return false }
        let numbers = Array(Set(days.map(\.dayNumber))).sorted()
        guard let current = numbers.firstIndex(of: number) else { return false }
        let (next, overflow) = current.addingReportingOverflow(offset)
        guard !overflow, numbers.indices.contains(next) else { return false }
        self = .day(numbers[next])
        return true
    }

    @discardableResult
    mutating func showOverview() -> Bool {
        guard self != .overview else { return false }
        self = .overview
        return true
    }
}

/// AIGC 图中的归一化画面坐标，不是经纬度、地形投影或导航轨迹。
struct TripExpeditionScenePoint: Equatable {
    let x: Double
    let y: Double
}

struct TripExpeditionLandmark: Identifiable, Equatable {
    let id: String
    let title: String
    let symbol: String
    let x: Double
    let y: Double
}

enum TripSceneArtwork: Equatable {
    case bundledAsset(String)
    case remoteURL(URL)
    case unavailable
}

/// 根页只消费两层摘要；完整行动资料继续由每日详情投影承载。
struct TripTimelineSummaryProjection: Identifiable, Equatable {
    let id: String
    var time: String? = nil
    let title: String
    var subtitle: String? = nil
    var sectionLabel: String? = nil
}

/// PAGE-TRIP-DETAIL 的只读组合投影。
/// `demoScenesEnabled` 由 App 的 Mock 配置显式注入，Feature 不读取调试配置。
struct TripExpeditionPresentation: Equatable {
    let source: TripDetailPresentation
    let selection: TripExpeditionSelection
    var demoScenesEnabled: Bool = false
    var remoteScenes: PersonalTripScenes? = nil

    var artwork: TripSceneArtwork {
        if demoScenesEnabled, isDemoScene { return .bundledAsset(assetName) }
        guard let remoteScenes,
              remoteScenes.isValid(
                tripID: source.detail.trip.identity,
                tripRevision: source.detail.revision,
                routeVersionID: source.detail.routeReference.adoptedRouteVersionID,
                tripDayIDs: Set(calendarDays.map(\.identity))
              ) else { return .unavailable }
        let image: SceneImage?
        if let selectedDay {
            image = remoteScenes.days.first { $0.tripDayID == selectedDay.identity }?.image
        } else {
            image = remoteScenes.overview
        }
        return image?.remoteURL.map(TripSceneArtwork.remoteURL) ?? .unavailable
    }

    var calendarDays: [PersonalTripDay] {
        source.days.days.sorted { $0.dayNumber < $1.dayNumber }
    }

    var selectedDay: PersonalTripDay? {
        guard case let .day(number) = selection else { return nil }
        return calendarDays.first { $0.dayNumber == number }
    }

    var eyebrow: String {
        guard let day = selectedDay else { return dateText }
        return Self.dayRoute(day) ?? Self.referenceRoute(day) ?? Self.date(day.date)
    }

    var title: String {
        guard let day = selectedDay else { return source.detail.trip.frozenRouteBasis.routeName }
        if isGonggaDemoScene {
            switch day.dayNumber {
            case 1: return "向山而行"
            case 2: return "河谷入山"
            case 3: return "翻越垭口"
            default: break
            }
        }
        return day.primaryStage
    }

    var subtitle: String {
        if let day = selectedDay {
            return Self.dayRoute(day) ?? Self.referenceRoute(day) ?? day.primaryStage
        }
        let trip = source.detail.trip
        return "\(trip.departureCity)出发 · \(trip.totalDayCount)天 · 徒步\(trip.hikingDayCount)天"
    }

    var dateText: String {
        if let day = selectedDay { return Self.date(day.date) }
        let start = source.days.startDate
        let end = source.days.endDate
        if start == end { return Self.date(start) }
        if start.year != end.year {
            return "\(start.year)年\(start.month)月\(start.day)日–\(end.year)年\(Self.date(end))"
        }
        return "\(start.month)月\(start.day)–\(Self.date(end))"
    }

    var timelineTitle: String {
        selectedDay == nil ? "全程概览" : "当日走法"
    }

    /// 日期列只留日号，月份在首条及实际月界出现；跨年行程保留年份。
    func timelineMonthLabel(for item: TripTimelineSummaryProjection) -> String? {
        let days = calendarDays
        guard selectedDay == nil, let index = days.firstIndex(where: { $0.identity == item.id }) else { return item.sectionLabel }
        let date = days[index].date
        if index > 0 {
            let previous = days[index - 1].date
            guard previous.year != date.year || previous.month != date.month else { return nil }
        }
        let crossesYear = days.first?.date.year != days.last?.date.year
        return crossesYear ? "\(date.year)年\(date.month)月" : "\(date.month)月"
    }

    func timelineAccessibilityDate(for item: TripTimelineSummaryProjection) -> String? {
        guard selectedDay == nil, let day = calendarDays.first(where: { $0.identity == item.id }) else { return nil }
        return "\(day.date.year)年\(day.date.month)月\(day.date.day)日"
    }

    /// 有限定词的时间仍完整呈现，不能把“08:00 前出发”改成精确 08:00。
    func timelineColumnTime(for item: TripTimelineSummaryProjection) -> String? {
        guard selectedDay != nil else { return item.time }
        guard let time = item.time, time.range(of: #"^\d{1,2}:\d{2}$"#, options: .regularExpression) != nil else { return nil }
        return time
    }

    var weather: TripWeatherDayProjection? {
        guard let day = selectedDay else { return nil }
        return source.weatherDayProjections.first { $0.dayNumber == day.dayNumber }
    }

    /// 样例身份、自然日结构和分段距离同时匹配才允许使用人工演示映射。
    /// 即使真实服务返回相同 ID，没有显式 Mock 注入也不会启用。
    var isDemoScene: Bool { isGonggaDemoScene || yadingScene != nil }

    private var yadingScene: YadingMockScene? {
        YadingMockScene(source: source, enabled: demoScenesEnabled)
    }

    private var isGonggaDemoScene: Bool {
        guard demoScenesEnabled,
              source.detail.trip.identity == "trip-1",
              source.days.tripID == "trip-1",
              source.detail.trip.frozenRouteBasis.routeName == "贡嘎环线",
              source.detail.trip.frozenRouteBasis.distance?.meters == 42_500,
              calendarDays.map(\.dayNumber) == [1, 2, 3],
              calendarDays.map(\.hikingDayNumber) == [nil, 1, 2],
              calendarDays[0].actions.allSatisfy({ $0.actionType != "hike" }) else {
            return false
        }
        let valley = calendarDays[1].actions.filter { $0.actionType == "hike" }
        let pass = calendarDays[2].actions.filter { $0.actionType == "hike" }
        return valley.count == 1 && pass.count == 1
            && valley[0].distance?.value?.meters == 12_500
            && valley[0].start?.value?.name == "老榆林"
            && valley[0].end?.value?.name == "下日乌且营地"
            && pass[0].distance?.value?.meters == 30_000
            && pass[0].start?.value?.name == "下日乌且营地"
            && pass[0].end?.value?.name == "草科"
    }

    var assetName: String {
        if let yadingScene { return yadingScene.assetName(dayNumber: selectedDay?.dayNumber) }
        guard isGonggaDemoScene else { return "TripExpeditionCover" }
        switch selectedDay?.dayNumber {
        case 1: return "TripSceneArrival"
        case 2: return "TripSceneValley"
        case 3: return "TripScenePass"
        default: return "TripSceneOverview"
        }
    }

    var timeline: [TripTimelineSummaryProjection] {
        guard let day = selectedDay else { return overviewTimeline }
        let presentation = TripDayPresentation(day: day)
        let actions = presentation.actions
        let points = presentation.points.map { Self.pointSummary($0, dayID: day.identity) }

        // 单一徒步行动且实际边界齐备时，日内点位沿其已有顺序承接；
        // 混合交通或多段徒步不猜测跨集合归属，保留行动序列及独立点位组。
        if actions.count == 1, let hike = actions.first, hike.actionType == "hike",
           let start = tripNonEmpty(hike.start?.value?.name),
           let end = tripNonEmpty(hike.end?.value?.name) {
            let startItem = TripTimelineSummaryProjection(
                id: "\(day.identity)-action-\(hike.sequence)-start", title: start,
                subtitle: Self.qualifiedSummary("起点", confidence: hike.start?.confidence)
            )
            let endItem = TripTimelineSummaryProjection(
                id: "\(day.identity)-action-\(hike.sequence)-end", title: end,
                subtitle: Self.qualifiedSummary("终点", confidence: hike.end?.confidence)
            )
            // 只有同名不足以证明点位就是行动端点；保留各自身份、角色与可信限定。
            return [startItem] + points + [endItem]
        }

        var result = actions.map { Self.actionSummary($0, dayID: day.identity) }
        var unassignedPoints = points
        if !unassignedPoints.isEmpty, !result.isEmpty { unassignedPoints[0].sectionLabel = "当日点位" }
        result.append(contentsOf: unassignedPoints)
        return result
    }

    private var overviewTimeline: [TripTimelineSummaryProjection] {
        calendarDays.map { day in
            let actions = day.actions.sorted { $0.sequence < $1.sequence }
            let first = actions.first
            let last = actions.last
            let start = first?.start ?? first?.origin
            let end = last?.end ?? last?.destination
            let endpoints = [tripNonEmpty(start?.value?.name), tripNonEmpty(end?.value?.name)]
            let route: String?
            if let origin = endpoints[0], let destination = endpoints[1] {
                let path = origin == destination ? origin : "\(origin) → \(destination)"
                route = Self.qualifiedSummary(path, confidences: [start?.confidence, end?.confidence])
            } else {
                route = Self.referenceRoute(day).map {
                    Self.qualifiedSummary($0, confidences: [day.routeGuide?.start?.confidence, day.routeGuide?.end?.confidence])
                }
            }
            return TripTimelineSummaryProjection(
                id: day.identity, time: String(day.date.day), title: day.primaryStage, subtitle: route
            )
        }
    }

    var metrics: [MetricItemModel] {
        guard let day = selectedDay else {
            let basis = source.detail.trip.frozenRouteBasis
            let includesTransfer = calendarDays.contains { $0.routeGuide?.referenceTrack != nil }
                || YadingMockScene.includesRecordedTransfer(in: source)
            return [
                MetricItemModel(id: "distance", value: basis.distance.map { Self.distance($0.meters) }, label: includesTransfer ? "全程轨迹" : "全程徒步"),
                MetricItemModel(id: "ascent", value: basis.ascent.map { Self.meters($0.meters) }, label: "累计爬升"),
                MetricItemModel(id: "descent", value: basis.descent.map { Self.meters($0.meters) }, label: "累计下降"),
                MetricItemModel(id: "duration", value: Self.completeSum([basis.estimatedDuration.seconds]).map(Self.duration), label: includesTransfer ? "预计行进用时" : "预计徒步用时"),
            ]
        }
        let hikes = day.actions.filter { $0.actionType == "hike" }
        guard !hikes.isEmpty else { return [] }
        if let reference = referenceMetricsTrack {
            return [
                MetricItemModel(id: "distance", value: Self.completeSum([reference.distance?.meters]).map(Self.distance), label: "参考行进"),
                MetricItemModel(id: "ascent", value: Self.completeSum([reference.ascent?.meters]).map(Self.meters), label: "参考爬升"),
                MetricItemModel(id: "descent", value: Self.completeSum([reference.descent?.meters]).map(Self.meters), label: "参考下降"),
                MetricItemModel(id: "duration", value: Self.completeSum([reference.estimatedDuration?.seconds]).map(Self.duration), label: "参考用时"),
            ]
        }
        return [
            MetricItemModel(id: "distance", value: Self.completeSum(hikes.map { $0.distance?.value?.meters }).map(Self.distance), label: "当日徒步"),
            MetricItemModel(id: "ascent", value: Self.completeSum(hikes.map { $0.ascent?.value?.meters }).map(Self.meters), label: "当日爬升"),
            // 行动合同暂未提供下降值，不能从全程或示意剖面反推。
            MetricItemModel(id: "descent", value: nil, label: "当日下降"),
            MetricItemModel(id: "duration", value: Self.completeSum(hikes.map { $0.estimatedDuration?.value?.seconds }).map(Self.duration), label: "预计徒步用时"),
        ]
    }

    var elevationProfile: FrozenRouteElevationProfile? {
        let profile = source.detail.trip.frozenRouteBasis.elevationProfile
        guard let day = selectedDay else { return profile }
        if let reference = day.routeGuide?.referenceTrack?.elevationProfile { return reference }
        if let yadingScene {
            return yadingScene.elevationProfile(dayNumber: day.dayNumber, basis: source.detail.trip.frozenRouteBasis)
        }
        guard isGonggaDemoScene, let profile else { return nil }
        switch day.dayNumber {
        case 2: return Self.slice(profile, from: 0, to: 12_500)
        case 3: return Self.slice(profile, from: 12_500, to: 42_500)
        default: return nil
        }
    }

    var elevationTitle: String {
        guard let day = selectedDay else { return "全程海拔" }
        return day.routeGuide?.referenceTrack?.elevationProfile == nil ? "当日海拔" : "当日参考海拔"
    }

    /// 参考行进使用独立的一整组来源，不能只拿参考下降或时间填实际徒步的缺项。
    private var referenceMetricsTrack: PersonalTripReferenceTrack? {
        guard let day = selectedDay, let track = day.routeGuide?.referenceTrack else { return nil }
        let hikes = day.actions.filter { $0.actionType == "hike" }
        if !hikes.isEmpty, hikes.allSatisfy({
            $0.distance?.value == nil && $0.ascent?.value == nil && $0.estimatedDuration?.value == nil
        }), track.distance != nil || track.ascent != nil || track.descent != nil || track.estimatedDuration != nil {
            return track
        }

        // 已采纳参考计划必须完整匹配；不从身份、标题或来源文案推测采纳关系。
        guard hikes.count == 1, let hike = hikes.first,
              let snapshot = hike.routeSectionSnapshot, hike.routeSectionConfidence == nil,
              let path = track.path, path.count >= 2, snapshot.path == path,
              let start = hike.start?.value, start == snapshot.start,
              let end = hike.end?.value, end == snapshot.end,
              let distance = hike.distance?.value?.meters,
              let ascent = hike.ascent?.value?.meters,
              let duration = hike.estimatedDuration?.value?.seconds,
              [distance, ascent, duration].allSatisfy({ $0.isFinite && $0 >= 0 }),
              distance == track.distance?.meters,
              ascent == track.ascent?.meters,
              duration == track.estimatedDuration?.seconds,
              [hike.distance?.confidence, hike.ascent?.confidence, hike.estimatedDuration?.confidence, track.confidence].allSatisfy({
                  $0?.status == "pending_verification" && $0?.category == .publicRouteFact
              }) else { return nil }
        return track
    }

    var referenceQualification: String? {
        guard !referenceInformationNotices.isEmpty, let guide = selectedDay?.routeGuide else { return nil }
        let statuses = Self.unique([guide.referenceTrack?.confidence, guide.start?.confidence, guide.end?.confidence]
            .compactMap(Self.compactStatus))
        return (["参考资料"] + statuses).joined(separator: " · ")
    }

    /// 来源完整文本由字段可访问说明承接，不恢复集中提醒面板。
    var referenceInformationNotices: [String] {
        guard let day = selectedDay else { return [] }
        var result = [String]()
        if let track = day.routeGuide?.referenceTrack,
           referenceMetricsTrack != nil || track.elevationProfile != nil {
            result.append("参考行进可能包含接驳，不等同于实际徒步指标。")
            result.append(contentsOf: Self.referenceNotices("参考行进", confidence: track.confidence))
        }
        if Self.dayRoute(day) == nil, Self.referenceRoute(day) != nil, let guide = day.routeGuide {
            result.append(contentsOf: Self.referenceNotices("参考起点", confidence: guide.start?.confidence))
            result.append(contentsOf: Self.referenceNotices("参考终点", confidence: guide.end?.confidence))
        }
        return Self.unique(result)
    }

    var elevationUnavailableText: String? {
        guard elevationProfile == nil else { return nil }
        guard let day = selectedDay else { return "全程海拔剖面暂未提供" }
        return day.actions.contains(where: { $0.actionType == "hike" })
            ? "当日海拔剖面暂未提供"
            : "交通日 · 无徒步海拔剖面"
    }

    var landmarks: [TripExpeditionLandmark] {
        if let yadingScene { return yadingScene.landmarks(dayNumber: selectedDay?.dayNumber) }
        guard isGonggaDemoScene else { return [] }
        switch selectedDay?.dayNumber {
        case 1:
            return [
                Self.landmark("origin", "成都", "location.fill", 0.14, 0.70),
                Self.landmark("transfer", "康定", "car.fill", 0.43, 0.54),
                Self.landmark("arrival", "老榆林", "flag.fill", 0.77, 0.39),
            ]
        case 2:
            return [
                Self.landmark("start", "老榆林", "figure.hiking", 0.15, 0.73),
                Self.landmark("water", "日乌且溪", "drop.fill", 0.44, 0.54),
                Self.landmark("camp", "下日乌且营地", "tent.fill", 0.76, 0.33),
            ]
        case 3:
            return [
                Self.landmark("camp", "下日乌且营地", "tent.fill", 0.15, 0.67),
                Self.landmark("pass", "日乌且垭口", "mountain.2.fill", 0.49, 0.28),
                Self.landmark("end", "草科", "flag.fill", 0.82, 0.66),
            ]
        default:
            return [
                Self.landmark("start", "老榆林", "figure.hiking", 0.15, 0.70),
                Self.landmark("camp", "下日乌且营地", "tent.fill", 0.39, 0.53),
                Self.landmark("pass", "日乌且垭口", "mountain.2.fill", 0.64, 0.28),
                Self.landmark("end", "草科", "flag.fill", 0.84, 0.65),
            ]
        }
    }

    var routePath: [TripExpeditionScenePoint] {
        let nodes = landmarks
        guard nodes.count >= 2 else { return [] }
        var result = [TripExpeditionScenePoint(x: nodes[0].x, y: nodes[0].y)]
        for (index, pair) in zip(nodes, nodes.dropFirst()).enumerated() {
            let (start, end) = pair
            let bend = index.isMultiple(of: 2) ? 0.035 : -0.035
            result.append(TripExpeditionScenePoint(x: start.x + (end.x - start.x) * 0.36 + bend, y: start.y + (end.y - start.y) * 0.36))
            result.append(TripExpeditionScenePoint(x: start.x + (end.x - start.x) * 0.68 - bend, y: start.y + (end.y - start.y) * 0.68))
            result.append(TripExpeditionScenePoint(x: end.x, y: end.y))
        }
        return result
    }

    /// 在已有剖面中按明确距离边界插值和归零；不估计边界以外的海拔。
    static func slice(_ profile: FrozenRouteElevationProfile, from lower: Double, to upper: Double) -> FrozenRouteElevationProfile? {
        let samples = profile.samples
        guard samples.count >= 2, lower.isFinite, upper.isFinite, lower < upper,
              samples.allSatisfy({ $0.distance.meters.isFinite && $0.elevation.meters.isFinite }),
              zip(samples, samples.dropFirst()).allSatisfy({ $0.0.distance.meters < $0.1.distance.meters }),
              let first = samples.first, let last = samples.last,
              lower >= first.distance.meters, upper <= last.distance.meters else { return nil }

        func elevation(at distance: Double) -> Double? {
            if let exact = samples.first(where: { $0.distance.meters == distance }) { return exact.elevation.meters }
            for (start, end) in zip(samples, samples.dropFirst()) where start.distance.meters < distance && distance < end.distance.meters {
                let fraction = (distance - start.distance.meters) / (end.distance.meters - start.distance.meters)
                return start.elevation.meters + fraction * (end.elevation.meters - start.elevation.meters)
            }
            return nil
        }
        guard let startElevation = elevation(at: lower), let endElevation = elevation(at: upper) else { return nil }
        var selected = [FrozenRouteElevationSample(distance: RouteDistance(meters: 0), elevation: RouteElevation(meters: startElevation))]
        selected.append(contentsOf: samples.filter { lower < $0.distance.meters && $0.distance.meters < upper }.map {
            FrozenRouteElevationSample(distance: RouteDistance(meters: $0.distance.meters - lower), elevation: $0.elevation)
        })
        selected.append(FrozenRouteElevationSample(distance: RouteDistance(meters: upper - lower), elevation: RouteElevation(meters: endElevation)))
        let elevations = selected.map(\.elevation.meters)
        guard let minimum = elevations.min(), let maximum = elevations.max() else { return nil }
        return FrozenRouteElevationProfile(minElevation: RouteElevation(meters: minimum), maxElevation: RouteElevation(meters: maximum), samples: selected)
    }

    private static func landmark(_ id: String, _ title: String, _ symbol: String, _ x: Double, _ y: Double) -> TripExpeditionLandmark {
        TripExpeditionLandmark(id: id, title: title, symbol: symbol, x: x, y: y)
    }

    private static func actionTitle(_ action: PersonalTripAction) -> String {
        if action.actionType == "hike" { return action.routeSectionSnapshot?.name ?? "徒步" }
        let places = [action.origin, action.destination].compactMap { place -> String? in
            guard let name = tripNonEmpty(place?.value?.name) else { return nil }
            guard let status = compactStatus(place?.confidence) else { return name }
            return "\(name)（\(status)）"
        }
        return places.isEmpty ? TripDetailPresentation.actionTitle(action) : places.joined(separator: " → ")
    }

    private static func actionSummary(_ action: PersonalTripAction, dayID: String) -> TripTimelineSummaryProjection {
        let time = tripNonEmpty(action.keyTimes?.value?.first)
        let exactTime = time?.range(of: #"^\d{1,2}:\d{2}$"#, options: .regularExpression) != nil
        let timeQualifier = compactStatus(action.keyTimes?.confidence)
        let columnTime = exactTime && timeQualifier == nil ? time : nil
        let subtitle: String?
        if let time, columnTime == nil {
            subtitle = qualifiedSummary(time, confidence: action.keyTimes?.confidence)
        } else if action.actionType == "hike" {
            let places = [tripNonEmpty(action.start?.value?.name), tripNonEmpty(action.end?.value?.name)].compactMap { $0 }
            let path = places.isEmpty ? nil : places.joined(separator: " → ")
            subtitle = path.map { qualifiedSummary($0, confidences: [action.start?.confidence, action.end?.confidence]) }
                ?? compactStatus(action.routeSectionConfidence)
        } else {
            subtitle = tripNonEmpty(action.mode?.value).map { qualifiedSummary($0, confidence: action.mode?.confidence) }
                ?? compactStatus(action.mode?.confidence)
        }
        return TripTimelineSummaryProjection(
            id: "\(dayID)-action-\(action.sequence)", time: columnTime,
            title: actionTitle(action), subtitle: subtitle
        )
    }

    private static func pointSummary(_ point: PersonalTripPoint, dayID: String) -> TripTimelineSummaryProjection {
        let name = tripNonEmpty(point.name) ?? point.type
        let title = point.isAlternative == true && !name.contains("备选") ? "\(name) · 备选" : name
        let subtitle: String?
        if let meters = point.distance?.value?.meters, meters.isFinite, meters >= 0 {
            subtitle = qualifiedSummary("\(distance(meters))处", confidence: point.distance?.confidence)
        } else {
            let type = tripNonEmpty(point.type).flatMap { $0 == name ? nil : $0 }
            let status = compactStatus(point.details?.confidence).map { "资料\($0)" }
            let parts = [type, status].compactMap { $0 }
            subtitle = parts.isEmpty ? nil : parts.joined(separator: " · ")
        }
        return TripTimelineSummaryProjection(
            id: "\(dayID)-point-\(point.sequence)", title: title, subtitle: subtitle
        )
    }

    private static func qualifiedSummary(_ value: String, confidence: InformationConfidence?) -> String {
        qualifiedSummary(value, confidences: [confidence])
    }

    private static func qualifiedSummary(_ value: String, confidences: [InformationConfidence?]) -> String {
        let statuses = unique(confidences.compactMap(compactStatus))
        return statuses.isEmpty ? value : "\(value) · \(statuses.joined(separator: "／"))"
    }

    private static func compactStatus(_ confidence: InformationConfidence?) -> String? {
        switch confidence?.status {
        case "pending_verification": "待核验"
        case "preliminary": "初步信息"
        case "unknown": "待确认"
        case "missing": "资料缺失"
        case "stale": "已过期"
        case "unavailable": "暂不可用"
        default: nil
        }
    }

    private static func transportPath(_ action: PersonalTripAction) -> String? {
        let places = [action.origin?.value?.name, action.destination?.value?.name].compactMap { tripNonEmpty($0) }
        return places.isEmpty ? nil : places.joined(separator: " → ")
    }

    private static func dayRoute(_ day: PersonalTripDay) -> String? {
        let actions = day.actions.sorted { $0.sequence < $1.sequence }
        let hikes = actions.filter { $0.actionType == "hike" }
        let places = hikes.isEmpty
            ? actions.filter { ["long_distance_transport", "route_transfer"].contains($0.actionType) }
                .flatMap { [$0.origin?.value?.name, $0.destination?.value?.name].compactMap { tripNonEmpty($0) } }
            : hikes.flatMap { [$0.start?.value?.name, $0.end?.value?.name].compactMap { tripNonEmpty($0) } }
        var chain = [String]()
        for place in places where chain.last != place { chain.append(place) }
        return chain.isEmpty ? nil : chain.joined(separator: " → ")
    }

    private static func referenceRoute(_ day: PersonalTripDay) -> String? {
        guard let start = tripNonEmpty(day.routeGuide?.start?.value?.name),
              let end = tripNonEmpty(day.routeGuide?.end?.value?.name) else { return nil }
        return "参考走法 · \(start) → \(end)"
    }

    private static func referenceNotices(_ title: String, confidence: InformationConfidence?) -> [String] {
        var result = notices([(title, confidence)])
        if let source = tripNonEmpty(confidence?.source) { result.append("\(title)来源：\(source)") }
        return result
    }

    private static func notices(_ fields: [(String, InformationConfidence?)]) -> [String] {
        fields.compactMap { field, confidence in
            guard let status = confidence?.status else { return nil }
            if status == "preliminary" { return "\(field)：初步信息" }
            guard ["unknown", "missing", "pending_verification", "stale", "unavailable"].contains(status) else { return nil }
            return TripContentNotice(field: field, status: status).message
        }
    }

    private static func unique(_ values: [String]) -> [String] {
        var seen = Set<String>()
        return values.filter { seen.insert($0).inserted }
    }

    private static func completeSum(_ values: [Double?]) -> Double? {
        let available = values.compactMap { $0 }
        guard !available.isEmpty, available.count == values.count, available.allSatisfy({ $0.isFinite && $0 >= 0 }) else { return nil }
        return available.reduce(0, +)
    }

    private static func date(_ date: LocalDate) -> String { "\(date.month)月\(date.day)日" }
    private static func meters(_ value: Double) -> String { "\(Int(value.rounded())) m" }
    private static func distance(_ value: Double) -> String {
        value >= 1_000 ? "\((value / 1_000).formatted(.number.precision(.fractionLength(0...1)))) km" : meters(value)
    }
    private static func duration(_ value: Double) -> String {
        let minutes = Int((value / 60).rounded())
        return minutes < 60 ? "\(minutes) 分钟" : (minutes % 60 == 0 ? "\(minutes / 60) 小时" : "\(minutes / 60) 小时 \(minutes % 60) 分")
    }
}
