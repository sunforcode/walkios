import CryptoKit
import Foundation
import WalkData

/// 明确的本地亚丁样例映射。艺术标注仅表达构图与先后，不作为地理坐标。
/// 真实轨迹与海拔保持原数据，不能反向从画面生成。
struct YadingMockScene {
    private let dayRanges: [Int: Range<Int>]

    /// Pin the artwork to the exact bundled sample, not merely matching day endpoints.
    private static let trackFingerprint = "72aa496e84c53b0faae57b561574cd62f57bed54d4e6a16bed8f70d7002343d2"

    /// 全程记录范围是样例数据事实，不随图片校准或自然日映射成功与否改变。
    static func includesRecordedTransfer(in source: TripDetailPresentation) -> Bool {
        source.detail.routeReference.routeID == "route-yading-5d"
            && source.detail.trip.frozenRouteBasis.distance?.meters == 69_150
    }

    init?(source: TripDetailPresentation, enabled: Bool) {
        let trip = source.detail.trip
        let days = source.days.days.sorted { $0.dayNumber < $1.dayNumber }
        guard enabled,
              trip.identity == "trip-yading-5d",
              source.days.tripID == trip.identity,
              source.days.revision == source.detail.revision,
              source.detail.routeReference.routeID == "route-yading-5d",
              source.detail.routeReference.adoptedRouteVersionID == "route-yading-5d-v1",
              trip.frozenRouteBasis.distance?.meters == 69_150,
              trip.totalDayCount == 5, trip.hikingDayCount == 5,
              source.days.totalDayCount == 5, source.days.hikingDayCount == 5,
              days.map(\.dayNumber) == [1, 2, 3, 4, 5],
              days.map(\.hikingDayNumber) == [1, 2, 3, 4, 5],
              days.map(\.identity) == (1...5).map({ "trip-yading-5d-day-\($0)" }),
              days == source.detail.days.sorted(by: { $0.dayNumber < $1.dayNumber }) else { return nil }

        let mainTrack = trip.frozenRouteBasis.mainTrackPath
        guard mainTrack.count == 1_990,
              mainTrack.allSatisfy({ $0.referenceSystem == "WGS84" }),
              Self.fingerprint(mainTrack) == Self.trackFingerprint else { return nil }
        var ranges = [Int: Range<Int>]()
        var previousEnd = -1
        for day in days {
            let names = (day.points ?? []).compactMap(\.name) + day.actions.flatMap {
                [$0.start?.value?.name, $0.end?.value?.name].compactMap { $0 }
            }
            guard Self.sceneLandmarks(dayNumber: day.dayNumber).allSatisfy({ marker in
                names.contains { $0.contains(marker.title) }
            }) else { return nil }
            let hikes = day.actions.filter { $0.actionType == "hike" }
            guard hikes.count == 1,
                  let path = hikes[0].routeSectionSnapshot?.path, path.count >= 2,
                  let first = path.first else { return nil }
            // 不只匹配首尾：中间路径也必须逐点相等，防止同起讫的其他路线误用剖面。
            let start = mainTrack.indices.first { index in
                guard index > previousEnd, mainTrack[index] == first,
                      path.count <= mainTrack.count - index else { return false }
                return mainTrack[index..<(index + path.count)].elementsEqual(path)
            }
            guard let start else { return nil }
            let range = start..<(start + path.count)
            ranges[day.dayNumber] = range
            previousEnd = range.upperBound - 1
        }
        dayRanges = ranges
    }

    func assetName(dayNumber: Int?) -> String {
        dayNumber.map { "YadingSceneDay\($0)" } ?? "YadingSceneOverview"
    }

    func landmarks(dayNumber: Int?) -> [TripExpeditionLandmark] {
        Self.sceneLandmarks(dayNumber: dayNumber)
    }

    /// Normalized art coordinates. Labels are sourced from this sample's existing itinerary.
    private static func sceneLandmarks(dayNumber: Int?) -> [TripExpeditionLandmark] {
        switch dayNumber {
        case 1:
            return [
                marker("start", "圣水门", "figure.hiking", 0.84, 0.83),
                marker("crossing", "过河", "arrow.triangle.branch", 0.55, 0.73),
                marker("camp", "第一天营地", "tent.fill", 0.25, 0.66),
            ]
        case 2:
            return [
                marker("start", "第一天营地", "tent.fill", 0.14, 0.80),
                marker("pass", "4900垭口", "mountain.2.fill", 0.45, 0.46),
                marker("camp", "贡嘎扎则营地", "tent.fill", 0.78, 0.70),
            ]
        case 3:
            return [
                marker("start", "贡嘎扎则营地", "tent.fill", 0.14, 0.76),
                marker("pass", "4700垭口", "mountain.2.fill", 0.47, 0.48),
                marker("camp", "新果牛场营地", "tent.fill", 0.82, 0.60),
            ]
        case 4:
            return [
                marker("start", "新果牛场营地", "tent.fill", 0.15, 0.80),
                marker("rock", "蝴蝶石", "mountain.2.fill", 0.40, 0.65),
                marker("camp", "蛇湖营地", "tent.fill", 0.77, 0.62),
            ]
        case 5:
            return [
                marker("start", "蛇湖营地", "tent.fill", 0.16, 0.79),
                marker("pass", "松多垭口", "mountain.2.fill", 0.35, 0.51),
                marker("lake", "牛奶海", "water.waves", 0.66, 0.65),
                marker("end", "扎灌崩", "flag.fill", 0.84, 0.84),
            ]
        case nil:
            return [
                marker("start", "扎灌崩", "figure.hiking", 0.11, 0.74),
                marker("camp1", "第一天营地", "tent.fill", 0.28, 0.52),
                marker("camp2", "贡嘎扎则营地", "tent.fill", 0.54, 0.37),
                marker("camp3", "新果牛场营地", "tent.fill", 0.82, 0.48),
                marker("camp4", "蛇湖营地", "tent.fill", 0.68, 0.70),
                marker("end", "扎灌崩", "flag.fill", 0.40, 0.84),
            ]
        default: return []
        }
    }

    private static func marker(_ id: String, _ title: String, _ symbol: String, _ x: Double, _ y: Double) -> TripExpeditionLandmark {
        TripExpeditionLandmark(id: id, title: title, symbol: symbol, x: x, y: y)
    }

    private static func fingerprint(_ path: [PublicRouteGeoPosition]) -> String {
        var bytes = Data(capacity: path.count * 16)
        for position in path {
            for coordinate in [position.latitude, position.longitude] {
                var bits = coordinate.bitPattern.bigEndian
                withUnsafeBytes(of: &bits) { bytes.append(contentsOf: $0) }
            }
        }
        return SHA256.hash(data: bytes).map { String(format: "%02x", $0) }.joined()
    }

    func elevationProfile(dayNumber: Int, basis: FrozenRouteBasis) -> FrozenRouteElevationProfile? {
        guard let profile = basis.elevationProfile,
              profile.samples.count == basis.mainTrackPath.count,
              let range = dayRanges[dayNumber] else { return nil }
        return TripExpeditionPresentation.slice(
            profile,
            from: profile.samples[range.lowerBound].distance.meters,
            to: profile.samples[range.upperBound - 1].distance.meters
        )
    }
}
