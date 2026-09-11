import SwiftUI
import WalkData
import WalkDesignSystem

@main
struct WalkApp: App {
    @StateObject private var appEnvironment: AppEnvironment
#if DEBUG
    private let componentPreviewRequest: ComponentPreviewRequest?
#endif

    init() {
        do {
#if DEBUG
            let componentPreviewRequest = ComponentPreviewRequest(arguments: ProcessInfo.processInfo.arguments)
            self.componentPreviewRequest = componentPreviewRequest
            let configuration: AppConfiguration
            if componentPreviewRequest != nil {
                configuration = AppConfiguration(
                    dataSourceMode: .mock,
                    baseURL: URL(string: "https://api.example.invalid/walkbg/api/v1")!,
                    environmentName: "component-preview"
                )
            } else {
                configuration = try AppConfiguration.process()
                RootNavigation.applyTabBarAppearance()
                RootNavigation.applyNavigationBarAppearance()
            }
#else
            let configuration = try AppConfiguration.process()
            RootNavigation.applyTabBarAppearance()
            RootNavigation.applyNavigationBarAppearance()
#endif
            let environment = try AppEnvironment(configuration: configuration)
            _appEnvironment = StateObject(wrappedValue: environment)
        } catch {
            fatalError("Invalid app configuration: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            appRoot
                .environmentObject(appEnvironment)
                .preferredColorScheme(usesFixedPreviewEnvironment ? .dark : nil)
                .statusBarHidden(usesFixedPreviewEnvironment)
        }
    }

    private var usesFixedPreviewEnvironment: Bool {
#if DEBUG
        if componentPreviewRequest != nil { return true }
#endif
        return appEnvironment.configuration.baselineScenario != nil
    }

    @ViewBuilder
    private var appRoot: some View {
#if DEBUG
        if let request = componentPreviewRequest {
            ComponentPreviewRootView(request: request)
        } else if let scenario = appEnvironment.configuration.baselineScenario {
            BaselineRootView(scenario: scenario)
        } else {
            RootView(appEnvironment: appEnvironment)
        }
#else
        if let scenario = appEnvironment.configuration.baselineScenario {
            BaselineRootView(scenario: scenario)
        } else {
            RootView(appEnvironment: appEnvironment)
        }
#endif
    }
}
