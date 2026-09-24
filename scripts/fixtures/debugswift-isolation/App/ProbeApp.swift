import SwiftUI
#if DEBUG
import WalkDebugTools
#endif

@main
struct ProbeApp: App {
#if DEBUG
    @State private var showsDebugTools = false
#endif
    var body: some Scene {
        WindowGroup {
            VStack(spacing: 24) {
                Text("Walk isolation probe")
#if DEBUG
                Button("Open debug tools") {
                    showsDebugTools = true
                }
                .accessibilityIdentifier("probe.open-debug-tools")
#else
                Text("Production graph")
                    .accessibilityIdentifier("probe.production")
#endif
            }
#if DEBUG
            .sheet(isPresented: $showsDebugTools, onDismiss: DebugToolsProbe.didDismiss) {
                DebugPanel()
            }
#endif
        }
    }
}

#if DEBUG
private struct DebugPanel: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> UIViewController {
        DebugToolsProbe.makeViewController()
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}
}
#endif
