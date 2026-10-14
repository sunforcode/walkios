import SwiftUI

private struct RouteMapAccessAvailableKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    /// Access is configured once by App. Features only consume this availability.
    var routeMapAccessAvailable: Bool {
        get { self[RouteMapAccessAvailableKey.self] }
        set { self[RouteMapAccessAvailableKey.self] = newValue }
    }
}
