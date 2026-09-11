import SwiftUI

extension PersonalTripStatus {
    var badgeTitle: String { title }

    var badgeForegroundColor: Color {
        switch self {
        case .planned: AppColors.statusPlanning
        case .inProgress: AppColors.statusProgress
        case .completed: AppColors.statusCompleted
        case .cancelled: AppColors.statusCancelled
        }
    }

    var badgeBackgroundColor: Color {
        switch self {
        case .planned: AppColors.statusPlanningBackground
        case .inProgress: AppColors.statusProgressBackground
        case .completed: AppColors.statusCompletedBackground
        case .cancelled: AppColors.statusCancelledBackground
        }
    }
}

/// 全产品唯一的状态徽章实现（抽象规范：StatusBadge）。
struct TripStatusBadge: View {
    private let status: PersonalTripStatus

    init(status: PersonalTripStatus) {
        self.status = status
    }

    var body: some View {
        Text(status.badgeTitle)
            .font(.tag)
            .foregroundStyle(status.badgeForegroundColor)
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.sm)
            .frame(minHeight: 28)
            .background(
                status.badgeBackgroundColor,
                in: RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
            )
            .fixedSize(horizontal: true, vertical: false)
            .accessibilityLabel("行程状态：\(status.badgeTitle)")
    }
}

#if DEBUG
#Preview("TripStatusBadge.planned") {
    TripStatusBadge(status: .planned)
        .padding()
        .background(AppColors.pageBase)
}

#Preview("TripStatusBadge.progress") {
    TripStatusBadge(status: .inProgress)
        .padding()
        .background(AppColors.pageBase)
}

#Preview("TripStatusBadge.completed") {
    TripStatusBadge(status: .completed)
        .padding()
        .background(AppColors.pageBase)
}

#Preview("TripStatusBadge.cancelled") {
    TripStatusBadge(status: .cancelled)
        .padding()
        .background(AppColors.pageBase)
}
#endif
