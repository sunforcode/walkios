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

    func body(content: Content) -> some View {
        content
            .onAppear {
                WalkDebugTools.configure(
                    info: { [model] in model.infoSections() },
                    actions: { [model] in model.actionSections() }
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
            }
    }
}

private struct DebugPanelContainer: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> UIViewController {
        WalkDebugTools.makeViewController()
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}
}
#endif
