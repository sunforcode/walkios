import SwiftUI
import Foundation
import WalkData
import WalkDesignSystem

final class AppEnvironment: ObservableObject {
    let configuration: AppConfiguration
    let apiClient: any APIClient
    let routeService: RouteService
    let equipmentService: EquipmentService
    let personalTripService: PersonalTripService
    let tripEquipmentService: TripEquipmentService
    let authManager: AuthManager
    let accountService: AccountService
    let apiStorage: any APIStorage
    let apiStorageGeneration: APIStorageGeneration

    /// 默认响应缓存目录。
    static var defaultResponseCacheDirectory: URL {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("APIResponses", isDirectory: true)
    }

    /// - Parameter cacheLifecycle: 启动生命周期记录。仅 App 进程入口传入；
    ///   测试与预览不传，避免读写宿主的真实状态。
    init(
        configuration: AppConfiguration,
        mockFixtures: [String: Data]? = nil,
        resourceBundle: Bundle = .main,
        responseCacheDirectory: URL = AppEnvironment.defaultResponseCacheDirectory,
        cacheLifecycle: ResponseCacheLifecycle? = nil
    ) throws {
        try configuration.validate()
        self.configuration = configuration
        // R-AUTH：同一认证实例由最终配置创建，并注入客户端、Service 与页面。
        self.authManager = AuthManager(
            persistenceNamespace: AuthManager.namespace(
                for: configuration.serviceIdentity,
                isMock: configuration.dataMode == .mock
            )
        )

        // R-INVALIDATION：remoteOnly 之后再进入 real，在创建存储前同步清理此前缓存，
        // 保证本次启动的任何请求都读不到旧条目。
        if cacheLifecycle?.recordLaunch(configuration.dataMode) == true {
            try? FileManager.default.removeItem(at: responseCacheDirectory)
        }
        let storage = try JSONFileAPIStorage(directory: responseCacheDirectory)
        let storageGeneration = APIStorageGeneration()
        self.apiStorage = storage
        self.apiStorageGeneration = storageGeneration
        // 服务身份由环境标识与规范化地址共同决定；同名不同地址按不同服务隔离。
        let context = APIStorageContext(
            schemaVersion: "v1",
            service: configuration.serviceIdentity,
            userIDProvider: { [authManager] in authManager.cacheIdentity }
        )

        let mode = configuration.dataMode
        switch mode {
        case .real, .remoteOnly:
            // real 与 remoteOnly 共用同一类真实实现，差异只来自模式装配。
            apiClient = AlamofireRemoteAPIClient(
                baseURL: configuration.baseURL,
                storage: storage,
                storageContext: context,
                storageGeneration: storageGeneration,
                responseCachePolicy: mode.responseCachePolicy,
                offlinePolicy: mode.effectiveOfflinePolicy(selected: configuration.offlinePolicy),
                accessToken: { [authManager] in authManager.currentToken },
                invalidateSession: { [authManager, storage, storageGeneration] in
                    authManager.invalidateSession()
                    await storageGeneration.invalidate()
                    try? await storage.removeAll()
                }
            )
        case .mock:
            if let mockFixtures {
                apiClient = MockAPIClient(fixtures: mockFixtures)
            } else {
                apiClient = DefaultMockEquipmentScenario(
                    fixtures: DefaultMockFixtures.all(bundle: resourceBundle),
                    identityProvider: { [authManager] in authManager.cacheIdentity }
                )
            }
        }
        routeService = RouteService(apiClient: apiClient)
        equipmentService = EquipmentService(apiClient: apiClient)
        personalTripService = PersonalTripService(apiClient: apiClient)
        tripEquipmentService = TripEquipmentService(apiClient: apiClient)
        accountService = AccountService(apiClient: apiClient, authManager: authManager)
    }
}
