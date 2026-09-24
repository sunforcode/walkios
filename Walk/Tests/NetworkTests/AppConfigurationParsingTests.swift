import XCTest
import WalkData
@testable import Walk

/// W2-1：App 配置解析。
///
/// 依据 specs/README.md R-CONFIG：数据模式、服务器身份、执行上下文三个维度独立，
/// 由 App 解析、校验并冻结为一次启动的有效配置。Debug 优先级为
/// 显式启动参数 > 进程环境变量 > 已保存的 Debug 设置 > 构建配置 > 代码默认值。
/// 未知、空白或同一来源内相互冲突的显式配置报错，不静默降级。
final class AppConfigurationParsingTests: XCTestCase {
    private let testURL = "https://api.example.test/v1"

    // MARK: - 数据模式值

    func testDataModeAcceptsThreeModesCaseInsensitively() throws {
        for (raw, expected) in [
            ("mock", WalkDataMode.mock),
            ("real", .real),
            ("remoteOnly", .remoteOnly),
            ("REMOTEONLY", .remoteOnly),
        ] {
            let configuration = try parse(arguments: ["-WalkDataMode", raw])
            XCTAssertEqual(configuration.dataMode, expected, raw)
        }
    }

    func testRetiredLocalModeIsUnsupported() {
        assertError(.unsupportedDataMode("local")) {
            try parse(arguments: ["-WalkDataMode", "local"])
        }
    }

    func testUnknownModeValueIsRejected() {
        for raw in ["remote", "offline", "cache"] {
            assertError(.invalidDataMode(raw)) {
                try parse(arguments: ["-WalkDataMode", raw])
            }
        }
    }

    func testBlankExplicitValueIsRejectedInsteadOfFallingThrough() {
        assertError(.emptyValue("-WalkDataMode")) {
            try parse(arguments: ["-WalkDataMode", "  "])
        }
        assertError(.emptyValue("-WalkDataMode")) {
            try parse(arguments: ["-WalkDataMode"])
        }
        assertError(.emptyValue("WALK_DATA_MODE")) {
            try parse(environment: ["WALK_DATA_MODE": ""])
        }
    }

    func testConflictingValuesWithinSameSourceAreRejected() {
        assertError(.conflictingValues("-WalkDataMode")) {
            try parse(arguments: ["-WalkDataMode", "mock", "-WalkDataMode", "real"])
        }
    }

    func testRepeatedIdenticalValueIsNotAConflict() throws {
        let configuration = try parse(arguments: ["-WalkDataMode", "mock", "-WalkDataMode", "mock"])
        XCTAssertEqual(configuration.dataMode, .mock)
    }

    // MARK: - 旧键

    /// 旧键不再作为兼容别名；传入时显式报错，避免被静默忽略。
    func testRetiredKeysAreRejectedInEverySource() {
        assertError(.retiredKey("-DataSourceMode")) {
            try parse(arguments: ["-DataSourceMode", "mock"])
        }
        assertError(.retiredKey("WALK_DATA_SOURCE_MODE")) {
            try parse(environment: ["WALK_DATA_SOURCE_MODE": "mock"])
        }
        assertError(.retiredKey("WalkDataSourceMode")) {
            try parse(bundleInfo: ["WalkDataSourceMode": "mock"])
        }
    }

    // MARK: - 优先级

    func testArgumentBeatsEnvironmentBeatsSettingsBeatsBuildConfiguration() throws {
        let settings = DebugSettings(
            dataMode: .remoteOnly,
            server: .init(environmentName: "settings", baseURL: URL(string: "https://settings.example.test/v1")!)
        )
        let bundle: [String: Any] = [
            "WalkDataMode": "mock",
            "WalkAPIBaseURL": "https://bundle.example.test/v1",
            "WalkEnvironment": "bundle",
        ]

        let fromBundle = try parse(bundleInfo: bundle)
        XCTAssertEqual(fromBundle.dataMode, .mock)
        XCTAssertEqual(fromBundle.environmentName, "bundle")

        let fromSettings = try parse(bundleInfo: bundle, debugSettings: settings)
        XCTAssertEqual(fromSettings.dataMode, .remoteOnly)
        XCTAssertEqual(fromSettings.baseURL.absoluteString, "https://settings.example.test/v1")
        XCTAssertEqual(fromSettings.environmentName, "settings")

        let fromEnvironment = try parse(
            environment: ["WALK_DATA_MODE": "real", "WALK_ENVIRONMENT": "env"],
            bundleInfo: bundle,
            debugSettings: settings
        )
        XCTAssertEqual(fromEnvironment.dataMode, .real)
        XCTAssertEqual(fromEnvironment.environmentName, "env")
        // 未被环境变量覆盖的维度仍取下一级来源。
        XCTAssertEqual(fromEnvironment.baseURL.absoluteString, "https://settings.example.test/v1")

        let fromArgument = try parse(
            arguments: ["-WalkDataMode", "mock", "-WalkEnvironment", "arg"],
            environment: ["WALK_DATA_MODE": "real", "WALK_ENVIRONMENT": "env"],
            bundleInfo: bundle,
            debugSettings: settings
        )
        XCTAssertEqual(fromArgument.dataMode, .mock)
        XCTAssertEqual(fromArgument.environmentName, "arg")
    }

    /// 代码默认值不得是 Mock：真实模式缺地址时报错，而不是改用 Mock。
    func testCodeDefaultIsRealAndMissingAddressIsAnError() {
        assertError(.missingBaseURL) {
            try AppConfiguration(arguments: ["Walk"], environment: [:], bundleInfo: [:], isDebugBuild: true)
        }
    }

    // MARK: - 维度独立

    /// 切换服务器不隐式改变模式，切换模式不隐式改变服务器。
    func testDataModeAndServerAreIndependent() throws {
        let settings = DebugSettings(
            dataMode: nil,
            server: .init(environmentName: "staging", baseURL: URL(string: "https://staging.example.test/v1")!)
        )
        let configuration = try parse(
            arguments: ["-WalkDataMode", "remoteOnly"],
            bundleInfo: ["WalkAPIBaseURL": testURL, "WalkEnvironment": "development"],
            debugSettings: settings
        )

        XCTAssertEqual(configuration.dataMode, .remoteOnly)
        XCTAssertEqual(configuration.environmentName, "staging")
        XCTAssertEqual(configuration.baseURL.absoluteString, "https://staging.example.test/v1")
    }

    // MARK: - 执行上下文

    /// 单元测试宿主由系统测试配置识别，而不是由服务器名推断；忽略个人 Debug 设置。
    func testUnitTestHostIgnoresPersonalDebugSettings() throws {
        let settings = DebugSettings(dataMode: .remoteOnly, server: nil)
        let configuration = try parse(
            environment: ["XCTestConfigurationFilePath": "/tmp/test.xctestconfiguration"],
            bundleInfo: ["WalkDataMode": "mock", "WalkAPIBaseURL": testURL, "WalkEnvironment": "development"],
            debugSettings: settings
        )

        XCTAssertEqual(configuration.executionContext, .unitTest)
        XCTAssertEqual(configuration.dataMode, .mock)
    }

    /// 服务器名为 test 不等于处于自动化测试。
    func testServerNamedTestDoesNotImplyTestContext() throws {
        let settings = DebugSettings(dataMode: .remoteOnly, server: nil)
        let configuration = try parse(
            environment: ["WALK_ENVIRONMENT": "test"],
            bundleInfo: ["WalkAPIBaseURL": testURL],
            debugSettings: settings
        )

        XCTAssertEqual(configuration.executionContext, .app)
        XCTAssertEqual(configuration.dataMode, .remoteOnly)
    }

    func testBaselineContextIgnoresPersonalDebugSettings() throws {
        let settings = DebugSettings(dataMode: .real, server: nil)
        let configuration = try parse(
            arguments: [
                "-WalkBaselineScenario", "page-trips--loaded",
                "-WalkEnvironment", "test",
            ],
            bundleInfo: ["WalkDataMode": "mock", "WalkAPIBaseURL": "https://api.example.invalid/v1"],
            debugSettings: settings
        )

        XCTAssertEqual(configuration.executionContext, .baseline)
        XCTAssertEqual(configuration.dataMode, .mock)
    }

    // MARK: - Release

    /// Release 固定使用构建配置：不读取启动参数、环境变量或 Debug 设置。
    func testReleaseUsesBuildConfigurationOnly() throws {
        let configuration = try AppConfiguration(
            arguments: ["Walk", "-WalkDataMode", "mock", "-APIBaseURL", "https://other.example.test/v1"],
            environment: ["WALK_DATA_MODE": "remoteOnly", "WALK_ENVIRONMENT": "development"],
            bundleInfo: [
                "WalkDataMode": "real",
                "WalkAPIBaseURL": "https://api.example.test/walkbg/api/v1",
                "WalkEnvironment": "production",
            ],
            debugSettings: DebugSettings(dataMode: .mock, server: nil),
            isDebugBuild: false
        )

        XCTAssertEqual(configuration.dataMode, .real)
        XCTAssertEqual(configuration.environmentName, "production")
        XCTAssertEqual(configuration.baseURL.absoluteString, "https://api.example.test/walkbg/api/v1")
        XCTAssertEqual(configuration.offlinePolicy, .fail)
    }

    func testReleaseRejectsNonRealBuildConfiguration() {
        assertError(.releaseRequiresReal) {
            try AppConfiguration(
                arguments: ["Walk"],
                environment: [:],
                bundleInfo: [
                    "WalkDataMode": "remoteOnly",
                    "WalkAPIBaseURL": "https://api.example.test/v1",
                    "WalkEnvironment": "production",
                ],
                isDebugBuild: false
            )
        }
    }

    // MARK: - 校验

    func testRealNetworkModesRejectPlaceholderAddress() {
        for mode in ["real", "remoteOnly"] {
            assertError(.placeholderBaseURL("https://api.example.invalid/v1")) {
                try parse(
                    arguments: ["-WalkDataMode", mode, "-APIBaseURL", "https://api.example.invalid/v1"]
                )
            }
        }
    }

    func testMockAllowsPlaceholderAddress() throws {
        let configuration = try parse(
            arguments: ["-WalkDataMode", "mock", "-APIBaseURL", "https://api.example.invalid/v1"]
        )
        XCTAssertEqual(configuration.dataMode, .mock)
    }

    func testProductionRejectsMock() {
        assertError(.productionRequiresRealNetwork) {
            try parse(arguments: ["-WalkDataMode", "mock", "-WalkEnvironment", "production"])
        }
    }

    func testServiceIdentityCombinesEnvironmentAndAddress() throws {
        let configuration = try parse(arguments: ["-WalkEnvironment", "development"])
        XCTAssertEqual(
            configuration.serviceIdentity,
            APIServiceIdentity(environmentName: "development", baseURL: URL(string: testURL)!)
        )
    }

    // MARK: - Helpers

    private func parse(
        arguments: [String] = [],
        environment: [String: String] = [:],
        bundleInfo: [String: Any]? = nil,
        debugSettings: DebugSettings? = nil
    ) throws -> AppConfiguration {
        try AppConfiguration(
            arguments: ["Walk"] + arguments,
            environment: environment,
            bundleInfo: bundleInfo ?? ["WalkAPIBaseURL": testURL, "WalkEnvironment": "development"],
            debugSettings: debugSettings,
            isDebugBuild: true
        )
    }

    private func assertError(
        _ expected: AppConfigurationError,
        file: StaticString = #filePath,
        line: UInt = #line,
        _ body: () throws -> Any
    ) {
        XCTAssertThrowsError(try body(), file: file, line: line) { error in
            XCTAssertEqual(error as? AppConfigurationError, expected, file: file, line: line)
        }
    }
}
