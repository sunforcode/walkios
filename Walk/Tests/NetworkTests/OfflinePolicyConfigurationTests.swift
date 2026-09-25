import XCTest
import WalkData
@testable import Walk

/// W3-4：断网策略作为独立配置维度。
///
/// 依据 specs/README.md R-CACHE-POLICY：App 注入默认策略，DebugTools 可选择已允许的策略；
/// `fail` 是未配置时的默认值。依据 R-CONFIG：来源优先级与其他维度一致，Release 固定 `fail`。
final class OfflinePolicyConfigurationTests: XCTestCase {
    private let bundle: [String: Any] = [
        "WalkAPIBaseURL": "https://api.example.test/v1",
        "WalkEnvironment": "development",
    ]

    func testDefaultIsFail() throws {
        XCTAssertEqual(try parse().offlinePolicy, .fail)
    }

    func testPolicyValuesAreParsedCaseInsensitively() throws {
        XCTAssertEqual(try parse(arguments: ["-WalkOfflinePolicy", "useCache"]).offlinePolicy, .useCache)
        XCTAssertEqual(try parse(arguments: ["-WalkOfflinePolicy", "USECACHE"]).offlinePolicy, .useCache)
        XCTAssertEqual(try parse(environment: ["WALK_OFFLINE_POLICY": "fail"]).offlinePolicy, .fail)
    }

    func testUnknownOrBlankPolicyIsRejected() {
        XCTAssertThrowsError(try parse(arguments: ["-WalkOfflinePolicy", "cacheFirst"])) { error in
            XCTAssertEqual(error as? AppConfigurationError, .invalidOfflinePolicy("cacheFirst"))
        }
        XCTAssertThrowsError(try parse(environment: ["WALK_OFFLINE_POLICY": " "])) { error in
            XCTAssertEqual(error as? AppConfigurationError, .emptyValue("WALK_OFFLINE_POLICY"))
        }
    }

    func testPriorityMatchesOtherDimensions() throws {
        let settings = DebugSettings(dataMode: nil, server: nil, offlinePolicy: .useCache)
        XCTAssertEqual(try parse(debugSettings: settings).offlinePolicy, .useCache)
        XCTAssertEqual(
            try parse(environment: ["WALK_OFFLINE_POLICY": "fail"], debugSettings: settings).offlinePolicy,
            .fail
        )
        XCTAssertEqual(
            try parse(
                arguments: ["-WalkOfflinePolicy", "useCache"],
                environment: ["WALK_OFFLINE_POLICY": "fail"]
            ).offlinePolicy,
            .useCache
        )
    }

    /// 自动化上下文忽略个人设置中的策略。
    func testUnitTestContextIgnoresSavedPolicy() throws {
        let settings = DebugSettings(dataMode: nil, server: nil, offlinePolicy: .useCache)
        let configuration = try parse(
            environment: ["XCTestConfigurationFilePath": "/tmp/x.xctestconfiguration"],
            debugSettings: settings
        )
        XCTAssertEqual(configuration.offlinePolicy, .fail)
    }

    func testReleaseAlwaysUsesFail() throws {
        let configuration = try AppConfiguration(
            arguments: ["Walk", "-WalkOfflinePolicy", "useCache"],
            environment: ["WALK_OFFLINE_POLICY": "useCache"],
            bundleInfo: [
                "WalkDataMode": "real",
                "WalkAPIBaseURL": "https://api.example.test/v1",
                "WalkEnvironment": "production",
            ],
            debugSettings: DebugSettings(dataMode: nil, server: nil, offlinePolicy: .useCache),
            isDebugBuild: false
        )
        XCTAssertEqual(configuration.offlinePolicy, .fail)
    }

    /// 未含策略字段的设置记录仍可读取，策略按未设置处理。
    func testSettingsRecordWithoutPolicyStillDecodes() throws {
        let json = #"{"version":1,"dataMode":"real"}"#
        let settings = try JSONDecoder().decode(DebugSettings.self, from: Data(json.utf8))
        XCTAssertEqual(settings.dataMode, .real)
        XCTAssertNil(settings.offlinePolicy)
    }

    private func parse(
        arguments: [String] = [],
        environment: [String: String] = [:],
        debugSettings: DebugSettings? = nil
    ) throws -> AppConfiguration {
        try AppConfiguration(
            arguments: ["Walk"] + arguments,
            environment: environment,
            bundleInfo: bundle,
            debugSettings: debugSettings,
            isDebugBuild: true
        )
    }
}
