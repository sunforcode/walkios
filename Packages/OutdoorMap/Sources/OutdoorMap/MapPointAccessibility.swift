import UIKit
import MapboxMaps
import MapComponentCore

/// Virtual map features, separate from the SDK's native controls and gesture surface.
final class MapPointAccessibilityContainer: UIView {
    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        isUserInteractionEnabled = false
        isAccessibilityElement = false
        autoresizingMask = [.flexibleWidth, .flexibleHeight]
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}

final class MapPointAccessibilityElement: UIAccessibilityElement {
    let objectID: String
    let coordinates: [MapCoordinate]
    let isInteractive: Bool
    private weak var mapView: MapView?
    private let onActivate: () -> Void

    init(container: UIView, mapView: MapView, points: [MapPoint], onActivate: @escaping () -> Void) {
        let point = points[0]
        self.objectID = point.objectID
        self.coordinates = points.map(\.coordinate)
        self.isInteractive = points.contains(where: \.isInteractive)
        self.mapView = mapView
        self.onActivate = onActivate
        super.init(accessibilityContainer: container)
        accessibilityIdentifier = "outdoor-point:\(objectID)"
        accessibilityLabel = isInteractive ? "查看\(point.name)" : point.name
        accessibilityTraits = isInteractive ? [.button] : [.staticText]
    }

    /// Prefer an on-screen occurrence when one object has several geographic positions.
    @discardableResult
    func updateFrame(selected: Bool) -> Bool {
        guard let mapView else { return false }
        let positions = coordinates.map { mapView.mapboxMap.point(for: $0.clCoordinate) }
            .filter { $0.x.isFinite && $0.y.isFinite }
        // The SDK may use (-1, -1) for positions behind the camera. Require the
        // projected center itself to be visible; a 44-point frame overlapping
        // the corner does not make an off-screen geographic point selectable.
        guard let position = positions.first(where: { mapView.bounds.contains($0) }) else { return false }
        let rect = CGRect(x: position.x - 22, y: position.y - 22, width: 44, height: 44)
        accessibilityFrame = UIAccessibility.convertToScreenCoordinates(rect, in: mapView)
        accessibilityTraits = isInteractive ? (selected ? [.button, .selected] : [.button]) : [.staticText]
        return true
    }

    override func accessibilityActivate() -> Bool {
        guard isInteractive else { return false }
        onActivate()
        return true
    }
}
