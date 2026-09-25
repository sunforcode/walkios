import DebugSwift
import UIKit

/// 调试面板中的一组只读信息。由 App 从有效配置转换而来。
public struct DebugInfoSection: Equatable, Sendable {
    public let title: String
    public let rows: [Row]

    public struct Row: Equatable, Sendable {
        public let title: String
        public let value: String

        public init(title: String, value: String) {
            self.title = title
            self.value = value
        }
    }

    public init(title: String, rows: [Row]) {
        self.title = title
        self.rows = rows
    }
}

/// 调试面板中的一组动作。动作本身由 App 注入，本包只负责展示与触发。
public struct DebugActionSection {
    public let title: String
    public let actions: [Action]

    public struct Action {
        public let title: String
        public let perform: () -> Void

        public init(title: String, perform: @escaping () -> Void) {
            self.title = title
            self.perform = perform
        }
    }

    public init(title: String, actions: [Action]) {
        self.title = title
        self.actions = actions
    }
}

/// DebugSwift 适配入口。
///
/// 依据 specs/README.md R-DEBUG：本包只在开发依赖图中存在；不依赖 WalkData、
/// WalkDesignSystem 或 App，不持有配置、不创建业务依赖。信息与动作每次打开面板时
/// 由 App 提供的闭包重新生成，因此展示的始终是当前状态。
///
/// SDK 的网络、性能、界面、资源观察全部隐藏，所有 swizzle 钩子关闭：
/// 本批不验证观察工具对请求、缓存、认证与取消语义的影响，因此不启用。
@MainActor
public enum WalkDebugTools {
    private static var infoProvider: () -> [DebugInfoSection] = { [] }
    private static var actionProvider: () -> [DebugActionSection] = { [] }
    private static var isConfigured = false

    /// 注册信息与动作来源。可重复调用，以最后一次为准；SDK 只初始化一次。
    public static func configure(
        info: @escaping () -> [DebugInfoSection],
        actions: @escaping () -> [DebugActionSection]
    ) {
        infoProvider = info
        actionProvider = actions
        guard !isConfigured else { return }
        isConfigured = true

        DebugSwift.App.shared.customInfo = {
            MainActor.assumeIsolated {
                infoProvider().map { section in
                    CustomData(
                        title: section.title,
                        infos: section.rows.map { .init(title: $0.title, subtitle: $0.value) }
                    )
                }
            }
        }
        DebugSwift.App.shared.customAction = {
            MainActor.assumeIsolated {
                actionProvider().map { section in
                    CustomAction(
                        title: section.title,
                        actions: section.actions.map { action in
                            .init(title: action.title, action: action.perform)
                        }
                    )
                }
            }
        }
        DebugSwift().setup(
            hideFeatures: [.network, .performance, .interface, .resources],
            disable: DebugSwiftSwizzleFeature.allCases
        )
    }

    /// 返回 SDK 面板。调用方负责呈现，关闭后调用 `didDismiss()`。
    public static func makeViewController() -> UIViewController {
        DebugSwift.debugViewControllerWillPresent()
        return DebugSwift.debugViewController()
    }

    public static func didDismiss() {
        DebugSwift.debugViewControllerDidDismiss()
    }
}
