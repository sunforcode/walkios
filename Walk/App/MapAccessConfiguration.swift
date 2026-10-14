import Foundation
import OutdoorMap

/// The App owns SDK access configuration. Features receive only availability.
enum MapAccessConfiguration {
    static let isAvailable = configure(bundleInfo: Bundle.main.infoDictionary ?? [:])

    static func configure(bundleInfo: [String: Any]) -> Bool {
        guard let value = bundleInfo["MBXAccessToken"] as? String else { return false }
        let token = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !token.isEmpty, !token.contains("$("), !token.contains("${") else { return false }
        return OutdoorMapAccess.configure(accessToken: token)
    }
}
