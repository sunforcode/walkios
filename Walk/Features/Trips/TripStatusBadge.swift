import SwiftUI

/// 状态标签组件
struct TripStatusBadge: View {
    let status: TripStatus

    var body: some View {
        Text(status.displayName)
            .font(.caption)
            .fontWeight(.medium)
            .foregroundColor(status.color)
            .padding(.horizontal, Spacing.sm)
            .padding(.vertical, Spacing.xs)
            .background(status.backgroundColor)
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
