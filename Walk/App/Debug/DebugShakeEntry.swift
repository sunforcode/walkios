#if DEBUG
import SwiftUI
import UIKit
import WalkDebugTools

// MARK: - 摇一摇入口
//
// 依据 specs/README.md R-DEBUG：调试入口由 App 承载，不进入 Feature 或任务栈；
// 不依赖登录状态。仅 DEBUG 编译，生产依赖图不包含 WalkDebugTools。

extension Notification.Name {
    static let walkDeviceDidShake = Notification.Name("walk.debug.deviceDidShake")
}

extension UIWindow {
    /// UIKit 把摇动事件沿响应链交给 key window；SwiftUI 没有对应事件。
    override open func motionEnded(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
        if motion == .motionShake {
            NotificationCenter.default.post(name: .walkDeviceDidShake, object: nil)
        }
        super.motionEnded(motion, with: event)
    }
}

/// 在 App 根部响应摇一摇，呈现 DebugSwift 面板。
struct DebugShakeEntry: ViewModifier {
    static let simulateShakeArgument = "-WalkSimulateShake"

    let model: DebugPanelModel
    @State private var isPresented = false
    @State private var isComponentCatalogPresented = false

    func body(content: Content) -> some View {
        content
            .onAppear {
                WalkDebugTools.configure(
                    info: { [model] in model.infoSections() },
                    actions: { [model] in
                        model.actionSections(openComponentCatalog: {
                            isComponentCatalogPresented = true
                        })
                    }
                )
                // UI 测试无法合成真实摇动事件；该参数走同一条通知路径，只替代事件来源。
                if ProcessInfo.processInfo.arguments.contains(Self.simulateShakeArgument) {
                    NotificationCenter.default.post(name: .walkDeviceDidShake, object: nil)
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .walkDeviceDidShake)) { _ in
                isPresented = true
            }
            .sheet(isPresented: $isPresented, onDismiss: WalkDebugTools.didDismiss) {
                DebugPanelContainer()
                    .ignoresSafeArea()
                    // 预览覆盖现有 SDK 面板，关闭时不销毁面板或重新装配 App。
                    .fullScreenCover(isPresented: $isComponentCatalogPresented) {
                        DebugComponentBrowser {
                            isComponentCatalogPresented = false
                        }
                    }
            }
    }
}

private struct DebugPanelContainer: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> UIViewController {
        WalkDebugTools.makeViewController()
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}
}

private struct DebugComponentBrowser: View {
    let close: () -> Void

    var body: some View {
        NavigationStack {
            List {
                ForEach([ComponentCategory.common, .business], id: \.rawValue) { category in
                    Section(category == .common ? "通用组件" : "业务组件") {
                        ForEach(ComponentCatalog.entries.filter { $0.category == category }, id: \.id) { entry in
                            NavigationLink {
                                DebugComponentStateList(entry: entry, close: close)
                            } label: {
                                Text(entry.id)
                            }
                            .accessibilityIdentifier("debug.component.\(entry.id)")
                        }
                    }
                }
            }
            .modifier(DebugComponentNavigation(title: "组件目录", close: close))
        }
        .preferredColorScheme(.dark)
    }
}

private struct DebugComponentStateList: View {
    let entry: ComponentCatalogEntry
    let close: () -> Void

    var body: some View {
        List(entry.stateIDs, id: \.self) { stateID in
            NavigationLink {
                ComponentPreviewRootView(
                    request: ComponentPreviewRequest(componentID: entry.id, stateID: stateID),
                    layout: .embedded
                )
                .modifier(DebugComponentNavigation(title: "\(entry.id) · \(stateID)", close: close))
            } label: {
                Text(stateID)
            }
            .accessibilityIdentifier("debug.component.state.\(stateID)")
        }
        .modifier(DebugComponentNavigation(title: entry.id, close: close))
    }
}

private struct DebugComponentNavigation: ViewModifier {
    let title: String
    let close: () -> Void

    func body(content: Content) -> some View {
        content
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            // 组件内部的页面壳不能隐藏浏览器的系统返回与关闭入口。
            .toolbar(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("关闭", action: close)
                        .accessibilityIdentifier("debug.components.close")
                }
            }
    }
}
#endif
