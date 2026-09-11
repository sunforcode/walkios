import SwiftUI
import WalkData
import WalkDesignSystem

struct RouteMapPositionProjection: Equatable {
    let x: Double
    let y: Double
}

struct RouteMapTrackProjection: Equatable {
    let positions: [RouteMapPositionProjection]
}

enum RouteMapPointCategory: Equatable {
    case keyPoint
    case interest
    case camp
    case overnight
    case water
    case supply

    var glyph: String {
        switch self {
        case .keyPoint: "关"
        case .interest: "景"
        case .camp: "营"
        case .overnight: "宿"
        case .water: "水"
        case .supply: "补"
        }
    }

    var color: Color {
        switch self {
        case .keyPoint: AppColors.mapWaypoint
        case .interest: AppColors.info
        case .camp: AppColors.statusCompleted
        case .overnight: AppColors.interactionPrimary
        case .water: AppColors.mapRoute
        case .supply: AppColors.warning
        }
    }
}

struct RouteMapPointProjection: Identifiable, Equatable {
    let id: String
    let name: String
    let category: RouteMapPointCategory
    let position: RouteMapPositionProjection
}

struct RouteMapPlaceLabelProjection: Identifiable, Equatable {
    let id: String
    let title: String
    let position: RouteMapPositionProjection
}

struct RouteMapProjection: Equatable {
    var track: RouteMapTrackProjection?
    let start: RouteMapPositionProjection
    let end: RouteMapPositionProjection
    var points: [RouteMapPointProjection]
    var placeLabels: [RouteMapPlaceLabelProjection]
    var activePointID: String? = nil
    var trackUnavailableMessage: String? = nil
}

extension RouteBusinessComponents {
    struct RouteMap: View {
        let projection: RouteMapProjection
        let onSelectPoint: (String) -> Void

        var body: some View {
            GeometryReader { geometry in
                ZStack {
                    terrainSurface

                    routeOverlay(size: geometry.size)
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel(projection.track == nil ? "路线轨迹不可用" : "路线轨迹示意")

                    ForEach(projection.placeLabels) { label in
                        Text(label.title)
                            .font(.micro)
                            .foregroundStyle(AppColors.textPrimary)
                            .padding(.horizontal, Spacing.sm)
                            .padding(.vertical, Spacing.xs)
                            .background(AppColors.surfaceControlOverlay, in: Capsule())
                            .overlay(Capsule().stroke(AppColors.borderOverlay, lineWidth: 1))
                            .position(point(for: label.position, size: geometry.size))
                            .accessibilityHidden(true)
                    }

                    terminalMarker(title: "起", color: AppColors.mapStart)
                        .position(point(for: projection.start, size: geometry.size))
                        .accessibilityLabel("路线起点")

                    terminalMarker(title: "终", color: AppColors.mapEnd)
                        .position(point(for: projection.end, size: geometry.size))
                        .accessibilityLabel("路线终点")

                    ForEach(projection.points) { pointProjection in
                        pointMarker(pointProjection)
                            .position(point(for: pointProjection.position, size: geometry.size))
                    }

                    if let message = routeNonEmpty(projection.trackUnavailableMessage) {
                        VStack {
                            InfoTag(
                                title: message,
                                systemImage: "exclamationmark.triangle",
                                tone: .overlay
                            )
                            .padding(.top, Spacing.lg)
                            Spacer()
                        }
                        .padding(.horizontal, Spacing.lg)
                    }
                }
                .clipped()
            }
            .background(AppColors.pageMiddle)
        }

        private var terrainSurface: some View {
            ZStack {
                LinearGradient(
                    colors: [AppColors.sceneNeutralHighlight, AppColors.pageMiddle, AppColors.pageBase],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                RouteMapTerrainShape()
                    .fill(AppColors.sceneForestMiddle.opacity(0.72))

                RouteMapWaterwayShape()
                    .stroke(
                        AppColors.info.opacity(0.32),
                        style: StrokeStyle(lineWidth: 18, lineCap: .round, lineJoin: .round)
                    )

                RouteMapRoadShape()
                    .stroke(
                        AppColors.textWeak.opacity(0.32),
                        style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round)
                    )

                VStack(spacing: Spacing.xs) {
                    HStack(spacing: Spacing.xs) {
                        building(width: 24, height: 18)
                        building(width: 16, height: 28)
                    }
                    HStack(spacing: Spacing.xs) {
                        building(width: 18, height: 22)
                        building(width: 28, height: 16)
                    }
                }
                .rotationEffect(.degrees(-8))
                .offset(x: 96, y: 118)
            }
            .accessibilityHidden(true)
        }

        private func building(width: CGFloat, height: CGFloat) -> some View {
            RoundedRectangle(cornerRadius: Radius.sm, style: .continuous)
                .fill(AppColors.surfaceElevated.opacity(0.62))
                .frame(width: width, height: height)
        }

        @ViewBuilder
        private func routeOverlay(size: CGSize) -> some View {
            if let track = projection.track, track.positions.count >= 2 {
                let path = routePath(track.positions, size: size)
                path.stroke(
                    AppColors.pageBase,
                    style: StrokeStyle(lineWidth: 11, lineCap: .round, lineJoin: .round)
                )
                path.stroke(
                    AppColors.mapRoute,
                    style: StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round)
                )
            }
        }

        private func terminalMarker(title: String, color: Color) -> some View {
            Text(title)
                .font(.microStrong)
                .foregroundStyle(AppColors.pageBase)
                .frame(width: 28, height: 28)
                .background(color, in: Circle())
                .overlay(Circle().stroke(AppColors.pageBase, lineWidth: 2))
                .frame(width: 44, height: 44)
        }

        private func pointMarker(_ point: RouteMapPointProjection) -> some View {
            let isSelected = projection.activePointID == point.id
            return Button {
                onSelectPoint(point.id)
            } label: {
                Text(point.category.glyph)
                    .font(.microStrong)
                    .foregroundStyle(AppColors.pageBase)
                    .frame(width: 28, height: 28)
                    .background(point.category.color, in: Circle())
                    .overlay {
                        Circle()
                            .stroke(
                                isSelected ? AppColors.interactionPrimary : AppColors.pageBase,
                                lineWidth: isSelected ? 3 : 2
                            )
                    }
                    .scaleEffect(isSelected ? 1.34 : 1)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("查看\(point.name)")
            .accessibilityAddTraits(isSelected ? .isSelected : [])
        }

        private func routePath(_ positions: [RouteMapPositionProjection], size: CGSize) -> Path {
            Path { path in
                guard let first = positions.first else { return }
                path.move(to: point(for: first, size: size))
                positions.dropFirst().forEach { path.addLine(to: point(for: $0, size: size)) }
            }
        }

        private func point(for position: RouteMapPositionProjection, size: CGSize) -> CGPoint {
            CGPoint(
                x: size.width * CGFloat(min(max(position.x, 0), 1)),
                y: size.height * CGFloat(min(max(position.y, 0), 1))
            )
        }
    }
}

private struct RouteMapTerrainShape: Shape {
    func path(in rect: CGRect) -> Path {
        Path { path in
            path.move(to: CGPoint(x: rect.minX, y: rect.height * 0.16))
            path.addCurve(
                to: CGPoint(x: rect.maxX, y: rect.height * 0.42),
                control1: CGPoint(x: rect.width * 0.35, y: rect.height * 0.02),
                control2: CGPoint(x: rect.width * 0.68, y: rect.height * 0.55)
            )
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
            path.closeSubpath()
        }
    }
}

private struct RouteMapWaterwayShape: Shape {
    func path(in rect: CGRect) -> Path {
        Path { path in
            path.move(to: CGPoint(x: rect.width * 0.08, y: rect.height * 0.18))
            path.addCurve(
                to: CGPoint(x: rect.width * 0.90, y: rect.height * 0.86),
                control1: CGPoint(x: rect.width * 0.58, y: rect.height * 0.28),
                control2: CGPoint(x: rect.width * 0.35, y: rect.height * 0.76)
            )
        }
    }
}

private struct RouteMapRoadShape: Shape {
    func path(in rect: CGRect) -> Path {
        Path { path in
            path.move(to: CGPoint(x: rect.width * 0.02, y: rect.height * 0.72))
            path.addCurve(
                to: CGPoint(x: rect.width * 0.96, y: rect.height * 0.18),
                control1: CGPoint(x: rect.width * 0.32, y: rect.height * 0.65),
                control2: CGPoint(x: rect.width * 0.72, y: rect.height * 0.31)
            )
        }
    }
}

#if DEBUG
#Preview("RouteMap.default") {
    RouteBusinessComponents.RouteMap(
        projection: BusinessComponentPreviewFixtures.routeMap,
        onSelectPoint: { _ in }
    )
    .frame(width: 390, height: 700)
}

#Preview("RouteMap.selected") {
    RouteBusinessComponents.RouteMap(
        projection: BusinessComponentPreviewFixtures.routeMapSelected,
        onSelectPoint: { _ in }
    )
    .frame(width: 390, height: 700)
}

#Preview("RouteMap.trackUnavailable") {
    RouteBusinessComponents.RouteMap(
        projection: BusinessComponentPreviewFixtures.routeMapUnavailable,
        onSelectPoint: { _ in }
    )
    .frame(width: 390, height: 700)
}
#endif
