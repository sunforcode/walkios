import SwiftUI

struct NavigationPlaceholderView: View {
    let routeID: String

    var body: some View {
        EmptyStateView(
            title: "路线导航",
            message: "导航能力暂未开放",
            icon: "location.north.line"
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppColors.pageBase)
        .navigationTitle("导航")
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityLabel("路线 \(routeID) 的导航页面，暂未开放")
    }
}
