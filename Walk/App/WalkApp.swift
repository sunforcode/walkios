import SwiftUI

@main
struct WalkApp: App {
    @StateObject private var appEnvironment: AppEnvironment

    init() {
        do {
            let configuration = try AppConfiguration.process()
            let environment = try AppEnvironment(configuration: configuration)
            _appEnvironment = StateObject(wrappedValue: environment)
        } catch {
            fatalError("Invalid app configuration: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(appEnvironment)
                .preferredColorScheme(nil)
        }
    }
}
