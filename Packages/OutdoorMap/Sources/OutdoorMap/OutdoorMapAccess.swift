import Foundation
import MapboxMaps

/// The application supplies configuration before creating its first map surface.
/// This component does not read app bundles, files, or process environment values.
public enum OutdoorMapAccess {
    @discardableResult
    public static func configure(accessToken: String?) -> Bool {
        guard let token = accessToken?.trimmingCharacters(in: .whitespacesAndNewlines),
              !token.isEmpty, !token.contains("$("), !token.contains("${") else { return false }
        MapboxOptions.accessToken = token
        return true
    }
}
