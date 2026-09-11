import SwiftUI
import WalkData
import WalkDesignSystem

struct RouteElevationSampleProjection: Identifiable, Equatable {
    let id: String
    let distance: Double
    let elevation: Double
}

struct ElevationProfileProjection: Equatable {
    let minimumLabel: String
    let maximumLabel: String
    let minimumElevation: Double
    let maximumElevation: Double
    let samples: [RouteElevationSampleProjection]
}

extension RouteBusinessComponents {
    struct ElevationProfile: View {
        let projection: ElevationProfileProjection
        var isCompact = false

        var body: some View {
            RouteBusinessSection(title: "海拔剖面") {
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    Text("\(projection.minimumLabel) — \(projection.maximumLabel)")
                        .font(.appCaption)
                        .foregroundStyle(AppColors.interactionPrimary)
                        .fixedSize(horizontal: false, vertical: true)

                    GeometryReader { geometry in
                        let points = chartPoints(in: geometry.size)
                        ZStack {
                            area(points: points, size: geometry.size)
                                .fill(AppColors.interactionPrimary.opacity(0.10))
                            line(points: points)
                                .stroke(
                                    AppColors.interactionPrimary,
                                    style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round)
                                )
                            if let last = points.last {
                                Circle()
                                    .fill(AppColors.pageBase)
                                    .overlay(Circle().stroke(AppColors.interactionPrimary, lineWidth: 2))
                                    .frame(width: Spacing.sm, height: Spacing.sm)
                                    .position(last)
                            }
                        }
                    }
                    .frame(height: isCompact ? 60 : 76)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("海拔从 \(projection.minimumLabel) 到 \(projection.maximumLabel)")
                }
            }
        }

        private func chartPoints(in size: CGSize) -> [CGPoint] {
            guard let firstDistance = projection.samples.first?.distance,
                  let lastDistance = projection.samples.last?.distance else { return [] }
            let distanceSpan = max(lastDistance - firstDistance, 0)
            let elevationSpan = max(projection.maximumElevation - projection.minimumElevation, 0)
            return projection.samples.map { sample in
                let x = distanceSpan > 0 ? (sample.distance - firstDistance) / distanceSpan : 0
                let y = elevationSpan > 0
                    ? (sample.elevation - projection.minimumElevation) / elevationSpan
                    : 0.5
                return CGPoint(x: size.width * CGFloat(x), y: size.height * CGFloat(1 - y))
            }
        }

        private func area(points: [CGPoint], size: CGSize) -> Path {
            Path { path in
                guard let first = points.first else { return }
                path.move(to: CGPoint(x: first.x, y: size.height))
                path.addLine(to: first)
                points.dropFirst().forEach { path.addLine(to: $0) }
                if let last = points.last {
                    path.addLine(to: CGPoint(x: last.x, y: size.height))
                }
                path.closeSubpath()
            }
        }

        private func line(points: [CGPoint]) -> Path {
            Path { path in
                guard let first = points.first else { return }
                path.move(to: first)
                points.dropFirst().forEach { path.addLine(to: $0) }
            }
        }
    }
}

#if DEBUG
#Preview("ElevationProfile.default") {
    BusinessComponentPreviewHost {
        RouteBusinessComponents.ElevationProfile(
            projection: BusinessComponentPreviewFixtures.elevationProfile
        )
    }
}

#Preview("ElevationProfile.compact") {
    BusinessComponentPreviewHost {
        RouteBusinessComponents.ElevationProfile(
            projection: BusinessComponentPreviewFixtures.elevationProfileCompact,
            isCompact: true
        )
    }
}
#endif
