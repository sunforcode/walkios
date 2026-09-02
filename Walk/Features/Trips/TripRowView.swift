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
                    AppColors.pageOuter,
                    AppColors.surfacePrimary
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            Image(systemName: "mountain.2.fill")
                .font(.system(size: 82, weight: .ultraLight))
                .foregroundStyle(AppColors.textPrimary.opacity(0.12))
        }
        .clipped()
        .accessibilityHidden(true)
    }
}

struct PersonalTripStatusBadge: View {
    let status: PersonalTripStatus

    private var foregroundColor: Color {
        switch status {
        case .planned: AppColors.statusPlanning
        case .inProgress: AppColors.statusProgress
        case .completed: AppColors.statusCompleted
        case .cancelled: AppColors.statusCancelled
        }
    }

    private var backgroundColor: Color {
        switch status {
        case .planned: AppColors.statusPlanningBackground
        case .inProgress: AppColors.statusProgressBackground
        case .completed: AppColors.statusCompletedBackground
        case .cancelled: AppColors.statusCancelledBackground
        }
    }

    var body: some View {
        Text(status.title)
            .font(.caption)
            .fontWeight(.medium)
            .foregroundStyle(foregroundColor)
            .padding(.horizontal, Spacing.sm)
            .padding(.vertical, Spacing.xs)
            .background(backgroundColor)
            .cornerRadius(6)
    }
}

struct TripRowView: View {
    let trip: PersonalTripSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            TripArtworkView(cover: trip.cover)
                .frame(height: TripLayout.listCoverHeight)

            VStack(alignment: .leading, spacing: Spacing.sm) {
                HStack(alignment: .firstTextBaseline, spacing: Spacing.sm) {
                    Text(trip.name)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(AppColors.textPrimary)
                        .lineLimit(1)

                    Spacer(minLength: Spacing.sm)
                    PersonalTripStatusBadge(status: trip.status)
                }

                Text(trip.routeName)
                    .font(.body)
                    .foregroundStyle(AppColors.textSecondary)
                    .lineLimit(1)

                HStack(spacing: Spacing.lg) {
                    Label(trip.dateRangeDescription, systemImage: "calendar")
                    Label("\(trip.totalDayCount) 天", systemImage: "clock")
                }
                .font(.caption)
                .foregroundStyle(AppColors.textWeak)
            }
            .padding(Spacing.lg)
        }
        .background(AppColors.surfacePrimary)
        .clipShape(RoundedRectangle(cornerRadius: TripLayout.cardCornerRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: TripLayout.cardCornerRadius, style: .continuous)
                .stroke(AppColors.borderPrimary, lineWidth: 1)
        }
    }
}

struct TripArtworkView: View {
    let cover: String?

    var body: some View {
        Group {
            if let cover, let url = URL(string: cover) {
                AsyncImage(url: url) { phase in
                    if let image = phase.image {
                        image.resizable().scaledToFill()
                    } else {
                        TripAtmosphericCover()
                    }
                }
            } else {
                TripAtmosphericCover()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
    }
}
