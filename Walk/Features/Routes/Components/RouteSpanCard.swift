import SwiftUI
import WalkDesignSystem

struct RouteSpanMetricProjection: Equatable {
    let label: String
    let value: String
    let isEmphasized: Bool

    init(label: String, value: String, isEmphasized: Bool = false) {
        self.label = label
        self.value = value
        self.isEmphasized = isEmphasized
    }
}

/// RouteSpanCard 输入投影。分日与分段两种口径互斥，由 `kind` 决定可出现的条目行，
/// 字段缺失时对应条目整体省略，不使用占位文案。
struct RouteSpanCardProjection: Equatable {
    enum Kind: Equatable {
        case day(number: Int)
        case segment(order: Int)
    }

    let spanID: String
    let kind: Kind
    let colorHex: String
    let headerTitle: String
    let metrics: [RouteSpanMetricProjection]
    let endpoints: String?
    let position: String?
    let duration: String?
    let lifecycle: String?
    let trait: String?
    let caution: String?

    var accessibilityName: String {
        switch kind {
        case .day(let number): "分日 D\(number) 摘要"
        case .segment(let order): "分段 \(order) 摘要"
        }
    }
}

extension RouteBusinessComponents {
    struct RouteSpanCard: View {
        let projection: RouteSpanCardProjection

        var body: some View {
            VStack(alignment: .leading, spacing: Spacing.md) {
                header

                if !projection.metrics.isEmpty {
                    RouteWrapLayout(horizontalSpacing: Spacing.lg, verticalSpacing: Spacing.sm) {
                        ForEach(Array(projection.metrics.enumerated()), id: \.offset) { _, metric in
                            metricView(metric)
                        }
                    }
                }

                if let endpoints = projection.endpoints {
                    row(systemImage: "point.topleft.down.curvedto.point.bottomright.up", text: endpoints)
                }

                if let position = projection.position {
                    row(systemImage: "scope", text: position)
                }

                if let duration = projection.duration {
                    row(systemImage: "clock", text: duration)
                }

                switch projection.kind {
                case .day:
                    if let lifecycle = projection.lifecycle {
                        row(systemImage: "bed.double", text: lifecycle)
                    }
                case .segment:
                    if let trait = projection.trait {
                        row(systemImage: "mountain.2", text: trait)
                    }
                }

                if let caution = projection.caution {
                    row(systemImage: "exclamationmark.triangle", text: caution, tone: .warning)
                }
            }
            .padding(Spacing.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppColors.surfaceElevated.opacity(0.96), in: RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                    .stroke(AppColors.borderSubtle, lineWidth: 1)
            }
            .appShadow(AppShadow.compactAction)
            .accessibilityElement(children: .combine)
            .accessibilityLabel(projection.accessibilityName)
        }

        private var header: some View {
            HStack(spacing: Spacing.sm) {
                Capsule()
                    .fill(Color(hex: projection.colorHex) ?? AppColors.interactionPrimary)
                    .frame(width: 4, height: 18)
                Text(projection.headerTitle)
                    .font(.listTitle)
                    .foregroundStyle(AppColors.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }

        private func metricView(_ metric: RouteSpanMetricProjection) -> some View {
            VStack(alignment: .leading, spacing: 2) {
                Text(metric.label)
                    .font(.micro)
                    .foregroundStyle(AppColors.textWeak)
                Text(metric.value)
                    .font(.listTitle)
                    .foregroundStyle(metric.isEmphasized ? AppColors.interactionPrimary : AppColors.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }

        private func row(systemImage: String, text: String, tone: InfoTagTone = .neutral) -> some View {
            HStack(alignment: .top, spacing: Spacing.sm) {
                Image(systemName: systemImage)
                    .font(.appCaption)
                    .foregroundStyle(tone == .warning ? AppColors.warning : AppColors.textWeak)
                    .frame(width: 18)
                Text(text)
                    .font(.appCaption)
                    .foregroundStyle(tone == .warning ? AppColors.warning : AppColors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

extension Color {
    init?(hex: String) {
        let value = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        guard value.count == 6, let rgb = UInt64(value, radix: 16) else { return nil }
        self.init(
            red: Double((rgb >> 16) & 0xFF) / 255,
            green: Double((rgb >> 8) & 0xFF) / 255,
            blue: Double(rgb & 0xFF) / 255
        )
    }
}

#if DEBUG
extension RouteSpanCardProjection {
    static let day = RouteSpanCardProjection(
        spanID: "day-1",
        kind: .day(number: 1),
        colorHex: "2F6FED",
        headerTitle: "D1 · 下日乌且营地",
        metrics: [
            RouteSpanMetricProjection(label: "里程", value: "10.6 km"),
            RouteSpanMetricProjection(label: "累计爬升", value: "+420 m", isEmphasized: true),
            RouteSpanMetricProjection(label: "累计下降", value: "-180 m", isEmphasized: true),
            RouteSpanMetricProjection(label: "最高海拔", value: "3520 m"),
            RouteSpanMetricProjection(label: "最低海拔", value: "2720 m"),
        ],
        endpoints: "康定老榆林 → 下日乌且营地",
        position: "全程 0 – 10.6 km",
        duration: "参考用时 5 小时",
        lifecycle: "住宿：下日乌且营地",
        trait: nil,
        caution: "垭口段午后天气多变，注意保暖。"
    )

    static let segment = RouteSpanCardProjection(
        spanID: "segment-1",
        kind: .segment(order: 1),
        colorHex: "2F6FED",
        headerTitle: "S1 · 进山段",
        metrics: [
            RouteSpanMetricProjection(label: "里程", value: "8.4 km"),
            RouteSpanMetricProjection(label: "累计爬升", value: "+980 m", isEmphasized: true),
            RouteSpanMetricProjection(label: "累计下降", value: "-60 m", isEmphasized: true),
        ],
        endpoints: "康定老榆林 → 下日乌且营地",
        position: "距起点 0 km · 距终点 32.9 km",
        duration: "徒步参考时长 4 小时",
        lifecycle: nil,
        trait: "难度：进阶 · 地形：碎石坡",
        caution: nil
    )
}

#Preview("RouteSpanCard.day") {
    BusinessComponentPreviewHost {
        RouteBusinessComponents.RouteSpanCard(
            projection: RouteSpanCardProjection.day
        )
        .padding()
    }
}

#Preview("RouteSpanCard.segment") {
    BusinessComponentPreviewHost {
        RouteBusinessComponents.RouteSpanCard(
            projection: RouteSpanCardProjection.segment
        )
        .padding()
    }
}
#endif
