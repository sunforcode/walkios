#if DEBUG
import SwiftUI
import WalkData
import WalkDesignSystem

struct ComponentPreviewRootView: View {
    static let canvasAccessibilityIdentifier = "component-preview-canvas"

    let request: ComponentPreviewRequest

    var body: some View {
        ZStack {
            AppColors.pageBase.ignoresSafeArea()

            Group {
                if let entry = ComponentCatalog.entry(id: request.componentID),
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
        .frame(width: 390, height: 844)
        .clipped()
        .ignoresSafeArea()
        .preferredColorScheme(.dark)
        .environment(\.locale, Locale(identifier: "zh_CN"))
        .environment(\.dynamicTypeSize, .large)
        .transaction { transaction in
            transaction.animation = nil
            transaction.disablesAnimations = true
        }
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
