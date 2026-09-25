import XCTest
import WalkData
@testable import Walk

/// Debug 构建默认配置必须允许调试面板把数据模式切换到任一模式后正常启动。
///
/// 缺陷：Debug 默认服务器曾为占位地址 `api.example.invalid`；面板只写入数据模式，
/// 切到 real / remoteOnly 后重启时回落到占位地址，被 R-CONFIG 拒绝，`WalkApp.init` 触发 fatalError。
/// 这里读取实际打包进 App 的 Info.plist（构建配置），模拟面板只保存数据模式的情形。
final class DebugBuildDefaultsTests: XCTestCase {
    private var buildConfiguration: [String: Any] {
        let info = Bundle(for: AppEnvironment.self).infoDictionary ?? [:]
        return info.filter { ["WalkDataMode", "WalkAPIBaseURL", "WalkEnvironment"].contains($0.key) }
    }

    func testBuildDefaultIsMockAgainstTheRealBackend() {
        XCTAssertEqual(buildConfiguration["WalkDataMode"] as? String, "mock")
        XCTAssertEqual(buildConfiguration["WalkAPIBaseURL"] as? String, "https://vialu.cn/walkbg/api/v1")
    }

    /// 面板「数据模式」动作只写入 dataMode；任一模式都必须能用构建默认服务器解析成功。
    func testEveryModeSelectedInDebugPanelResolvesWithBuildDefaults() throws {
        for mode in WalkDataMode.allCases {
            let configuration = try AppConfiguration(
                arguments: ["Walk"],
                environment: [:],
                bundleInfo: buildConfiguration,
                debugSettings: DebugSettings(dataMode: mode, server: nil),
                isDebugBuild: true
            )
            XCTAssertEqual(configuration.dataMode, mode)
            XCTAssertEqual(configuration.baseURL.absoluteString, "https://vialu.cn/walkbg/api/v1")
            XCTAssertNoThrow(try AppEnvironment(configuration: configuration), "\(mode) 无法装配")
        }
    }
}
