import Foundation

public enum DefaultMockFixtures {
     public static func all(bundle: Bundle = .main) -> [String: Data] {
        tripFixtures(bundle: bundle)
            .merging(accountFixtures()) { _, account in account }
            .merging(personalTripFixtures()) { _, personalTrip in personalTrip }
            .merging(tripEquipmentFixtures()) { _, tripEquipment in tripEquipment }
            .merging(routeFixtures()) { _, route in route }
            .merging(equipmentFixtures()) { _, equipment in equipment }
    }

     public static func tripFixtures(bundle: Bundle = .main) -> [String: Data] {
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

     public static func accountFixtures() -> [String: Data] {
        var fixtures = [
            AccountAPI.Current().identifier: Data(#"{"data":{"account":{"identity":"account-1"},"profile":{"identity":"profile-1","maskedPhone":"+86 138****8000","nickname":"行者"}}}"#.utf8),
            AccountAPI.Logout().identifier: Data(#"{"data":{"loggedOut":true}}"#.utf8),
        ]
        if let sendCode = try? AccountAPI.SendVerificationCode(phone: "+8613800138000") {
            fixtures[sendCode.identifier] = Data(#"{"data":{"verificationId":"verification-1","expiresAt":"2026-09-03T05:10:00Z","resendAvailableAt":"2026-09-03T05:01:00Z"}}"#.utf8)
        }
        if let createSession = try? AccountAPI.CreateSession(
            verificationID: "verification-1",
            code: "123456"
        ) {
            fixtures[createSession.identifier] = Data(#"{"data":{"accessToken":"mock-access-token","tokenType":"Bearer"}}"#.utf8)
        }
        return fixtures
    }

     public static func personalTripFixtures() -> [String: Data] {
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
            PersonalTripAPI.Calendar().identifier: Data(#"{"data":{"windowStartDate":"2025-08-26","windowEndDate":"2026-08-27","days":[{"date":"2026-08-25","tripCount":1},{"date":"2026-08-26","tripCount":1},{"date":"2026-08-27","tripCount":1}]}}"#.utf8),
            PersonalTripAPI.Detail(tripID: "trip-1").identifier: personalTripDetailData,
            PersonalTripAPI.Days(tripID: "trip-1").identifier: personalTripDaysData,
            PersonalTripAPI.Weather(tripID: "trip-1").identifier: personalTripWeatherData,
            PersonalTripAPI.RouteVersionStatus(tripID: "trip-1").identifier: personalTripRouteVersionStatusData,
            PersonalTripAPI.GenerationContext(routeID: "route-1").identifier: personalTripGenerationContextData,
        ]
        if let create {
            fixtures[create.identifier] = personalTripCreatedData
        }
        return fixtures
    }

     public static func equipmentFixtures() -> [String: Data] {
        let emptySummary = #"{"equipmentItemCount":0,"equipmentListCount":0,"knownTotalWeight":{"grams":0},"missingWeightItemCount":0}"#
        let populatedSummary = #"{"equipmentItemCount":1,"equipmentListCount":1,"knownTotalWeight":{"grams":3600},"missingWeightItemCount":0}"#
        let originalItem = #"{"identity":"equipment-1","name":"帐篷","ownedQuantity":1}"#
        let updatedItem = #"{"identity":"equipment-1","name":"双人帐篷","ownedQuantity":2,"unitWeight":{"grams":1800}}"#
        let emptyList = #"{"identity":"list-1","name":"周末露营","members":[],"summary":{"itemCount":0,"knownTotalWeight":{"grams":0},"missingWeightItemCount":0}}"#
        let renamedList = #"{"identity":"list-1","name":"高山露营","members":[],"summary":{"itemCount":0,"knownTotalWeight":{"grams":0},"missingWeightItemCount":0}}"#
        let populatedList = #"{"identity":"list-1","name":"周末露营","members":[{"identity":"equipment-1","name":"双人帐篷","ownedQuantity":2,"unitWeight":{"grams":1800},"quantity":2}],"summary":{"itemCount":1,"knownTotalWeight":{"grams":3600},"missingWeightItemCount":0}}"#

        var fixtures = [
            PersonalEquipmentAPI.Collection().identifier: Data("{\"data\":{\"items\":[],\"summary\":\(emptySummary)}}".utf8),
            PersonalEquipmentAPI.Detail(personalEquipmentID: "equipment-1").identifier: Data("{\"data\":\(originalItem)}".utf8),
            PersonalEquipmentAPI.DeletionImpact(personalEquipmentID: "equipment-1").identifier: Data(#"{"data":{"personalEquipmentId":"equipment-1","equipmentListReferenceCount":1,"affectedEquipmentLists":[{"identity":"list-1","name":"周末露营"}]}}"#.utf8),
            PersonalEquipmentAPI.Delete(personalEquipmentID: "equipment-1").identifier: Data("{\"data\":{\"deletedPersonalEquipmentId\":\"equipment-1\",\"removedEquipmentListReferenceCount\":1,\"summary\":\(emptySummary)}}".utf8),
            EquipmentListAPI.Collection().identifier: Data(#"{"data":{"items":[]}}"#.utf8),
            EquipmentListAPI.Detail(equipmentListID: "list-1").identifier: Data("{\"data\":\(emptyList)}".utf8),
            EquipmentListAPI.Delete(equipmentListID: "list-1").identifier: Data("{\"data\":{\"deletedEquipmentListId\":\"list-1\",\"personalEquipmentSummary\":\(emptySummary)}}".utf8),
            EquipmentListAPI.DeleteMember(equipmentListID: "list-1", personalEquipmentID: "equipment-1").identifier: Data("{\"data\":{\"equipmentList\":\(emptyList)}}".utf8),
        ]
        if let request = try? PersonalEquipmentAPI.Create(name: "帐篷", ownedQuantity: 1, unitWeightGrams: nil) {
            fixtures[request.identifier] = Data("{\"data\":{\"item\":\(originalItem),\"summary\":\(populatedSummary)}}".utf8)
        }
        if let request = try? PersonalEquipmentAPI.Update(
            personalEquipmentID: "equipment-1",
            update: PersonalEquipmentUpdate(
                name: "双人帐篷",
                ownedQuantity: 2,
                unitWeight: .value(EquipmentWeight(grams: 1_800))
            )
        ) {
            fixtures[request.identifier] = Data("{\"data\":{\"item\":\(updatedItem),\"summary\":\(populatedSummary)}}".utf8)
        }
        if let request = try? EquipmentListAPI.Create(name: "周末露营") {
            fixtures[request.identifier] = Data("{\"data\":{\"equipmentList\":\(emptyList),\"personalEquipmentSummary\":\(populatedSummary)}}".utf8)
        }
        if let request = try? EquipmentListAPI.Rename(equipmentListID: "list-1", name: "高山露营") {
            fixtures[request.identifier] = Data("{\"data\":{\"equipmentList\":\(renamedList)}}".utf8)
        }
        if let request = try? EquipmentListAPI.PutMember(
            equipmentListID: "list-1",
            personalEquipmentID: "equipment-1",
            quantity: 2
        ) {
            fixtures[request.identifier] = Data("{\"data\":{\"equipmentList\":\(populatedList)}}".utf8)
        }
        return fixtures
    }

     public static func tripEquipmentFixtures() -> [String: Data] {
        [
            TripEquipmentAPI.Current(tripID: "trip-1").identifier: Data(
                """
                {"data":{"trip":{"identity":"trip-1","status":"planned","routeName":"贡嘎环线","startDate":"2026-08-25","endDate":"2026-08-27"},"revision":"revision-1","editable":true,"snapshot":{"identity":"equipment-snapshot-1","items":[\(personalTripEquipmentItemsJSON)],"summary":\(personalTripEquipmentSummaryJSON)}}}
                """.utf8
            ),
        ]
    }

     public static func routeFixtures() -> [String: Data] {
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
        let path = """
        [{"latitude":29.60,"longitude":101.80,"referenceSystem":"WGS84"},{"latitude":29.62,"longitude":101.82,"referenceSystem":"WGS84"},{"latitude":29.645,"longitude":101.84,"referenceSystem":"WGS84"},{"latitude":29.66,"longitude":101.87,"referenceSystem":"WGS84"},{"latitude":29.68,"longitude":101.90,"referenceSystem":"WGS84"},{"latitude":29.70,"longitude":101.92,"referenceSystem":"WGS84"},{"latitude":29.72,"longitude":101.95,"referenceSystem":"WGS84"},{"latitude":29.635,"longitude":101.985,"referenceSystem":"WGS84"}]
        """
        let json = """
        {"data":{"routeId":"\(id)","currentVersion":{"versionId":"\(id)-v1","versionLabel":"经典环线公开版","summary":{"routeType":"multi_day","name":"\(name)","region":"\(region)","start":{"name":"老榆林","position":{"latitude":29.60,"longitude":101.80,"referenceSystem":"WGS84"}},"end":{"name":"草科","position":{"latitude":29.635,"longitude":101.985,"referenceSystem":"WGS84"}},"estimatedDuration":{"seconds":259200},"difficulty":"中等","direction":"环线","distance":{"meters":42500},"ascent":{"meters":2300},"descent":{"meters":2200},"maxElevation":{"meters":4850},"suggestedDays":3,"tags":["雪山","高海拔"],"introduction":"贡嘎环线是围绕贡嘎山主峰展开的多日高山徒步路线，串联老榆林、日乌且垭口与草科温泉，全程以高山草甸和河谷密林为主，景观层次丰富。"},"mainTrackAvailability":"valid","generationEligibility":{"eligible":true,"missingReasons":[]},"mainTrack":{"identity":"main-track-1","path":\(path)},"elevationProfile":{"minElevation":{"meters":1500},"maxElevation":{"meters":4850},"samples":[{"identity":"s-1","distance":{"meters":0},"elevation":{"meters":2720}},{"identity":"s-2","distance":{"meters":6100},"elevation":{"meters":3200}},{"identity":"s-3","distance":{"meters":12500},"elevation":{"meters":3520}},{"identity":"s-4","distance":{"meters":18700},"elevation":{"meters":3950}},{"identity":"s-5","distance":{"meters":25000},"elevation":{"meters":4850}},{"identity":"s-6","distance":{"meters":31200},"elevation":{"meters":4200}},{"identity":"s-7","distance":{"meters":37500},"elevation":{"meters":3400}},{"identity":"s-8","distance":{"meters":42500},"elevation":{"meters":1500}}]},"professionalAnalysis":{"fitnessRequirement":{"value":"较高，日均爬升约 700 米","confidence":{"status":"verified"}},"experienceRequirement":{"value":"需有高原徒步经验","confidence":{"status":"verified"}},"mainTerrain":{"value":"高山草甸与河谷密林","confidence":{"status":"verified"}},"technicalDifficulty":{"value":"中等，垭口有碎石坡","confidence":{"status":"preliminary"}},"highAltitudeImpact":{"value":"最高点 4850 米，谨防高反","confidence":{"status":"verified"}},"exposedSections":{"value":"日乌且垭口段无遮挡，注意防风","confidence":{"status":"preliminary"}},"dangerAreas":{"value":"垭口北坡落石风险高","confidence":{"status":"verified"}},"signalCoverage":{"value":"多数路段无信号，垭口顶部偶有微弱信号","confidence":{"status":"preliminary"}},"evacuationDifficulty":{"value":"部分路段仅能徒步撤离","confidence":{"status":"preliminary"}}},"referenceDays":[{"identity":"ref-day-1","dayNumber":1,"title":"第一天：进山","start":{"name":"老榆林","position":{"latitude":29.60,"longitude":101.80,"referenceSystem":"WGS84"}},"end":{"name":"下日乌且","position":{"latitude":29.645,"longitude":101.84,"referenceSystem":"WGS84"}},"distance":{"meters":12500},"estimatedDuration":{"seconds":18000},"ascent":{"meters":700},"descent":{"meters":120},"maxElevation":{"meters":4280},"minElevation":{"meters":3200},"accommodation":"下日乌且营地","notes":"出发前确认天气，营地水源充足"},{"identity":"ref-day-2","dayNumber":2,"title":"第二天：翻垭口","start":{"name":"下日乌且","position":{"latitude":29.645,"longitude":101.84,"referenceSystem":"WGS84"}},"end":{"name":"草科","position":{"latitude":29.635,"longitude":101.985,"referenceSystem":"WGS84"}},"distance":{"meters":30000},"estimatedDuration":{"seconds":45900},"ascent":{"meters":1600},"descent":{"meters":2080},"maxElevation":{"meters":4850},"minElevation":{"meters":1500},"accommodation":"草科客栈","notes":"垭口下午易起雾，建议早点出发"}],"segments":[{"identity":"seg-1","order":1,"name":"老榆林至下日乌且","start":{"name":"老榆林"},"end":{"name":"下日乌且"},"distance":{"meters":12500},"estimatedDuration":{"seconds":18000},"ascent":{"meters":700},"descent":{"meters":120},"difficulty":"中等","terrainOrRoadType":"机耕路与河谷","description":"沿溪谷缓升，体力消耗平稳","notes":"注意补水","mainTrackRange":{"startPathPosition":{"precedingPositionIndex":0,"progressToNextPosition":0},"endPathPosition":{"precedingPositionIndex":2,"progressToNextPosition":0}}},{"identity":"seg-2","order":2,"name":"下日乌且至上日乌且","start":{"name":"下日乌且"},"end":{"name":"上日乌且"},"distance":{"meters":15500},"estimatedDuration":{"seconds":24300},"ascent":{"meters":950},"descent":{"meters":380},"difficulty":"困难","terrainOrRoadType":"高山草甸","description":"持续爬升，垭口前最后一段坡度大","notes":"垭口后下降较缓","mainTrackRange":{"startPathPosition":{"precedingPositionIndex":2,"progressToNextPosition":0},"endPathPosition":{"precedingPositionIndex":5,"progressToNextPosition":0}}},{"identity":"seg-3","order":3,"name":"上日乌且至草科","start":{"name":"上日乌且"},"end":{"name":"草科"},"distance":{"meters":14500},"estimatedDuration":{"seconds":21600},"ascent":{"meters":650},"descent":{"meters":1700},"difficulty":"中等","terrainOrRoadType":"河谷密林","description":"连续下降至草科乡，结束徒步","notes":"出山后可在草科温泉休整","mainTrackRange":{"startPathPosition":{"precedingPositionIndex":5,"progressToNextPosition":0},"endPathPosition":{"precedingPositionIndex":7,"progressToNextPosition":0}}}],"keyPoints":[{"identity":"kp-1","name":"老榆林","positions":[{"latitude":29.60,"longitude":101.80,"referenceSystem":"WGS84"}],"category":"trailhead","description":"徒步起点，可停车与补给","elevation":{"meters":2720},"media":[]},{"identity":"kp-2","name":"日乌且垭口","positions":[{"latitude":29.68,"longitude":101.90,"referenceSystem":"WGS84"}],"category":"pass","description":"全线最高点，翻越后进入莫溪沟","elevation":{"meters":4850},"media":[]},{"identity":"kp-3","name":"草科温泉","positions":[{"latitude":29.635,"longitude":101.985,"referenceSystem":"WGS84"}],"category":"trailhead","description":"终点，可泡温泉缓解疲劳","elevation":{"meters":1500},"media":[]}],"interestPoints":[{"identity":"poi-1","name":"贡嘎主峰观景台","positions":[{"latitude":29.645,"longitude":101.84,"referenceSystem":"WGS84"}],"category":"scenery","description":"晴天可见贡嘎主峰日照金山","elevation":{"meters":4020},"media":["https://example.test/routes/route-1/poi-1.jpg"]},{"identity":"poi-2","name":"莫溪沟瀑布","positions":[{"latitude":29.70,"longitude":101.92,"referenceSystem":"WGS84"}],"category":"scenery","description":"落差约 40 米的季节性瀑布","elevation":{"meters":3450},"media":[]}],"campsites":[{"identity":"camp-1","name":"下日乌且营地","positions":[{"latitude":29.645,"longitude":101.84,"referenceSystem":"WGS84"}],"elevation":{"meters":3520},"details":"水源充足，夜间风大","status":"regular"},{"identity":"camp-2","name":"上日乌且营地","positions":[{"latitude":29.66,"longitude":101.87,"referenceSystem":"WGS84"}],"elevation":{"meters":3980},"details":"靠近溪流，地面平整","status":"regular"}],"overnightPlaces":[{"identity":"night-1","name":"无卡子客栈","positions":[{"latitude":29.70,"longitude":101.92,"referenceSystem":"WGS84"}],"elevation":{"meters":3260},"type":"客栈","facilities":["热水","电热毯"],"details":"可提前电话预定","status":"open"}],"waterSources":[{"identity":"water-1","name":"日乌且溪","positions":[{"latitude":29.66,"longitude":101.87,"referenceSystem":"WGS84"}],"elevation":{"meters":3950},"sourceType":"溪流","seasonalReliability":"夏季稳定","treatmentRecommended":true,"treatmentAdvice":"烧开或过滤后饮用","description":"流量大，靠近营地"},{"identity":"water-2","name":"草科乡井水","positions":[{"latitude":29.635,"longitude":101.985,"referenceSystem":"WGS84"}],"elevation":{"meters":1500},"sourceType":"泉","seasonalReliability":"四季稳定","treatmentRecommended":false,"treatmentAdvice":null,"description":"村民饮用水源"}],"supplyPoints":[{"identity":"supply-1","name":"子梅村小卖部","positions":[{"latitude":29.62,"longitude":101.82,"referenceSystem":"WGS84"}],"supplyType":"村店","availableItems":["应急食品","瓶装水","打火机"],"description":"只在白天营业"}],"communicationAndSafety":{"coverageSummary":"进山前租借卫星电话；垭口顶部偶有电信信号","notices":[{"identity":"notice-1","kind":"warning","title":"落石区","description":"日乌且垭口北坡有落石风险，快速通过勿停留","positions":[{"latitude":29.68,"longitude":101.90,"referenceSystem":"WGS84"}]},{"identity":"notice-2","kind":"notice","title":"熊出没","description":"营地片区近年出现熊踪，食物需悬挂保存","positions":[{"latitude":29.645,"longitude":101.84,"referenceSystem":"WGS84"},{"latitude":29.66,"longitude":101.87,"referenceSystem":"WGS84"}]}]},"seasonalWeather":{"bestSeasons":["6-10 月"],"conditions":[{"identity":"cond-1","season":"6-8 月","typicalWeather":"多云午后阵雨","environmentalRisks":["暴雨","雷暴"],"notes":"夜间低温接近 0 度"},{"identity":"cond-2","season":"9-10 月","typicalWeather":"晴朗干燥","environmentalRisks":["大风","霜冻"],"notes":"垭口风大，注意防风保暖"}]},"seasonalEquipmentRecommendations":[{"identity":"rec-1","seasonOrCondition":"6-8 月","name":"冲锋衣","level":"required","reason":"午后阵雨频繁，防雨防寒"},{"identity":"rec-2","seasonOrCondition":"全年","name":"头灯","level":"required","reason":"部分路段天黑前行进"},{"identity":"rec-3","seasonOrCondition":"垭口段","name":"冰爪","level":"recommended","reason":"初冬垭口结冰"}],"images":[{"identity":"img-cover","mediaReference":"https://example.test/routes/route-1/cover.jpg","role":"cover","caption":"贡嘎主峰日照金山","position":{"latitude":29.645,"longitude":101.84,"referenceSystem":"WGS84"}},{"identity":"img-1","mediaReference":"https://example.test/routes/route-1/photo-1.jpg","role":"environment","caption":"日乌且垭口","position":{"latitude":29.68,"longitude":101.90,"referenceSystem":"WGS84"}},{"identity":"img-2","mediaReference":"https://example.test/routes/route-1/photo-2.jpg","role":"environment","caption":"莫溪沟溪流","position":{"latitude":29.70,"longitude":101.92,"referenceSystem":"WGS84"}}]}}}
        """
        return Data(json.utf8)
    }

    private static let personalTripSummaryJSON = """
    {"tripId":"trip-1","revision":"revision-1","name":"贡嘎环线三日计划","status":"planned","routeReference":{"routeId":"route-1","adoptedRouteVersionId":"route-1-v1"},"routeName":"贡嘎环线","routeType":"multi_day","start":{"name":"老榆林"},"end":{"name":"草科"},"estimatedDuration":{"seconds":259200},"startDate":"2026-08-25","endDate":"2026-08-27","totalDayCount":3,"hikingDayCount":2,"versionLabel":"初始公开版本","direction":"环线","distance":{"meters":42500},"ascent":{"meters":2300}}
    """

    private static let personalTripDay1WeatherJSON = """
    {"condition":{"value":"多云转阵雨","confidence":{"status":"verified","category":"dynamic_external_information"}},"temperatureRange":{"value":{"low":12,"high":20},"confidence":{"status":"verified","category":"dynamic_external_information"}},"precipitation":{"value":"午后短时阵雨，降水概率 45%","confidence":{"status":"pending_verification","category":"dynamic_external_information"}},"wind":{"value":"西南风 2-3 级","confidence":{"status":"verified","category":"dynamic_external_information"}},"placeContext":{"value":"成都、康定、老榆林","confidence":{"status":"verified"}},"source":{"value":"高原气象服务","confidence":{"status":"verified"}},"updatedAt":{"value":"2026-08-24 20:00","confidence":{"status":"verified"}}}
    """

    private static let personalTripDay2WeatherJSON = """
    {"condition":{"value":"阴转小雨","confidence":{"status":"verified","category":"dynamic_external_information"}},"temperatureRange":{"value":{"low":3,"high":12},"confidence":{"status":"verified","category":"dynamic_external_information"}},"precipitation":{"value":"午后垭口附近可能有雨夹雪","confidence":{"status":"pending_verification","category":"dynamic_external_information"}},"wind":{"value":"山脊西风 4-5 级","confidence":{"status":"verified","category":"dynamic_external_information"}},"placeContext":{"value":"老榆林至下日乌且营地","confidence":{"status":"verified"}},"routeSectionContext":{"value":"老榆林至下日乌且","confidence":{"status":"verified"}},"source":{"value":"高原气象服务","confidence":{"status":"verified"}},"updatedAt":{"value":"2026-08-24 20:00","confidence":{"status":"verified"}}}
    """

    private static let personalTripDay3WeatherJSON = """
    {"condition":{"value":"晴间多云","confidence":{"status":"verified","category":"dynamic_external_information"}},"temperatureRange":{"value":{"low":-2,"high":10},"confidence":{"status":"verified","category":"dynamic_external_information"}},"precipitation":{"value":"垭口降水概率 20%","confidence":{"status":"verified","category":"dynamic_external_information"}},"wind":{"value":"垭口阵风 6 级，信息可能变化","confidence":{"status":"stale","category":"dynamic_external_information"}},"placeContext":{"value":"下日乌且、日乌且垭口、草科","confidence":{"status":"verified"}},"routeSectionContext":{"value":"下日乌且至草科","confidence":{"status":"verified"}},"source":{"value":"高原气象服务","confidence":{"status":"verified"}},"updatedAt":{"value":"2026-08-24 20:00","confidence":{"status":"verified"}}}
    """

    private static let personalTripDay1JSON = """
    {"identity":"trip-day-1","dayNumber":1,"date":"2026-08-25","primaryStage":"交通日","actions":[{"sequence":1,"actionType":"long_distance_transport","origin":{"value":{"name":"成都东站"},"confidence":{"status":"verified"}},"destination":{"value":{"name":"康定客运站"},"confidence":{"status":"verified"}},"mode":{"value":"高铁 + 城际巴士","confidence":{"status":"verified"}},"keyTimes":{"value":["07:15 成都东站出发","10:48 抵达康定"],"confidence":{"status":"verified"}},"estimatedDuration":{"value":{"seconds":12780},"confidence":{"status":"verified"}},"transferNotes":{"value":["康定客运站换乘","预留 40 分钟接驳"],"confidence":{"status":"verified"}}},{"sequence":2,"actionType":"route_transfer","origin":{"value":{"name":"康定客运站"},"confidence":{"status":"verified"}},"destination":{"value":{"name":"老榆林"},"confidence":{"status":"verified"}},"mode":{"value":"预约越野车","confidence":{"status":"verified"}},"keyTimes":{"value":["11:30 康定出发","13:00 抵达老榆林"],"confidence":{"status":"verified"}},"estimatedDuration":{"value":{"seconds":5400},"confidence":{"status":"verified"}},"transferNotes":{"value":["提前一天确认车辆和司机","抵达后核对进山登记"],"confidence":{"status":"pending_verification"}}}],"weather":\(personalTripDay1WeatherJSON),"points":[{"sequence":1,"category":"supply","type":"补给","name":"康定客运站补给点","distance":{"value":{"meters":0},"confidence":{"status":"verified"}},"location":{"value":{"latitude":30.052,"longitude":101.964,"referenceSystem":"WGS84"},"confidence":{"status":"verified"}},"details":{"value":"补齐燃料、路餐和瓶装水，进山后补给有限","confidence":{"status":"verified"}},"isAlternative":false}]}
    """

    private static let personalTripDay2JSON = """
    {"identity":"trip-day-2","dayNumber":2,"date":"2026-08-26","primaryStage":"徒步日 1","hikingDayNumber":1,"actions":[{"sequence":1,"actionType":"hike","routeSectionSnapshot":{"start":{"name":"老榆林","position":{"latitude":29.60,"longitude":101.80,"referenceSystem":"WGS84"}},"end":{"name":"下日乌且","position":{"latitude":29.645,"longitude":101.84,"referenceSystem":"WGS84"}},"name":"老榆林至下日乌且","path":[{"latitude":29.60,"longitude":101.80,"referenceSystem":"WGS84"},{"latitude":29.62,"longitude":101.82,"referenceSystem":"WGS84"},{"latitude":29.645,"longitude":101.84,"referenceSystem":"WGS84"}]},"start":{"value":{"name":"老榆林"},"confidence":{"status":"verified"}},"end":{"value":{"name":"下日乌且营地"},"confidence":{"status":"verified"}},"distance":{"value":{"meters":12500},"confidence":{"status":"verified"}},"ascent":{"value":{"meters":700},"confidence":{"status":"verified"}},"estimatedDuration":{"value":{"seconds":18000},"confidence":{"status":"verified"}},"transferNotes":{"value":["08:00 前出发","河谷段注意涉水点"],"confidence":{"status":"verified"}}}],"weather":\(personalTripDay2WeatherJSON),"points":[{"sequence":1,"category":"water","type":"水源","name":"日乌且溪","distance":{"value":{"meters":6800},"confidence":{"status":"verified"}},"location":{"value":{"latitude":29.63,"longitude":101.83,"referenceSystem":"WGS84"},"confidence":{"status":"verified"}},"details":{"value":"流量稳定，建议过滤或烧开后饮用","confidence":{"status":"verified"}},"isAlternative":false},{"sequence":2,"category":"camp","type":"营地","name":"下日乌且营地","distance":{"value":{"meters":12500},"confidence":{"status":"verified"}},"location":{"value":{"latitude":29.645,"longitude":101.84,"referenceSystem":"WGS84"},"confidence":{"status":"verified"}},"details":{"value":"海拔约 3520 米，水源充足，夜间风大","confidence":{"status":"verified"}},"isAlternative":false},{"sequence":3,"category":"camp","type":"营地","name":"上日乌且备选营地","distance":{"value":{"meters":15100},"confidence":{"status":"preliminary"}},"location":{"value":{"latitude":29.66,"longitude":101.87,"referenceSystem":"WGS84"},"confidence":{"status":"preliminary"}},"details":{"value":"备选 · 距下日乌且约 2.6 km","confidence":{"status":"preliminary"}},"isAlternative":true}]}
    """

    private static let personalTripDay3JSON = """
    {"identity":"trip-day-3","dayNumber":3,"date":"2026-08-27","primaryStage":"徒步日 2","hikingDayNumber":2,"actions":[{"sequence":1,"actionType":"hike","routeSectionSnapshot":{"start":{"name":"下日乌且","position":{"latitude":29.645,"longitude":101.84,"referenceSystem":"WGS84"}},"end":{"name":"草科","position":{"latitude":29.635,"longitude":101.985,"referenceSystem":"WGS84"}},"name":"下日乌且经垭口至草科","path":[{"latitude":29.645,"longitude":101.84,"referenceSystem":"WGS84"},{"latitude":29.68,"longitude":101.90,"referenceSystem":"WGS84"},{"latitude":29.70,"longitude":101.92,"referenceSystem":"WGS84"},{"latitude":29.635,"longitude":101.985,"referenceSystem":"WGS84"}]},"start":{"value":{"name":"下日乌且营地"},"confidence":{"status":"verified"}},"end":{"value":{"name":"草科"},"confidence":{"status":"verified"}},"distance":{"value":{"meters":30000},"confidence":{"status":"verified"}},"ascent":{"value":{"meters":1600},"confidence":{"status":"verified"}},"estimatedDuration":{"value":{"seconds":45900},"confidence":{"status":"verified"}},"transferNotes":{"value":["06:30 前出发翻越垭口","下午雾起前通过暴露路段"],"confidence":{"status":"verified"}}},{"sequence":2,"actionType":"route_transfer","origin":{"value":{"name":"草科徒步终点"},"confidence":{"status":"verified"}},"destination":{"value":{"name":"草科客栈"},"confidence":{"status":"verified"}},"mode":{"value":"当地接驳车","confidence":{"status":"pending_verification"}},"keyTimes":{"value":["预计 19:00 前抵达客栈"],"confidence":{"status":"pending_verification"}},"estimatedDuration":{"value":{"seconds":1800},"confidence":{"status":"preliminary"}},"transferNotes":{"value":["出山前电话确认车辆"],"confidence":{"status":"pending_verification"}}},{"sequence":3,"actionType":"long_distance_transport","origin":{"value":{"name":"草科"},"confidence":{"status":"verified"}},"destination":{"value":{"name":"成都"},"confidence":{"status":"verified"}},"mode":{"value":"次日预约车辆返程","confidence":{"status":"preliminary"}},"keyTimes":{"value":["返程班次需在出发前再次确认"],"confidence":{"status":"pending_verification"}},"estimatedDuration":{"value":{"seconds":21600},"confidence":{"status":"preliminary"}},"transferNotes":{"value":["本项为返程安排摘要，不虚构具体班次"],"confidence":{"status":"verified"}}}],"weather":\(personalTripDay3WeatherJSON),"points":[{"sequence":1,"category":"key_point","type":"垭口","name":"日乌且垭口","distance":{"value":{"meters":9800},"confidence":{"status":"verified"}},"location":{"value":{"latitude":29.68,"longitude":101.90,"referenceSystem":"WGS84"},"confidence":{"status":"verified"}},"details":{"value":"海拔约 4850 米，北坡碎石和落石风险高","confidence":{"status":"verified"}},"isAlternative":false},{"sequence":2,"category":"water","type":"水源","name":"莫溪沟溪流","distance":{"value":{"meters":18300},"confidence":{"status":"verified"}},"location":{"value":{"latitude":29.70,"longitude":101.92,"referenceSystem":"WGS84"},"confidence":{"status":"verified"}},"details":{"value":"下降途中可补水，建议过滤","confidence":{"status":"verified"}},"isAlternative":false},{"sequence":3,"category":"overnight","type":"住宿","name":"草科客栈","distance":{"value":{"meters":30000},"confidence":{"status":"verified"}},"location":{"value":{"latitude":29.635,"longitude":101.985,"referenceSystem":"WGS84"},"confidence":{"status":"verified"}},"details":{"value":"可洗热水澡并补充正餐，建议提前预订","confidence":{"status":"pending_verification"}},"isAlternative":false}]}
    """

    private static let personalTripDaysJSON = """
    \(personalTripDay1JSON),\(personalTripDay2JSON),\(personalTripDay3JSON)
    """

    private static let personalTripEquipmentSummaryJSON = """
    {"itemCount":8,"knownTotalWeight":{"grams":7200},"missingWeightItemCount":1,"ownedItemCount":6,"unconfirmedOwnedItemCount":2}
    """

    private static let personalTripEquipmentItemsJSON = """
    {"identity":"trip-equipment-1","name":"双人帐篷","quantity":1,"unitWeight":{"grams":1800},"note":"含地钉和风绳","source":"system_suggestion","ownershipStatus":"owned"},
    {"identity":"trip-equipment-2","name":"零度睡袋","quantity":1,"unitWeight":{"grams":1200},"note":"舒适温标 0℃","source":"system_suggestion","ownershipStatus":"owned"},
    {"identity":"trip-equipment-3","name":"充气防潮垫","quantity":1,"unitWeight":{"grams":500},"note":null,"source":"user_adjusted","ownershipStatus":"owned"},
    {"identity":"trip-equipment-4","name":"冲锋衣裤","quantity":1,"unitWeight":{"grams":700},"note":"防雨并兼顾垭口防风","source":"system_suggestion","ownershipStatus":"owned"},
    {"identity":"trip-equipment-5","name":"炉头与套锅","quantity":1,"unitWeight":{"grams":400},"note":"燃料需在康定补充","source":"system_suggestion","ownershipStatus":"unconfirmed_owned"},
    {"identity":"trip-equipment-6","name":"头灯","quantity":1,"unitWeight":{"grams":100},"note":"携带备用电池","source":"system_suggestion","ownershipStatus":"owned"},
    {"identity":"trip-equipment-7","name":"饮水与水袋","quantity":2,"unitWeight":{"grams":1250},"note":"起步携带约 2.5 L","source":"user_adjusted","ownershipStatus":"owned"},
    {"identity":"trip-equipment-8","name":"个人急救包","quantity":1,"unitWeight":null,"note":"包含高反药物和保温毯","source":"user_added","ownershipStatus":"unconfirmed_owned"}
    """

    private static let personalTripRouteVersionStatusJSON = """
    {"tripId":"trip-1","tripRevision":"revision-1","adoptedVersion":{"routeVersionId":"route-1-v1","versionLabel":"初始公开版本"},"currentPublicVersion":{"routeVersionId":"route-1-v1","versionLabel":"初始公开版本"},"versionRelationship":"current","migrationEligible":false}
    """

    private static let personalTripDetailJSON = """
    {"revision":"revision-1","trip":{"identity":"trip-1","name":"贡嘎环线三日计划","firstGeneratedAt":"2026-08-01T10:00:00Z","status":"planned","departureCity":"成都","startDate":"2026-08-25","endDate":"2026-08-27","totalDayCount":3,"hikingDayCount":2,"frozenRouteBasis":{"routeName":"贡嘎环线","routeType":"multi_day","region":"四川甘孜","start":{"name":"老榆林","position":{"latitude":29.60,"longitude":101.80,"referenceSystem":"WGS84"}},"end":{"name":"草科","position":{"latitude":29.635,"longitude":101.985,"referenceSystem":"WGS84"}},"estimatedDuration":{"seconds":259200},"mainTrackPath":[{"latitude":29.60,"longitude":101.80,"referenceSystem":"WGS84"},{"latitude":29.62,"longitude":101.82,"referenceSystem":"WGS84"},{"latitude":29.645,"longitude":101.84,"referenceSystem":"WGS84"},{"latitude":29.66,"longitude":101.87,"referenceSystem":"WGS84"},{"latitude":29.68,"longitude":101.90,"referenceSystem":"WGS84"},{"latitude":29.70,"longitude":101.92,"referenceSystem":"WGS84"},{"latitude":29.72,"longitude":101.95,"referenceSystem":"WGS84"},{"latitude":29.635,"longitude":101.985,"referenceSystem":"WGS84"}],"versionLabel":"初始公开版本","direction":"环线","distance":{"meters":42500},"ascent":{"meters":2300},"descent":{"meters":2200},"maxElevation":{"meters":4850}},"weatherOverview":{"summary":{"value":"首日多云转阵雨，垭口日风大且低温","confidence":{"status":"pending_verification","category":"dynamic_external_information"}}},"importantNotices":[{"sequence":1,"type":"altitude","content":{"value":"最高海拔约 4850 米，出发前确认高反应对方案","confidence":{"status":"verified"}}},{"sequence":2,"type":"weather","content":{"value":"日乌且垭口午后易起雾并伴随强风，建议尽早通过","confidence":{"status":"pending_verification"}}},{"sequence":3,"type":"safety","content":{"value":"营地附近曾有熊踪，食物与有气味物品需悬挂保存","confidence":{"status":"verified"}}}]},"routeReference":{"routeId":"route-1","adoptedRouteVersionId":"route-1-v1"},"days":[\(personalTripDaysJSON)],"equipmentSnapshot":{"snapshotId":"equipment-snapshot-1","summary":\(personalTripEquipmentSummaryJSON)},"routeVersionStatus":\(personalTripRouteVersionStatusJSON)}
    """

    private static let personalTripDetailData = Data(
        "{\"data\":\(personalTripDetailJSON)}".utf8
    )

    private static let personalTripCreatedData = Data(
        "{\"data\":{\"resultType\":\"trip_created\",\"trip\":\(personalTripDetailJSON)}}".utf8
    )

    private static let personalTripDaysData = Data(
        """
        {"data":{"tripId":"trip-1","revision":"revision-1","startDate":"2026-08-25","endDate":"2026-08-27","totalDayCount":3,"hikingDayCount":2,"days":[\(personalTripDaysJSON)]}}
        """.utf8
    )

    private static let personalTripWeatherData = Data(
        """
        {"data":{"tripId":"trip-1","revision":"revision-1","days":[{"tripDayId":"trip-day-1","dayNumber":1,"date":"2026-08-25","weatherAssociations":[{"associationIdentity":"weather-association-1","sequence":1,"scope":"day","targetLocation":{"position":{"latitude":29.60,"longitude":101.80,"referenceSystem":"WGS84"},"name":"老榆林"},"targetPeriodStart":"2026-08-24T16:00:00Z","targetPeriodEnd":"2026-08-25T16:00:00Z","forecastConfidence":{"status":"unavailable","category":"dynamic_external_information"}}]},{"tripDayId":"trip-day-2","dayNumber":2,"date":"2026-08-26","weatherAssociations":[{"associationIdentity":"weather-association-1","sequence":1,"scope":"hike_action","hikeActionIdentity":"hike-action-1","targetLocation":{"position":{"latitude":29.645,"longitude":101.84,"referenceSystem":"WGS84"},"name":"下日乌且"},"targetPeriodStart":"2026-08-25T22:00:00Z","targetPeriodEnd":"2026-08-26T14:00:00Z","forecast":{"identity":"weather-forecast-1","location":{"position":{"latitude":29.645,"longitude":101.84,"referenceSystem":"WGS84"},"name":"下日乌且"},"source":"高原气象服务","publishedAt":"2026-08-24T12:00:00Z","periods":[{"periodStart":"2026-08-25T22:00:00Z","periodEnd":"2026-08-26T06:00:00Z","condition":{"value":{"description":"阴转小雨"}},"temperatureRange":{"value":{"low":3,"high":12}},"precipitation":{"value":{"description":"午后可能有雨夹雪","probability":0.45}},"wind":{"value":{"description":"山脊西风","averageSpeed":{"metersPerSecond":6},"gustSpeed":{"metersPerSecond":10},"direction":"西风"}}}]}}]},{"tripDayId":"trip-day-3","dayNumber":3,"date":"2026-08-27","weatherAssociations":[{"associationIdentity":"weather-association-1","sequence":1,"scope":"hike_action","hikeActionIdentity":"hike-action-1","targetLocation":{"position":{"latitude":29.68,"longitude":101.90,"referenceSystem":"WGS84"},"name":"日乌且垭口"},"targetPeriodStart":"2026-08-26T22:00:00Z","targetPeriodEnd":"2026-08-27T14:00:00Z","forecastConfidence":{"status":"stale","category":"dynamic_external_information"},"forecast":{"identity":"weather-forecast-2","location":{"position":{"latitude":29.68,"longitude":101.90,"referenceSystem":"WGS84"},"name":"日乌且垭口"},"source":"高原气象服务","publishedAt":"2026-08-24T12:00:00Z","periods":[{"periodStart":"2026-08-26T22:00:00Z","periodEnd":"2026-08-27T10:00:00Z","condition":{"value":{"description":"晴间多云"}},"temperatureRange":{"value":{"low":-2,"high":10}},"wind":{"value":{"description":"垭口阵风较强","averageSpeed":{"metersPerSecond":8},"gustSpeed":{"metersPerSecond":14},"direction":"西风"}}}]}}]}]}}
        """.utf8
    )

    private static let personalTripRouteVersionStatusData = Data(
        """
        {"data":\(personalTripRouteVersionStatusJSON)}
        """.utf8
    )

    private static let personalTripGenerationContextData = Data(
        """
        {"data":{"route":{"routeId":"route-1","currentPublicRouteVersionId":"route-1-v1","routeType":"multi_day","generationEligibility":{"eligible":true},"versionLabel":"初始公开版本","name":"贡嘎环线","region":"四川甘孜","start":{"name":"老榆林"},"end":{"name":"草科"},"difficulty":"中等","distance":{"meters":42500},"estimatedDuration":{"seconds":259200}},"personalEquipmentSummary":{"equipmentItemCount":8,"equipmentListCount":1,"knownTotalWeight":{"grams":7200},"missingWeightItemCount":1},"equipmentLists":[{"equipmentListId":"equipment-list-1","name":"贡嘎三日轻装清单","summary":{"itemCount":8,"knownTotalWeight":{"grams":7200},"missingWeightItemCount":1}}]}}
        """.utf8
    )

    private static func load(_ name: String, bundle: Bundle) -> Data? {
        let url = bundle.url(forResource: name, withExtension: "json", subdirectory: "MockAPI")
            ?? bundle.url(forResource: name, withExtension: "json")
        guard let url else { return nil }
        return try? Data(contentsOf: url)
    }
}
