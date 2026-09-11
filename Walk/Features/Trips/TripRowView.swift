import SwiftUI
import WalkData
import WalkDesignSystem

enum TripLayout {
    static let listCoverSize: CGFloat = 52
    static let compactListCoverSize: CGFloat = 48
    static let detailCoverHeight: CGFloat = 275
}

struct TripAtmosphericCover: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    AppColors.sceneForestHighlight,
                    AppColors.sceneForestMiddle,
                    AppColors.pageOuter
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            TripContourLines()
                .stroke(AppColors.interactionPrimary.opacity(0.16), lineWidth: 1)
            TripMountainSilhouette()
                .fill(AppColors.pageBase.opacity(0.78))
        }
        .clipped()
        .accessibilityHidden(true)
    }
}

private struct TripContourLines: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        for index in 0..<6 {
            let y = rect.height * (0.16 + CGFloat(index) * 0.14)
            path.move(to: CGPoint(x: -rect.width * 0.08, y: y))
            path.addCurve(
                to: CGPoint(x: rect.width * 1.08, y: y + rect.height * 0.04),
                control1: CGPoint(x: rect.width * 0.24, y: y + rect.height * 0.20),
                control2: CGPoint(x: rect.width * 0.66, y: y - rect.height * 0.16)
            )
        }
        return path
    }
}

private struct TripMountainSilhouette: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.height * 0.72))
        path.addLine(to: CGPoint(x: rect.width * 0.17, y: rect.height * 0.58))
        path.addLine(to: CGPoint(x: rect.width * 0.29, y: rect.height * 0.68))
        path.addLine(to: CGPoint(x: rect.width * 0.49, y: rect.height * 0.38))
        path.addLine(to: CGPoint(x: rect.width * 0.62, y: rect.height * 0.57))
        path.addLine(to: CGPoint(x: rect.width * 0.75, y: rect.height * 0.44))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.height * 0.67))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}
