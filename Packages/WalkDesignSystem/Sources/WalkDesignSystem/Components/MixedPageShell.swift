import SwiftUI

public struct MixedPageShell<Content: View>: View {
    private let content: Content

     public init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

     public var body: some View {
        ZStack {
            LinearGradient(
                colors: [AppColors.pageOuter, AppColors.pageMiddle, AppColors.pageBase],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            content
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .foregroundStyle(AppColors.textPrimary)
    }
}
