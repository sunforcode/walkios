#if DEBUG
import SwiftUI
import WalkData
import WalkDesignSystem

struct ComponentPreviewRootView: View {
    static let canvasAccessibilityIdentifier = "component-preview-canvas"

    enum Layout {
        case fixedCanvas
        case embedded
    }

    let request: ComponentPreviewRequest
    let layout: Layout

    init(request: ComponentPreviewRequest, layout: Layout = .fixedCanvas) {
        self.request = request
        self.layout = layout
    }

    var body: some View {
        previewLayout
            .preferredColorScheme(.dark)
            .environment(\.locale, Locale(identifier: "zh_CN"))
            .environment(\.dynamicTypeSize, .large)
            .transaction { transaction in
                transaction.animation = nil
                transaction.disablesAnimations = true
            }
    }

    @ViewBuilder
    private var previewLayout: some View {
        switch layout {
        case .fixedCanvas:
            // 定向 UITest 继续使用原来的固定画布与安全区行为。
            ZStack {
                AppColors.pageBase.ignoresSafeArea()
                previewContent
            }
            .frame(width: 390, height: 844)
            .clipped()
            .ignoresSafeArea()
        case .embedded:
            // 由浏览器提供安全区和导航；高组件自然撑开滚动内容，不截成固定画布。
            GeometryReader { proxy in
                ScrollView {
                    previewContent
                        .frame(maxWidth: .infinity, minHeight: proxy.size.height)
                }
                .background { AppColors.pageBase }
                .clipped()
            }
        }
    }

    private var previewContent: some View {
        Group {
            if let entry = ComponentCatalog.entry(id: request.componentID),
               entry.stateIDs.contains(request.stateID),
               let component = entry.makeView(request.stateID) {
                ZStack(alignment: .topLeading) {
                    componentSurface(component)
                    readinessMarker(identifier: readyMarker)
                }
            } else {
                ZStack(alignment: .topLeading) {
                    unsupportedView
                    readinessMarker(identifier: unsupportedMarker)
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(Self.canvasAccessibilityIdentifier)
    }

    private func componentSurface(_ component: AnyView) -> some View {
        ZStack {
            AppColors.pageBase
            component
        }
        .foregroundStyle(AppColors.textPrimary)
    }

    private var unsupportedView: some View {
        Text("Unsupported component preview: \(request.componentID):\(request.stateID)")
            .font(.caption.monospaced())
            .foregroundStyle(AppColors.textWeak)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(AppColors.pageBase)
    }

    private func readinessMarker(identifier: String) -> some View {
        Text(identifier)
            .font(.system(size: 1))
            .foregroundStyle(AppColors.textPrimary.opacity(0))
            .frame(width: 1, height: 1)
            .accessibilityIdentifier(identifier)
    }

    private var readyMarker: String {
        "component-preview-ready:\(request.componentID):\(request.stateID)"
    }

    private var unsupportedMarker: String {
        "component-preview-unsupported:\(request.componentID):\(request.stateID)"
    }
}
#endif
