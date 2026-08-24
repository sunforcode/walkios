import SwiftUI

enum TripLayout {
    static let listCoverHeight: CGFloat = 120
    static let detailMapHeight: CGFloat = 220
    static let detailCoverHeight: CGFloat = 260
    static let cardCornerRadius: CGFloat = 16
}

struct TripAtmosphericCover: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.18, green: 0.31, blue: 0.38),
                    Color(red: 0.12, green: 0.20, blue: 0.30),
                    AppColors.bgPanel
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            Image(systemName: "mountain.2.fill")
                .font(.system(size: 82, weight: .ultraLight))
                .foregroundStyle(Color.white.opacity(0.12))
        }
        .clipped()
        .accessibilityHidden(true)
    }
}

/// 行程卡片（列表行组件）
struct TripRowView: View {
    let trip: Trip

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            TripAtmosphericCover()
                .frame(height: TripLayout.listCoverHeight)

            VStack(alignment: .leading, spacing: Spacing.sm) {
                HStack(alignment: .firstTextBaseline, spacing: Spacing.sm) {
                    Text(trip.displayName)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(AppColors.textPrimary)
                        .lineLimit(1)

                    Spacer(minLength: Spacing.sm)
                    TripStatusBadge(status: trip.status)
                }

                if let description = trip.description, !description.isEmpty {
                    Text(description)
                        .font(.body)
                        .foregroundStyle(AppColors.textSecondary)
                        .lineLimit(2)
                }

                HStack(spacing: Spacing.lg) {
                    Label(trip.dateRangeDescription, systemImage: "calendar")
                    Label(trip.durationDescription, systemImage: "clock")
                }
                .font(.caption)
                .foregroundStyle(AppColors.textWeak)
            }
            .padding(Spacing.lg)
        }
        .background(AppColors.bgPanel)
        .clipShape(RoundedRectangle(cornerRadius: TripLayout.cardCornerRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: TripLayout.cardCornerRadius, style: .continuous)
                .stroke(Color.white.opacity(0.10), lineWidth: 1)
        }
    }
}

#Preview {
    VStack(spacing: Spacing.legacyMd) {
        TripRowView(trip: Trip(
            id: "1",
            name: "五台山徒步",
            description: "五台山朝台路线，全程约 50km",
            status: .inProgress,
            startDate: Date(),
            endDate: Calendar.current.date(byAdding: .day, value: 3, to: Date()),
            userId: "user1",
            routeId: "route1",
            createdAt: Date(),
            updatedAt: Date()
        ))

        TripRowView(trip: Trip(
            id: "2",
            name: "箭扣长城",
            description: nil,
            status: .planning,
            startDate: nil,
            endDate: nil,
            userId: "user1",
            routeId: nil,
            createdAt: Date(),
            updatedAt: Date()
        ))
    }
    .padding()
    .background(AppColors.bgBase)
}
