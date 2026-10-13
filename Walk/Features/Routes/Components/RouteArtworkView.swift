import Foundation
import SwiftUI
import WalkDesignSystem

/// 图片引用的端内解析，不把任意媒体字符串当作本地资源名或文件路径。
enum RouteArtworkSource: Equatable {
    case bundledAsset(String)
    case remoteURL(URL)

    static func resolve(_ reference: String?) -> Self? {
        guard let reference = reference?.trimmingCharacters(in: .whitespacesAndNewlines),
              !reference.isEmpty else { return nil }
        let bundledAssets = [
            "YadingSceneOverview", "YadingSceneDay1", "YadingSceneDay2",
            "YadingSceneDay3", "YadingSceneDay4", "YadingSceneDay5",
        ]
        if let name = bundledAssets.first(where: { reference == "asset://\($0)" }) {
            return .bundledAsset(name)
        }
        guard let url = URL(string: reference),
              let scheme = url.scheme?.lowercased(), ["https", "http"].contains(scheme),
              let host = url.host, !host.isEmpty else { return nil }
        return .remoteURL(url)
    }
}

/// 路线发现、列表、搜索和详情图库共用的图片内部节点；各消费位置保留既有失败占位。
struct RouteArtworkView: View {
    enum Placeholder {
        case terrain
        case forest
        case symbol(String)
    }

    let cover: String?
    var placeholder: Placeholder = .terrain
    var contentMode: ContentMode = .fill

    var body: some View {
        // 图片只消费父容器已经分配的空间，不让 scaledToFill 的比例尺寸撑大分页卡片。
        GeometryReader { geometry in
            artwork
                .frame(width: geometry.size.width, height: geometry.size.height)
                .clipped()
        }
    }

    private var artwork: some View {
        Group {
            switch RouteArtworkSource.resolve(cover) {
            case let .bundledAsset(name):
                Image(name).resizable().aspectRatio(contentMode: contentMode)
            case let .remoteURL(url):
                AsyncImage(url: url) { phase in
                    if let image = phase.image {
                        image.resizable().aspectRatio(contentMode: contentMode)
                    } else {
                        placeholderSurface
                    }
                }
            case nil:
                placeholderSurface
            }
        }
    }

    @ViewBuilder
    private var placeholderSurface: some View {
        switch placeholder {
        case .forest:
            RouteDeterministicImageSurface(style: .forest)
        case let .symbol(systemName):
            ZStack {
                AppColors.surfaceElevated
                Image(systemName: systemName)
                    .foregroundStyle(AppColors.textWeak)
            }
        case .terrain:
            ZStack {
                LinearGradient(
                    colors: [AppColors.surfacePrimary, AppColors.pageMiddle, AppColors.pageBase],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                Image(systemName: "mountain.2.fill")
                    .font(.ornament(64))
                    .foregroundStyle(AppColors.surfaceGlass)
            }
        }
    }
}
