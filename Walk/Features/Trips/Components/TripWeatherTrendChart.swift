import SwiftUI
import WalkData
import WalkDesignSystem

/// 业务组合 TripWeatherTrendChart（L2c）：逐日最高温/最低温/降水概率趋势图。
/// 视觉合同见 docs/ui/components/business/composites/trip-weather-trend-chart/spec.md。
/// 冻结原型 SVG viewBox 为 288 × 112。
struct TripWeatherTrendSampleProjection: Equatable, Identifiable {
    let id: String
    let date: String
    let low: Double?
    let high: Double?
    let rain: Double?
}

extension TripBusinessComponents {
    struct TripWeatherTrendChart: View {
        let samples: [TripWeatherTrendSampleProjection]

        var body: some View {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                legend

                ChartCanvas(samples: samples)
                    .aspectRatio(288 / 78, contentMode: .fit)
                    .accessibilityLabel("\(samples.count) 日气温与降水趋势")

                HStack(alignment: .center, spacing: 0) {
                    ForEach(samples) { sample in
                        Text(sample.date)
                            .font(.micro)
                            .foregroundStyle(AppColors.textWeak)
                            .lineLimit(1)
                            .minimumScaleFactor(0.5)
                            .frame(maxWidth: .infinity)
                    }
                }
            }
            .accessibilityElement(children: .contain)
        }

        private var legend: some View {
            HStack(spacing: Spacing.md) {
                legendItem(color: AppColors.interactionPrimary, label: "最高温")
                legendItem(color: AppColors.info, label: "最低温")
                legendItem(color: AppColors.mapWaypoint, label: "降水")
            }
        }

        private func legendItem(color: Color, label: String) -> some View {
            HStack(spacing: 4) {
                RoundedRectangle(cornerRadius: 1)
                    .fill(color)
                    .frame(width: 10, height: 3)
                Text(label)
                    .font(.micro)
                    .foregroundStyle(AppColors.textSecondary)
            }
        }
    }

    private struct ChartCanvas: View {
        let samples: [TripWeatherTrendSampleProjection]

        var body: some View {
            GeometryReader { proxy in
                ZStack {
                    guideLines(width: proxy.size.width, height: proxy.size.height)

                    rainBars(width: proxy.size.width, height: proxy.size.height)

                    temperatureLine(
                        keyPath: { $0.high },
                        color: AppColors.interactionPrimary,
                        width: proxy.size.width,
                        height: proxy.size.height
                    )

                    temperatureLine(
                        keyPath: { $0.low },
                        color: AppColors.info,
                        width: proxy.size.width,
                        height: proxy.size.height
                    )
                }
            }
        }

        private var temperatureSpan: (min: Double, max: Double) {
            let values = samples.flatMap { [$0.low, $0.high].compactMap { $0 } }
            guard let lowest = values.min(), let highest = values.max(), highest > lowest else {
                return (0, 1)
            }
            return (lowest, highest)
        }

        private func xCenter(_ index: Int) -> CGFloat {
            guard samples.count > 1 else { return 0.5 }
            return CGFloat(index) / CGFloat(samples.count - 1)
        }

        private func yTemperature(_ value: Double, height: CGFloat) -> CGFloat {
            let span = temperatureSpan
            let fraction = (value - span.min) / (span.max - span.min)
            // 上下各留 10% 余量，高温在上。
            return height * (0.9 - 0.8 * CGFloat(fraction))
        }

        private func guideLines(width: CGFloat, height: CGFloat) -> some View {
            Path { path in
                for fraction in [0.1, 0.5, 0.9] {
                    let y = height * fraction
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addLine(to: CGPoint(x: width, y: y))
                }
            }
            .stroke(AppColors.surfaceDivider, lineWidth: 1)
            .accessibilityHidden(true)
        }

        private func rainBars(width: CGFloat, height: CGFloat) -> some View {
            ForEach(Array(samples.enumerated()), id: \.element.id) { index, sample in
                if let rain = sample.rain {
                    let barWidth: CGFloat = 18
                    let x = max(0, min(width - barWidth, xCenter(index) * width - barWidth / 2))
                    let barHeight = max(2, height * CGFloat(min(1, max(0, rain))))
                    RoundedRectangle(cornerRadius: 2)
                        .fill(AppColors.mapWaypoint.opacity(0.55))
                        .frame(width: barWidth, height: barHeight)
                        .position(
                            x: x + barWidth / 2,
                            y: height - barHeight / 2
                        )
                        .accessibilityHidden(true)
                }
            }
        }

        private func temperatureLine(
            keyPath: (TripWeatherTrendSampleProjection) -> Double?,
            color: Color,
            width: CGFloat,
            height: CGFloat
        ) -> some View {
            let points = samples.enumerated().compactMap { index, sample -> CGPoint? in
                keyPath(sample).map { CGPoint(x: xCenter(index) * width, y: yTemperature($0, height: height)) }
            }
            return ZStack {
                if points.count > 1 {
                    Path { path in
                        path.move(to: points[0])
                        for point in points.dropFirst() {
                            path.addLine(to: point)
                        }
                    }
                    .stroke(color, style: StrokeStyle(lineWidth: 1.5, lineJoin: .round))
                    .accessibilityHidden(true)
                }
                ForEach(Array(points.enumerated()), id: \.offset) { _, point in
                    Circle()
                        .fill(color)
                        .frame(width: 6, height: 6)
                        .position(point)
                        .accessibilityHidden(true)
                }
            }
        }
    }
}

#if DEBUG
#Preview("TripWeatherTrendChart.default") {
    BusinessComponentPreviewHost {
        TripBusinessComponents.TripWeatherTrendChart(
            samples: [
                TripWeatherTrendSampleProjection(id: "d1", date: "09-07", low: 8, high: 16, rain: 0.2),
                TripWeatherTrendSampleProjection(id: "d2", date: "09-08", low: 6, high: 14, rain: 0.45),
                TripWeatherTrendSampleProjection(id: "d3", date: "09-09", low: 5, high: 12, rain: 0.1),
                TripWeatherTrendSampleProjection(id: "d4", date: "09-10", low: 4, high: 15, rain: 0.05),
                TripWeatherTrendSampleProjection(id: "d5", date: "09-11", low: 7, high: 17, rain: 0.6),
            ]
        )
        .padding(Spacing.lg)
    }
}

#Preview("TripWeatherTrendChart.sparse") {
    BusinessComponentPreviewHost {
        TripBusinessComponents.TripWeatherTrendChart(
            samples: [
                TripWeatherTrendSampleProjection(id: "d1", date: "09-07", low: 8, high: 16, rain: 0.2),
                TripWeatherTrendSampleProjection(id: "d3", date: "09-09", low: 5, high: 12, rain: nil),
                TripWeatherTrendSampleProjection(id: "d4", date: "09-10", low: nil, high: 15, rain: 0.05),
            ]
        )
        .padding(Spacing.lg)
    }
}
#endif
