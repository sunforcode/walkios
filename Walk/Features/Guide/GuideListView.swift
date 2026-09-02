import SwiftUI

/// 攻略列表页
struct GuideListView: View {
    @ObservedObject var viewModel: GuideListViewModel

    var body: some View {
        UtilityPageContainer {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: Spacing.xl) {
                    PageHeroHeader(
                        title: "精选攻略",
                        subtitle: "发现灵感，准备下一段旅程"
                    )

                    guideContent
                }
                .padding(.horizontal, Spacing.pageHorizontal)
                .padding(.top, Spacing.xl)
                .padding(.bottom, Spacing.xxl)
            }
            .refreshable {
                await viewModel.refresh()
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .task {
            await viewModel.loadIfNeeded()
        }
    }

    @ViewBuilder
    private var guideContent: some View {
        if viewModel.isLoading {
            LoadingView()
                .frame(minHeight: 320)
        } else if let error = viewModel.errorMessage, viewModel.guides.isEmpty {
            ErrorView(message: error) {
                Task { await viewModel.retry() }
            }
            .frame(minHeight: 320)
        } else if viewModel.guides.isEmpty {
            EmptyStateView(
                title: "暂无攻略",
                message: "敬请期待精选攻略",
                icon: "book"
            )
            .frame(minHeight: 320)
        } else {
            ForEach(viewModel.guides) { guide in
                NavigationLink(destination: GuideDetailView(guideId: guide.id)) {
                    GuideCardView(guide: guide)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

/// 攻略卡片
struct GuideCardView: View {
    let guide: Guide

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Rectangle()
                .fill(AppColors.surfacePrimary)
                .frame(height: 160)
                .overlay(
                    Image(systemName: "photo")
                        .foregroundColor(AppColors.textWeak)
                        .font(.title)
                )
                .cornerRadius(8)

            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(guide.title ?? "未命名攻略")
                    .font(.headline)
                    .foregroundColor(AppColors.textPrimary)
                    .lineLimit(2)

                if let summary = guide.summary {
                    Text(summary)
                        .font(.caption)
                        .foregroundColor(AppColors.textSecondary)
                        .lineLimit(2)
                }

                HStack(spacing: Spacing.legacyMd) {
                    if let authorName = guide.authorName {
                        Text(authorName)
                            .font(.caption)
                            .foregroundColor(AppColors.textWeak)
                    }

                    Spacer()

                    HStack(spacing: Spacing.legacyLg) {
                        Label(guide.readCountDescription, systemImage: "eye")
                            .font(.caption)
                            .foregroundColor(AppColors.textWeak)

                        Label(guide.likeCountDescription, systemImage: "heart")
                            .font(.caption)
                            .foregroundColor(AppColors.textWeak)
                    }
                }
            }
            .padding(.horizontal, Spacing.sm)
        }
        .padding(.bottom, Spacing.sm)
        .background(AppColors.surfacePrimary)
        .clipShape(RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
        .shadow(color: AppColors.shadowCard, radius: 4, x: 0, y: 2)
    }
}

#if DEBUG
#Preview("Guide List") {
    GuideListView(viewModel: GuideListViewModel())
}

#Preview("Guide Card") {
    GuideCardView(guide: MockData.guides.first!)
        .padding()
        .background(AppColors.pageBase)
}
#endif
