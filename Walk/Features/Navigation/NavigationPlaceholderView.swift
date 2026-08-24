import SwiftUI

struct NavigationPlaceholderView: View {
    var body: some View {
        AppColors.bgBase
            .ignoresSafeArea()
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.visible, for: .navigationBar)
            .accessibilityLabel("导航页面")
    }
}
