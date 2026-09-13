#if DEBUG
import Foundation
import SwiftUI
import WalkData
import WalkDesignSystem

struct BusinessComponentPreviewHost<Content: View>: View {
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        ScrollView {
            content
                .frame(maxWidth: 560, alignment: .leading)
                .padding(Spacing.lg)
                .frame(maxWidth: .infinity, alignment: .top)
        }
        .background(AppColors.pageBase)
        .foregroundStyle(AppColors.textPrimary)
    }
}

enum BusinessComponentPreviewFixtures {
    static let operationError = "网络连接中断，当前操作没有完成，请稍后重试。"
    static let fixedExpiry = Date(timeIntervalSince1970: 1_789_690_500)
    static let fixedResend = Date(timeIntervalSince1970: 1_789_689_900)
    static let fixedRetry = Date(timeIntervalSince1970: 1_789_690_020)

    static let profileDefault = ProfileProjection(
        identity: "profile-001",
        maskedPhone: "138****8000",
        nickname: "林野",
        avatar: nil
    )

    static let profileWithAvatar = ProfileProjection(
        identity: "profile-002",
        maskedPhone: "+86*******8000",
        nickname: "林野",
        avatar: "local-preview-avatar"
    )

    static let profileMinimal = ProfileProjection(
        identity: "profile-003",
        maskedPhone: "+44*******0186",
        nickname: nil,
        avatar: nil
    )

    static let authPhone = AuthPanelProjection(
        stage: .phone,
        sourceContext: "登录后继续管理个人资料与装备。",
        phone: "+8613800138000"
    )

    static let authPhoneInvalid = AuthPanelProjection(
        stage: .phone,
        sourceContext: "登录后继续管理个人资料与装备。",
        phone: "138",
        fieldError: "请输入有效的 E.164 手机号",
        isPrimaryEnabled: false
    )

    static let authSending = AuthPanelProjection(
        stage: .phone,
        sourceContext: "登录后继续管理个人资料与装备。",
        phone: "+8613800138000",
        isLoading: true,
        isPrimaryEnabled: false
    )

    static let authThrottled = AuthPanelProjection(
        stage: .phone,
        sourceContext: "登录后继续管理个人资料与装备。",
        phone: "+8613800138000",
        retryAvailableAt: fixedRetry,
        isPrimaryEnabled: false
    )

    static let authSendFailed = AuthPanelProjection(
        stage: .phone,
        sourceContext: "登录后继续管理个人资料与装备。",
        phone: "+8613800138000",
        operationError: "验证码发送失败，请保留手机号后重试。"
    )

    static let authCode = AuthPanelProjection(
        stage: .code,
        sourceContext: "完成验证后将继续刚才的任务。",
        phone: "+8613800138000",
        code: "012345",
        verificationID: "verification-001",
        expiresAt: fixedExpiry,
        resendAvailableAt: fixedResend
    )

    static let authCodeInvalid = AuthPanelProjection(
        stage: .code,
        sourceContext: "完成验证后将继续刚才的任务。",
        phone: "+8613800138000",
        code: "01234",
        verificationID: "verification-001",
        expiresAt: fixedExpiry,
        resendAvailableAt: fixedResend,
        fieldError: "验证码不正确",
        isPrimaryEnabled: false
    )

    static let authExpired = AuthPanelProjection(
        stage: .code,
        sourceContext: "完成验证后将继续刚才的任务。",
        phone: "+8613800138000",
        code: "012345",
        verificationID: "verification-001",
        expiresAt: fixedExpiry,
        resendAvailableAt: fixedResend,
        operationError: "验证码已过期，请重新获取。",
        isPrimaryEnabled: false
    )

    static let authVerifying = AuthPanelProjection(
        stage: .code,
        sourceContext: "完成验证后将继续刚才的任务。",
        phone: "+8613800138000",
        code: "012345",
        verificationID: "verification-001",
        expiresAt: fixedExpiry,
        resendAvailableAt: fixedResend,
        isLoading: true,
        isPrimaryEnabled: false,
        isSecondaryEnabled: false
    )

    static let authConfirmingFocus = AuthPanelProjection(
        stage: .confirmingFocus,
        sourceContext: "登录已完成，正在恢复行程上下文。",
        verificationID: "verification-001",
        expiresAt: fixedExpiry,
        resendAvailableAt: fixedResend,
        isLoading: true
    )

    static let authFocusError = AuthPanelProjection(
        stage: .focusError,
        sourceContext: "登录已完成，但刚才的个人任务尚未恢复。",
        verificationID: "verification-001",
        expiresAt: fixedExpiry,
        resendAvailableAt: fixedResend,
        operationError: "焦点行程读取失败，登录状态已保留。"
    )

    static let checklistMemberKnown = ChecklistItemRowProjection(
        identity: "equipment-001",
        listIdentity: "list-001",
        listName: "周末轻装清单",
        equipmentName: "双人轻量帐篷",
        ownedQuantity: 1,
        quantity: 1,
        unitWeightGrams: 1_680
    )

    static let checklistMemberUnknown = ChecklistItemRowProjection(
        identity: "equipment-002",
        listIdentity: "list-001",
        listName: "周末轻装清单",
        equipmentName: "应急保温毯",
        ownedQuantity: 3,
        quantity: 2,
        unitWeightGrams: nil
    )

    static let checklistMembers = [checklistMemberKnown, checklistMemberUnknown]

    static let checklistSummary = EquipmentListSummaryProjection(
        identity: "list-001",
        name: "周末轻装清单",
        itemCount: 2,
        knownTotalWeightGrams: 1_680,
        missingWeightItemCount: 0
    )

    static let checklistUnknownWeightSummary = EquipmentListSummaryProjection(
        identity: "list-002",
        name: "高海拔过夜与连续降雨备用清单",
        itemCount: 2,
        knownTotalWeightGrams: 1_680,
        missingWeightItemCount: 1
    )

    static let deletionImpact = PersonalEquipmentDeletionImpact(
        personalEquipmentId: "equipment-001",
        equipmentListReferenceCount: 2,
        affectedEquipmentLists: [
            EquipmentListReference(identity: "list-001", name: "周末轻装清单"),
            EquipmentListReference(identity: "list-002", name: "连续降雨与高海拔过夜备用清单"),
        ]
    )

    static let deletionImpactNone = PersonalEquipmentDeletionImpact(
        personalEquipmentId: "equipment-003",
        equipmentListReferenceCount: 0,
        affectedEquipmentLists: []
    )

    static let personalEquipmentRow = EquipmentListRowProjection.personalAsset(
        PersonalEquipmentRowProjection(
            identity: "equipment-001",
            name: "双人轻量帐篷",
            ownedQuantity: 1,
            unitWeightGrams: 1_680
        )
    )

    static let inlineEquipmentDefault = InlineEquipmentEditorProjection(
        title: "修改本次装备",
        name: "双人轻量帐篷",
        quantity: 1,
        unitWeight: "1680",
        note: "营地夜间有风"
    )

    static let inlineEquipmentValidationError = InlineEquipmentEditorProjection(
        title: "新增本次装备",
        name: "",
        quantity: 1,
        unitWeight: "-20",
        note: "",
        nameError: "请输入装备名称",
        unitWeightError: "请输入大于零的克重"
    )

    static let inlineEquipmentSaveFailed = InlineEquipmentEditorProjection(
        title: "修改本次装备",
        name: "双人轻量帐篷",
        quantity: 1,
        unitWeight: "1680",
        note: "营地夜间有风",
        saveError: operationError
    )

    static let inlineListDefault = InlineListNameEditorProjection(
        mode: .create,
        name: "周末轻装清单"
    )

    static let inlineListValidationError = InlineListNameEditorProjection(
        mode: .rename,
        name: " ",
        fieldError: "请输入清单名称"
    )

    static let inlineListSaveFailed = InlineListNameEditorProjection(
        mode: .rename,
        name: "高海拔过夜清单",
        saveError: operationError
    )

    static let personalEquipmentFormDefault = PersonalEquipmentFormProjection(
        name: "双人轻量帐篷",
        ownedQuantity: "1",
        unitWeight: "1680"
    )

    static let personalEquipmentFormCreate = PersonalEquipmentFormProjection(
        name: "",
        ownedQuantity: "1",
        unitWeight: ""
    )

    static let personalEquipmentFormValidationError = PersonalEquipmentFormProjection(
        name: " ",
        ownedQuantity: "0",
        unitWeight: "-20",
        nameError: "请输入装备名称",
        ownedQuantityError: "请输入大于零的正整数",
        unitWeightError: "请输入大于零的克重"
    )

    static let personalEquipmentFormSaveFailed = PersonalEquipmentFormProjection(
        name: "双人轻量帐篷",
        ownedQuantity: "1",
        unitWeight: "1680",
        saveError: operationError
    )

    static let personalEquipmentSummary = PersonalEquipmentSummary(
        equipmentItemCount: 12,
        equipmentListCount: 3,
        knownTotalWeight: EquipmentWeight(grams: 8_420),
        missingWeightItemCount: 2
    )

    static let personalEquipmentSummaryEmpty = PersonalEquipmentSummary(
        equipmentItemCount: 0,
        equipmentListCount: 0,
        knownTotalWeight: EquipmentWeight(grams: 0),
        missingWeightItemCount: 0
    )

    static let elevationProfile = ElevationProfileProjection(
        minimumLabel: "1,240 m",
        maximumLabel: "2,860 m",
        minimumElevation: 1_240,
        maximumElevation: 2_860,
        samples: [
            RouteElevationSampleProjection(id: "elevation-1", distance: 0, elevation: 1_240),
            RouteElevationSampleProjection(id: "elevation-2", distance: 3_200, elevation: 1_780),
            RouteElevationSampleProjection(id: "elevation-3", distance: 7_400, elevation: 2_420),
            RouteElevationSampleProjection(id: "elevation-4", distance: 11_800, elevation: 2_860),
            RouteElevationSampleProjection(id: "elevation-5", distance: 16_300, elevation: 2_110),
        ]
    )

    static let elevationProfileCompact = ElevationProfileProjection(
        minimumLabel: "820 m",
        maximumLabel: "1,320 m",
        minimumElevation: 820,
        maximumElevation: 1_320,
        samples: [
            RouteElevationSampleProjection(id: "compact-1", distance: 0, elevation: 820),
            RouteElevationSampleProjection(id: "compact-2", distance: 2_400, elevation: 1_320),
            RouteElevationSampleProjection(id: "compact-3", distance: 5_600, elevation: 980),
        ]
    )

    static let generationRouteDefault = GenerationRouteSummaryProjection(
        routeType: "多日路线",
        generationEligibility: .eligible(label: "可生成"),
        name: "贡嘎西南坡环线",
        versionLabel: "2026 夏季版",
        region: "四川 · 甘孜",
        start: "上木居",
        end: "草科",
        difficulty: "进阶",
        distance: "42.8 km",
        estimatedDuration: "4 天"
    )

    static let generationRoutePartial = GenerationRouteSummaryProjection(
        routeType: "一日路线",
        generationEligibility: .eligible(label: "可生成"),
        name: nil,
        versionLabel: nil,
        region: "北京 · 门头沟",
        start: nil,
        end: nil,
        difficulty: nil,
        distance: "12.4 km",
        estimatedDuration: nil
    )

    static let generationRouteIneligible = GenerationRouteSummaryProjection(
        routeType: "多日路线",
        generationEligibility: .ineligible(label: "资料不足"),
        name: "峡谷穿越候选路线",
        versionLabel: "资料核验中",
        region: "云南 · 怒江",
        start: "北侧入口",
        end: "南侧出口",
        difficulty: "困难",
        distance: nil,
        estimatedDuration: nil
    )

    static let generationRouteLong = GenerationRouteSummaryProjection(
        routeType: "多日路线",
        generationEligibility: .eligible(label: "可生成"),
        name: "跨越高山草甸、原始森林与连续垭口的长距离徒步路线",
        versionLabel: "2026 年雨季前公开核验版本",
        region: "四川省甘孜藏族自治州康定市与泸定县交界区域",
        start: "高山村北侧徒步入口",
        end: "河谷游客服务站",
        difficulty: "高海拔进阶路线",
        distance: "68.5 km",
        estimatedDuration: "6 天"
    )

    static let generationWaiting = GenerationWaitingProjection(
        title: "正在整理贡嘎西南坡环线",
        description: "请稍候，个人行程结果形成后会在当前流程中继续展示。"
    )

    // MARK: - GenerationEquipmentSelection

    private static let generationEquipmentListA = GenerationEquipmentListOptionProjection(
        equipmentListID: "list-a",
        name: "贡嘎西南坡三日夏季清单",
        itemCount: 14,
        knownTotalWeightGrams: 9200,
        missingWeightItemCount: 0
    )

    private static let generationEquipmentListB = GenerationEquipmentListOptionProjection(
        equipmentListID: "list-b",
        name: "高海拔垭口穿越轻量化清单",
        itemCount: 11,
        knownTotalWeightGrams: 7400,
        missingWeightItemCount: 2
    )

    private static let generationEquipmentListLong = GenerationEquipmentListOptionProjection(
        equipmentListID: "list-long",
        name: "含备用保暖、防潮与应急通讯的长距离多日徒步综合装备清单",
        itemCount: 23,
        knownTotalWeightGrams: 12_600,
        missingWeightItemCount: 4
    )

    static let generationEquipmentDefault = GenerationEquipmentSelectionProjection(
        equipmentItemCount: 18,
        equipmentListCount: 2,
        knownTotalWeightGrams: 9800,
        missingWeightItemCount: 0,
        equipmentLists: [generationEquipmentListA, generationEquipmentListB],
        selectedEquipmentListID: nil
    )

    static let generationEquipmentSelected = GenerationEquipmentSelectionProjection(
        equipmentItemCount: 18,
        equipmentListCount: 2,
        knownTotalWeightGrams: 9800,
        missingWeightItemCount: 0,
        equipmentLists: [generationEquipmentListA, generationEquipmentListB],
        selectedEquipmentListID: "list-b"
    )

    static let generationEquipmentNoPersonalEquipment = GenerationEquipmentSelectionProjection(
        equipmentItemCount: 0,
        equipmentListCount: 2,
        knownTotalWeightGrams: 0,
        missingWeightItemCount: 0,
        equipmentLists: [generationEquipmentListA, generationEquipmentListB],
        selectedEquipmentListID: nil
    )

    static let generationEquipmentNoLists = GenerationEquipmentSelectionProjection(
        equipmentItemCount: 18,
        equipmentListCount: 0,
        knownTotalWeightGrams: 9800,
        missingWeightItemCount: 0,
        equipmentLists: [],
        selectedEquipmentListID: nil
    )

    static let generationEquipmentEmpty = GenerationEquipmentSelectionProjection(
        equipmentItemCount: 0,
        equipmentListCount: 0,
        knownTotalWeightGrams: 0,
        missingWeightItemCount: 0,
        equipmentLists: [],
        selectedEquipmentListID: nil
    )

    static let generationEquipmentPartialWeight = GenerationEquipmentSelectionProjection(
        equipmentItemCount: 18,
        equipmentListCount: 2,
        knownTotalWeightGrams: 7600,
        missingWeightItemCount: 3,
        equipmentLists: [generationEquipmentListA, generationEquipmentListB],
        selectedEquipmentListID: nil
    )

    static let generationEquipmentLong = GenerationEquipmentSelectionProjection(
        equipmentItemCount: 26,
        equipmentListCount: 3,
        knownTotalWeightGrams: 14_200,
        missingWeightItemCount: 5,
        equipmentLists: [generationEquipmentListLong, generationEquipmentListA, generationEquipmentListB],
        selectedEquipmentListID: "list-long"
    )

    // MARK: - TransportOptionSelection

    static let transportSelectionUnselected = TransportOptionSelectionProjection(
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

    static let transportSelectionSelected = TransportOptionSelectionProjection(
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

    static let transportSelectionPartial = TransportOptionSelectionProjection(
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

    static let transportSelectionLong = TransportOptionSelectionProjection(
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

    static let routeSafetyFacts = RouteFactSectionProjection(
        title: "通信与安全",
        items: [
            RouteFactItemProjection(id: "safety-signal", bookmark: "信", title: "通信覆盖", content: "峡谷路段信号不稳定，垭口附近可短暂恢复。"),
            RouteFactItemProjection(id: "safety-risk", bookmark: "险", title: "危险区域", content: "雨后碎石坡湿滑，需避开坡脚停留。"),
            RouteFactItemProjection(id: "safety-evacuation", bookmark: "撤", title: "撤离难度", content: "中段最近公路距离较远，需预留返程体力。"),
        ]
    )

    static let routeSeasonFacts = RouteFactSectionProjection(
        title: "季节天气",
        items: [
            RouteFactItemProjection(id: "season-main", bookmark: "季", title: "适宜季节", content: "五月下旬至六月、九月至十月。"),
            RouteFactItemProjection(id: "season-summer", bookmark: "夏", title: "夏季", content: "午后对流天气频繁，需提前通过暴露山脊。"),
            RouteFactItemProjection(id: "season-autumn", bookmark: "秋", title: "秋季", content: "昼夜温差明显，背阴坡可能提前结冰。"),
        ]
    )

    static let routeImages = [
        RouteImageProjection(id: "route-image-1", title: "高山垭口", description: "从垭口回望连续山谷。"),
        RouteImageProjection(id: "route-image-2", title: "林线营地", description: "靠近稳定水源的开阔营地。"),
        RouteImageProjection(id: "route-image-3", title: "河谷路段", description: "沿河谷下降的主要路径。"),
    ]

    static func imageStyle(for identity: String) -> RouteVisualStyle {
        switch identity {
        case "route-image-2": .forest
        case "route-image-3": .water
        default: .ridge
        }
    }

    static let routeIntroduction = RouteIntroductionProjection(
        introduction: "路线连接高山草甸、冰川遗迹与河谷森林，适合具备连续多日徒步经验的队伍。",
        analysisItems: [
            RouteAnalysisItemProjection(id: "analysis-fitness", mark: "体", title: "体能要求", description: "连续上升路段较长，需要稳定的负重行走能力。"),
            RouteAnalysisItemProjection(id: "analysis-terrain", mark: "地", title: "主要地形", description: "以山地土路、碎石坡和草甸横切为主。"),
        ]
    )

    static let routeIntroductionLong = RouteIntroductionProjection(
        introduction: "这条路线穿过连续变化的高山环境，从河谷森林逐步进入高山草甸，再跨越开阔垭口。沿途天气变化快，完整行程需要为长距离爬升、湿滑路面与低温环境留出充分余量。",
        analysisItems: [
            RouteAnalysisItemProjection(id: "analysis-experience", mark: "经", title: "经验要求", description: "需要具备在能见度下降时识别主路径、管理队伍节奏并根据实际天气及时折返的经验。"),
            RouteAnalysisItemProjection(id: "analysis-altitude", mark: "高", title: "高海拔影响", description: "多个连续路段位于高海拔区域，队伍应按实际成员情况安排适应时间，不由路线介绍替代个人风险判断。"),
            RouteAnalysisItemProjection(id: "analysis-exposure", mark: "露", title: "暴露路段", description: "垭口两侧缺少稳定遮蔽物，雷雨、大风或结冰条件下通过难度明显增加。"),
        ]
    )

    static let routeRowDefault = RouteListRowProjection.browse(
        RouteBrowseRowProjection(
            routeID: "route-001",
            coverAvailable: true,
            name: "贡嘎西南坡环线",
            region: "四川 · 甘孜",
            difficulty: "进阶",
            distance: "42.8 km",
            ascent: "爬升 2,340 m",
            estimatedDuration: "约 4 天"
        )
    )

    static let routeRowNameMissing = RouteListRowProjection.browse(
        RouteBrowseRowProjection(
            routeID: "route-003",
            coverAvailable: true,
            name: nil,
            region: "云南 · 怒江",
            difficulty: "困难",
            distance: "31.2 km",
            ascent: "爬升 1,980 m",
            estimatedDuration: "约 3 天"
        )
    )

    static let routeRowCoverMissing = RouteListRowProjection.browse(
        RouteBrowseRowProjection(
            routeID: "route-004",
            coverAvailable: false,
            name: "峡谷森林线",
            region: "云南 · 怒江",
            difficulty: "中等",
            distance: "21.4 km",
            ascent: "爬升 1,120 m",
            estimatedDuration: "约 2 天"
        )
    )

    static let routeRowPartial = RouteListRowProjection.browse(
        RouteBrowseRowProjection(
            routeID: "route-005",
            coverAvailable: true,
            name: "白河峡谷",
            region: nil,
            difficulty: nil,
            distance: "9.8 km",
            ascent: nil,
            estimatedDuration: nil
        )
    )

    static let routeRowMinimal = RouteListRowProjection.browse(
        RouteBrowseRowProjection(
            routeID: "route-006",
            coverAvailable: false,
            name: "河谷短线",
            region: nil,
            difficulty: nil,
            distance: nil,
            ascent: nil,
            estimatedDuration: nil
        )
    )

    static let routeRowLong = RouteListRowProjection.browse(
        RouteBrowseRowProjection(
            routeID: "route-007",
            coverAvailable: true,
            name: "穿越原始森林、高山草甸与连续垭口的长距离环形徒步路线",
            region: "四川省甘孜藏族自治州康定市与泸定县交界区域",
            difficulty: "高海拔进阶路线",
            distance: "68.5 km",
            ascent: "爬升 3,920 m",
            estimatedDuration: "约 6 天"
        )
    )

    static let searchResultRowDefault = SearchRouteResultRowProjection(
        routeID: "route-search-001",
        coverAvailable: true,
        name: "海坨山谷穿越",
        region: "北京 · 延庆",
        difficulty: "中等",
        distance: "18.6 km",
        estimatedDuration: "约 8 小时"
    )

    static let searchResultRowNameMissing = SearchRouteResultRowProjection(
        routeID: "route-search-002",
        coverAvailable: true,
        name: nil,
        region: "云南 · 香格里拉",
        difficulty: "进阶",
        distance: "32.0 km",
        estimatedDuration: "约 3 天"
    )

    static let searchResultRowCoverMissing = SearchRouteResultRowProjection(
        routeID: "route-search-003",
        coverAvailable: false,
        name: "五台山逆穿",
        region: "山西 · 忻州",
        difficulty: "中等",
        distance: "52.0 km",
        estimatedDuration: "约 3 天"
    )

    static let searchResultRowPartial = SearchRouteResultRowProjection(
        routeID: "route-search-004",
        coverAvailable: true,
        name: "武功山穿越",
        region: nil,
        difficulty: nil,
        distance: "24.0 km",
        estimatedDuration: nil
    )

    static let routePointDetail = RoutePointDetailProjection(
        id: "point-camp-1",
        name: "林线营地",
        type: "营地",
        location: "路线第 18.6 km",
        description: "营地位于林线边缘的平缓台地，应避开低洼积水区域。",
        details: [
            RoutePointDetailItemProjection(id: "point-elevation", label: "海拔", value: "3,260 m"),
            RoutePointDetailItemProjection(id: "point-water", label: "水源", value: "营地下方约 180 m 有季节性溪流"),
        ]
    )

    static let routePointSection = RoutePointSectionProjection(
        title: "关键点",
        points: [
            RoutePointRowProjection(id: "point-key-1", bookmark: "关", name: "北侧垭口", elevation: "3,860 m", type: "关键点", location: "路线第 12.4 km", description: "通过后进入暴露山脊。"),
            RoutePointRowProjection(id: "point-camp-1", bookmark: "营", name: "林线营地", elevation: "3,260 m", type: "营地", location: "路线第 18.6 km", description: "平缓台地，靠近季节性水源。"),
        ],
        activePointID: "point-camp-1"
    )

    static let routeWaterSection = RoutePointSectionProjection(
        title: "水源",
        points: [
            RoutePointRowProjection(id: "point-water-1", bookmark: "水", name: "石壁溪流", elevation: "2,940 m", type: "季节性水源", location: "路线第 21.3 km", description: "枯水季可能断流。"),
        ]
    )

    static let routePointSectionDisabled = RoutePointSectionProjection(
        title: "补给点",
        points: [
            RoutePointRowProjection(id: "point-supply-1", bookmark: "补", name: "河谷补给站", elevation: nil, type: "补给", location: "路线终点", description: nil),
        ],
        activePointID: nil,
        isDisabled: true
    )

    static let referenceDays = [
        RouteReferenceDayProjection(id: "reference-day-1", dayNumber: 1, title: "上木居至河谷营地", metrics: ["14.8 km", "爬升 920 m"], description: "沿森林缓慢爬升，下午抵达河谷营地。"),
        RouteReferenceDayProjection(id: "reference-day-3", dayNumber: 3, title: "翻越北侧垭口", metrics: ["11.6 km", "约 8 小时"], description: "尽早出发，午后天气变化前通过垭口。"),
    ]

    static let routeSceneMetrics = [
        MetricItemModel(id: "distance", value: "42.8", unit: "km", label: "距离"),
        MetricItemModel(id: "ascent", value: "2,340", unit: "m", label: "累计爬升"),
        MetricItemModel(id: "duration", value: "4", unit: "天", label: "预计用时"),
    ]

    static let routeScene = RouteSceneProjection(
        routeID: "route-001",
        coverAvailable: true,
        name: "贡嘎西南坡环线",
        region: "四川 · 甘孜",
        difficulty: "进阶",
        metrics: routeSceneMetrics
    )

    static let routeSceneNeutral = RouteSceneProjection(
        routeID: "route-002",
        coverAvailable: false,
        name: "河谷森林线",
        region: "云南 · 怒江",
        difficulty: "中等",
        metrics: routeSceneMetrics
    )

    static let routeSceneNameMissing = RouteSceneProjection(
        routeID: "route-003",
        coverAvailable: true,
        name: nil,
        region: "青海 · 海西",
        difficulty: "困难",
        metrics: routeSceneMetrics
    )

    static let routeSceneTagsOmitted = RouteSceneProjection(
        routeID: "route-004",
        coverAvailable: true,
        name: "高山草甸环线",
        region: nil,
        difficulty: nil,
        metrics: routeSceneMetrics
    )

    static let routeScenePartialMetrics = RouteSceneProjection(
        routeID: "route-005",
        coverAvailable: true,
        name: "山谷观景线",
        region: "北京 · 延庆",
        difficulty: "中等",
        metrics: [routeSceneMetrics[0]]
    )

    static let routeSceneMetricsOmitted = RouteSceneProjection(
        routeID: "route-006",
        coverAvailable: true,
        name: "林线短程路线",
        region: "四川 · 阿坝",
        difficulty: "简单",
        metrics: []
    )

    static let routeSceneLong = RouteSceneProjection(
        routeID: "route-007",
        coverAvailable: true,
        name: "穿越原始森林、高山草甸与连续垭口的长距离环形徒步路线",
        region: "四川省甘孜藏族自治州",
        difficulty: "高海拔进阶路线",
        metrics: routeSceneMetrics
    )

    static let routeSegments = RouteSegmentListProjection(
        segments: [
            RouteSegmentProjection(id: "segment-1", order: 1, name: "河谷入口至林线营地", start: "上木居", end: "林线营地", metrics: ["14.8 km", "爬升 920 m"], description: "沿河谷与森林缓慢爬升。"),
            RouteSegmentProjection(id: "segment-2", order: 2, name: "林线营地至北侧垭口", start: "林线营地", end: "北侧垭口", metrics: ["9.6 km", "约 6 小时"], description: "后半段进入碎石坡与暴露山脊。"),
        ],
        activeSegmentID: "segment-2"
    )

    static let routeSegmentSingle = RouteSegmentListProjection(
        segments: [
            RouteSegmentProjection(id: "segment-only", order: 4, name: "河谷下降段", start: "北侧垭口", end: "草科", metrics: [], description: nil),
        ]
    )

    static let routeSegmentsDisabled = RouteSegmentListProjection(
        segments: routeSegments.segments,
        activeSegmentID: nil,
        isDisabled: true
    )

    static let routeSummaryMetrics = [
        MetricItemModel(id: "summary-distance", value: "42.8", unit: "km", label: "距离"),
        MetricItemModel(id: "summary-duration", value: "4", unit: "天", label: "预计用时"),
        MetricItemModel(id: "summary-ascent", value: "2,340", unit: "m", label: "累计爬升"),
        MetricItemModel(id: "summary-descent", value: "2,180", unit: "m", label: "累计下降"),
    ]

    static let routeSummary = RouteSummaryProjection(
        name: "贡嘎西南坡环线",
        introduction: "环绕贡嘎西南坡的经典徒步线路，翻越垭口远眺主峰，冰川、草甸与森林交替呈现。",
        tags: ["四川 · 甘孜", "进阶", "多日路线"],
        metrics: routeSummaryMetrics
    )

    static let routeSummaryPartial = RouteSummaryProjection(
        name: "河谷森林线",
        introduction: nil,
        tags: ["中等"],
        metrics: [routeSummaryMetrics[0]]
    )

    static let routeSummaryLong = RouteSummaryProjection(
        name: "穿越原始森林、高山草甸与连续垭口的长距离环形徒步路线",
        introduction: "从高山村北侧徒步入口出发，沿河谷溯溪而上，穿越原始森林与连续垭口后下撤至河谷游客服务站。",
        tags: ["四川省甘孜藏族自治州", "高海拔进阶路线", "多日路线"],
        metrics: routeSummaryMetrics
    )

    static let routeMap = RouteMapProjection(
        track: RouteMapTrackProjection(positions: [
            RouteMapPositionProjection(x: 0.12, y: 0.78),
            RouteMapPositionProjection(x: 0.25, y: 0.64),
            RouteMapPositionProjection(x: 0.42, y: 0.57),
            RouteMapPositionProjection(x: 0.54, y: 0.35),
            RouteMapPositionProjection(x: 0.72, y: 0.42),
            RouteMapPositionProjection(x: 0.88, y: 0.18),
        ]),
        start: RouteMapPositionProjection(x: 0.12, y: 0.78),
        end: RouteMapPositionProjection(x: 0.88, y: 0.18),
        points: [
            RouteMapPointProjection(id: "map-key", name: "北侧垭口", category: .keyPoint, position: RouteMapPositionProjection(x: 0.54, y: 0.35)),
            RouteMapPointProjection(id: "map-camp", name: "林线营地", category: .camp, position: RouteMapPositionProjection(x: 0.36, y: 0.61)),
            RouteMapPointProjection(id: "map-water", name: "石壁溪流", category: .water, position: RouteMapPositionProjection(x: 0.70, y: 0.43)),
        ],
        placeLabels: [
            RouteMapPlaceLabelProjection(id: "place-1", title: "上木居", position: RouteMapPositionProjection(x: 0.17, y: 0.87)),
            RouteMapPlaceLabelProjection(id: "place-2", title: "林线", position: RouteMapPositionProjection(x: 0.31, y: 0.50)),
            RouteMapPlaceLabelProjection(id: "place-3", title: "北侧垭口", position: RouteMapPositionProjection(x: 0.57, y: 0.25)),
            RouteMapPlaceLabelProjection(id: "place-4", title: "草科", position: RouteMapPositionProjection(x: 0.84, y: 0.10)),
        ]
    )

    static let routeMapSelected = RouteMapProjection(
        track: routeMap.track,
        start: routeMap.start,
        end: routeMap.end,
        points: routeMap.points,
        placeLabels: routeMap.placeLabels,
        activePointID: "map-camp"
    )

    static let routeMapUnavailable = RouteMapProjection(
        track: nil,
        start: routeMap.start,
        end: routeMap.end,
        points: routeMap.points,
        placeLabels: routeMap.placeLabels,
        activePointID: nil,
        trackUnavailableMessage: "当前没有可用主轨迹，其他可验证点位仍可查看。"
    )

    private static let previewBusinessDates: [String] = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let start = calendar.date(
            from: DateComponents(
                calendar: calendar,
                timeZone: calendar.timeZone,
                year: 2025,
                month: 9,
                day: 10
            )
        )!
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return (0..<365).map { offset in
            formatter.string(from: calendar.date(byAdding: .day, value: offset, to: start)!)
        }
    }()

    static let heatmapDefault: [TripHeatmapDayProjection] = previewBusinessDates.enumerated().map { index, date in
        let level: TripHeatmapLevel
        if index.isMultiple(of: 47) {
            level = TripHeatmapLevel(rawValue: index % 3 + 1) ?? .low
        } else {
            level = .empty
        }
        return TripHeatmapDayProjection(businessDate: date, level: level)
    }

    static let heatmapCalendarDefault: [TripHeatmapDayProjection] = previewBusinessDates.enumerated().map { index, date in
        TripHeatmapDayProjection(
            businessDate: date,
            level: index.isMultiple(of: 53) ? (index.isMultiple(of: 106) ? .medium : .low) : .empty
        )
    }

    static let heatmapEmpty = previewBusinessDates.map {
        TripHeatmapDayProjection(businessDate: $0, level: .empty)
    }

    static let tripCalendarDefault = TripCalendarCardProjection(
        days: heatmapCalendarDefault,
        emptyHint: nil
    )

    static let tripCalendarEmpty = TripCalendarCardProjection(
        days: heatmapEmpty,
        emptyHint: "过去 365 天还没有个人行程"
    )

    static let weatherKnown = TripWeatherProjection(
        condition: TripWeatherValueProjection(value: "多云", state: nil),
        temperature: TripWeatherValueProjection(value: "8–16 ℃", state: nil),
        precipitation: TripWeatherValueProjection(value: "降水概率 20%", state: nil),
        wind: TripWeatherValueProjection(value: "3 级", state: nil)
    )

    static let weatherPendingVerification = TripWeatherProjection(
        condition: TripWeatherValueProjection(value: "多云", state: .pendingVerification),
        temperature: TripWeatherValueProjection(value: "8–16 ℃", state: .pendingVerification),
        precipitation: TripWeatherValueProjection(value: "降水概率 20%", state: .pendingVerification),
        wind: TripWeatherValueProjection(value: "3 级", state: .pendingVerification)
    )

    static let weatherPartial = TripWeatherProjection(
        condition: TripWeatherValueProjection(value: "阵雨", state: .pendingVerification),
        temperature: TripWeatherValueProjection(value: "6–13 ℃", state: nil),
        precipitation: TripWeatherValueProjection(value: nil, state: .unavailable),
        wind: TripWeatherValueProjection(value: "4 级", state: .stale)
    )

    static let weatherUnavailable = TripWeatherProjection(
        condition: TripWeatherValueProjection(value: nil, state: .unavailable),
        temperature: TripWeatherValueProjection(value: nil, state: .unavailable),
        precipitation: TripWeatherValueProjection(value: nil, state: .unavailable),
        wind: TripWeatherValueProjection(value: nil, state: .unavailable)
    )

    static let weatherDayDefault = TripWeatherDayProjection(
        id: "trip-day-weather-1",
        dayNumber: 1,
        date: "2026-09-07",
        primaryStage: "抵达与适应",
        hikingDayNumber: nil,
        weather: weatherPendingVerification
    )

    static let weatherDayKnownSecond = TripWeatherDayProjection(
        id: "trip-day-weather-known-2",
        dayNumber: 2,
        date: "2026-09-08",
        primaryStage: "翻越北侧垭口",
        hikingDayNumber: 1,
        weather: weatherKnown
    )

    static let weatherDayPartial = TripWeatherDayProjection(
        id: "trip-day-weather-2",
        dayNumber: 2,
        date: "2026-09-08",
        primaryStage: "翻越北侧垭口",
        hikingDayNumber: 1,
        weather: weatherPartial
    )

    static let weatherDayUnavailable = TripWeatherDayProjection(
        id: "trip-day-weather-3",
        dayNumber: 3,
        date: "2026-09-09",
        primaryStage: "河谷下降",
        hikingDayNumber: 2,
        weather: weatherUnavailable
    )

    /// 行程详情页每日天气摘要行 fixture：携带冻结天气地点，覆盖已知天气分支。
    static let weatherDayRowKnown = TripWeatherDayProjection(
        id: "trip-day-weather-row-known",
        dayNumber: 2,
        date: "2026-09-08",
        primaryStage: "翻越北侧垭口",
        hikingDayNumber: 1,
        placeContext: "老榆林村",
        weather: weatherKnown
    )

    static let weatherDayLong = TripWeatherDayProjection(
        id: "trip-day-weather-long",
        dayNumber: 4,
        date: "2026-09-10",
        primaryStage: "穿越高山草甸与连续暴露山脊",
        hikingDayNumber: 3,
        weather: TripWeatherProjection(
            condition: TripWeatherValueProjection(value: "午后可能出现短时雷阵雨并伴随低云", state: .pendingVerification),
            temperature: TripWeatherValueProjection(value: "清晨 2 ℃ 至午后 12 ℃", state: nil),
            precipitation: TripWeatherValueProjection(value: "局地降水概率 70%，垭口附近可能更高", state: .pendingVerification),
            wind: TripWeatherValueProjection(value: "山脊阵风可能达到 6 级", state: .stale)
        )
    )

    static let tripCoverDefault = TripCoverHeaderProjection(
        name: "贡嘎西南坡四日行程",
        status: .planned,
        departureCity: "成都",
        startDate: "2026-09-07",
        endDate: "2026-09-10",
        totalDayCount: 4,
        hikingDayCount: 3
    )

    static let tripCoverLongName = TripCoverHeaderProjection(
        name: "穿越高山草甸、原始森林与连续垭口的长距离个人徒步行程",
        status: .inProgress,
        departureCity: "四川省成都市",
        startDate: "2026-09-07",
        endDate: "2026-09-12",
        totalDayCount: 6,
        hikingDayCount: 5,
        coverAvailable: false
    )

    static let tripDayActions = [
        TripTimelineItemProjection(
            id: "trip-action-1",
            time: "07:30",
            title: "路线接驳",
            details: ["上木居 → 徒步入口", "预计 45 分钟"]
        ),
        TripTimelineItemProjection(
            id: "trip-action-2",
            time: "08:30",
            title: "河谷入口至林线营地",
            details: ["14.8 km", "累计爬升 920 m", "预计 7 小时"],
            notices: ["末段路面湿滑，保留通过时间。"]
        ),
    ]

    static let tripTransportActions = [
        TripTimelineItemProjection(
            id: "trip-action-transport",
            time: nil,
            title: "大交通",
            details: ["成都 → 康定", "班次时间待核验"]
        ),
    ]

    static let tripDayPoints = [
        TripPointProjection(
            id: "trip-point-1",
            title: "石壁溪流",
            details: ["路线第 8.4 km", "枯水季可能断流"],
            trailing: "水源"
        ),
        TripPointProjection(
            id: "trip-point-2",
            title: "林线营地",
            details: ["平缓台地，避开低洼积水区域"],
            trailing: "营地"
        ),
    ]

    static let tripRouteMetrics = [
        MetricItemModel(id: "day-distance", value: "14.8", unit: "km", label: "距离"),
        MetricItemModel(id: "day-ascent", value: "920", unit: "m", label: "累计爬升"),
        MetricItemModel(id: "day-duration", value: "7", unit: "小时", label: "预计用时"),
    ]

    static let tripDayResources = [
        TripDayResourceProjection(id: "point-1", category: "水源", name: "河谷水源点", distance: "2.2 km"),
        TripDayResourceProjection(id: "point-2", category: "营地", name: "林线营地", distance: nil),
    ]

    static let tripDayDefault = TripDayProjection(
        tripDayID: "trip-day-2",
        dayNumber: 2,
        date: "2026-09-08",
        primaryStage: "翻越北侧垭口",
        hikingDayNumber: 1,
        actions: tripDayActions,
        points: tripDayPoints,
        resources: tripDayResources,
        weather: weatherKnown,
        dailyRouteSummary: TripDailyRouteSummaryProjection(
            title: "河谷入口至林线营地",
            endpoints: "徒步入口 → 林线营地",
            metrics: tripRouteMetrics
        ),
        totalTrekDays: 2,
        outboundTransport: TripDayTransportSummaryProjection(
            direction: .outbound,
            title: "大交通与路线接驳",
            timeRange: "08:00 出发",
            duration: "3.0 小时",
            path: "成都 → 四姑娘山镇",
            modes: "公共交通",
            notice: "游客中心换乘"
        ),
        hikeSummary: TripDayHikeSummaryProjection(
            segment: "河谷入口至林线营地",
            distance: "12.4 km",
            ascent: "860 m",
            duration: "5.0 小时",
            nodes: [
                TripDayHikeNodeProjection(type: "起点", name: "河谷入口", position: nil),
                TripDayHikeNodeProjection(type: "终点", name: "林线营地", position: nil),
            ]
        ),
        returnTransport: nil
    )

    static let tripDayPartial = TripDayProjection(
        tripDayID: "trip-day-3",
        dayNumber: 3,
        date: "2026-09-09",
        primaryStage: "河谷下降",
        hikingDayNumber: 2,
        actions: [
            TripTimelineItemProjection(
                id: "trip-action-partial",
                time: nil,
                title: "下降至河谷",
                details: ["预计用时不可用"]
            ),
        ],
        points: [],
        weather: weatherPartial,
        dailyRouteSummary: TripDailyRouteSummaryProjection(
            title: "林线营地至河谷出口",
            endpoints: nil,
            metrics: [tripRouteMetrics[0]]
        ),
        totalTrekDays: 2,
        outboundTransport: nil,
        hikeSummary: TripDayHikeSummaryProjection(
            segment: "林线营地至河谷出口",
            distance: nil,
            ascent: nil,
            duration: nil,
            nodes: [
                TripDayHikeNodeProjection(type: "起点", name: "林线营地", position: nil),
                TripDayHikeNodeProjection(type: "终点", name: "河谷出口", position: nil),
            ]
        ),
        returnTransport: TripDayTransportSummaryProjection(
            direction: .return,
            title: "返程接驳与大交通",
            timeRange: nil,
            duration: nil,
            path: nil,
            modes: nil,
            notice: nil
        )
    )

    static let tripDayTransportOnly = TripDayProjection(
        tripDayID: "trip-day-1",
        dayNumber: 1,
        date: "2026-09-07",
        primaryStage: "抵达与适应",
        hikingDayNumber: nil,
        actions: tripTransportActions,
        points: [],
        weather: weatherKnown,
        dailyRouteSummary: nil
    )

    // MARK: - TripRouteMetricsSummary

    static let tripRouteMetricsDefault = TripRouteMetricsSummaryProjection(
        distance: "42.5 km",
        ascent: "2,300 m",
        descent: "2,180 m",
        maxElevation: "4,980 m"
    )

    static let tripRouteMetricsPartial = TripRouteMetricsSummaryProjection(
        distance: "42.5 km",
        ascent: nil,
        descent: nil,
        maxElevation: nil
    )

    static let tripRouteMetricsLong = TripRouteMetricsSummaryProjection(
        distance: "126.8 km",
        ascent: "8,940 m",
        descent: "8,410 m",
        maxElevation: "5,220 m"
    )

    // MARK: - TripEquipmentOverview

    static let tripEquipmentOverviewDefault = TripEquipmentOverviewProjection(
        itemCount: 12,
        knownTotalWeightGrams: 8420,
        missingWeightItemCount: 0,
        ownedItemCount: 10,
        unconfirmedOwnedItemCount: 2
    )

    static let tripEquipmentOverviewPartialWeight = TripEquipmentOverviewProjection(
        itemCount: 12,
        knownTotalWeightGrams: 7960,
        missingWeightItemCount: 2,
        ownedItemCount: 9,
        unconfirmedOwnedItemCount: 3
    )

    static let tripEquipmentOverviewEmpty = TripEquipmentOverviewProjection(
        itemCount: 0,
        knownTotalWeightGrams: 0,
        missingWeightItemCount: 0,
        ownedItemCount: 0,
        unconfirmedOwnedItemCount: 0
    )

    static let tripEquipmentOverviewLong = TripEquipmentOverviewProjection(
        itemCount: 38,
        knownTotalWeightGrams: 126_400,
        missingWeightItemCount: 4,
        ownedItemCount: 31,
        unconfirmedOwnedItemCount: 7
    )

    // MARK: - TripEquipmentItemRow

    static let tripEquipmentItemDefault = TripEquipmentItemRowProjection(
        identity: "trip-equipment-default",
        name: "双人帐篷",
        quantity: 1,
        unitWeightGrams: 1800,
        note: nil,
        source: .systemSuggestion,
        ownershipStatus: .owned,
        editable: true
    )

    static let tripEquipmentItemUserAdjusted = TripEquipmentItemRowProjection(
        identity: "trip-equipment-adjusted",
        name: "饮水与水袋",
        quantity: 2,
        unitWeightGrams: 1250,
        note: nil,
        source: .userAdjusted,
        ownershipStatus: .owned,
        editable: true
    )

    static let tripEquipmentItemUserAdded = TripEquipmentItemRowProjection(
        identity: "trip-equipment-added",
        name: "个人急救包",
        quantity: 1,
        unitWeightGrams: nil,
        note: nil,
        source: .userAdded,
        ownershipStatus: .unconfirmedOwned,
        editable: true
    )

    static let tripEquipmentItemUnknownWeight = TripEquipmentItemRowProjection(
        identity: "trip-equipment-unknown",
        name: "备用保温毯",
        quantity: 1,
        unitWeightGrams: nil,
        note: nil,
        source: .systemSuggestion,
        ownershipStatus: .unconfirmedOwned,
        editable: true
    )

    static let tripEquipmentItemWithNote = TripEquipmentItemRowProjection(
        identity: "trip-equipment-note",
        name: "零度睡袋",
        quantity: 1,
        unitWeightGrams: 1200,
        note: "舒适温标 0℃，垭口日搭配羽绒内胆使用。",
        source: .systemSuggestion,
        ownershipStatus: .owned,
        editable: true
    )

    static let tripEquipmentItemReadonly = TripEquipmentItemRowProjection(
        identity: "trip-equipment-readonly",
        name: "充气防潮垫",
        quantity: 1,
        unitWeightGrams: 500,
        note: nil,
        source: .userAdjusted,
        ownershipStatus: .owned,
        editable: false
    )

    static let tripEquipmentItemLong = TripEquipmentItemRowProjection(
        identity: "trip-equipment-long",
        name: "含备用保暖、防潮与应急通讯的长距离多日徒步综合装备组合",
        quantity: 3,
        unitWeightGrams: 2400,
        note: "含羽绒内胆、防潮坐垫与卫星通讯模块；出发前确认电池与备用充电方案。",
        source: .userAdjusted,
        ownershipStatus: .unconfirmedOwned,
        editable: true
    )

    static let tripDayWeatherUnavailable = TripDayProjection(
        tripDayID: "trip-day-4",
        dayNumber: 4,
        date: "2026-09-10",
        primaryStage: "返程",
        hikingDayNumber: nil,
        actions: tripTransportActions,
        points: tripDayPoints,
        weather: weatherUnavailable,
        dailyRouteSummary: nil
    )

    static let tripArrangementDefault = TripDayArrangementProjection(
        blocks: [
            .transport(
                tripDayDefault.outboundTransport ?? TripDayTransportSummaryProjection(
                    direction: .outbound,
                    title: "大交通与路线接驳",
                    timeRange: nil,
                    duration: nil,
                    path: nil,
                    modes: nil,
                    notice: nil
                ),
                details: []
            ),
            .hike(
                tripDayDefault.hikeSummary ?? TripDayHikeSummaryProjection(
                    segment: "徒步段",
                    distance: nil,
                    ascent: nil,
                    duration: nil,
                    nodes: []
                ),
                details: tripDayDefault.actions,
                points: tripDayDefault.points
            ),
            .weather(tripDayDefault.weather),
        ]
    )

    static let tripArrangementTransportOnly = TripDayArrangementProjection(
        blocks: [
            .transport(
                tripDayTransportOnly.outboundTransport ?? TripDayTransportSummaryProjection(
                    direction: .outbound,
                    title: "大交通与路线接驳",
                    timeRange: nil,
                    duration: nil,
                    path: nil,
                    modes: nil,
                    notice: nil
                ),
                details: tripTransportActions
            ),
            .weather(tripDayTransportOnly.weather),
        ]
    )

    static let tripArrangementWeatherUnavailable = TripDayArrangementProjection(
        blocks: [
            .hike(
                tripDayWeatherUnavailable.hikeSummary ?? TripDayHikeSummaryProjection(
                    segment: "徒步段",
                    distance: nil,
                    ascent: nil,
                    duration: nil,
                    nodes: []
                ),
                details: tripDayWeatherUnavailable.actions,
                points: tripDayWeatherUnavailable.points
            ),
            .weather(tripDayWeatherUnavailable.weather),
        ]
    )

    static let tripDayOverviewEntryDefault = TripDayOverviewEntryProjection(
        tripDayID: "trip-day-2",
        dayNumber: 2,
        date: "9月8日",
        hikingDayNumber: 1,
        totalTrekDays: 2,
        subtitle: "老榆林 → 下日乌且营地"
    )

    static let tripEquipmentDefault = TripEquipmentSummaryProjection(
        knownTotalWeight: "8.42 kg",
        itemCount: 12,
        ownedItemCount: 10,
        unconfirmedOwnedItemCount: 2,
        missingWeightItemCount: 0,
        editable: true
    )

    static let tripEquipmentPartialWeight = TripEquipmentSummaryProjection(
        knownTotalWeight: "7.96 kg",
        itemCount: 12,
        ownedItemCount: 9,
        unconfirmedOwnedItemCount: 3,
        missingWeightItemCount: 2,
        editable: true
    )

    static let tripEquipmentSummaryReadonly = TripEquipmentSummaryProjection(
        knownTotalWeight: "8.42 kg",
        itemCount: 12,
        ownedItemCount: 10,
        unconfirmedOwnedItemCount: 2,
        missingWeightItemCount: 0,
        editable: false
    )

    static let tripRowDefault = TripListRowProjection(
        tripID: "trip-001",
        name: "贡嘎西南坡四日行程",
        status: .planned,
        routeName: "贡嘎西南坡环线",
        startDate: "2026-09-07",
        endDate: "2026-09-10"
    )

    static let tripRowInProgress = TripListRowProjection(
        tripID: "trip-002",
        name: "海坨山谷穿越",
        status: .inProgress,
        routeName: "海坨山谷穿越线",
        startDate: "2026-09-08",
        endDate: "2026-09-09"
    )

    static let tripRowCompleted = TripListRowProjection(
        tripID: "trip-003",
        name: "白河峡谷周末行程",
        status: .completed,
        routeName: "白河峡谷",
        startDate: "2026-08-22",
        endDate: "2026-08-23"
    )

    static let tripRowCancelled = TripListRowProjection(
        tripID: "trip-004",
        name: "河谷森林线行程",
        status: .cancelled,
        routeName: "河谷森林线",
        startDate: "2026-07-18",
        endDate: "2026-07-19"
    )

    static let tripRowLongContent = TripListRowProjection(
        tripID: "trip-006",
        name: "穿越高山草甸、原始森林与连续垭口的长距离个人徒步行程",
        status: .planned,
        routeName: "四川省甘孜藏族自治州高海拔连续垭口环形路线",
        startDate: "2026-09-07",
        endDate: "2026-09-12"
    )

    static let tripRouteEntryDefault = TripRouteSummaryProjection(
        routeName: "贡嘎西南坡环线",
        versionLabel: "2026 夏季版",
        routeOrientation: "顺时针环绕贡嘎西坡，自老榆林经上子梅村翻越日乌且垭口至草科结束。",
        elevationSamples: [
            FrozenRouteElevationSample(
                distance: RouteDistance(meters: 0),
                elevation: RouteElevation(meters: 3_800)
            ),
            FrozenRouteElevationSample(
                distance: RouteDistance(meters: 15_000),
                elevation: RouteElevation(meters: 4_500)
            ),
            FrozenRouteElevationSample(
                distance: RouteDistance(meters: 32_000),
                elevation: RouteElevation(meters: 4_980)
            ),
            FrozenRouteElevationSample(
                distance: RouteDistance(meters: 55_000),
                elevation: RouteElevation(meters: 3_300)
            ),
        ]
    )

    static let tripRouteEntryPartial = TripRouteSummaryProjection(
        routeName: "河谷森林线",
        versionLabel: nil,
        routeOrientation: nil,
        elevationSamples: nil
    )

    static let tripRouteEntryLong = TripRouteSummaryProjection(
        routeName: "四川省甘孜藏族自治州高海拔连续垭口环形路线",
        versionLabel: "2026 夏季高海拔连续垭口修正版",
        routeOrientation: "顺时针环绕，连续翻越日乌且垭口、莫溪沟垭口与玉龙西垭口，途中沿河谷与林线交替行进，长距离缓升陡降交替。",
        elevationSamples: (0...12).map { index in
            FrozenRouteElevationSample(
                distance: RouteDistance(meters: Double(index) * 12_500),
                elevation: RouteElevation(meters: 3_200 + Double(index % 5) * 380)
            )
        }
    )

    static let tripWeatherDefault = TripWeatherSummaryProjection(
        samples: [
            TripWeatherTrendSampleProjection(id: "d1", date: "09-08", low: 8, high: 16, rain: 0.2),
            TripWeatherTrendSampleProjection(id: "d2", date: "09-09", low: 6, high: 14, rain: 0.45),
        ],
        notice: nil
    )

    static let tripWeatherPartial = TripWeatherSummaryProjection(
        samples: [
            TripWeatherTrendSampleProjection(id: "d1", date: "09-08", low: 8, high: 16, rain: 0.2),
        ],
        notice: TripNoticeProjection(
            id: "weather-partial",
            title: "部分天气待确认",
            message: "缺失日期不在趋势图中，其他日期与已知字段不变。",
            tone: .warning
        )
    )

    static let tripWeatherLongContent = TripWeatherSummaryProjection(
        samples: [
            TripWeatherTrendSampleProjection(id: "d1", date: "09-08", low: -3, high: 21, rain: 0.65),
            TripWeatherTrendSampleProjection(id: "d2", date: "09-09", low: 2, high: 18, rain: 0.3),
            TripWeatherTrendSampleProjection(id: "d3", date: "09-10", low: 0, high: 12, rain: 0.8),
            TripWeatherTrendSampleProjection(id: "d4", date: "09-11", low: 5, high: 19, rain: 0.1),
            TripWeatherTrendSampleProjection(id: "d5", date: "09-12", low: 7, high: 17, rain: 0.55),
            TripWeatherTrendSampleProjection(id: "d6", date: "09-13", low: 4, high: 15, rain: 0.25),
        ],
        notice: TripNoticeProjection(
            id: "weather-long",
            title: "部分天气可能过期",
            message: "长天气结论完整展示，不以截断或缩小字号隐藏字段状态。",
            tone: .stale
        )
    )

    static let weatherOverviewDefault = WeatherOverviewProjection(
        summary: TripWeatherValueProjection(value: "行程前半段多云，后半段有阵雨。", state: nil),
        importantImpacts: [
            "午后通过垭口时可能遇到短时雷雨。",
            "山脊阵风可能影响队伍行进节奏。",
        ]
    )

    static let weatherOverviewStale = WeatherOverviewProjection(
        summary: TripWeatherValueProjection(
            value: "原概况提示垭口区域以多云和间歇阵雨为主。",
            state: .stale
        ),
        importantImpacts: ["请结合逐日天气与实际现场条件判断。"]
    )

    static let routeSpanCardDay = RouteSpanCardProjection(
        spanID: "day-1",
        kind: .day(number: 1),
        colorHex: "2F6FED",
        headerTitle: "D1 · 下日乌且营地",
        metrics: [
            RouteSpanMetricProjection(label: "里程", value: "10.6 km"),
            RouteSpanMetricProjection(label: "累计爬升", value: "+420 m", isEmphasized: true),
            RouteSpanMetricProjection(label: "累计下降", value: "-180 m", isEmphasized: true),
            RouteSpanMetricProjection(label: "最高海拔", value: "3520 m"),
            RouteSpanMetricProjection(label: "最低海拔", value: "2720 m"),
        ],
        endpoints: "康定老榆林 → 下日乌且营地",
        position: "全程 0 – 10.6 km",
        duration: "参考用时 5 小时",
        lifecycle: "住宿：下日乌且营地",
        trait: nil,
        caution: "垭口段午后天气多变，注意保暖。"
    )

    static let routeSpanCardSegment = RouteSpanCardProjection(
        spanID: "segment-1",
        kind: .segment(order: 1),
        colorHex: "2F6FED",
        headerTitle: "S1 · 进山段",
        metrics: [
            RouteSpanMetricProjection(label: "里程", value: "8.4 km"),
            RouteSpanMetricProjection(label: "累计爬升", value: "+980 m", isEmphasized: true),
            RouteSpanMetricProjection(label: "累计下降", value: "-60 m", isEmphasized: true),
        ],
        endpoints: "康定老榆林 → 下日乌且营地",
        position: "距起点 0 km · 距终点 32.9 km",
        duration: "徒步参考时长 4 小时",
        lifecycle: nil,
        trait: "难度：进阶 · 地形：碎石坡",
        caution: nil
    )
}
#endif
