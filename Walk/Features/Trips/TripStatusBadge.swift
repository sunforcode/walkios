import SwiftUI

/// 状态标签组件
struct TripStatusBadge: View {
    let status: TripStatus

    private var foregroundColor: Color {
        switch status {
        case .planning: AppColors.statusPlanning
        case .inProgress: AppColors.statusProgress
        case .completed: AppColors.statusCompleted
        case .cancelled: AppColors.statusCancelled
        case .unknown: AppColors.textWeak
        }
    }

    private var backgroundColor: Color {
        switch status {
        case .planning: AppColors.statusPlanningBackground
        case .inProgress: AppColors.statusProgressBackground
        case .completed: AppColors.statusCompletedBackground
        case .cancelled: AppColors.statusCancelledBackground
        case .unknown: AppColors.interactionBackground
        }
    }

    var body: some View {
        Text(status.displayName)
            .font(.caption)
            .fontWeight(.medium)
            .foregroundStyle(foregroundColor)
            .padding(.horizontal, Spacing.sm)
            .padding(.vertical, Spacing.xs)
            .background(backgroundColor)
            .cornerRadius(6)
    }
}

#Preview {
    HStack(spacing: Spacing.md) {
        TripStatusBadge(status: .planning)
        TripStatusBadge(status: .inProgress)
        TripStatusBadge(status: .completed)
        TripStatusBadge(status: .cancelled)
    }
    .padding()
}
