import DebugSwift
import UIKit

/// W0 validation adapter, not the production DebugTools integration.
@MainActor
public enum DebugToolsProbe {
    private static let sdk: DebugSwift = {
        DebugSwift.App.shared.customInfo = {
            [CustomData(title: "W0 Probe", infos: [
                .init(title: "SDK", subtitle: "DebugSwift 1.19.0")
            ])]
        }
        return DebugSwift().setup(
            hideFeatures: [.network, .performance, .interface, .resources],
            disable: DebugSwiftSwizzleFeature.allCases
        )
    }()

    public static func makeViewController() -> UIViewController {
        _ = sdk
        DebugSwift.debugViewControllerWillPresent()
        return DebugSwift.debugViewController()
    }

    public static func didDismiss() {
        DebugSwift.debugViewControllerDidDismiss()
    }
}
