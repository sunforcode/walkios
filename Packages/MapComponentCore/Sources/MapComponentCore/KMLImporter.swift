import Foundation
#if canImport(FoundationXML)
import FoundationXML
#endif

public enum KMLImportError: LocalizedError {
    case invalidDocument, fileTooLarge, unsupportedEncoding, externalEntities, invalidCoordinates, noGeometry
    case unsupportedGeometry(String)

    public var errorDescription: String? {
        switch self {
        case .invalidDocument: return "文件不是有效的 KML 文档。"
        case .fileTooLarge: return "实验组件支持不超过 20 MB 的 KML 文件。"
        case .unsupportedEncoding: return "请使用 UTF-8 编码的 KML 文件。"
        case .externalEntities: return "KML 不支持 DTD 或外部实体。"
        case .unsupportedGeometry(let name): return "暂不支持 KML 几何：\(name)。"
        case .invalidCoordinates: return "KML 中存在无效坐标，未导入该文件。"
        case .noGeometry: return "KML 中没有可显示的轨迹或点位。"
        }
    }
}

public struct KMLImporter {
    public init() {}
    public func parse(_ data: Data) throws -> MapScene {
        guard data.count <= 20 * 1024 * 1024 else { throw KMLImportError.fileTooLarge }
        guard let text = String(data: data, encoding: .utf8) else { throw KMLImportError.unsupportedEncoding }
        let uppercase = text.uppercased()
        guard !uppercase.contains("<!DOCTYPE"), !uppercase.contains("<!ENTITY") else {
            throw KMLImportError.externalEntities
        }
        let delegate = KMLParserDelegate()
        let parser = XMLParser(data: data)
        parser.shouldProcessNamespaces = true
        parser.shouldResolveExternalEntities = false
        parser.delegate = delegate
        let parsed = parser.parse()
        if let error = delegate.failure { throw error }
        guard parsed, delegate.isKML else { throw KMLImportError.invalidDocument }
        guard !delegate.tracks.isEmpty || !delegate.points.isEmpty else { throw KMLImportError.noGeometry }
        return try MapScene(tracks: delegate.tracks, points: delegate.points)
    }
}

private final class KMLParserDelegate: NSObject, XMLParserDelegate {
    struct Node { let name: String; var text = "" }
    struct Geometry { let kind: String; let depth: Int; var positions: [MapCoordinate] = [] }
    struct Placemark { let index: Int; let depth: Int; var name = ""; var geometries: [Geometry] = [] }
    var tracks: [MapTrack] = []
    var points: [MapPoint] = []
    var failure: Error?
    var isKML = false
    private var stack: [Node] = []
    private var placemark: Placemark?
    private var geometry: Geometry?
    private var placemarkCount = 0

    func parser(_ parser: XMLParser, didStartElement name: String, namespaceURI: String?, qualifiedName: String?, attributes: [String: String]) {
        if stack.isEmpty {
            isKML = name == "kml"
            if !isKML { fail(KMLImportError.invalidDocument, parser); return }
        }
        stack.append(Node(name: name))
        if ["Polygon", "Model", "GroundOverlay", "PhotoOverlay", "NetworkLink"].contains(name) {
            fail(KMLImportError.unsupportedGeometry(name), parser)
        } else if name == "Placemark" {
            guard placemark == nil else { fail(KMLImportError.invalidDocument, parser); return }
            placemarkCount += 1
            placemark = Placemark(index: placemarkCount, depth: stack.count)
        } else if ["LineString", "Point", "Track"].contains(name) {
            guard placemark != nil, geometry == nil else { fail(KMLImportError.invalidDocument, parser); return }
            geometry = Geometry(kind: name, depth: stack.count)
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        if !stack.isEmpty { stack[stack.count - 1].text += string }
    }

    func parser(_ parser: XMLParser, foundCDATA block: Data) {
        if let string = String(data: block, encoding: .utf8) { self.parser(parser, foundCharacters: string) }
    }

    func parser(_ parser: XMLParser, didEndElement name: String, namespaceURI: String?, qualifiedName: String?) {
        guard let node = stack.last, failure == nil else { return }
        do {
            if name == "name", stack.count == (placemark?.depth ?? -1) + 1 {
                placemark?.name = node.text.trimmingCharacters(in: .whitespacesAndNewlines)
            } else if name == "coordinates", let current = geometry, stack.count == current.depth + 1 {
                guard current.kind != "Track" else { throw KMLImportError.invalidCoordinates }
                geometry?.positions += try node.text.split(whereSeparator: \.isWhitespace).map { token in
                    try position(String(token).split(separator: ",", omittingEmptySubsequences: false))
                }
            } else if name == "coord", let current = geometry, current.kind == "Track", stack.count == current.depth + 1 {
                geometry?.positions.append(try position(node.text.split(whereSeparator: \.isWhitespace)))
            }
            if let current = geometry, stack.count == current.depth, name == current.kind {
                guard current.kind == "Point" ? current.positions.count == 1 : current.positions.count >= 2 else {
                    throw KMLImportError.invalidCoordinates
                }
                placemark?.geometries.append(current)
                geometry = nil
            }
            if name == "Placemark", let current = placemark {
                for (index, item) in current.geometries.enumerated() {
                    let id = "kml-p\(current.index)-g\(index)"
                    if item.kind == "Point" {
                        points.append(try MapPoint(id: id, name: current.name.isEmpty ? "点位 \(points.count + 1)" : current.name, coordinate: item.positions[0]))
                    } else {
                        tracks.append(try MapTrack(id: id, name: current.name.isEmpty ? "轨迹 \(tracks.count + 1)" : current.name, coordinates: item.positions))
                    }
                }
                placemark = nil
            }
        } catch { fail(error, parser) }
        stack.removeLast()
    }

    private func position(_ fields: [Substring]) throws -> MapCoordinate {
        guard fields.count == 2 || fields.count == 3,
              let longitude = Double(fields[0]), let latitude = Double(fields[1]) else {
            throw KMLImportError.invalidCoordinates
        }
        var elevation: Double?
        if fields.count == 3 {
            guard let value = Double(fields[2]) else { throw KMLImportError.invalidCoordinates }
            elevation = value
        }
        return try MapCoordinate(latitude: latitude, longitude: longitude, elevation: elevation)
    }

    private func fail(_ error: Error, _ parser: XMLParser) {
        if failure == nil { failure = error }
        parser.abortParsing()
    }
}
