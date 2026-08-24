import SwiftUI
import Foundation

final class AppEnvironment: ObservableObject {
    let configuration: AppConfiguration
    let apiClient: any APIClient
    let routeService: RouteService
    let tripRepository: any TripRepository
    let authManager: AuthManager
    let apiStorage: any APIStorage
    let apiStorageGeneration: APIStorageGeneration

    init(
        configuration: AppConfiguration,
        mockFixtures: [String: Data]? = nil,
        resourceBundle: Bundle = .main
    ) throws {
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
                storageGeneration: storageGeneration
            )
        case .local:
            apiClient = LocalAPIClient(storage: storage, storageContext: context)
        case .mock:
            apiClient = MockAPIClient(
                fixtures: mockFixtures ?? DefaultMockFixtures.all(
                    userID: configuration.userID,
                    bundle: resourceBundle
                )
            )
        }
        routeService = RouteService(apiClient: apiClient, userID: configuration.userID)
        tripRepository = DefaultTripRepository(client: apiClient)
    }
}
