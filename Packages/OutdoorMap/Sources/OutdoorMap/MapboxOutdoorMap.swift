import SwiftUI
import MapboxMaps
import MapComponentCore

/// Reusable map surface; controls, file access and detail presentation belong to its host.
public struct MapboxOutdoorMap: UIViewRepresentable {
    public var scene: MapScene
    public var options: MapDisplayOptions
    public var selection: MapSelection?
    public var fitRequest: Int
    public var location: GuidanceLocation?
    public var locationFocusRequest: Int
    public var locationFocusPadding: UIEdgeInsets
    public var scrubMarker: MapScrubMarker?
    public var cameraRequest: MapCameraRequest?
    public var zoomEnabled: Bool
    public var rotateEnabled: Bool
    public var onEvent: (OutdoorMapEvent) -> Void

    public init(scene: MapScene, options: MapDisplayOptions = .init(), selection: MapSelection? = nil,
                fitRequest: Int = 0, location: GuidanceLocation? = nil,
                locationFocusRequest: Int = 0, locationFocusPadding: UIEdgeInsets = .zero,
                scrubMarker: MapScrubMarker? = nil, cameraRequest: MapCameraRequest? = nil,
                zoomEnabled: Bool = true, rotateEnabled: Bool = true,
                onEvent: @escaping (OutdoorMapEvent) -> Void = { _ in }) {
        self.scene = scene
        self.options = options
        self.selection = selection
        self.fitRequest = fitRequest
        self.location = location
        self.locationFocusRequest = locationFocusRequest
        self.locationFocusPadding = locationFocusPadding
        self.scrubMarker = scrubMarker
        self.cameraRequest = cameraRequest
        self.zoomEnabled = zoomEnabled
        self.rotateEnabled = rotateEnabled
        self.onEvent = onEvent
    }

    public func makeCoordinator() -> Coordinator { Coordinator(self) }

    public func makeUIView(context: Context) -> MapView {
        let camera = CameraOptions(center: scene.coordinates.first?.clCoordinate, zoom: 13, pitch: options.cameraPitch)
        let view = OutdoorMapSurface(frame: .zero, mapInitOptions: MapInitOptions(cameraOptions: camera, styleURI: nil))
        view.accessibilityIdentifier = "outdoor-map"
        context.coordinator.attach(view)
        view.mapboxMap.mapStyle = options.baseMap.mapStyle
        return view
    }

    public func updateUIView(_ view: MapView, context: Context) { context.coordinator.update(self) }

    public static func dismantleUIView(_ uiView: MapView, coordinator: Coordinator) { coordinator.detach() }

    public final class Coordinator: NSObject, GestureManagerDelegate {
        private var parent: MapboxOutdoorMap
        private weak var view: MapView?
        private var renderer: MapSceneRenderer?
        private var observations = Set<AnyCancelable>()
        private var interactions = Set<AnyCancelable>()
        private var styleReady = false
        private var renderFailed = false
        private var lastFit: Int?
        private var lastLocationFocus = 0
        private var lastCameraRequest: Int?
        private weak var accessibilityContainer: MapPointAccessibilityContainer?
        private var accessibilityScene: MapScene?
        private var accessibilityPoints: [MapPointAccessibilityElement] = []

        init(_ parent: MapboxOutdoorMap) { self.parent = parent; super.init() }

        func attach(_ view: MapView) {
            self.view = view
            renderer = MapSceneRenderer(map: view.mapboxMap)
            let accessibility = MapPointAccessibilityContainer(frame: view.bounds)
            view.addSubview(accessibility)
            accessibilityContainer = accessibility
            updateAccessibility()
            view.gestures.delegate = self
            applyGestures()
            applyOrnaments()
            (view as? OutdoorMapSurface)?.onLayout = { [weak self] in
                guard let self else { return }
                if self.styleReady { self.applyCameraRequests() }
                self.updateAccessibilityFrames()
            }
            view.mapboxMap.onStyleLoaded.observe { [weak self] _ in
                guard let self else { return }
                self.styleReady = true
                self.renderer?.styleDidReload()
                self.render()
                self.applyCameraPitch()
                self.applyCameraRequests()
                if !self.renderFailed {
                    self.installInteractions()
                    self.emit(.styleReady)
                }
            }.store(in: &observations)
            view.mapboxMap.onMapLoaded.observe { [weak self] _ in
                if let self, !self.renderFailed { self.emit(.mapLoaded) }
            }.store(in: &observations)
            view.mapboxMap.onCameraChanged.observe { [weak self] _ in
                self?.updateAccessibilityFrames()
            }.store(in: &observations)
            view.mapboxMap.onMapLoadingError.observe { [weak self] _ in
                // SDK resource errors may contain URLs; do not forward tokens into UI/logs.
                self?.emit(.failed("地图资源加载失败，请检查网络和本地访问配置。"))
            }.store(in: &observations)
        }

        private func installInteractions() {
            interactions.removeAll()
            guard let view else { return }
            AnyCancelable(view.mapboxMap.addInteraction(TapInteraction(.layer(MapSceneRenderer.pinLayer), radius: 24) { [weak self] feature, _ in
                guard case .boolean(true) = feature.properties["interactive"] else { return false }
                guard case .string(let id) = feature.properties["objectID"] else { return false }
                self?.emit(.selected(.point(id)))
                return true
            })).store(in: &interactions)
            AnyCancelable(view.mapboxMap.addInteraction(TapInteraction(.layer(MapSceneRenderer.routeLayer), radius: 12) { [weak self] feature, _ in
                guard case .string(let id) = feature.properties["objectID"] else { return false }
                self?.emit(.selected(.track(id)))
                return true
            })).store(in: &interactions)
            AnyCancelable(view.mapboxMap.addInteraction(TapInteraction { [weak self] _ in
                self?.emit(.selected(nil)); return true
            })).store(in: &interactions)
            AnyCancelable(view.mapboxMap.addInteraction(LongPressInteraction { [weak self] context in
                if let coordinate = try? MapCoordinate(latitude: context.coordinate.latitude, longitude: context.coordinate.longitude) {
                    self?.emit(.longPressed(coordinate))
                }
                return true
            })).store(in: &interactions)
        }

        func update(_ parent: MapboxOutdoorMap) {
            let previous = self.parent
            self.parent = parent
            guard let view else { return }
            applyGestures()
            applyOrnaments()
            updateAccessibility()
            if previous.options.showsTerrain != parent.options.showsTerrain ||
                previous.options.terrainLevel != parent.options.terrainLevel {
                applyCameraPitch()
            }
            if previous.options.baseMap != parent.options.baseMap {
                styleReady = false
                view.mapboxMap.mapStyle = parent.options.baseMap.mapStyle
                return
            }
            if styleReady { render(); applyCameraRequests() }
        }

        private func applyGestures() {
            guard let view else { return }
            var gestures = view.gestures.options
            gestures.pinchZoomEnabled = parent.zoomEnabled
            gestures.doubleTapToZoomInEnabled = parent.zoomEnabled
            gestures.doubleTouchToZoomOutEnabled = parent.zoomEnabled
            gestures.quickZoomEnabled = parent.zoomEnabled
            gestures.rotateEnabled = parent.rotateEnabled
            gestures.pitchEnabled = parent.options.showsTerrain
            view.gestures.options = gestures
        }

        private func updateAccessibility() {
            guard let container = accessibilityContainer, let view else { return }
            if accessibilityScene != parent.scene {
                accessibilityScene = parent.scene
                var orderedIDs: [String] = []
                var groups: [String: [MapPoint]] = [:]
                for point in parent.scene.points {
                    if groups[point.objectID] == nil { orderedIDs.append(point.objectID) }
                    groups[point.objectID, default: []].append(point)
                }
                accessibilityPoints = orderedIDs.compactMap { id in
                    guard let points = groups[id], !points.isEmpty else { return nil }
                    return MapPointAccessibilityElement(container: container, mapView: view, points: points) { [weak self] in
                        self?.emit(.selected(.point(id)))
                    }
                }
            }
            updateAccessibilityFrames()
        }

        private func updateAccessibilityFrames() {
            let selectedID: String?
            if case .point(let id) = parent.selection { selectedID = id } else { selectedID = nil }
            accessibilityContainer?.accessibilityElements = accessibilityPoints.filter {
                $0.updateFrame(selected: $0.objectID == selectedID)
            }
        }

        public func gestureManager(_ gestureManager: GestureManager, didBegin gestureType: GestureType) {
            if gestureType != .singleTap { emit(.userInteractionBegan) }
        }

        public func gestureManager(_ gestureManager: GestureManager, didEnd gestureType: GestureType, willAnimate: Bool) {}
        public func gestureManager(_ gestureManager: GestureManager, didEndAnimatingFor gestureType: GestureType) {}

        private func applyCameraPitch() {
            view?.mapboxMap.setCamera(to: CameraOptions(pitch: parent.options.cameraPitch))
        }

        private func render() {
            do {
                try renderer?.render(scene: parent.scene, options: parent.options, selection: parent.selection,
                                     location: parent.location, scrubMarker: parent.scrubMarker)
                renderFailed = false
            } catch {
                renderFailed = true
                emit(.failed("地图图层配置失败。"))
            }
        }

        private func fitIfNeeded() {
            guard parent.cameraRequest == nil else { return }
            guard lastFit != parent.fitRequest, let view, view.bounds.width > 0, !parent.scene.coordinates.isEmpty else { return }
            do {
                let camera = try view.mapboxMap.camera(for: parent.scene.coordinates.map(\.clCoordinate),
                    camera: CameraOptions(padding: .zero, bearing: 0, pitch: parent.options.cameraPitch),
                    coordinatesPadding: UIEdgeInsets(top: 64, left: 44, bottom: 64, right: 44), maxZoom: 15, offset: nil)
                lastFit = parent.fitRequest
                view.mapboxMap.setCamera(to: camera)
            } catch { emit(.failed("当前视口无法容纳轨迹。")) }
        }

        private func applyCameraRequests() {
            applyOrnaments()
            if parent.cameraRequest != nil { focusExplicitRequestIfNeeded() }
            else { fitIfNeeded(); focusLocationIfNeeded() }
        }

        private func applyOrnaments() {
            guard let view, view.bounds.width > 0, view.bounds.height > 0 else { return }
            let padding = Self.clampedPadding(parent.cameraRequest?.padding ?? .zero, size: view.bounds.size)
            let bottom = min(padding.bottom + 8, max(8, view.bounds.height - 52))
            var options = view.ornaments.options
            options.logo.position = .bottomLeading
            options.logo.margins = CGPoint(x: min(padding.left + 8, max(8, view.bounds.width - 100)), y: bottom)
            options.attributionButton.position = .bottomTrailing
            options.attributionButton.margins = CGPoint(x: min(padding.right + 8, max(8, view.bounds.width - 60)), y: bottom)
            // Preserve the SDK's visible logo and attribution controls.
            if options != view.ornaments.options { view.ornaments.options = options }
        }

        private func focusExplicitRequestIfNeeded() {
            guard let request = parent.cameraRequest, lastCameraRequest != request.id,
                  let view, view.bounds.width > 0, view.bounds.height > 0 else { return }
            let padding = Self.clampedPadding(request.padding, size: view.bounds.size)
            let coordinates: [MapCoordinate]
            let maxZoom: Double
            switch request.target {
            case .coordinate(let coordinate, let zoom):
                guard zoom.isFinite else { return }
                view.mapboxMap.setCamera(to: CameraOptions(center: coordinate.clCoordinate, padding: padding,
                    zoom: min(22, max(0, zoom)), bearing: 0, pitch: parent.options.cameraPitch))
                lastCameraRequest = request.id
                return
            case .scene:
                coordinates = parent.scene.coordinates
                maxZoom = 15
            case .track(let id):
                coordinates = parent.scene.tracks.first(where: { $0.id == id })?.coordinates ?? []
                maxZoom = 15
            case .point(let id):
                coordinates = parent.scene.points.filter { $0.objectID == id }.map(\.coordinate)
                maxZoom = 15
            case .coordinates(let supplied, let zoom):
                guard zoom.isFinite else { return }
                coordinates = supplied
                maxZoom = min(22, max(0, zoom))
            }
            guard !coordinates.isEmpty else { return }
            do {
                let camera = try view.mapboxMap.camera(for: coordinates.map(\.clCoordinate),
                    camera: CameraOptions(padding: padding, bearing: 0, pitch: parent.options.cameraPitch),
                    coordinatesPadding: UIEdgeInsets(top: 24, left: 24, bottom: 24, right: 24),
                    maxZoom: maxZoom, offset: nil)
                view.mapboxMap.setCamera(to: camera)
                lastCameraRequest = request.id
            } catch { emit(.failed("当前视口无法容纳所选位置。")) }
        }

        private static func clampedPadding(_ value: UIEdgeInsets, size: CGSize) -> UIEdgeInsets {
            func bounded(_ value: CGFloat) -> CGFloat { value.isFinite ? max(0, value) : 0 }
            var result = UIEdgeInsets(top: bounded(value.top), left: bounded(value.left),
                                      bottom: bounded(value.bottom), right: bounded(value.right))
            let horizontal = result.left + result.right
            let vertical = result.top + result.bottom
            if horizontal > max(0, size.width - 48), horizontal > 0 {
                let scale = max(0, size.width - 48) / horizontal
                result.left *= scale; result.right *= scale
            }
            if vertical > max(0, size.height - 48), vertical > 0 {
                let scale = max(0, size.height - 48) / vertical
                result.top *= scale; result.bottom *= scale
            }
            return result
        }

        private func focusLocationIfNeeded() {
            guard lastLocationFocus != parent.locationFocusRequest,
                  let location = parent.location, let view, view.bounds.width > 0 else { return }
            let requested = parent.locationFocusPadding
            let padding = UIEdgeInsets(top: min(requested.top, view.bounds.height * 0.2),
                                       left: requested.left,
                                       bottom: min(requested.bottom, view.bounds.height * 0.5), right: requested.right)
            view.mapboxMap.setCamera(to: CameraOptions(center: location.coordinate.clCoordinate,
                padding: padding, zoom: max(14, view.mapboxMap.cameraState.zoom),
                bearing: 0, pitch: parent.options.cameraPitch))
            lastLocationFocus = parent.locationFocusRequest
        }

        private func emit(_ event: OutdoorMapEvent) {
            DispatchQueue.main.async { [weak self] in self?.parent.onEvent(event) }
        }

        func detach() {
            (view as? OutdoorMapSurface)?.onLayout = nil
            view?.gestures.delegate = nil
            accessibilityContainer?.removeFromSuperview()
            accessibilityContainer = nil
            accessibilityPoints.removeAll()
            observations.removeAll()
            interactions.removeAll()
            view = nil
            renderer = nil
        }
    }
}

private final class OutdoorMapSurface: MapView {
    var onLayout: (() -> Void)?
    override func layoutSubviews() {
        super.layoutSubviews()
        onLayout?()
    }
}
