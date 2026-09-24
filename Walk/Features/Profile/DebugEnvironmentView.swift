import SwiftUI
import WalkData
import WalkDesignSystem

// MARK: - Debug 环境切换页
//
// 仅 DEBUG 构建编译。选择后写入 DebugSettingsStore，只影响下一次启动（R-SWITCH）。
// 三个选项只是常用组合的快捷入口，保存的仍是独立的数据模式与服务器两个维度；
// 按维度分别选择的完整调试界面归 W3。iOS 无法自重启，选中后提示手动退出重开。

#if DEBUG
struct DebugEnvironmentView: View {
    private let store: DebugSettingsStore
    private let effective: AppConfiguration
    @State private var pending: DebugSettings?

    init(effective: AppConfiguration, store: DebugSettingsStore = DebugSettingsStore()) {
        self.store = store
        self.effective = effective
        _pending = State(initialValue: store.load())
    }

    var body: some View {
        UtilityPage(title: "环境") {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                SurfaceElevated {
                    VStack(spacing: 0) {
                        ForEach(Array(Preset.allCases.enumerated()), id: \.element) { index, preset in
                            row(preset, showsDivider: index < Preset.allCases.count - 1)
                        }
                    }
                }

                SurfaceElevated {
                    VStack(alignment: .leading, spacing: Spacing.xs) {
                        Text("当前生效：\(Self.describe(effective.dataMode, effective.environmentName))")
                            .font(.appBody)
                            .foregroundStyle(AppColors.textPrimary)
                        if hasPendingChange {
                            Text("已保存新设置，请手动退出 App 后重新打开以生效。")
                                .font(.appCaption)
                                .foregroundStyle(AppColors.textSecondary)
                        }
                    }
                    .padding(Spacing.lg)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }

    /// 待生效提示根据保存值与当前有效值是否不同计算。
    private var hasPendingChange: Bool {
        guard let pending else { return false }
        if let mode = pending.dataMode, mode != effective.dataMode { return true }
        if let server = pending.server,
           server.environmentName != effective.environmentName || server.baseURL != effective.baseURL {
            return true
        }
        return false
    }

    private var selectedPreset: Preset? {
        guard let pending else { return nil }
        return Preset.allCases.first { $0.settings == pending }
    }

    private func row(_ preset: Preset, showsDivider: Bool) -> some View {
        let isSelected = selectedPreset == preset
        return Button {
            store.save(preset.settings)
            pending = preset.settings
        } label: {
            HStack(alignment: .center, spacing: Spacing.md) {
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text(preset.title)
                        .font(.appBody)
                        .foregroundStyle(AppColors.textPrimary)
                    Text(preset.detail)
                        .font(.appCaption)
                        .foregroundStyle(AppColors.textSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.appBody)
                    .foregroundStyle(isSelected ? AppColors.interactionPrimary : AppColors.textWeak)
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, Spacing.lg)
            .frame(minHeight: RootNavigation.toolButtonHitSize, alignment: .leading)
            .contentShape(Rectangle())
            .overlay(alignment: .bottom) {
                if showsDivider {
                    Rectangle()
                        .fill(AppColors.surfaceDivider)
                        .frame(height: 1)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(preset.title)，\(preset.detail)")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private static func describe(_ mode: WalkDataMode, _ environmentName: String) -> String {
        "\(mode.rawValue) · \(environmentName)"
    }

    /// 常用组合。后端目前只有 vialu.cn 一个部署，测试服与线上地址相同、环境标识不同，
    /// 按服务身份规则属于不同服务，缓存与会话各自隔离。
    private enum Preset: CaseIterable, Hashable {
        case mock
        case testServer
        case production

        private static let vialu = URL(string: "https://vialu.cn/walkbg/api/v1")!

        var title: String {
            switch self {
            case .mock: "Mock 数据"
            case .testServer: "测试服"
            case .production: "线上"
            }
        }

        var detail: String {
            switch self {
            case .mock: "本地假数据，不请求后端"
            case .testServer, .production: Self.vialu.absoluteString
            }
        }

        var settings: DebugSettings {
            switch self {
            case .mock:
                // 只选择模式，服务器沿用下一级来源。
                DebugSettings(dataMode: .mock, server: nil)
            case .testServer:
                DebugSettings(dataMode: .real, server: .init(environmentName: "development", baseURL: Self.vialu))
            case .production:
                DebugSettings(dataMode: .real, server: .init(environmentName: "production", baseURL: Self.vialu))
            }
        }
    }
}
#endif
