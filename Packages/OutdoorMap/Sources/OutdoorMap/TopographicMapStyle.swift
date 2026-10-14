import MapboxMaps

/// A subdued base owned by the component. Relief and user data are installed by MapSceneRenderer.
enum TopographicMapStyle {
    static let json = """
    {
      "version": 8,
      "name": "Outdoor gray relief",
      "glyphs": "mapbox://fonts/mapbox/{fontstack}/{range}.pbf",
      "sources": {
        "outdoor-base-streets": {"type": "vector", "url": "mapbox://mapbox.mapbox-streets-v8"}
      },
      "layers": [
        {"id": "outdoor-base-background", "type": "background", "paint": {"background-color": "#ECEDE9"}},
        {
          "id": "outdoor-base-water", "type": "fill", "source": "outdoor-base-streets", "source-layer": "water",
          "paint": {"fill-color": "#ABC9D0", "fill-opacity": 0.7}
        },
        {
          "id": "outdoor-base-waterway", "type": "line", "source": "outdoor-base-streets", "source-layer": "waterway",
          "minzoom": 10,
          "layout": {"line-cap": "round", "line-join": "round"},
          "paint": {"line-color": "#8DB4C1", "line-opacity": 0.65, "line-width": ["interpolate", ["linear"], ["zoom"], 10, 0.4, 15, 1.2]}
        },
        {
          "id": "outdoor-base-trails", "type": "line", "source": "outdoor-base-streets", "source-layer": "road",
          "minzoom": 11,
          "filter": ["match", ["get", "class"], ["path", "track", "pedestrian"], true, false],
          "layout": {"line-cap": "round", "line-join": "round"},
          "paint": {"line-color": "#AF9D92", "line-opacity": 0.55, "line-width": ["interpolate", ["linear"], ["zoom"], 11, 0.5, 15, 1.1], "line-dasharray": [2, 2]}
        }
      ]
    }
    """
}

extension MapDisplayOptions.BaseMap {
    var mapStyle: MapStyle {
        switch self {
        case .topographic: return MapStyle(json: TopographicMapStyle.json)
        case .standard: return .standard
        case .satellite: return .satelliteStreets
        }
    }
}
