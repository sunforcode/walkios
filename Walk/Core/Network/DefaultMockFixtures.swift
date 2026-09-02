import Foundation

enum DefaultMockFixtures {
    static func all(bundle: Bundle = .main) -> [String: Data] {
        tripFixtures(bundle: bundle)
            .merging(accountFixtures()) { _, account in account }
            .merging(personalTripFixtures()) { _, personalTrip in personalTrip }
            .merging(tripEquipmentFixtures()) { _, tripEquipment in tripEquipment }
            .merging(routeFixtures()) { _, route in route }
            .merging(equipmentFixtures()) { _, equipment in equipment }
    }

    static func tripFixtures(bundle: Bundle = .main) -> [String: Data] {
        var fixtures: [String: Data] = [:]

        if let data = load("trip-list", bundle: bundle) {
            fixtures[TripAPI.List().identifier] = data
        }
        let emptyHistory = Data("""
        {"success":true,"message":"success","data":{"content":[],"number":0,"size":20,"totalElements":0,"totalPages":0,"first":true,"last":true},"timestamp":1724544001,"code":200}
        """.utf8)
        fixtures[TripAPI.List(status: .completed).identifier] = emptyHistory
        fixtures[TripAPI.List(status: .cancelled).identifier] = emptyHistory
        if let data = load("trip-detail-trip-1", bundle: bundle) ?? load("trip-detail", bundle: bundle) {
            fixtures[TripAPI.Detail(id: "trip-1").identifier] = data
        }

        return fixtures
    }

    static func accountFixtures() -> [String: Data] {
        [
            AccountAPI.Current().identifier: Data(#"{"data":{"account":{"identity":"account-1"},"profile":{"identity":"profile-1","maskedPhone":"+86 138****8000","nickname":"行者"}}}"#.utf8),
        ]
    }

    static func personalTripFixtures() -> [String: Data] {
        let summary = personalTripSummaryJSON
        let create = try? PersonalTripAPI.Create(
            input: PersonalTripCreateRequest(
                routeID: "route-1",
                routeVersionID: "route-1-v1",
                departureCity: "成都",
                startDate: LocalDate(year: 2026, month: 8, day: 25),
                equipmentListID: nil,
                transportSelection: nil
            ),
            idempotencyKey: "mock-create"
        )
        var fixtures = [
            PersonalTripAPI.Focus().identifier: Data("{\"data\":{\"trip\":\(summary)}}".utf8),
            PersonalTripAPI.Collection().identifier: Data("{\"data\":{\"currentTrips\":[\(summary)],\"historicalTrips\":[]}}".utf8),
            PersonalTripAPI.Calendar().identifier: Data(#"{"data":{"windowStartDate":"2025-08-26","windowEndDate":"2026-08-25","days":[{"date":"2026-08-25","tripCount":1}]}}"#.utf8),
            PersonalTripAPI.Detail(tripID: "trip-1").identifier: personalTripDetailData,
            PersonalTripAPI.Days(tripID: "trip-1").identifier: personalTripDaysData,
            PersonalTripAPI.Weather(tripID: "trip-1").identifier: personalTripWeatherData,
            PersonalTripAPI.GenerationContext(routeID: "route-1").identifier: personalTripGenerationContextData,
        ]
        if let create {
            fixtures[create.identifier] = personalTripCreatedData
        }
        return fixtures
    }

    static func equipmentFixtures() -> [String: Data] {
        [
            PersonalEquipmentAPI.Collection().identifier: Data(#"{"data":{"items":[],"summary":{"equipmentItemCount":0,"equipmentListCount":0,"knownTotalWeight":{"grams":0},"missingWeightItemCount":0}}}"#.utf8),
            EquipmentListAPI.Collection().identifier: Data(#"{"data":{"items":[]}}"#.utf8),
        ]
    }

    static func tripEquipmentFixtures() -> [String: Data] {
        [
            TripEquipmentAPI.Current(tripID: "trip-1").identifier: Data(
                #"{"data":{"trip":{"identity":"trip-1","status":"planned","routeName":"贡嘎环线","startDate":"2026-08-25","endDate":"2026-08-27"},"revision":"revision-1","editable":true,"snapshot":{"identity":"equipment-snapshot-1","items":[],"summary":{"itemCount":0,"knownTotalWeight":{"grams":0},"missingWeightItemCount":0,"ownedItemCount":0,"unconfirmedOwnedItemCount":0}}}}"#.utf8
            ),
        ]
    }

    static func routeFixtures() -> [String: Data] {
        let routes = [
            (id: "route-1", name: "贡嘎环线", region: "四川甘孜"),
            (id: "route_001", name: "五台山逆穿", region: "山西忻州"),
            (id: "route_002", name: "箭扣长城", region: "北京怀柔"),
            (id: "route_003", name: "海坨山南坡", region: "北京延庆")
        ]
        let summaries = routes.map { route in
            """
            {"routeId":"\(route.id)","currentVersionId":"\(route.id)-v1","name":"\(route.name)","region":"\(route.region)","difficulty":"中等","distance":{"meters":12500},"ascent":{"meters":850},"estimatedDuration":{"seconds":28800}}
            """
        }.joined(separator: ",")
        let browse = Data("{\"data\":{\"items\":[\(summaries)]}}".utf8)
        let search = Data("""
        {"data":{"state":"completed","items":[{"routeId":"route-1","currentVersionId":"route-1-v1","name":"贡嘎环线","region":"四川甘孜","difficulty":"中等","distance":{"meters":42500},"estimatedDuration":{"seconds":259200}}]}}
        """.utf8)
        let initialSearch = Data("{\"data\":{\"state\":\"initial\",\"items\":[]}}".utf8)
        var fixtures: [String: Data] = [
            PublicRouteAPI.Featured().identifier: browse,
            PublicRouteAPI.All().identifier: browse,
            PublicRouteAPI.Search(query: "贡嘎").identifier: search,
            PublicRouteAPI.Search(query: nil).identifier: initialSearch,
        ]

        for route in routes {
            fixtures[PublicRouteAPI.Detail(id: route.id).identifier] = publicRouteDetailData(
                id: route.id,
                name: route.name,
                region: route.region
            )
        }
        return fixtures
    }

    private static func publicRouteDetailData(id: String, name: String, region: String) -> Data {
        Data("""
        {"data":{"routeId":"\(id)","currentVersion":{"versionId":"\(id)-v1","versionLabel":"初始公开版本","summary":{"routeType":"multi_day","name":"\(name)","region":"\(region)","start":{"name":"起点"},"end":{"name":"终点"},"estimatedDuration":{"seconds":259200},"difficulty":"中等","direction":"环线","distance":{"meters":42500},"ascent":{"meters":2300},"descent":{"meters":2200},"introduction":"公开路线资料"},"mainTrackAvailability":"pending_review","generationEligibility":{"eligible":false,"missingReasons":["validMainTrack"]}}}}
        """.utf8)
    }

    private static let personalTripSummaryJSON = """
    {"tripId":"trip-1","revision":"revision-1","name":"贡嘎行程","status":"planned","routeReference":{"routeId":"route-1","adoptedRouteVersionId":"route-1-v1"},"routeName":"贡嘎环线","routeType":"multi_day","start":{"name":"老榆林"},"end":{"name":"草科"},"estimatedDuration":{"seconds":259200},"startDate":"2026-08-25","endDate":"2026-08-27","totalDayCount":3,"hikingDayCount":2,"versionLabel":"初始公开版本","direction":"环线","distance":{"meters":42500},"ascent":{"meters":2300}}
    """

    private static let personalTripDayJSON = """
    {"identity":"trip-day-1","dayNumber":1,"date":"2026-08-25","primaryStage":"成都至老榆林","actions":[],"weather":{"condition":{"value":"多云"},"temperatureRange":{"value":{"minimum_celsius":8,"maximum_celsius":16}},"precipitation":{"value":"午后可能有雨"},"wind":{"value":"微风"},"placeContext":{"value":"老榆林"}},"points":[]}
    """

    private static let personalTripDetailJSON = """
    {"revision":"revision-1","trip":{"identity":"trip-1","name":"贡嘎行程","firstGeneratedAt":"2026-08-01T10:00:00Z","status":"planned","departureCity":"成都","startDate":"2026-08-25","endDate":"2026-08-27","totalDayCount":3,"hikingDayCount":2,"frozenRouteBasis":{"routeName":"贡嘎环线","routeType":"multi_day","region":"四川甘孜","start":{"name":"老榆林"},"end":{"name":"草科"},"estimatedDuration":{"seconds":259200},"mainTrackPath":[{"latitude":29.6,"longitude":101.8,"referenceSystem":"WGS84"},{"latitude":29.7,"longitude":101.9,"referenceSystem":"WGS84"}],"versionLabel":"初始公开版本","direction":"环线","distance":{"meters":42500},"ascent":{"meters":2300},"descent":{"meters":2200},"maxElevation":{"meters":4700}},"weatherOverview":{"value":"多云，午后可能有雨"},"importantNotices":[]},"routeReference":{"routeId":"route-1","adoptedRouteVersionId":"route-1-v1"},"days":[\(personalTripDayJSON)],"equipmentSnapshot":{"snapshotId":"equipment-snapshot-1","summary":{"itemCount":0,"knownTotalWeight":{"grams":0},"missingWeightItemCount":0,"ownedItemCount":0,"unconfirmedOwnedItemCount":0}},"routeVersionStatus":{"tripId":"trip-1","tripRevision":"revision-1","adoptedVersion":{"routeVersionId":"route-1-v1","versionLabel":"初始公开版本"},"currentPublicVersion":{"routeVersionId":"route-1-v1","versionLabel":"初始公开版本"},"versionRelationship":"current","migrationEligible":false}}
    """

    private static let personalTripDetailData = Data(
        "{\"data\":\(personalTripDetailJSON)}".utf8
    )

    private static let personalTripCreatedData = Data(
        "{\"data\":{\"resultType\":\"trip_created\",\"trip\":\(personalTripDetailJSON)}}".utf8
    )

    private static let personalTripDaysData = Data(
        """
        {"data":{"tripId":"trip-1","revision":"revision-1","startDate":"2026-08-25","endDate":"2026-08-27","totalDayCount":3,"hikingDayCount":2,"days":[\(personalTripDayJSON)]}}
        """.utf8
    )

    private static let personalTripWeatherData = Data(
        """
        {"data":{"tripId":"trip-1","revision":"revision-1","routeName":"贡嘎环线","startDate":"2026-08-25","endDate":"2026-08-27","days":[{"tripDayId":"trip-day-1","dayNumber":1,"date":"2026-08-25","primaryStage":"成都至老榆林","weather":{"condition":{"value":"多云"},"temperatureRange":{"value":{"minimum_celsius":8,"maximum_celsius":16}},"precipitation":{"value":"午后可能有雨"},"wind":{"value":"微风"},"placeContext":{"value":"老榆林"}}}],"weatherOverview":{"value":"多云，午后可能有雨"}}}
        """.utf8
    )

    private static let personalTripGenerationContextData = Data(
        """
        {"data":{"route":{"routeId":"route-1","currentPublicRouteVersionId":"route-1-v1","routeType":"multi_day","generationEligibility":{"eligible":true},"versionLabel":"初始公开版本","name":"贡嘎环线","region":"四川甘孜","start":{"name":"老榆林"},"end":{"name":"草科"},"difficulty":"中等","distance":{"meters":42500},"estimatedDuration":{"seconds":259200}},"personalEquipmentSummary":{"equipmentItemCount":0,"equipmentListCount":0,"knownTotalWeight":{"grams":0},"missingWeightItemCount":0},"equipmentLists":[]}}
        """.utf8
    )

    private static func load(_ name: String, bundle: Bundle) -> Data? {
        let url = bundle.url(forResource: name, withExtension: "json", subdirectory: "MockAPI")
            ?? bundle.url(forResource: name, withExtension: "json")
        guard let url else { return nil }
        return try? Data(contentsOf: url)
    }
}
