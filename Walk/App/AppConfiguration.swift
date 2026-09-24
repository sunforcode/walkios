import Foundation
import WalkData
import WalkDesignSystem

enum AppConfigurationError: Error, Equatable {
    case invalidDataMode(String)
    /// 可识别但已无等价能力的模式，例如已下线的 `local`。
    case unsupportedDataMode(String)
    /// 已退役的配置键；不再作为兼容别名，传入即报错以免被静默忽略。
    case retiredKey(String)
    /// 显式配置为空白。
    case emptyValue(String)
    /// 同一来源内同一键出现不同的值。
    case conflictingValues(String)
    case invalidBaselineScenario(String)
    case missingBaseURL
    case invalidBaseURL(String)
    case baselineRequiresMock
    case baselineUnavailableInProduction
    case productionRequiresRealNetwork
    case releaseRequiresReal
    case placeholderBaseURL(String)
}

/// 一次启动的执行上下文。
///
/// 依据 R-CONFIG：不能仅凭服务器名为 `test` 判断处于自动化测试。
/// 非 `.app` 上下文忽略个人 Debug 设置，由调用方显式注入场景配置。
enum ExecutionContext: Equatable {
    case app
    case unitTest
    case baseline
    case componentPreview
}

/// App 最终有效配置。
///
/// 依据 specs/README.md R-CONFIG：数据模式、服务器身份、执行上下文三个维度独立，
/// 由 App 解析、校验并冻结。WalkData 只接收由此生成的依赖与策略，不重新读取配置源。
struct AppConfiguration: Equatable {
    let dataMode: WalkDataMode
    let baseURL: URL
    let environmentName: String
    let executionContext: ExecutionContext
    /// 首版固定为默认值 `fail`；W3 起由 DebugTools 选择。
    let offlinePolicy: OfflinePolicy
    let baselineScenario: CurrentBaselineScenario?

    init(
        dataMode: WalkDataMode,
        baseURL: URL,
        environmentName: String,
        executionContext: ExecutionContext = .app,
        offlinePolicy: OfflinePolicy = .default,
        baselineScenario: CurrentBaselineScenario? = nil
    ) {
        self.dataMode = dataMode
        self.baseURL = baseURL
        self.environmentName = environmentName
        self.executionContext = executionContext
        self.offlinePolicy = offlinePolicy
        self.baselineScenario = baselineScenario
    }

    /// 服务器身份：环境标识与规范化地址共同决定，同名不同地址视为不同服务。
    var serviceIdentity: APIServiceIdentity {
        APIServiceIdentity(environmentName: environmentName, baseURL: baseURL)
    }

    // MARK: - 键

    enum Key {
        static let dataModeArgument = "-WalkDataMode"
        static let dataModeEnvironment = "WALK_DATA_MODE"
        static let dataModeBundle = "WalkDataMode"

        static let baseURLArgument = "-APIBaseURL"
        static let baseURLEnvironment = "WALK_API_BASE_URL"
        static let baseURLBundle = "WalkAPIBaseURL"

        static let environmentArgument = "-WalkEnvironment"
        static let environmentEnvironment = "WALK_ENVIRONMENT"
        static let environmentBundle = "WalkEnvironment"

        static let baselineArgument = "-WalkBaselineScenario"
        static let baselineEnvironment = "WALK_BASELINE_SCENARIO"

        /// 系统在单元测试宿主进程中注入的测试配置路径。
        static let unitTestHostEnvironment = "XCTestConfigurationFilePath"

        static let retiredArguments = ["-DataSourceMode"]
        static let retiredEnvironment = ["WALK_DATA_SOURCE_MODE"]
        static let retiredBundle = ["WalkDataSourceMode"]
    }

    // MARK: - 解析

    /// 解析最终配置。
    ///
    /// Debug 优先级：显式启动参数 > 进程环境变量 > 已保存的 Debug 设置 > 构建配置 > 代码默认值。
    /// Release 只读取构建配置，不接受开发模式切换入口。
    init(
        arguments: [String],
        environment: [String: String],
        bundleInfo: [String: Any] = Bundle.main.infoDictionary ?? [:],
        debugSettings: DebugSettings? = nil,
        isDebugBuild: Bool = AppConfiguration.isDebugBuild
    ) throws {
        let bundle = BundleSource(info: bundleInfo)
        try bundle.rejectRetiredKeys()

        guard isDebugBuild else {
            self = try Self.releaseConfiguration(bundle: bundle)
            return
        }

        let launch = LaunchSource(arguments: arguments, environment: environment)
        try launch.rejectRetiredKeys()

        let baselineRaw = try launch.value(
            argument: Key.baselineArgument,
            environment: Key.baselineEnvironment
        )
        let context: ExecutionContext
        if baselineRaw != nil {
            context = .baseline
        } else if environment[Key.unitTestHostEnvironment] != nil {
            context = .unitTest
        } else {
            context = .app
        }
        // 只有正常运行上下文读取个人 Debug 设置。
        let settings = context == .app ? debugSettings : nil

        let rawMode = try launch.value(argument: Key.dataModeArgument, environment: Key.dataModeEnvironment)
            ?? settings?.dataMode?.rawValue
            ?? bundle.value(Key.dataModeBundle)
            ?? WalkDataMode.real.rawValue
        let rawURL = try launch.value(argument: Key.baseURLArgument, environment: Key.baseURLEnvironment)
            ?? settings?.server?.baseURL.absoluteString
            ?? bundle.value(Key.baseURLBundle)
        let environmentName = try launch.value(
            argument: Key.environmentArgument,
            environment: Key.environmentEnvironment
        )
            ?? settings?.server?.environmentName
            ?? bundle.value(Key.environmentBundle)
            ?? "production"

        let baselineScenario: CurrentBaselineScenario?
        if let baselineRaw {
            guard let parsed = CurrentBaselineScenario(rawValue: baselineRaw) else {
                throw AppConfigurationError.invalidBaselineScenario(baselineRaw)
            }
            baselineScenario = parsed
        } else {
            baselineScenario = nil
        }

        self.init(
            dataMode: try Self.parseMode(rawMode),
            baseURL: try Self.parseURL(rawURL),
            environmentName: environmentName,
            executionContext: context,
            baselineScenario: baselineScenario
        )
        try validate()
    }

    private static func releaseConfiguration(bundle: BundleSource) throws -> AppConfiguration {
        let mode = try parseMode(bundle.value(Key.dataModeBundle) ?? WalkDataMode.real.rawValue)
        guard mode == .real else {
            throw AppConfigurationError.releaseRequiresReal
        }
        let configuration = AppConfiguration(
            dataMode: mode,
            baseURL: try parseURL(bundle.value(Key.baseURLBundle)),
            environmentName: bundle.value(Key.environmentBundle) ?? "production"
        )
        try configuration.validate()
        return configuration
    }

    private static func parseMode(_ raw: String) throws -> WalkDataMode {
        let normalized = raw.lowercased()
        if normalized == "local" {
            throw AppConfigurationError.unsupportedDataMode(raw)
        }
        guard let mode = WalkDataMode.allCases.first(where: { $0.rawValue.lowercased() == normalized }) else {
            throw AppConfigurationError.invalidDataMode(raw)
        }
        return mode
    }

    private static func parseURL(_ raw: String?) throws -> URL {
        guard let raw, !raw.isEmpty else {
            throw AppConfigurationError.missingBaseURL
        }
        guard let url = URL(string: raw), url.scheme != nil, url.host != nil else {
            throw AppConfigurationError.invalidBaseURL(raw)
        }
        return url
    }

    // MARK: - 校验

    func validate() throws {
        let isProduction = environmentName.caseInsensitiveCompare("production") == .orderedSame
        if baselineScenario != nil {
            guard !isProduction else {
                throw AppConfigurationError.baselineUnavailableInProduction
            }
            guard dataMode == .mock else {
                throw AppConfigurationError.baselineRequiresMock
            }
        }
        if isProduction, !dataMode.usesRealNetwork {
            throw AppConfigurationError.productionRequiresRealNetwork
        }
        // 真实模式必须有有效服务地址，不因地址错误改用 Mock 或其他服务器。
        if dataMode.usesRealNetwork, Self.isPlaceholder(baseURL) {
            throw AppConfigurationError.placeholderBaseURL(baseURL.absoluteString)
        }
    }

    private static func isPlaceholder(_ url: URL) -> Bool {
        guard let host = url.host?.lowercased(), !host.isEmpty else { return true }
        return host == "localhost"
            || host == "127.0.0.1"
            || host == "::1"
            || host.hasSuffix(".invalid")
    }

    // MARK: - 进程入口

    static var isDebugBuild: Bool {
#if DEBUG
        true
#else
        false
#endif
    }

    static func process() throws -> AppConfiguration {
#if DEBUG
        let settings = DebugSettingsStore().load()
#else
        let settings: DebugSettings? = nil
#endif
        return try AppConfiguration(
            arguments: ProcessInfo.processInfo.arguments,
            environment: ProcessInfo.processInfo.environment,
            bundleInfo: Bundle.main.infoDictionary ?? [:],
            debugSettings: settings
        )
    }
}

// MARK: - 来源

/// 启动参数与进程环境变量。两者是不同来源，参数优先。
private struct LaunchSource {
    let arguments: [String]
    let environment: [String: String]

    func rejectRetiredKeys() throws {
        for key in AppConfiguration.Key.retiredArguments where arguments.contains(key) {
            throw AppConfigurationError.retiredKey(key)
        }
        for key in AppConfiguration.Key.retiredEnvironment where environment[key] != nil {
            throw AppConfigurationError.retiredKey(key)
        }
    }

    func value(argument: String, environment environmentKey: String) throws -> String? {
        if let fromArgument = try argumentValue(argument) {
            return fromArgument
        }
        guard let raw = environment[environmentKey] else { return nil }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw AppConfigurationError.emptyValue(environmentKey)
        }
        return trimmed
    }

    /// 同一参数出现多次且值不同即冲突；参数缺值或值空白即报错。
    private func argumentValue(_ flag: String) throws -> String? {
        var values: [String] = []
        for (index, element) in arguments.enumerated() where element == flag {
            let next = index + 1
            guard arguments.indices.contains(next) else {
                throw AppConfigurationError.emptyValue(flag)
            }
            let value = arguments[next].trimmingCharacters(in: .whitespacesAndNewlines)
            guard !value.isEmpty else {
                throw AppConfigurationError.emptyValue(flag)
            }
            values.append(value)
        }
        guard let first = values.first else { return nil }
        guard values.allSatisfy({ $0 == first }) else {
            throw AppConfigurationError.conflictingValues(flag)
        }
        return first
    }
}

/// 构建配置（Info.plist）。构建设置未定义时展开为空字符串，按未提供处理。
private struct BundleSource {
    let info: [String: Any]

    func rejectRetiredKeys() throws {
        for key in AppConfiguration.Key.retiredBundle where info[key] != nil {
            throw AppConfigurationError.retiredKey(key)
        }
    }

    func value(_ key: String) -> String? {
        guard let raw = info[key] as? String else { return nil }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
