import Combine
import Foundation

@MainActor
final class GuideListViewModel: ObservableObject {
    @Published var guides: [Guide] = []
    @Published var isLoading = false
    @Published var isRefreshing = false
    @Published var errorMessage: String?
    private(set) var hasLoaded = false

    private let loadGuides: () async throws -> [Guide]
    private var isRequesting = false

    init(loadGuides: @escaping () async throws -> [Guide] = {
        try await GuideService().getGuides()
    }) {
        self.loadGuides = loadGuides
    }

    func loadIfNeeded() async {
        guard !hasLoaded else { return }
        await load(showInitialLoading: guides.isEmpty)
    }

    func refresh() async {
        await load(showInitialLoading: guides.isEmpty)
    }

    func retry() async {
        await load(showInitialLoading: guides.isEmpty)
    }

    private func load(showInitialLoading: Bool) async {
        guard !isRequesting else { return }
        isRequesting = true
        errorMessage = nil
        if showInitialLoading {
            isLoading = true
        } else {
            isRefreshing = true
        }
        defer {
            isRequesting = false
            isLoading = false
            isRefreshing = false
        }

        do {
            guides = try await loadGuides()
            hasLoaded = true
        } catch let error as APIError {
            errorMessage = error.errorDescription
        } catch let error as NetworkError {
            errorMessage = error.errorDescription
        } catch {
            errorMessage = "加载失败：\(error.localizedDescription)"
        }
    }
}
