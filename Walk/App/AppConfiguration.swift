import Foundation
import WalkData
import WalkDesignSystem

enum AppConfigurationError: Error, Equatable {
    case invalidDataMode(String)
    case invalidOfflinePolicy(String)
    /// 可识别但已无等价能力的模式，例如已下线的 `local`。
    case unsupportedDataMode(String)
    /// 已退役的配置键；不再作为兼容别名，传入即报错以免被静默忽略。
    case retiredKey(String)
    /// 显式配置为空白。
    case emptyValue(String)
    /// 同一来源内同一键出现不同的值。
    case conflictingValues(String)
    case missingBaseURL
    case invalidBaseURL(String)
    case productionRequiresRealNetwork
    case releaseRequiresReal
    case invalidDistribution(String)
    case invalidOfflineDemoConfiguration
    case placeholderBaseURL(String)
}

/// 一次启动的执行上下文。
///
/// 依据 R-CONFIG：不能仅凭服务器名为 `test` 判断处于自动化测试。
/// 非 `.app` 上下文忽略个人 Debug 设置，由调用方显式注入场景配置。
enum ExecutionContext: Equatable {
    case app
    case unitTest
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
    /// 断网策略。Debug 可经启动参数、环境变量或 Debug 设置选择；Release 固定 `fail`。
    /// 端点离线资格仍决定是否真正允许离线返回。
    let offlinePolicy: OfflinePolicy

    init(
        dataMode: WalkDataMode,
        baseURL: URL,
        environmentName: String,
        executionContext: ExecutionContext = .app,
        offlinePolicy: OfflinePolicy = .default
    ) {
        self.dataMode = dataMode
        self.baseURL = baseURL
        self.environmentName = environmentName
        self.executionContext = executionContext
        self.offlinePolicy = offlinePolicy
    }

    /// 服务器身份：环境标识与规范化地址共同决定，同名不同地址视为不同服务。
    var serviceIdentity: APIServiceIdentity {
        APIServiceIdentity(environmentName: environmentName, baseURL: baseURL)
    }

    // MARK: - 键

    enum Key {
        /// 仅 Release 读取的发布标识，不提供运行时覆盖入口。
        static let distributionBundle = "WalkDistribution"

        static let dataModeArgument = "-WalkDataMode"
        static let dataModeEnvironment = "WALK_DATA_MODE"
        static let dataModeBundle = "WalkDataMode"

        static let baseURLArgument = "-APIBaseURL"
        static let baseURLEnvironment = "WALK_API_BASE_URL"
        static let baseURLBundle = "WalkAPIBaseURL"

        static let environmentArgument = "-WalkEnvironment"
        static let environmentEnvironment = "WALK_ENVIRONMENT"
        static let environmentBundle = "WalkEnvironment"

        static let offlinePolicyArgument = "-WalkOfflinePolicy"
        static let offlinePolicyEnvironment = "WALK_OFFLINE_POLICY"

        /// 系统在单元测试宿主进程中注入的测试配置路径。
        static let unitTestHostEnvironment = "XCTestConfigurationFilePath"

        static let retiredArguments = ["-DataSourceMode", "-WalkBaselineScenario"]
        static let retiredEnvironment = ["WALK_DATA_SOURCE_MODE", "WALK_BASELINE_SCENARIO"]
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

        let context: ExecutionContext
        if environment[Key.unitTestHostEnvironment] != nil {
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

        // 构建配置不承载策略：Release 固定 fail，Debug 未选择时同样取默认值。
        let rawPolicy = try launch.value(
            argument: Key.offlinePolicyArgument,
            environment: Key.offlinePolicyEnvironment
        ) ?? settings?.offlinePolicy?.rawValue

        self.init(
            dataMode: try Self.parseMode(rawMode),
            baseURL: try Self.parseURL(rawURL),
            environmentName: environmentName,
            executionContext: context,
            offlinePolicy: try rawPolicy.map(Self.parseOfflinePolicy) ?? .default
        )
        try validate()
    }

    private static func releaseConfiguration(bundle: BundleSource) throws -> AppConfiguration {
        let distribution = bundle.value(Key.distributionBundle)
        if distribution == "offline-demo" {
            // 离线演示必须由完整构建配置显式声明，地址精确匹配以排除外网、凭据和端口变体。
            guard bundle.value(Key.dataModeBundle) == WalkDataMode.mock.rawValue,
                  bundle.value(Key.environmentBundle) == "offline-demo",
                  let rawURL = bundle.value(Key.baseURLBundle),
                  rawURL == "https://offline.walk.invalid/api/v1",
                  let baseURL = URL(string: rawURL) else {
                throw AppConfigurationError.invalidOfflineDemoConfiguration
            }
            let configuration = AppConfiguration(
                dataMode: .mock,
                baseURL: baseURL,
                environmentName: "offline-demo",
                offlinePolicy: .fail
            )
            try configuration.validate()
            return configuration
        }
        if let distribution, distribution != "production" {
            throw AppConfigurationError.invalidDistribution(distribution)
        }

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

    private static func parseOfflinePolicy(_ raw: String) throws -> OfflinePolicy {
        guard let policy = OfflinePolicy.allCases.first(where: {
            $0.rawValue.caseInsensitiveCompare(raw) == .orderedSame
        }) else {
            throw AppConfigurationError.invalidOfflinePolicy(raw)
        }
        return policy
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
        return try resolveProcess(
            arguments: ProcessInfo.processInfo.arguments,
            environment: ProcessInfo.processInfo.environment,
            bundleInfo: Bundle.main.infoDictionary ?? [:],
            store: DebugSettingsStore()
        ).configuration
#else
        return try AppConfiguration(
            arguments: ProcessInfo.processInfo.arguments,
            environment: ProcessInfo.processInfo.environment,
            bundleInfo: Bundle.main.infoDictionary ?? [:]
        )
#endif
    }

#if DEBUG
    struct ProcessResolution {
        let configuration: AppConfiguration
        /// 已保存的 Debug 设置无法组成合法配置时被清除，这里记录原因。
        let discardedSettingsError: AppConfigurationError?
    }

    /// 个人保存的 Debug 设置不应让 App 无法启动：它们不合法时清除并回落到下一级来源重新解析。
    /// 显式启动参数、环境变量与构建配置出错仍然直接失败（R-CONFIG：显式配置错误不静默降级）。
    static func resolveProcess(
        arguments: [String],
        environment: [String: String],
        bundleInfo: [String: Any],
        store: DebugSettingsStore,
        isDebugBuild: Bool = AppConfiguration.isDebugBuild
    ) throws -> ProcessResolution {
        let saved = store.load()
        do {
            let configuration = try AppConfiguration(
                arguments: arguments,
                environment: environment,
                bundleInfo: bundleInfo,
                debugSettings: saved,
                isDebugBuild: isDebugBuild
            )
            return ProcessResolution(configuration: configuration, discardedSettingsError: nil)
        } catch let error as AppConfigurationError where saved != nil {
            let configuration = try AppConfiguration(
                arguments: arguments,
                environment: environment,
                bundleInfo: bundleInfo,
                debugSettings: nil,
                isDebugBuild: isDebugBuild
            )
            store.clear()
            print("[Walk] 已保存的 Debug 设置无效，已清除并使用构建默认值：\(error)")
            return ProcessResolution(configuration: configuration, discardedSettingsError: error)
        }
    }
#endif
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
