import SwiftUI

/// 攻略详情页
struct GuideDetailView: View {
    let guideId: String
    @StateObject private var viewModel = GuideDetailViewModel()

    var body: some View {
        Group {
            if viewModel.isLoading {
                LoadingView()
            } else if let error = viewModel.errorMessage {
                ErrorView(message: error) {
                    Task { await viewModel.loadGuide(id: guideId) }
                }
            } else if let guide = viewModel.guide {
                guideDetailContent(guide: guide)
            }
        }
        .navigationTitle(viewModel.guide?.title ?? "攻略详情")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.loadGuide(id: guideId)
        }
    }

    private func guideDetailContent(guide: Guide) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.legacyMd) {
                // 标题
                Text(guide.title ?? "未命名攻略")
                    .font(.largeTitle)
                    .foregroundColor(.textPrimary)

                // 作者信息
                HStack(spacing: Spacing.sm) {
                    Circle()
                        .fill(Color.cardBackground)
                        .frame(width: 32, height: 32)
                        .overlay(
                            Image(systemName: "person")
                                .foregroundColor(.textSecondary)
                                .font(.caption)
                        )

                    Text(guide.authorName ?? "匿名")
                        .font(.subheadline)
                        .foregroundColor(.textSecondary)

                    Spacer()

                    Text(guide.createdAt?.fullDateString ?? "")
                        .font(.caption)
                        .foregroundColor(.textTertiary)
                }

                Divider()

                // 内容
                if let content = guide.content {
                    Text(content)
                        .font(.body)
                        .foregroundColor(.textPrimary)
                        .lineSpacing(6)
                } else if let summary = guide.summary {
                    Text(summary)
                        .font(.body)
                        .foregroundColor(.textPrimary)
                }

                Spacer()
            }
            .padding(Spacing.legacyMd)
        }
        .background(Color.background)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    Task { await viewModel.like() }
                }) {
                    Image(systemName: viewModel.isLiked ? "heart.fill" : "heart")
                        .foregroundColor(viewModel.isLiked ? .red : .textSecondary)
                }
            }
        }
    }
}

/// 攻略详情 ViewModel
@MainActor
final class GuideDetailViewModel: ObservableObject {
    @Published var guide: Guide?
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var isLiked = false

    private let service = GuideService()

    func loadGuide(id: String) async {
        isLoading = true
        errorMessage = nil

        do {
            guide = try await service.getGuideDetail(id: id)
        } catch let error as APIError {
            errorMessage = error.errorDescription
        } catch let error as NetworkError {
            errorMessage = error.errorDescription
        } catch {
            errorMessage = "加载失败：\(error.localizedDescription)"
        }

        isLoading = false
    }

    func like() async {
        guard let id = guide?.id else { return }
        isLiked.toggle()
        do {
            _ = try await service.likeGuide(id: id)
        } catch {
            isLiked.toggle()
        }
    }
}
