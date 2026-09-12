import SwiftUI
import WalkData
import WalkDesignSystem

/// 纯地图划分口径：分日（行程规划单位）与分段（路线物理切分单位）互斥。
enum RouteDivisionKind: Equatable {
    case day
    case segment
}

/// 稳定划分色：同一分日/分段在地图轨迹、海拔曲线区间与信息卡标题条使用同一颜色。
enum RouteDivisionPalette {
    static let hexValues = ["2F6FED", "E8830C", "2E9E5B", "7A4FD0", "D04F8C", "0E9BA8"]

    static func hex(for index: Int) -> String {
        hexValues[max(0, index) % hexValues.count]
    }
}

/// 单个分日/分段在纯地图下的划分投影。`startDistance`/`endDistance` 为全程累计距离，
/// 只在调用方提供可靠范围事实且能与海拔剖面累计距离对应时给出；缺失时不参与曲线选中高亮。
struct RouteDivisionSpanProjection: Identifiable, Equatable {
    let id: String
    let label: String
    let title: String?
    let colorHex: String
    let startDistance: Double?
    let endDistance: Double?
}

struct RouteMapDockProjection: Equatable {
    var elevation: ElevationProfileProjection?
    let daySpans: [RouteDivisionSpanProjection]
    let segmentSpans: [RouteDivisionSpanProjection]

    var hasBothDivisions: Bool {
        !daySpans.isEmpty && !segmentSpans.isEmpty
    }

    func spans(for division: RouteDivisionKind) -> [RouteDivisionSpanProjection] {
        switch division {
        case .day: daySpans
        case .segment: segmentSpans
        }
    }
}

extension RouteBusinessComponents {
    struct RouteMapDock: View {
        let projection: RouteMapDockProjection
        let activeDivision: RouteDivisionKind
        let activeSpanID: String?
        let onRestore: () -> Void
        let onSelectSpan: (String) -> Void
        let onScrub: (PublicRoutePathPosition?) -> Void

        @Environment(\.accessibilityReduceMotion) private var reduceMotion
        @State private var scrubDistance: Double?
        /// 本次拖动是否已判定为上划召回：触发后不再重复回调。
        @State private var isRestoreGesture = false

        private static let chartHeight: CGFloat = 160

        var body: some View {
            VStack(spacing: Spacing.xs) {
                restoreStrip

                chartContent
            }
            .padding(.top, Spacing.sm)
            .padding(.bottom, Spacing.xs)
            .background(
                // 完全不透明：半透明背景会让地图地名标注（如 S432 路牌）透过 dock，
                // 与 restoreStrip 的提示文字叠在一起。
                LinearGradient(
                    stops: [
                        .init(color: AppColors.pageBase.opacity(0), location: 0),
                        .init(color: AppColors.pageBase.opacity(1), location: 0.05),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                ),
                ignoresSafeAreaEdges: .bottom
            )
        }

        // MARK: - RestoreStrip（图例 + 上划唤回）

        /// 海拔曲线下方的通栏条：左侧划分图例（可点选中），上划或点按唤回信息面。
        private var restoreStrip: some View {
            HStack(spacing: Spacing.md) {
                legendChips
                Spacer()
                Text("上划唤回信息面")
                    .font(.micro)
                    .foregroundStyle(AppColors.textWeak)
            }
            .padding(.horizontal, Spacing.pageHorizontal)
            .padding(.vertical, Spacing.xs)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 6)
                    .onEnded { value in
                        if value.translation.height < -12 {
                            onRestore()
                        }
                    }
            )
            .onTapGesture(perform: onRestore)
            .accessibilityAction(named: Text("唤回信息面")) {
                onRestore()
            }
        }

        /// 划分图例：色点 + 标签，点击等价于曲线区间选中。
        @ViewBuilder
        private var legendChips: some View {
            let spans = projection.spans(for: activeDivision)
            if !spans.isEmpty {
                HStack(spacing: Spacing.md) {
                    ForEach(spans) { span in
                        legendChip(span: span)
                    }
                }
            }
        }

        private func legendChip(span: RouteDivisionSpanProjection) -> some View {
            let isSelected = activeSpanID == span.id
            return Button {
                onSelectSpan(span.id)
            } label: {
                HStack(spacing: 6) {
                    Circle()
                        .fill(Color(hex: span.colorHex) ?? AppColors.interactionPrimary)
                        .frame(width: 8, height: 8)
                    Text(span.label)
                        .font(.microStrong)
                        .foregroundStyle(AppColors.textPrimary)
                }
                .opacity(activeSpanID == nil || isSelected ? 1 : 0.45)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityAddTraits(isSelected ? .isSelected : [])
            .accessibilityLabel(span.title.map { "\(span.label) \($0)" } ?? span.label)
        }

        // MARK: - InteractiveElevationChart

        @ViewBuilder
        private var chartContent: some View {
            if let elevation = projection.elevation, !elevation.samples.isEmpty {
                GeometryReader { geometry in
                    chart(elevation: elevation, size: geometry.size)
                        .contentShape(Rectangle())
                        .gesture(scrubGesture(elevation: elevation, width: geometry.size.width))
                }
                .frame(height: Self.chartHeight)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("海拔走势，可滑动定位轨迹位置")
                .overlay(alignment: .topTrailing) {
                    Text(elevation.maximumLabel)
                        .font(.micro)
                        .foregroundStyle(AppColors.textWeak)
                        .padding(.trailing, Spacing.sm)
                        .padding(.top, Spacing.xs)
                }
                .overlay(alignment: .bottomTrailing) {
                    Text(elevation.minimumLabel)
                        .font(.micro)
                        .foregroundStyle(AppColors.textWeak)
                        .padding(.trailing, Spacing.sm)
                        .padding(.bottom, 20)
                }
                .overlay(alignment: .bottom) {
                    distanceTicks(elevation)
                }
            }
        }

        /// 底轴距离刻度：起点 / 中点 / 终点，均匀分布在全宽上。
        private func distanceTicks(_ elevation: ElevationProfileProjection) -> some View {
            let first = elevation.samples.first?.distance ?? 0
            let last = elevation.samples.last?.distance ?? 0
            func label(_ meters: Double) -> String {
                String(format: "%.1f km", meters / 1000)
            }
            return HStack {
                Text(label(first))
                Spacer()
                Text(label((first + last) / 2))
                Spacer()
                Text(label(last))
            }
            .font(.micro)
            .foregroundStyle(AppColors.textWeak)
            .padding(.horizontal, Spacing.md)
            .padding(.bottom, 2)
        }

        private func chart(elevation: ElevationProfileProjection, size: CGSize) -> some View {
            let samples = elevation.samples
            let basePoints = points(elevation: elevation, size: size)
            let spans = projection.spans(for: activeDivision)

            return ZStack {
                area(points: basePoints, size: size)
                    .fill(
                        LinearGradient(
                            colors: [
                                AppColors.interactionPrimary.opacity(0.45),
                                AppColors.interactionPrimary.opacity(0.20),
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                baseline(points: basePoints)
                    .stroke(
                        AppColors.interactionPrimary,
                        style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round)
                    )

                ForEach(spans.filter { $0.startDistance != nil && $0.endDistance != nil }) { span in
                    intervalLine(
                        samples: samples,
                        startDistance: span.startDistance ?? 0,
                        endDistance: span.endDistance ?? 0,
                        elevation: elevation,
                        size: size,
                        color: Color(hex: span.colorHex) ?? AppColors.interactionPrimary,
                        isSelected: activeSpanID == span.id
                    )
                    .onTapGesture { onSelectSpan(span.id) }
                }

                if let scrubDistance, let point = point(atDistance: scrubDistance, elevation: elevation, size: size) {
                    Circle()
                        .fill(AppColors.pageBase)
                        .overlay(Circle().stroke(AppColors.interactionPrimary, lineWidth: 2))
                        .frame(width: Spacing.md, height: Spacing.md)
                        .position(point)
                        .accessibilityHidden(true)
                }
            }
        }

        private func scrubGesture(elevation: ElevationProfileProjection, width: CGFloat) -> some Gesture {
            DragGesture(minimumDistance: 0, coordinateSpace: .local)
                .onChanged { value in
                    // 上划召回：纵向向上拖动优先于海拔 scrub，与「上划唤回信息面」提示一致；
                    // 否则 scrub 手势（minimumDistance 0）会吞掉整个图表区域的上划。
                    if value.translation.height < -12,
                       abs(value.translation.height) > abs(value.translation.width) {
                        guard !isRestoreGesture else { return }
                        isRestoreGesture = true
                        scrubDistance = nil
                        onScrub(nil)
                        onRestore()
                        return
                    }
                    guard let distance = distance(atX: value.location.x, width: width, elevation: elevation) else { return }
                    scrubDistance = distance
                    onScrub(pathPosition(atDistance: distance, elevation: elevation))
                }
                .onEnded { _ in
                    isRestoreGesture = false
                    scrubDistance = nil
                    onScrub(nil)
                }
        }

        // MARK: - Geometry helpers

        private func distanceSpan(_ elevation: ElevationProfileProjection) -> Double {
            guard let first = elevation.samples.first?.distance,
                  let last = elevation.samples.last?.distance else { return 0 }
            return max(last - first, 0)
        }

        private func elevationSpan(_ elevation: ElevationProfileProjection) -> Double {
            max(elevation.maximumElevation - elevation.minimumElevation, 0)
        }

        private func points(elevation: ElevationProfileProjection, size: CGSize) -> [CGPoint] {
            elevation.samples.map { sample in
                CGPoint(
                    x: xPosition(atDistance: sample.distance, elevation: elevation, width: size.width),
                    y: yPosition(atElevation: sample.elevation, elevation: elevation, height: size.height)
                )
            }
        }

        private func xPosition(atDistance distance: Double, elevation: ElevationProfileProjection, width: CGFloat) -> CGFloat {
            let span = distanceSpan(elevation)
            guard span > 0 else { return 0 }
            return width * CGFloat(min(max((distance - (elevation.samples.first?.distance ?? 0)) / span, 0), 1))
        }

        private func yPosition(atElevation value: Double, elevation: ElevationProfileProjection, height: CGFloat) -> CGFloat {
            let span = elevationSpan(elevation)
            let fraction = span > 0 ? (value - elevation.minimumElevation) / span : 0.5
            return height * CGFloat(1 - min(max(fraction, 0), 1))
        }

        private func distance(atX x: CGFloat, width: CGFloat, elevation: ElevationProfileProjection) -> Double? {
            guard let first = elevation.samples.first, let last = elevation.samples.last else { return nil }
            let span = distanceSpan(elevation)
            guard span > 0 else { return nil }
            // 图表按 GeometryReader 宽度全宽绘制，x 除以宽度后线性对应累计距离。
            let fraction = Double(min(max(x / max(width, 1), 0), 1))
            return first.distance + span * fraction
        }

        private func point(atDistance distance: Double, elevation: ElevationProfileProjection, size: CGSize) -> CGPoint? {
            guard let previous = elevation.samples.last(where: { $0.distance <= distance }),
                  let next = elevation.samples.first(where: { $0.distance >= distance }) else { return nil }
            let interpolation: Double
            if next.distance > previous.distance {
                interpolation = min(max((distance - previous.distance) / (next.distance - previous.distance), 0), 1)
            } else {
                interpolation = 0
            }
            let value = previous.elevation + (next.elevation - previous.elevation) * interpolation
            return CGPoint(
                x: xPosition(atDistance: distance, elevation: elevation, width: size.width),
                y: yPosition(atElevation: value, elevation: elevation, height: size.height)
            )
        }

        private func intervalLine(
            samples: [RouteElevationSampleProjection],
            startDistance: Double,
            endDistance: Double,
            elevation: ElevationProfileProjection,
            size: CGSize,
            color: Color,
            isSelected: Bool
        ) -> some View {
            let points = intervalPoints(
                samples: samples,
                startDistance: startDistance,
                endDistance: endDistance,
                elevation: elevation,
                size: size
            )
            let path = Path { path in
                guard let first = points.first else { return }
                path.move(to: first)
                points.dropFirst().forEach { path.addLine(to: $0) }
            }
            return path.stroke(
                color,
                style: StrokeStyle(
                    lineWidth: isSelected ? 5 : 3.5,
                    lineCap: .round,
                    lineJoin: .round
                )
            )
            .opacity(activeSpanID == nil || isSelected ? 1 : 0.3)
        }

        private func intervalPoints(
            samples: [RouteElevationSampleProjection],
            startDistance: Double,
            endDistance: Double,
            elevation: ElevationProfileProjection,
            size: CGSize
        ) -> [CGPoint] {
            var result: [CGPoint] = []
            guard let first = samples.first, let last = samples.last, endDistance > first.distance, startDistance < last.distance else {
                return result
            }
            var index = 0
            while index < samples.count {
                let sample = samples[index]
                let nextDistance = index + 1 < samples.count ? samples[index + 1].distance : sample.distance
                if nextDistance >= startDistance, sample.distance <= endDistance {
                    let entry = max(sample.distance, startDistance)
                    if entry <= nextDistance {
                        let fraction = nextDistance > sample.distance ? (entry - sample.distance) / (nextDistance - sample.distance) : 0
                        let value = sample.elevation
                            + (index + 1 < samples.count ? (samples[index + 1].elevation - sample.elevation) * fraction : 0)
                        result.append(CGPoint(
                            x: xPosition(atDistance: entry, elevation: elevation, width: size.width),
                            y: yPosition(atElevation: value, elevation: elevation, height: size.height)
                        ))
                    }
                    let exit = min(nextDistance, endDistance)
                    if exit > entry, index + 1 < samples.count {
                        let nextSample = samples[index + 1]
                        let fraction = nextDistance > sample.distance ? (exit - sample.distance) / (nextDistance - sample.distance) : 0
                        let value = sample.elevation + (nextSample.elevation - sample.elevation) * fraction
                        result.append(CGPoint(
                            x: xPosition(atDistance: exit, elevation: elevation, width: size.width),
                            y: yPosition(atElevation: value, elevation: elevation, height: size.height)
                        ))
                    }
                }
                if nextDistance > endDistance { break }
                index += 1
            }
            return result
        }

        private func pathPosition(atDistance distance: Double, elevation: ElevationProfileProjection) -> PublicRoutePathPosition? {
            let samples = elevation.samples
            guard let first = samples.first, let last = samples.last,
                  distance >= first.distance, distance <= last.distance else { return nil }
            if distance >= last.distance {
                return PublicRoutePathPosition(precedingPositionIndex: samples.count - 1, progressToNextPosition: nil)
            }
            for index in samples.indices.dropLast() {
                let sample = samples[index]
                let next = samples[index + 1]
                if distance <= next.distance {
                    let span = next.distance - sample.distance
                    let progress = span > 0 ? (distance - sample.distance) / span : 0
                    return PublicRoutePathPosition(
                        precedingPositionIndex: index,
                        progressToNextPosition: min(max(progress, 0), 0.999)
                    )
                }
            }
            return PublicRoutePathPosition(precedingPositionIndex: samples.count - 1, progressToNextPosition: nil)
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

        private func baseline(points: [CGPoint]) -> Path {
            Path { path in
                guard let first = points.first else { return }
                path.move(to: first)
                points.dropFirst().forEach { path.addLine(to: $0) }
            }
        }
    }
}

#if DEBUG
private extension RouteMapDockProjection {
    static let preview = RouteMapDockProjection(
        elevation: ElevationProfileProjection(
            minimumLabel: "1500 m",
            maximumLabel: "4850 m",
            minimumElevation: 1500,
            maximumElevation: 4850,
            samples: [
                RouteElevationSampleProjection(id: "s-1", distance: 0, elevation: 2720),
                RouteElevationSampleProjection(id: "s-2", distance: 6100, elevation: 3200),
                RouteElevationSampleProjection(id: "s-3", distance: 12500, elevation: 3520),
                RouteElevationSampleProjection(id: "s-4", distance: 18700, elevation: 3950),
                RouteElevationSampleProjection(id: "s-5", distance: 25000, elevation: 4850),
                RouteElevationSampleProjection(id: "s-6", distance: 31200, elevation: 4200),
                RouteElevationSampleProjection(id: "s-7", distance: 37500, elevation: 3400),
                RouteElevationSampleProjection(id: "s-8", distance: 42500, elevation: 1500),
            ]
        ),
        daySpans: [
            RouteDivisionSpanProjection(id: "d1", label: "D1", title: "第一天", colorHex: "2F6FED", startDistance: 0, endDistance: 18700),
            RouteDivisionSpanProjection(id: "d2", label: "D2", title: "第二天", colorHex: "E8830C", startDistance: 18700, endDistance: 42500),
        ],
        segmentSpans: [
            RouteDivisionSpanProjection(id: "s1", label: "S1", title: "进山段", colorHex: "2F6FED", startDistance: 0, endDistance: 12500),
            RouteDivisionSpanProjection(id: "s2", label: "S2", title: "翻垭口段", colorHex: "E8830C", startDistance: 12500, endDistance: 31200),
            RouteDivisionSpanProjection(id: "s3", label: "S3", title: "下降段", colorHex: "2E9E5B", startDistance: nil, endDistance: nil),
        ]
    )
}

#Preview("RouteMapDock.default") {
    BusinessComponentPreviewHost {
        RouteBusinessComponents.RouteMapDock(
            projection: .preview,
            activeDivision: .day,
            activeSpanID: nil,
            onRestore: {},
            onSelectSpan: { _ in },
            onScrub: { _ in }
        )
    }
}

#Preview("RouteMapDock.spanSelected") {
    BusinessComponentPreviewHost {
        RouteBusinessComponents.RouteMapDock(
            projection: .preview,
            activeDivision: .day,
            activeSpanID: "d2",
            onRestore: {},
            onSelectSpan: { _ in },
            onScrub: { _ in }
        )
    }
}
#endif
