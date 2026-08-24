import SwiftUI

/// 攻略列表 ViewModel
@MainActor
final class GuideListViewModel: ObservableObject {
    @Published var guides: [Guide] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let service = GuideService()

    func loadGuides() async {
        isLoading = true
        errorMessage = nil

        do {
            guides = try await service.getGuides()
        } catch let error as APIError {
            errorMessage = error.errorDescription
        } catch let error as NetworkError {
            errorMessage = error.errorDescription
        } catch {
            errorMessage = "加载失败：\(error.localizedDescription)"
        }

        isLoading = false
    }

    func retry() async {
        errorMessage = nil
        await loadGuides()
    }
}
