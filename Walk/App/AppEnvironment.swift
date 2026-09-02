import SwiftUI
import Foundation

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

    init(
        configuration: AppConfiguration,
        mockFixtures: [String: Data]? = nil,
        resourceBundle: Bundle = .main
    ) throws {
        try configuration.validate()
        self.configuration = configuration
        self.authManager = .shared

        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        let storage = try JSONFileAPIStorage(directory: caches.appendingPathComponent("APIResponses", isDirectory: true))
        let storageGeneration = APIStorageGeneration()
        self.apiStorage = storage
        self.apiStorageGeneration = storageGeneration
        let context = APIStorageContext(
            schemaVersion: "v1",
            environment: configuration.environmentName,
            userIDProvider: { [authManager] in authManager.cacheIdentity }
        )

        switch configuration.dataSourceMode {
        case .remote:
            apiClient = AlamofireRemoteAPIClient(
                baseURL: configuration.baseURL,
                storage: storage,
                storageContext: context,
                storageGeneration: storageGeneration,
                accessToken: { [authManager] in authManager.currentToken },
                invalidateSession: { [authManager, storage, storageGeneration] in
                    authManager.invalidateSession()
                    await storageGeneration.invalidate()
                    try? await storage.removeAll()
                }
            )
        case .local:
            apiClient = LocalAPIClient(storage: storage, storageContext: context)
        case .mock:
            apiClient = MockAPIClient(
                fixtures: mockFixtures ?? DefaultMockFixtures.all(bundle: resourceBundle)
            )
        }
        routeService = RouteService(apiClient: apiClient)
        equipmentService = EquipmentService(apiClient: apiClient)
        personalTripService = PersonalTripService(apiClient: apiClient)
        tripEquipmentService = TripEquipmentService(apiClient: apiClient)
        accountService = AccountService(apiClient: apiClient, authManager: authManager)
    }
}
