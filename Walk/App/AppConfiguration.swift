import Foundation

enum AppConfigurationError: Error, Equatable {
    case invalidDataSourceMode(String)
    case missingBaseURL
    case invalidBaseURL(String)
}

struct AppConfiguration: Equatable {
    let dataSourceMode: DataSourceMode
    let baseURL: URL
    let environmentName: String
    let userID: String

    init(
        dataSourceMode: DataSourceMode,
        baseURL: URL,
        environmentName: String,
        userID: String
    ) {
        self.dataSourceMode = dataSourceMode
        self.baseURL = baseURL
        self.environmentName = environmentName
        self.userID = userID
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
            ?? "mock"
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

        self.init(
            dataSourceMode: mode,
            baseURL: url,
            environmentName: environment["WALK_ENVIRONMENT"]
                ?? bundleInfo["WalkEnvironment"] as? String
                ?? "production",
            userID: environment["WALK_USER_ID"] ?? "anonymous"
        )
    }

    static func process() throws -> AppConfiguration {
        try AppConfiguration(
            arguments: ProcessInfo.processInfo.arguments,
            environment: ProcessInfo.processInfo.environment,
            bundleInfo: Bundle.main.infoDictionary ?? [:]
        )
    }
}
