import SwiftUI
import MapKit
import WalkData
import WalkDesignSystem

struct RouteShareButton: View {
    let shareText: String
    @State private var isPresented = false

    var body: some View {
        IconButton(
            systemName: "square.and.arrow.up",
            accessibilityLabel: "分享路线",
            variant: .overlay,
            action: { isPresented = true }
        )
        .sheet(isPresented: $isPresented) {
            ShareSheet(items: [shareText])
        }
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}

struct RouteDetailStateOverlay<Content: View>: View {
    @ViewBuilder let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.horizontal, Spacing.xl)
            .padding(.top, 100)
            .padding(.bottom, 110)
            .background(AppColors.pageBase.opacity(0.52))
    }
}

/// 工具栏紧凑生成入口：资格不足时保持可见，禁用呈现但可点，触发原因提示。
struct RouteToolbarGenerateAction: View {
    let action: RouteGenerationActionPresentation
    let onGenerate: () -> Void
    let onUnavailable: () -> Void

    var body: some View {
        PrimaryAction(
            title: "立即出发",
            systemImage: "wand.and.stars",
            variant: .compact,
            isDisabled: false,
            action: action.isEnabled ? onGenerate : onUnavailable
        )
        .opacity(action.isEnabled ? 1 : 0.62)
        .accessibilityHint(action.isEnabled ? "使用当前路线生成个人行程" : action.unavailableMessage ?? "路线资料不足，暂不可生成")
    }
}

/// 顶部滚动状态读取：onScrollGeometryChange 侦测内容是否回到顶部。
/// contentMargins + viewAligned 下内容全局 frame 不随滚动变化，preference 方式会失效。
struct RouteDetailScrollTopReader: ViewModifier {
    let baseline: CGFloat
    let onChange: (Bool) -> Void

    func body(content: Content) -> some View {
        content.onScrollGeometryChange(for: Bool.self) { geometry in
            geometry.contentOffset.y <= 1
        } action: { _, isTop in
            onChange(isTop)
        }
    }
}

extension View {
    /// 内容不贴合视口时禁用滚动弹动。
    var routeDetailScrollNoBounce: some View {
        scrollBounceBehavior(.basedOnSize)
    }

    /// 标记 section 列表为吸附目标布局。
    func routeDetailScrollTargetLayout() -> some View {
        scrollTargetLayout()
    }

    /// 滚动容器：顶部内边距让首屏 section 对齐屏幕。
    /// 不再挂 scrollTargetBehavior：viewAligned 的「最近目标」策略会把小幅上划
    /// 直接吸回原 section；去掉后滚动完全自然，轻扫停在松手位置，拂动靠惯性滑动。
    func routeDetailAlignedScrolling(topInset: CGFloat) -> some View {
        contentMargins(.top, topInset, for: .scrollContent)
    }
}

struct RouteDetailScrollOverlay: View {
    let presentation: RouteDetailPresentation
    let elevationProfile: ElevationProfileProjection?
    let topSpacerHeight: CGFloat
    /// 首屏 section 固定高度：首屏只展示路线概要，不露出后续 section。
    let firstSectionHeight: CGFloat
    /// 顶部下拽跟手偏移，由页面持有：收起时保持原值随动画滑出，唤回时归零。
    @Binding var panelDragOffset: CGFloat
    let selectedSegmentID: String?
    let highlightedPointIdentity: String?
    let onSelectSegment: (String) -> Void
    let onSelectItem: (String) -> Void
    let onFocusPoint: (String) -> Void
    /// 信息面顶部下拽越过阈值后松手，自动收起进入纯地图。
    let onCollapse: () -> Void
    /// 滚动离顶/回顶回调：驱动全屏按钮显隐。
    let onScrolledTopChange: (Bool) -> Void

    @State private var isScrolledToTop = true

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 0) {
                panelSections

                // 底部安全区：最后一个区块不被手势条遮挡；放在 target layout 外避免成为吸附点。
                AppColors.surfacePrimary.opacity(0)
                    .frame(height: 120)
                    .accessibilityHidden(true)
            }
        }
        .routeDetailAlignedScrolling(topInset: topSpacerHeight)
        .modifier(RouteDetailScrollTopReader(
            baseline: scrollOffsetBaseline,
            onChange: { isTop in
                if isTop != isScrolledToTop {
                    isScrolledToTop = isTop
                    onScrolledTopChange(isTop)
                }
            }
        ))
        .offset(y: panelDragOffset)
        .simultaneousGesture(
            DragGesture(minimumDistance: 16)
                .onChanged { value in
                    guard isScrolledToTop else { return }
                    // 顶部下拽：面板跟手移动；禁弹后不再叠加滚动阻尼。
                    panelDragOffset = max(0, value.translation.height)
                }
                .onEnded { value in
                    if isScrolledToTop, value.translation.height > 120 {
                        // 不归零跟手偏移：面板从当前拖拽位置随收起动画直接滑出，避免先弹回再消失的跳变。
                        onCollapse()
                        return
                    }
                    withAnimation(.easeOut(duration: 0.22)) { panelDragOffset = 0 }
                }
        )
        .routeDetailScrollNoBounce
        .accessibilityAction(named: Text("收起信息面进入纯地图")) {
            onCollapse()
        }
    }

    /// 吸附滚动基线：contentMargins 模式下内容 minY 静止时等于顶部内边距。
    private var scrollOffsetBaseline: CGFloat {
        topSpacerHeight
    }

    /// 信息面容器透明，每个资料区独立成卡片悬浮展示；海拔曲线固定在最底部。
    @ViewBuilder
    private var panelSections: some View {
        VStack(spacing: RouteDetailLayout.sectionSpacing) {
            sectionCard(fixedHeight: firstSectionHeight - Spacing.xl * 2) {
                RouteBusinessComponents.RouteSummary(
                    projection: presentation.routeSummaryProjection
                )
            }

            if let generationMessage = presentation.generationMessage {
                NoticeView(
                    message: generationMessage,
                    title: "路线资料不足",
                    icon: "exclamationmark.triangle",
                    tone: .warning
                )
                .padding(.horizontal, Spacing.pageHorizontal)
            }

            if let introduction = presentation.routeIntroductionProjection {
                sectionCard {
                    RouteBusinessComponents.RouteIntroduction(projection: introduction)
                }
            }

            if !presentation.referenceDayProjections.isEmpty {
                sectionCard {
                    RouteBusinessComponents.RouteReferenceDayList(
                        days: presentation.referenceDayProjections
                    )
                }
            }

            if let segments = presentation.routeSegmentListProjection {
                sectionCard {
                    RouteBusinessComponents.RouteSegmentList(
                        projection: selectedSegments(segments),
                        onSelectSegment: onSelectSegment
                    )
                }
            }

            ForEach(Array(presentation.routePointGroupProjections.enumerated()), id: \.element.id) { _, group in
                sectionCard {
                    VStack(alignment: .leading, spacing: Spacing.lg) {
                        ForEach(Array(group.sections.enumerated()), id: \.element.title) { _, section in
                            RouteBusinessComponents.RoutePointSection(
                                projection: selectedPointSection(section),
                                onFocusPoint: onFocusPoint
                            )
                        }
                    }
                }
            }

            ForEach(Array(presentation.routeFactSectionProjections.enumerated()), id: \.element.title) { _, section in
                sectionCard {
                    RouteBusinessComponents.RouteFactSection(projection: section)
                }
            }

            if presentation.sections.contains(where: { $0.id == .imagery }) {
                sectionCard {
                    RouteBusinessComponents.RouteImageGallery(
                        images: presentation.images.map { item in
                            RouteImageProjection(
                                id: item.id,
                                title: item.caption,
                                description: nil
                            )
                        }
                    ) { image in
                        detailImageSurface(
                            source: presentation.images.first(where: { $0.id == image.id })?.source ?? "",
                            failurePlaceholderSystemImage: "photo"
                        )
                    }
                }
            }

            if !presentation.sceneImages.isEmpty {
                sectionCard {
                    RouteBusinessComponents.RouteImageGallery(
                        images: presentation.sceneImages.map {
                            RouteImageProjection(id: $0.id, title: $0.contextLabel, description: nil)
                        },
                        title: "场景示意"
                    ) { image in
                        RouteArtworkView(
                            cover: presentation.sceneImages.first(where: { $0.id == image.id })?.source,
                            placeholder: .symbol("photo"),
                            contentMode: .fit
                        )
                    }
                }
            }

            if let elevationProfile {
                sectionCard {
                    RouteBusinessComponents.ElevationProfile(projection: elevationProfile)
                }
            }

            // 底部安全区留白已上移到滚动内容层，此处仅收束 section 列表。
        }
        .routeDetailScrollTargetLayout()
        .frame(maxWidth: 600)
        .frame(maxWidth: .infinity)
    }

    private func sectionCard<Content: View>(
        fixedHeight: CGFloat? = nil,
        @ViewBuilder _ content: () -> Content
    ) -> some View {
        let card = content()
            .frame(maxWidth: .infinity, alignment: .leading)
        return Group {
            if let fixedHeight {
                card.frame(height: fixedHeight, alignment: .top)
            } else {
                card
            }
        }
        .padding(Spacing.xl)
        .background(
            AppColors.surfacePrimary,
            in: RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
        )
        .padding(.horizontal, RouteDetailLayout.sectionHorizontalMargin)
    }

    private func selectedSegments(_ projection: RouteSegmentListProjection) -> RouteSegmentListProjection {
        var projection = projection
        projection.activeSegmentID = selectedSegmentID
        return projection
    }

    private func selectedPointSection(_ projection: RoutePointSectionProjection) -> RoutePointSectionProjection {
        var projection = projection
        projection.activePointID = highlightedPointIdentity
        return projection
    }

    /// 只读图片视觉：解析图片引用并保留失败占位，不建立任何打开事件。
    private func detailImageSurface(source: String, failurePlaceholderSystemImage: String) -> some View {
        RouteArtworkView(cover: source, placeholder: .symbol(failurePlaceholderSystemImage))
        .frame(maxWidth: .infinity)
        .frame(height: 70)
        .clipped()
        .clipShape(RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
    }
}
