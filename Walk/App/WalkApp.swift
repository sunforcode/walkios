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
                    dataMode: .mock,
                    baseURL: URL(string: "https://api.example.invalid/walkbg/api/v1")!,
                    environmentName: "component-preview",
                    executionContext: .componentPreview
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
            // 只有正常运行上下文参与缓存启动生命周期；测试、Baseline 与预览不读写宿主状态。
            let environment = try AppEnvironment(
                configuration: configuration,
                cacheLifecycle: configuration.executionContext == .app ? ResponseCacheLifecycle() : nil
            )
            _appEnvironment = StateObject(wrappedValue: environment)
        } catch {
            fatalError("Invalid app configuration: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            appRoot
                .environmentObject(appEnvironment)
                .preferredColorScheme(.dark)
                .statusBarHidden(usesFixedPreviewEnvironment)
        }
    }

    private var usesFixedPreviewEnvironment: Bool {
#if DEBUG
        if componentPreviewRequest != nil { return true }
#endif
        return appEnvironment.configuration.baselineScenario != nil
    }

#if DEBUG
    private var debugPanelModel: DebugPanelModel {
        let environment = appEnvironment
        return DebugPanelModel(
            effective: environment.configuration,
            store: DebugSettingsStore(),
            clearResponseCache: {
                Task {
                    await environment.apiStorageGeneration.invalidate()
                    try? await environment.apiStorage.removeAll()
                }
            }
        )
    }
#endif

    @ViewBuilder
    private var appRoot: some View {
#if DEBUG
        if let request = componentPreviewRequest {
            ComponentPreviewRootView(request: request)
        } else if let scenario = appEnvironment.configuration.baselineScenario {
            BaselineRootView(scenario: scenario)
        } else {
            // 调试入口只挂在正常运行的根视图；Baseline 与组件预览不加载调试 SDK。
            RootView(appEnvironment: appEnvironment)
                .modifier(DebugShakeEntry(model: debugPanelModel))
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
