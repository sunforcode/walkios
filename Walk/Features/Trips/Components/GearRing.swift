import SwiftUI
import WalkData
import WalkDesignSystem

/// 业务原子 GearRing（L2a）：单个装备圆环，环心为数值与标签。
/// 视觉合同见 docs/ui/components/business/atoms/gear-ring/spec.md。
struct GearRingProjection: Equatable {
    enum Tone: Equatable {
        case neutral
        case mint
        case orange
    }

    let value: Int
    let total: Int
    let tone: Tone
    let label: String

    var progress: Double {
        guard tone != .neutral, total > 0 else { return 1 }
        return min(1, max(0, Double(value) / Double(total)))
    }

    var toneColor: Color {
        switch tone {
        case .neutral: AppColors.textSecondary
        case .mint: AppColors.interactionPrimary
        case .orange: AppColors.warning
        }
    }
}

extension TripBusinessComponents {
    struct GearRing: View {
        let projection: GearRingProjection

        var body: some View {
            ZStack {
                Circle()
                    .strokeBorder(AppColors.borderSubtle, lineWidth: 1)

                RingShape(progress: projection.progress)
                    .fill(projection.toneColor)

                // 径向遮罩：内 54% 显示 surface、外部透明（对应原型 radial-gradient 54%）。
                Circle()
                    .fill(AppColors.surfacePrimary)
                    .scaleEffect(0.54)
                    .overlay {
                        Circle()
                            .strokeBorder(Color.white.opacity(0.025), lineWidth: 1)
                    }

                VStack(spacing: 0) {
                    Text("\(projection.value)")
                        .font(.bodyEmphasis)
                        .foregroundStyle(AppColors.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                    Text(projection.label)
                        .font(.micro)
                        .foregroundStyle(AppColors.textWeak)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                }
                .padding(4)
            }
            .aspectRatio(1, contentMode: .fit)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(projection.label) \(projection.value)")
        }
    }

    private struct RingShape: Shape {
        let progress: Double

        func path(in rect: CGRect) -> Path {
            var path = Path()
            path.addArc(
                center: CGPoint(x: rect.midX, y: rect.midY),
                radius: rect.width / 2,
                startAngle: .degrees(-90),
                endAngle: .degrees(-90 + 360 * progress),
                clockwise: false
            )
            path.addLine(to: CGPoint(x: rect.midX, y: rect.midY))
            path.closeSubpath()
            return path
        }
    }
}

#if DEBUG
#Preview("GearRing.default") {
    BusinessComponentPreviewHost {
        HStack(spacing: Spacing.md) {
            TripBusinessComponents.GearRing(
                projection: GearRingProjection(value: 8, total: 8, tone: .neutral, label: "清单")
            )
            TripBusinessComponents.GearRing(
                projection: GearRingProjection(value: 6, total: 8, tone: .mint, label: "已有")
            )
            TripBusinessComponents.GearRing(
                projection: GearRingProjection(value: 2, total: 8, tone: .orange, label: "未确认")
            )
        }
        .padding(Spacing.lg)
    }
}

#Preview("GearRing.zero") {
    BusinessComponentPreviewHost {
        HStack(spacing: Spacing.md) {
            TripBusinessComponents.GearRing(
                projection: GearRingProjection(value: 0, total: 0, tone: .neutral, label: "清单")
            )
            TripBusinessComponents.GearRing(
                projection: GearRingProjection(value: 0, total: 0, tone: .mint, label: "已有")
            )
        }
        .padding(Spacing.lg)
    }
}
#endif
