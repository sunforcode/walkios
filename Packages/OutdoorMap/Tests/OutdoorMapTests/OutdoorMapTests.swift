import XCTest
import MapboxMaps
import MapComponentCore
@testable import OutdoorMap

@MainActor
final class OutdoorMapTests: XCTestCase {
    private var testWindow: UIWindow?
    private let blankStyle = """
    {"version":8,"name":"Deterministic test style","glyphs":"mapbox://fonts/mapbox/{fontstack}/{range}.pbf","sources":{},"layers":[{"id":"background","type":"background","paint":{"background-color":"#DCE4E2"}}]}
    """

    func testAccessConfigurationRejectsMissingAndUnexpandedValuesWithoutChangingCurrentConfiguration() {
        let previous = MapboxOptions.accessToken
        for token: String? in [nil, "", " \n ", "$(MAPBOX_ACCESS_TOKEN)", "${MAPBOX_ACCESS_TOKEN}"] {
            XCTAssertFalse(OutdoorMapAccess.configure(accessToken: token))
            XCTAssertTrue(MapboxOptions.accessToken == previous)
        }
    }

    func testAccessConfigurationUsesOnlyTheExplicitHostValue() {
        let previous = MapboxOptions.accessToken
        defer { MapboxOptions.accessToken = previous }
        let localTestValue = "pk.outdoor-map-local-configuration-test"
        XCTAssertTrue(OutdoorMapAccess.configure(accessToken: " \(localTestValue)\n"))
        XCTAssertTrue(MapboxOptions.accessToken == localTestValue)
    }

    func testAttributionAndLogoRemainVisibleAboveHostPaddingWithoutReplayingCameraRequest() async throws {
        let view = try await loadedMap()
        var component = MapboxOutdoorMap(scene: try fixture(),
            cameraRequest: MapCameraRequest(id: 1, target: .scene,
                padding: UIEdgeInsets(top: 60, left: 20, bottom: 180, right: 24)))
        let coordinator = component.makeCoordinator()
        coordinator.attach(view)
        defer { coordinator.detach() }
        coordinator.update(component)
        XCTAssertEqual(view.ornaments.options.logo.position, .bottomLeading)
        XCTAssertEqual(view.ornaments.options.attributionButton.position, .bottomTrailing)
        XCTAssertEqual(view.ornaments.options.logo.margins, CGPoint(x: 28, y: 188))
        XCTAssertEqual(view.ornaments.options.attributionButton.margins, CGPoint(x: 32, y: 188))
        XCTAssertFalse(view.ornaments.logoView.isHidden)
        XCTAssertFalse(view.ornaments.attributionButton.isHidden)

        // Insets remain live UI input even when the one-shot camera request ID is unchanged.
        component.cameraRequest = MapCameraRequest(id: 1, target: .scene,
            padding: UIEdgeInsets(top: 60, left: 20, bottom: 280, right: 24))
        coordinator.update(component)
        XCTAssertEqual(view.ornaments.options.logo.margins.y, 288)
        XCTAssertEqual(view.ornaments.options.attributionButton.margins.y, 288)
        component.cameraRequest = MapCameraRequest(id: 1, target: .scene,
            padding: UIEdgeInsets(top: 0, left: 5_000, bottom: 5_000, right: 5_000))
        coordinator.update(component)
        XCTAssertLessThanOrEqual(view.ornaments.options.logo.margins.y, view.bounds.height - 52)
        XCTAssertLessThanOrEqual(view.ornaments.options.attributionButton.margins.y, view.bounds.height - 52)
        XCTAssertFalse(view.ornaments.logoView.isHidden)
        XCTAssertFalse(view.ornaments.attributionButton.isHidden)
    }

    func testAccessiblePointsGroupBusinessIdentityKeepFullNameAndActivateTheMapSelectionEvent() async throws {
        let view = try await loadedMap()
        let a = try MapCoordinate(latitude: 45.906, longitude: 6.94)
        let b = try MapCoordinate(latitude: 45.907, longitude: 6.942)
        let scene = try MapScene(points: [
            MapPoint(id: "camp:1", name: "完整名称的高山营地", coordinate: a, objectID: "camp"),
            MapPoint(id: "camp:2", name: "完整名称的高山营地", coordinate: b, objectID: "camp"),
            MapPoint(id: "start", name: "起点", coordinate: a, isInteractive: false),
            MapPoint(id: "far", name: "屏幕之外的点位", coordinate: MapCoordinate(latitude: 0, longitude: 0)),
            MapPoint(id: "behind", name: "相机背面的点位", coordinate: MapCoordinate(latitude: -45.906, longitude: -173.06))
        ])
        let activated = expectation(description: "AX activates the same point event as a map tap")
        let component = MapboxOutdoorMap(scene: scene) { event in
            if case .selected(.point("camp")) = event { activated.fulfill() }
        }
        let coordinator = component.makeCoordinator()
        coordinator.attach(view)
        defer { coordinator.detach() }
        let container = try XCTUnwrap(view.subviews.compactMap { $0 as? MapPointAccessibilityContainer }.first)
        XCTAssertFalse(container.isUserInteractionEnabled)
        let elements = try XCTUnwrap(container.accessibilityElements as? [MapPointAccessibilityElement])
        XCTAssertEqual(elements.count, 2) // One business point plus a static terminal, despite two camp positions.
        XCTAssertFalse(elements.contains(where: { $0.objectID == "far" || $0.objectID == "behind" }))
        let camp = try XCTUnwrap(elements.first(where: { $0.objectID == "camp" }))
        XCTAssertEqual(camp.accessibilityIdentifier, "outdoor-point:camp")
        XCTAssertEqual(camp.accessibilityLabel, "查看完整名称的高山营地")
        XCTAssertTrue(camp.accessibilityTraits.contains(.button))
        XCTAssertEqual(camp.accessibilityFrame.width, 44, accuracy: 0.01)
        XCTAssertEqual(camp.accessibilityFrame.height, 44, accuracy: 0.01)
        let start = try XCTUnwrap(elements.first(where: { $0.objectID == "start" }))
        XCTAssertFalse(start.accessibilityTraits.contains(.button))
        XCTAssertFalse(start.accessibilityActivate())
        XCTAssertTrue(camp.accessibilityActivate())
        await fulfillment(of: [activated], timeout: 2)
        let originalFrame = camp.accessibilityFrame
        view.mapboxMap.setCamera(to: CameraOptions(center: .init(latitude: b.latitude, longitude: b.longitude + 0.0003), zoom: 17))
        coordinator.update(component)
        XCTAssertNotEqual(camp.accessibilityFrame, originalFrame)
        XCTAssertFalse(view.ornaments.attributionButton.isHidden)
        XCTAssertTrue(view.ornaments.attributionButton.isAccessibilityElement)
    }

    func testGeoJSONKeepsDisconnectedTracksAndStablePointIDs() throws {
        let scene = try fixture()
        let features = MapSceneRenderer.trackFeatures(scene)
        XCTAssertEqual(features.count, 2)
        XCTAssertEqual(features.first?.identifier, .string("route-a"))
        if case .lineString(let line) = features.first?.geometry {
            XCTAssertEqual(line.coordinates.count, 2)
            XCTAssertEqual(line.coordinates[0].longitude, 6.94)
        } else { XCTFail("Expected a separate LineString") }
        XCTAssertEqual(MapSceneRenderer.pointFeatures(scene).first?.properties?["objectID"], .string("water"))
        let label = MapSceneRenderer.pointFeatures(scene).first?.properties?["label"]
        XCTAssertTrue(String(describing: label).contains("Water"))
        XCTAssertTrue(String(describing: label).contains("2000"))
        XCTAssertEqual(MapSceneRenderer.heatFeatures(scene).first?.properties?["weight"], .number(0.75))
    }

    func testPresentationFeaturesKeepStylesAndGroupedPointIdentity() throws {
        let a = try MapCoordinate(latitude: 30, longitude: 100)
        let b = try MapCoordinate(latitude: 30.01, longitude: 100.01)
        let scene = try MapScene(tracks: [MapTrack(id: "span", name: "Span", coordinates: [a, b],
            style: MapTrackStyle(colorHex: "#123456", casingColorHex: "#ABCDEF", lineWidth: 5,
                                 casingWidth: 11, opacity: 0.2))],
            points: [MapPoint(id: "annotation:1", name: "Camp", coordinate: a, objectID: "camp"),
                     MapPoint(id: "annotation:2", name: "Camp", coordinate: b, objectID: "camp"),
                     MapPoint(id: "start", name: "Start", coordinate: a, isInteractive: false)])
        let track = try XCTUnwrap(MapSceneRenderer.trackFeatures(scene).first)
        XCTAssertEqual(track.properties?["color"], .string("#123456"))
        XCTAssertEqual(track.properties?["casingColor"], .string("#ABCDEF"))
        XCTAssertEqual(track.properties?["width"], .number(5))
        XCTAssertEqual(track.properties?["casingWidth"], .number(11))
        XCTAssertEqual(track.properties?["opacity"], .number(0.2))
        let points = MapSceneRenderer.pointFeatures(scene)
        XCTAssertEqual(points[0].identifier, .string("annotation:1"))
        XCTAssertEqual(points[1].identifier, .string("annotation:2"))
        XCTAssertEqual(points[0].properties?["objectID"], .string("camp"))
        XCTAssertEqual(points[1].properties?["objectID"], .string("camp"))
        XCTAssertEqual(points[2].properties?["interactive"], .boolean(false))
    }

    func testIndependentScrubLayerDoesNotDrawUserAccuracyAndRestoresAfterReload() async throws {
        let view = try await loadedMap()
        let renderer = MapSceneRenderer(map: view.mapboxMap)
        let scene = try fixture()
        let marker = MapScrubMarker(coordinate: try MapCoordinate(latitude: 45.91, longitude: 6.946))
        try renderer.render(scene: scene, options: .init(), selection: nil, scrubMarker: marker)
        XCTAssertTrue(view.mapboxMap.layerExists(withId: "outdoor-scrub-marker"))
        XCTAssertEqual(view.mapboxMap.layerPropertyValue(for: "outdoor-scrub-marker", property: "visibility") as? String, "visible")
        XCTAssertEqual(view.mapboxMap.layerPropertyValue(for: "outdoor-user-location", property: "visibility") as? String, "none")
        XCTAssertEqual(MapSceneRenderer.scrubFeatures(marker).count, 1)
        XCTAssertEqual(scene.coordinates.count, 6)
        try renderer.render(scene: scene, options: .init(), selection: nil, scrubMarker: nil)
        XCTAssertEqual(view.mapboxMap.layerPropertyValue(for: "outdoor-scrub-marker", property: "visibility") as? String, "none")
        renderer.styleDidReload()
        try renderer.render(scene: scene, options: .init(), selection: nil, scrubMarker: marker)
        XCTAssertEqual(view.mapboxMap.layerPropertyValue(for: "outdoor-scrub-marker", property: "visibility") as? String, "visible")
    }

    func testExplicitCameraRequestPreservesManualBrowsingUntilANewRequest() async throws {
        let view = try await loadedMap()
        let focus = try MapCoordinate(latitude: 30, longitude: 100)
        let padding = UIEdgeInsets(top: 80, left: 20, bottom: 180, right: 20)
        var component = MapboxOutdoorMap(scene: try fixture(),
            cameraRequest: MapCameraRequest(id: 0, target: .coordinate(focus, zoom: 14), padding: padding))
        let coordinator = component.makeCoordinator()
        coordinator.attach(view)
        defer { coordinator.detach() }
        let reloaded = expectation(description: "Explicit camera style loaded")
        let observation = view.mapboxMap.onStyleLoaded.observeNext { _ in reloaded.fulfill() }
        view.mapboxMap.styleJSON = blankStyle.replacingOccurrences(of: "#DCE4E2", with: "#FDFDFD")
        await fulfillment(of: [reloaded], timeout: 10)
        withExtendedLifetime(observation) {}
        XCTAssertEqual(view.mapboxMap.cameraState.center.latitude, 30, accuracy: 0.0001)
        XCTAssertEqual(view.mapboxMap.cameraState.padding.bottom, 180)

        view.mapboxMap.setCamera(to: CameraOptions(center: .init(latitude: 20, longitude: 90), zoom: 10))
        component.selection = .point("water")
        component.scrubMarker = MapScrubMarker(coordinate: focus)
        component.fitRequest += 1 // Legacy requests cannot override explicit camera ownership.
        coordinator.update(component)
        XCTAssertEqual(view.mapboxMap.cameraState.center.latitude, 20, accuracy: 0.0001)
        component.cameraRequest = MapCameraRequest(id: 1, target: .point("water"), padding: padding)
        coordinator.update(component)
        XCTAssertEqual(view.mapboxMap.cameraState.center.latitude, 45.906, accuracy: 0.01)
        component.cameraRequest = MapCameraRequest(id: 2, target: .coordinates([focus], maxZoom: 15), padding: padding)
        coordinator.update(component)
        XCTAssertEqual(view.mapboxMap.cameraState.center.latitude, focus.latitude, accuracy: 0.0001)
        XCTAssertEqual(view.mapboxMap.cameraState.center.longitude, focus.longitude, accuracy: 0.0001)
        XCTAssertLessThanOrEqual(view.mapboxMap.cameraState.zoom, 15)
    }

    func testTerrainLevelsApplyToRenderingCameraActionsAndStyleReload() async throws {
        XCTAssertEqual(MapDisplayOptions().terrainLevel, .normal)
        let view = try await loadedMap()
        var component = MapboxOutdoorMap(scene: try fixture(), options: .init(showsTerrain: true))
        let coordinator = component.makeCoordinator()
        coordinator.attach(view)
        defer { coordinator.detach() }

        func reloadLocalStyle(_ background: String) async {
            let loaded = expectation(description: "Terrain level style restored \(background)")
            let observation = view.mapboxMap.onStyleLoaded.observeNext { _ in loaded.fulfill() }
            view.mapboxMap.styleJSON = blankStyle.replacingOccurrences(of: "#DCE4E2", with: background)
            await fulfillment(of: [loaded], timeout: 10)
            withExtendedLifetime(observation) {}
        }

        func assertTerrain(_ exaggeration: Double, pitch: Double,
                           file: StaticString = #filePath, line: UInt = #line) {
            let terrain: StylePropertyValue = view.mapboxMap.terrainProperty("exaggeration")
            XCTAssertEqual((terrain.value as? NSNumber)?.doubleValue ?? -1, exaggeration,
                           accuracy: 0.001, file: file, line: line)
            XCTAssertEqual(Double(view.mapboxMap.cameraState.pitch), pitch, accuracy: 0.001, file: file, line: line)
        }

        // First visible camera, including the component's initial automatic fit.
        await reloadLocalStyle("#FDFDFD")
        assertTerrain(1, pitch: 40)

        // Changing just the level must update both terrain geometry and the current camera.
        component.options.terrainLevel = .enhanced
        coordinator.update(component)
        assertTerrain(1.5, pitch: 60)
        view.mapboxMap.setCamera(to: CameraOptions(pitch: 17))
        component.fitRequest += 1
        coordinator.update(component)
        assertTerrain(1.5, pitch: 60)
        component.location = GuidanceLocation(coordinate: try MapCoordinate(latitude: 45.91, longitude: 6.946),
                                              horizontalAccuracy: 8)
        view.mapboxMap.setCamera(to: CameraOptions(pitch: 23))
        component.locationFocusRequest += 1
        coordinator.update(component)
        assertTerrain(1.5, pitch: 60)

        // Style restoration resets the pitch without needing fresh fit/focus requests.
        view.mapboxMap.setCamera(to: CameraOptions(pitch: 19))
        await reloadLocalStyle("#FCFCFC")
        assertTerrain(1.5, pitch: 60)

        // A reload after fit/location requests have already been consumed must keep the level.
        component.options.baseMap = .satellite
        coordinator.update(component)
        await reloadLocalStyle("#FAFAFA")
        assertTerrain(1.5, pitch: 60)

        // The early-return basemap branch must not lose a level changed in the same update.
        component.options.baseMap = .standard
        component.options.terrainLevel = .normal
        coordinator.update(component)
        await reloadLocalStyle("#F8F8F8")
        assertTerrain(1, pitch: 40)
        component.options.baseMap = .topographic
        component.options.terrainLevel = .enhanced
        coordinator.update(component)
        await reloadLocalStyle("#F6F6F6")
        assertTerrain(1.5, pitch: 60)

        // 2D flattens all camera actions without discarding the selected 3D level.
        component.options.showsTerrain = false
        coordinator.update(component)
        XCTAssertEqual(view.mapboxMap.cameraState.pitch, 0)
        let removed: StylePropertyValue = view.mapboxMap.terrainProperty("source")
        XCTAssertFalse(removed.value as? String == MapSceneRenderer.demSource)
        XCTAssertEqual(component.options.terrainLevel, .enhanced)
        component.fitRequest += 1
        coordinator.update(component)
        XCTAssertEqual(view.mapboxMap.cameraState.pitch, 0)
        component.locationFocusRequest += 1
        coordinator.update(component)
        XCTAssertEqual(view.mapboxMap.cameraState.pitch, 0)
        component.options.showsTerrain = true
        coordinator.update(component)
        assertTerrain(1.5, pitch: 60)
    }

    func testGuidanceLocationLayersClearAndRestoreWithoutMovingOriginalKML() async throws {
        let view = try await loadedMap()
        let renderer = MapSceneRenderer(map: view.mapboxMap)
        let scene = try fixture()
        let position = GuidanceLocation(coordinate: try MapCoordinate(latitude: 45.91, longitude: 6.946),
                                        horizontalAccuracy: 8, courseDegrees: 90)
        try renderer.render(scene: scene, options: .init(), selection: nil, location: position)
        XCTAssertTrue(view.mapboxMap.layerExists(withId: "outdoor-user-location"))
        XCTAssertTrue(view.mapboxMap.layerExists(withId: "outdoor-user-accuracy"))
        XCTAssertEqual(view.mapboxMap.layerPropertyValue(for: "outdoor-user-location", property: "visibility") as? String, "visible")
        XCTAssertEqual(MapSceneRenderer.trackFeatures(scene).first?.identifier, .string("route-a"))
        let feature = try XCTUnwrap(MapSceneRenderer.locationFeatures(position).first)
        if case .point(let point) = feature.geometry {
            XCTAssertEqual(point.coordinates.longitude, 6.946)
            XCTAssertEqual(point.coordinates.latitude, 45.91)
        } else { XCTFail("Expected actual location without snapping") }
        try renderer.render(scene: scene, options: .init(), selection: nil, location: nil)
        XCTAssertEqual(view.mapboxMap.layerPropertyValue(for: "outdoor-user-location", property: "visibility") as? String, "none")
        let reloaded = expectation(description: "Location style reloaded")
        let observation = view.mapboxMap.onStyleLoaded.observeNext { _ in reloaded.fulfill() }
        view.mapboxMap.styleJSON = blankStyle.replacingOccurrences(of: "#DCE4E2", with: "#FFFFFF")
        await fulfillment(of: [reloaded], timeout: 10)
        withExtendedLifetime(observation) {}
        XCTAssertFalse(view.mapboxMap.layerExists(withId: "outdoor-user-location"))
        renderer.styleDidReload()
        try renderer.render(scene: scene, options: .init(), selection: .track("route-a"), location: position)
        XCTAssertEqual(view.mapboxMap.layerPropertyValue(for: "outdoor-user-location", property: "visibility") as? String, "visible")
    }

    func testInstallsActualSDKLayersAndHonorsVisibilityAndSelection() async throws {
        let view = try await loadedMap()
        let renderer = MapSceneRenderer(map: view.mapboxMap)
        try renderer.render(scene: fixture(), options: .init(showsContours: false, showsHeatmap: true), selection: .point("water"))
        XCTAssertTrue(view.mapboxMap.sourceExists(withId: MapSceneRenderer.tracks))
        XCTAssertTrue(view.mapboxMap.layerExists(withId: MapSceneRenderer.pinLayer))
        let contour = view.mapboxMap.layerPropertyValue(for: MapSceneRenderer.contourLayer, property: "visibility")
        let heat = view.mapboxMap.layerPropertyValue(for: MapSceneRenderer.heatLayer, property: "visibility")
        XCTAssertEqual(contour as? String, "none")
        XCTAssertEqual(heat as? String, "visible")
        let filter = view.mapboxMap.layerPropertyValue(for: "outdoor-pin-selection", property: "filter")
        XCTAssertTrue(String(describing: filter).contains("water"))
    }

    func testHikingStyleKeepsReliefAndDualStrokeRouteReadable() async throws {
        let view = try await loadedMap()
        let renderer = MapSceneRenderer(map: view.mapboxMap)
        try renderer.render(scene: fixture(), options: .init(showsHeatmap: true), selection: nil)
        XCTAssertTrue(view.mapboxMap.layerExists(withId: "outdoor-hillshade"))
        let opacity = view.mapboxMap.layerPropertyValue(for: MapSceneRenderer.contourLayer, property: "line-opacity")
        XCTAssertLessThanOrEqual((opacity as? NSNumber)?.doubleValue ?? 1, 0.4)
        let outer = try view.mapboxMap.layer(withId: "outdoor-route-casing", type: LineLayer.self)
        let inner = try view.mapboxMap.layer(withId: MapSceneRenderer.routeLayer, type: LineLayer.self)
        XCTAssertTrue(String(describing: outer.lineColor).contains("casingColor"))
        XCTAssertTrue(String(describing: inner.lineColor).contains("color"))
        let features = MapSceneRenderer.trackFeatures(try fixture())
        XCTAssertEqual(features.first?.properties?["casingColor"], .string("#AC6BD8"))
        XCTAssertEqual(features.first?.properties?["color"], .string("#FFD454"))
        let ids = view.mapboxMap.allLayerIdentifiers.map(\.id)
        XCTAssertLessThan(try XCTUnwrap(ids.firstIndex(of: MapSceneRenderer.heatLayer)),
                          try XCTUnwrap(ids.firstIndex(of: MapSceneRenderer.routeLayer)))
        try renderer.render(scene: fixture(), options: .init(showsTerrain: true), selection: .track("route-a"))
        XCTAssertTrue(view.mapboxMap.layerExists(withId: "outdoor-hillshade"))
        let source: StylePropertyValue = view.mapboxMap.terrainProperty("source")
        XCTAssertEqual(source.value as? String, "outdoor-dem")
        try renderer.render(scene: fixture(), options: .init(baseMap: .satellite, showsTerrain: true), selection: nil)
        XCTAssertEqual(view.mapboxMap.layerPropertyValue(for: "outdoor-hillshade", property: "visibility") as? String, "none")
    }

    func testSceneReplacementAndStyleReloadRestoreOverlayState() async throws {
        let view = try await loadedMap()
        let renderer = MapSceneRenderer(map: view.mapboxMap)
        let scene = try fixture()
        try renderer.render(scene: scene, options: .init(showsHeatmap: true), selection: .track("route-b"))
        let replacement = try MapScene(points: scene.points)
        try renderer.render(scene: replacement, options: .init(), selection: nil)
        XCTAssertEqual(MapSceneRenderer.trackFeatures(replacement).count, 0)
        let loaded = expectation(description: "Style reloaded")
        let observation = view.mapboxMap.onStyleLoaded.observeNext { _ in loaded.fulfill() }
        view.mapboxMap.styleJSON = blankStyle.replacingOccurrences(of: "#DCE4E2", with: "#FFFFFF")
        await fulfillment(of: [loaded], timeout: 10)
        withExtendedLifetime(observation) {}
        XCTAssertFalse(view.mapboxMap.layerExists(withId: MapSceneRenderer.routeLayer))
        renderer.styleDidReload()
        try renderer.render(scene: scene, options: .init(showsHeatmap: true, showsTerrain: true), selection: .track("route-b"))
        XCTAssertTrue(view.mapboxMap.layerExists(withId: MapSceneRenderer.routeLayer))
        XCTAssertTrue(view.mapboxMap.layerExists(withId: MapSceneRenderer.pinLayer))
        let source: StylePropertyValue = view.mapboxMap.terrainProperty("source")
        XCTAssertEqual(source.value as? String, "outdoor-dem")
        let width = view.mapboxMap.layerPropertyValue(for: MapSceneRenderer.routeLayer, property: "line-width")
        XCTAssertTrue(String(describing: width).contains("route-b"))
        try renderer.render(scene: scene, options: .init(showsTerrain: false), selection: nil)
        let removed: StylePropertyValue = view.mapboxMap.terrainProperty("source")
        XCTAssertFalse(removed.value as? String == "outdoor-dem")
    }

    private func loadedMap() async throws -> MapView {
        if let scene = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).first {
            testWindow = UIWindow(windowScene: scene)
        } else { testWindow = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 600)) }
        testWindow?.rootViewController = UIViewController()
        testWindow?.makeKeyAndVisible()
        let view = MapView(frame: CGRect(x: 0, y: 0, width: 390, height: 600),
            mapInitOptions: MapInitOptions(cameraOptions: CameraOptions(center: .init(latitude: 45.906, longitude: 6.94), zoom: 13), styleURI: nil))
        let loaded = expectation(description: "Local style loaded")
        let observation = view.mapboxMap.onStyleLoaded.observeNext { _ in loaded.fulfill() }
        testWindow?.rootViewController?.view.addSubview(view)
        view.mapboxMap.styleJSON = blankStyle
        await fulfillment(of: [loaded], timeout: 10)
        withExtendedLifetime(observation) {}
        return view
    }

    override func tearDown() {
        testWindow?.isHidden = true
        testWindow = nil
        super.tearDown()
    }

    private func fixture() throws -> MapScene {
        let a = try MapCoordinate(latitude: 45.906, longitude: 6.94, elevation: 2000)
        let b = try MapCoordinate(latitude: 45.907, longitude: 6.95)
        let c = try MapCoordinate(latitude: 45.92, longitude: 6.96)
        let d = try MapCoordinate(latitude: 45.925, longitude: 6.97)
        return try MapScene(tracks: [MapTrack(id: "route-a", name: "A", coordinates: [a, b]),
                                    MapTrack(id: "route-b", name: "B", coordinates: [c, d])],
                            points: [MapPoint(id: "water", name: "Water", coordinate: a, style: MapPinStyle(colorHex: "#489CFF", symbolName: "drop.fill"))],
                            heatPoints: [MapHeatPoint(id: "heat-a", coordinate: b, weight: 0.75)])
    }
}
