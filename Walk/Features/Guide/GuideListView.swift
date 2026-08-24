import SwiftUI

/// 攻略列表页
struct GuideListView: View {
    @StateObject private var viewModel = GuideListViewModel()

    var body: some View {
        Group {
            if viewModel.isLoading {
                LoadingView()
            } else if let error = viewModel.errorMessage {
                ErrorView(message: error) {
                    Task { await viewModel.retry() }
                }
            } else if viewModel.guides.isEmpty {
                EmptyStateView(
                    title: "暂无攻略",
                    message: "敬请期待精选攻略",
                    icon: "book"
                )
            } else {
                guideListContent
            }
        }
        .navigationTitle("攻略")
        .task {
            await viewModel.loadGuides()
        }
    }

    private var guideListContent: some View {
        ScrollView {
            LazyVStack(spacing: Spacing.legacyMd) {
                ForEach(viewModel.guides) { guide in
                    NavigationLink(destination: GuideDetailView(guideId: guide.id)) {
                        GuideCardView(guide: guide)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.horizontal, Spacing.legacyMd)
            .padding(.vertical, Spacing.sm)
        }
        .background(Color.groupedBackground)
        .refreshable {
            await viewModel.loadGuides()
        }
    }
}

/// 攻略卡片
struct GuideCardView: View {
    let guide: Guide

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            // 封面图占位
            Rectangle()
                .fill(Color.cardBackground)
                .frame(height: 160)
                .overlay(
                    Image(systemName: "photo")
                        .foregroundColor(.textTertiary)
                        .font(.title)
                )
                .cornerRadius(8)

            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(guide.title ?? "未命名攻略")
                    .font(.headline)
                    .foregroundColor(.textPrimary)
                    .lineLimit(2)

                if let summary = guide.summary {
                    Text(summary)
                        .font(.caption)
                        .foregroundColor(.textSecondary)
                        .lineLimit(2)
                }

                HStack(spacing: Spacing.legacyMd) {
                    if let authorName = guide.authorName {
                        Text(authorName)
                            .font(.caption)
                            .foregroundColor(.textTertiary)
                    }

                    Spacer()

                    HStack(spacing: Spacing.legacyLg) {
                        Label(guide.readCountDescription, systemImage: "eye")
                            .font(.caption)
                            .foregroundColor(.textTertiary)

                        Label(guide.likeCountDescription, systemImage: "heart")
                            .font(.caption)
                            .foregroundColor(.textTertiary)
                    }
                }
            }
            .padding(.horizontal, Spacing.sm)
        }
        .padding(.bottom, Spacing.sm)
        .background(Color.cardBackground)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
    }
}

#if DEBUG
#Preview("Guide List") {
    GuideListView()
}

#Preview("Guide Card") {
    GuideCardView(guide: MockData.guides.first!)
        .padding()
        .background(Color.groupedBackground)
}
#endif
