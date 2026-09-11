import Foundation

enum AppConfigurationError: Error, Equatable {
    case invalidDataSourceMode(String)
    case invalidBaselineScenario(String)
    case missingBaseURL
    case invalidBaseURL(String)
    case baselineRequiresMock
    case baselineUnavailableInProduction
    case productionRequiresRemote
    case placeholderBaseURL(String)
}

struct AppConfiguration: Equatable {
    let dataSourceMode: DataSourceMode
    let baseURL: URL
    let environmentName: String
    let baselineScenario: CurrentBaselineScenario?

    init(
        dataSourceMode: DataSourceMode,
        baseURL: URL,
        environmentName: String,
        baselineScenario: CurrentBaselineScenario? = nil
    ) {
        self.dataSourceMode = dataSourceMode
        self.baseURL = baseURL
        self.environmentName = environmentName
        self.baselineScenario = baselineScenario
    }

    init(
        arguments: [String],
        environment: [String: String],
        bundleInfo: [String: Any] = Bundle.main.infoDictionary ?? [:]
    ) throws {
        func value(after flag: String) -> String? {
            guard let index = arguments.firstIndex(of: flag), arguments.indices.contains(index + 1) else { return nil }
            return arguments[index + 1]
        }

        let rawMode = value(after: "-DataSourceMode")
            ?? environment["WALK_DATA_SOURCE_MODE"]
            ?? bundleInfo["WalkDataSourceMode"] as? String
            ?? "remote"
        guard let mode = DataSourceMode(rawValue: rawMode.lowercased()) else {
            throw AppConfigurationError.invalidDataSourceMode(rawMode)
        }

        let rawURL = value(after: "-APIBaseURL")
            ?? environment["WALK_API_BASE_URL"]
            ?? bundleInfo["WalkAPIBaseURL"] as? String
        guard let rawURL, !rawURL.isEmpty else {
            throw AppConfigurationError.missingBaseURL
        }
        guard let url = URL(string: rawURL), url.scheme != nil, url.host != nil else {
            throw AppConfigurationError.invalidBaseURL(rawURL)
        }

        let rawBaselineScenario = value(after: "-WalkBaselineScenario")
            ?? environment["WALK_BASELINE_SCENARIO"]
        let baselineScenario: CurrentBaselineScenario?
        if let rawBaselineScenario, !rawBaselineScenario.isEmpty {
            guard let parsed = CurrentBaselineScenario(rawValue: rawBaselineScenario) else {
                throw AppConfigurationError.invalidBaselineScenario(rawBaselineScenario)
            }
            baselineScenario = parsed
        } else {
            baselineScenario = nil
        }

        self.init(
            dataSourceMode: mode,
            baseURL: url,
            environmentName: value(after: "-WalkEnvironment")
                ?? environment["WALK_ENVIRONMENT"]
                ?? bundleInfo["WalkEnvironment"] as? String
                ?? "production",
            baselineScenario: baselineScenario
        )
        try validate()
    }

    func validate() throws {
        if baselineScenario != nil {
            guard environmentName.caseInsensitiveCompare("production") != .orderedSame else {
                throw AppConfigurationError.baselineUnavailableInProduction
            }
            guard dataSourceMode == .mock else {
                throw AppConfigurationError.baselineRequiresMock
            }
        }
        guard environmentName.caseInsensitiveCompare("production") == .orderedSame else { return }
        guard dataSourceMode == .remote else {
            throw AppConfigurationError.productionRequiresRemote
        }
        guard !Self.isPlaceholder(baseURL) else {
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

    static func process() throws -> AppConfiguration {
        try AppConfiguration(
            arguments: ProcessInfo.processInfo.arguments,
            environment: ProcessInfo.processInfo.environment,
            bundleInfo: Bundle.main.infoDictionary ?? [:]
        )
    }
}
