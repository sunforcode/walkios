import SwiftUI
import UIKit
import WalkData
import WalkDesignSystem

enum RouteDiscoveryLayout {
    /// 卡片高度等于分页视口：scroll snap 的吸附单位是容器高度，
    /// 卡片必须与视口等高才能逐屏对齐（第二屏起不累积偏差）。
    static func cardHeight(for viewportHeight: CGFloat) -> CGFloat {
        max(0, viewportHeight)
    }
}

struct RouteDiscoveryView: View {
    @StateObject private var viewModel: RouteDiscoveryViewModel
    private let onNavigate: (AppDestination) -> Void
    /// 固定窗口安全区常量：与 PageShell 同源（PinnedWindowSafeAreaInsets），
    /// 转场期间动态安全区尖峰不再顶跳页头与场景。
    /// 只能在 onAppear 解析（视图事务内读 UIWindow 会锁死 iOS 26 更新管道）。
    @State private var pinnedInsets = EdgeInsets()
    /// 当前分页卡片的 routeId：由 scrollPosition 双向驱动——手势翻页写入，
    /// 可访问性等价动作（selectAdjacentRoute）通过写入它实现编程式翻页。
    @State private var activeRouteID: String?

    init(
        routeService: RouteService,
        onNavigate: @escaping (AppDestination) -> Void = { _ in }
    ) {
        self.onNavigate = onNavigate
        _viewModel = StateObject(wrappedValue: RouteDiscoveryViewModel(service: routeService))
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            // 场景层：铺满整个页面可用区域，向上延伸至顶部安全区之后。
            routeState
                .padding(.top, pinnedInsets.top)

            // 页面头浮层：叠加在场景层上，位于系统顶部安全区下方。
            pageHeaderOverlay
                .padding(.top, pinnedInsets.top)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        // 顶部用 pin 常量（转场期间动态顶部 inset 有 62→168→116 尖峰，会顶跳页头）；
        // 底部继续消费动态安全区：TabView 的 tab bar safeAreaInset（34+49=83）
        // 不在 UIWindow inset 内，pin 常量拿不到它，且实测转场期间恒定不跳。
        .ignoresSafeArea(edges: .top)
        .background {
            RadialGradient(
                colors: [AppColors.pageOuter, AppColors.pageMiddle, AppColors.pageBase],
                center: .top,
                startRadius: 0,
                endRadius: 700
            )
            .ignoresSafeArea()
        }
        .toolbar(.hidden, for: .navigationBar)
        .immersiveSystemAreaContext()
        // 窗口安全区常量在视图挂载后解析（同 PageShell）：首帧在屏幕外不可见。
        .onAppear {
            if pinnedInsets == EdgeInsets() {
                pinnedInsets = PinnedWindowSafeAreaInsets.current
            }
        }
        .task { await viewModel.loadRoutes() }
    }

    /// 页面头浮层：标题 + 副标题 + 固定右上 allRoutes，底部对比遮罩保证浮层在场景图上可读。
    private var pageHeaderOverlay: some View {
        PageTitleBlock(
            title: "路线",
            description: "选一条想走的，看清了再出发",
            trailing: {
                SecondaryAction(title: "全部路线", variant: .overlayCompact) {
                    onNavigate(.routeList)
                }
            }
        )
        .padding(.horizontal, Spacing.pageHorizontal)
        .background(alignment: .top) {
            LinearGradient(
                colors: [AppColors.pageBase, AppColors.pageBase.opacity(0)],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 260)
            .ignoresSafeArea(edges: .top)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
    }

    @ViewBuilder
    private var routeState: some View {
        if viewModel.isLoading && viewModel.routes.isEmpty {
            RouteSceneSkeleton()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.bottom, Spacing.xxl)
        } else if let message = viewModel.errorMessage, viewModel.routes.isEmpty {
            ErrorView(
                message: "不会用缓存猜测替代真实路线资料。",
                title: "暂时无法加载路线",
                variant: .scene
            ) {
                Task { await viewModel.retry() }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if viewModel.routes.isEmpty {
            EmptyStateView(
                title: "暂无路线",
                message: "当前暂无可发现路线",
                icon: "route",
                variant: .default
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            GeometryReader { proxy in
                routePager(cardHeight: RouteDiscoveryLayout.cardHeight(for: proxy.size.height))
                    .frame(width: proxy.size.width)
            }
            // 分页区域铺满整个屏幕：顶部延伸至状态栏之后（规范：场景层延伸至顶部安全区之后），
            // 底部延伸至 tab bar 之后（规范：tab bar 悬浮于内容之上）。
            // 底部内容避让由 DesignSystem 的沉浸式系统区域上下文统一承载。
            .ignoresSafeArea(edges: [.top, .bottom])
        }
    }

    /// RoutePager：规范要求本页唯一纵向滚动拥有者，纵向 scroll snap 分页、首尾不循环。
    /// 每屏一条 RouteScene，卡片高度等于分页区域（整屏）。
    private func routePager(cardHeight: CGFloat) -> some View {
        ScrollView(.vertical, showsIndicators: false) {
            // 路线数量有限且需精确分页定位，不用 Lazy 容器（scrollPosition 对 lazy 内容定位不稳定）。
            VStack(spacing: 0) {
                ForEach(Array(viewModel.routes.enumerated()), id: \.element.routeId) { index, route in
                    routeCard(route)
                        .frame(height: cardHeight)
                        // 换页后只让当前 RouteScene 进入焦点顺序。
                        .accessibilityHidden(index != activeIndex)
                }
            }
            .scrollTargetLayout()
        }
        .scrollTargetBehavior(.paging)
        .scrollPosition(id: $activeRouteID)
        .onChange(of: viewModel.routes) { _, routes in
            if activeRouteID == nil {
                activeRouteID = routes.first?.routeId
            }
        }
        .onChange(of: activeRouteID) { previous, current in
            // 首次赋值是初始定位，不作换页公告。
            guard previous != nil, let current else { return }
            announcePagePosition(routeID: current)
        }
        .modifier(RoutePagerAccessibilityActions(
            routeCount: viewModel.routes.count,
            onAdjacent: { selectAdjacentRoute($0) }
        ))
    }

    private func routeCard(_ route: PublicRouteBrowseSummary) -> some View {
        RouteBusinessComponents.RouteScene(
            projection: RouteSceneProjection(
                routeID: route.routeId,
                coverAvailable: false,
                name: route.name,
                region: route.region,
                difficulty: route.difficulty,
                metrics: [
                    route.distance.map {
                        MetricItemModel(
                            id: "distance",
                            value: distanceText($0.meters),
                            label: "距离"
                        )
                    },
                    route.ascent.map {
                        MetricItemModel(
                            id: "ascent",
                            value: metersText($0.meters),
                            label: "累计爬升"
                        )
                    },
                    route.estimatedDuration.map {
                        MetricItemModel(
                            id: "estimated-duration",
                            value: durationText($0.seconds),
                            label: "预计用时"
                        )
                    },
                ].compactMap { $0 }
            ),
            onSelect: { _ in
                onNavigate(.routeDetail(route.routeId))
            }
        ) {
            RouteDeterministicImageSurface(style: .forest)
        }
    }

    /// 当前分页索引：由 activeRouteID 派生；未定位时所有卡保持可见。
    private var activeIndex: Int? {
        viewModel.routes.firstIndex(where: { $0.routeId == activeRouteID })
    }

    /// 可访问性等价动作 `selectAdjacentRoute`：切换相邻路线；首尾不循环，
    /// 越界时按规范公告「已到第一条路线」「已到最后一条路线」。
    private func selectAdjacentRoute(_ offset: Int) {
        guard let currentIndex = viewModel.routes.firstIndex(where: { $0.routeId == activeRouteID }) else {
            return
        }
        let target = currentIndex + offset
        guard viewModel.routes.indices.contains(target) else {
            announce(offset < 0 ? "已到第一条路线" : "已到最后一条路线")
            return
        }
        withAnimation {
            activeRouteID = viewModel.routes[target].routeId
        }
    }

    /// 换页公告：「{路线身份}，第 {当前序号} 条，共 {总数} 条」。
    private func announcePagePosition(routeID: String) {
        guard let index = viewModel.routes.firstIndex(where: { $0.routeId == routeID }) else { return }
        let route = viewModel.routes[index]
        announce("\(route.name)，第 \(index + 1) 条，共 \(viewModel.routes.count) 条")
    }

    private func announce(_ message: String) {
        UIAccessibility.post(notification: .announcement, argument: message)
    }
}

/// 分页可访问性等价动作：多于一务路线时暴露上一条/下一条；单条路线不注册。
private struct RoutePagerAccessibilityActions: ViewModifier {
    let routeCount: Int
    let onAdjacent: (Int) -> Void

    func body(content: Content) -> some View {
        if routeCount > 1 {
            content
                .accessibilityAction(named: Text("上一条路线")) { onAdjacent(-1) }
                .accessibilityAction(named: Text("下一条路线")) { onAdjacent(1) }
        } else {
            content
        }
    }
}

struct RouteCollectionView: View {
    @StateObject private var viewModel: RouteCollectionViewModel
    private let showsBackButton: Bool
    private let onNavigate: (AppDestination) -> Void

    init(
        routeService: RouteService,
        showsBackButton: Bool = true,
        onNavigate: @escaping (AppDestination) -> Void = { _ in }
    ) {
        self.showsBackButton = showsBackButton
        self.onNavigate = onNavigate
        _viewModel = StateObject(wrappedValue: RouteCollectionViewModel(service: routeService))
    }

    var body: some View {
        UtilityPage(
            title: "全部路线",
            showsBackEntry: showsBackButton,
            trailing: IconButtonConfiguration(
                systemName: "magnifyingglass",
                accessibilityLabel: "搜索路线",
                action: { onNavigate(.routeSearch) }
            )
        ) {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                Text("快速扫描和比较 Walk 当前提供的路线")
                    .font(.appCaption)
                    .foregroundStyle(AppColors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                collectionState
                    .frame(maxWidth: .infinity)
            }
            .frame(maxWidth: 600, alignment: .topLeading)
            .frame(maxWidth: .infinity, alignment: .top)
        }
        .navigationBarBackButtonHidden(true)
        .task { await viewModel.loadRoutes() }
    }

    @ViewBuilder
    private var collectionState: some View {
        if viewModel.isLoading && viewModel.routes.isEmpty {
            RouteRowSkeletonList()
        } else if let message = viewModel.errorMessage, viewModel.routes.isEmpty {
            ErrorView(
                message: "不会使用缓存或猜测路线替代。",
                title: "暂时无法加载全部路线",
                variant: .section
            ) {
                Task { await viewModel.retry() }
            }
            .frame(minHeight: 360)
        } else if viewModel.routes.isEmpty {
            EmptyStateView(
                title: "当前暂无可选择路线",
                message: "路线准备完成后会出现在这里。",
                icon: "route",
                variant: .default
            )
            .frame(maxWidth: .infinity, minHeight: 360, alignment: .center)
        } else {
            LazyVStack(spacing: Spacing.md) {
                ForEach(viewModel.routes) { route in
                    RouteBusinessComponents.RouteListRow(
                        projection: .browse(
                            RouteBrowseRowProjection(
                                routeID: route.routeId,
                                coverAvailable: false,
                                name: route.name,
                                region: route.region,
                                difficulty: route.difficulty,
                                distance: route.distance.map { distanceText($0.meters) },
                                ascent: route.ascent.map { "爬升 \(metersText($0.meters))" },
                                estimatedDuration: route.estimatedDuration.map { "约 \(durationText($0.seconds))" }
                            )
                        ),
                        onSelect: { routeID in
                            onNavigate(.routeDetail(routeID))
                        }
                    ) {
                        RouteDeterministicImageSurface(style: .forest)
                    }
                }
            }
        }
    }
}

struct RouteSearchView: View {
    /// S5：会话状态由 App 层持有，返回后再进恢复 query 与结果；预览/独立使用时用 convenience init 自建。
    @ObservedObject private var viewModel: RouteDiscoveryViewModel
    @Binding private var query: String
    private let ownsModel: Bool
    @State private var localQuery = ""
    private let onNavigate: (AppDestination) -> Void

    init(
        model: RouteDiscoveryViewModel,
        query: Binding<String>,
        onNavigate: @escaping (AppDestination) -> Void
    ) {
        _viewModel = ObservedObject(wrappedValue: model)
        _query = query
        ownsModel = false
        self.onNavigate = onNavigate
    }

    init(
        routeService: RouteDiscoveryServicing,
        onNavigate: @escaping (AppDestination) -> Void = { _ in }
    ) {
        _viewModel = ObservedObject(wrappedValue: RouteDiscoveryViewModel(service: routeService))
        _query = .constant("")
        ownsModel = true
        self.onNavigate = onNavigate
    }

    private var boundQuery: Binding<String> {
        ownsModel ? $localQuery : $query
    }

    var body: some View {
        UtilityPage(
            // 标题与 sticky 输入区由 hero 固定头部承载，结果列表是唯一滚动区
            // （PAGE-SEARCH：不让结果滚动带走输入区）。
            hero: {
                VStack(alignment: .leading, spacing: 0) {
                    PageTitleBlock(title: "路线搜索")
                    searchInputRegion
                }
                .padding(.top, Spacing.navBarHeight)
            }
        ) {
            searchState
                .frame(maxWidth: .infinity)
                .frame(minHeight: 320, alignment: .top)
                .frame(maxWidth: 600, alignment: .topLeading)
                .padding(.bottom, Spacing.xxl)
        }
        .navigationBarBackButtonHidden(true)
        .task(id: boundQuery.wrappedValue) {
            await viewModel.search(query: normalizedQueryIsEmpty(boundQuery.wrappedValue) ? nil : boundQuery.wrappedValue)
        }
    }

    private var searchInputRegion: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            SearchField(
                text: boundQuery,
                placeholder: "输入路线名称或地区",
                onSubmit: submitSearch
            )
            .background(SearchFocusActivator(placeholder: "输入路线名称或地区"))

            Text("只搜索 Walk 当前提供的徒步路线")
                .font(.appCaption)
                .foregroundStyle(AppColors.textWeak)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, Spacing.pageHorizontal)
        .padding(.top, Spacing.sm)
        .padding(.bottom, Spacing.lg)
        .background(AppColors.pageBase.opacity(0.96))
    }

    @ViewBuilder
    private var searchState: some View {
        if viewModel.isLoading {
            RouteRowSkeletonList()
        } else if let message = viewModel.errorMessage {
            ErrorView(
                message: "已保留关键词，不会用猜测结果替代。",
                title: "暂时无法搜索路线",
                variant: .section,
                retryTitle: "重新搜索"
            ) {
                submitSearch()
            }
        } else if viewModel.searchState == .initial {
            EmptyStateView(
                title: "输入名称或地区",
                message: "初始状态不展示默认结果。",
                icon: nil,
                variant: .compactText
            )
            .padding(.top, Spacing.xxxl)
        } else if viewModel.searchResults.isEmpty {
            EmptyStateView(
                title: "未找到路线",
                message: "Walk 当前没有找到相关路线",
                icon: nil,
                variant: .compactText
            )
            .padding(.top, Spacing.xxxl)
        } else {
            LazyVStack(spacing: Spacing.md) {
                ForEach(viewModel.searchResults) { route in
                    RouteBusinessComponents.SearchRouteResultRow(
                        projection: SearchRouteResultRowProjection(
                            routeID: route.routeId,
                            coverAvailable: nonEmpty(route.cover) != nil,
                            name: route.name,
                            region: route.region,
                            difficulty: route.difficulty,
                            distance: route.distance.map { distanceText($0.meters) },
                            estimatedDuration: route.estimatedDuration.map { "约 \(durationText($0.seconds))" }
                        ),
                        onSelect: { routeID in
                            onNavigate(.routeDetail(routeID))
                        }
                    ) {
                        RouteArtworkView(cover: route.cover)
                    }
                }
            }
        }
    }

    /// S4：submit 立即提交同一 query，不经防抖。
    private func submitSearch() {
        Task { await viewModel.search(query: boundQuery.wrappedValue, immediate: true) }
    }

    private func normalizedQueryIsEmpty(_ value: String) -> Bool {
        value.unicodeScalars.allSatisfy { scalar in
            switch scalar.value {
            case 0x20, 0x09, 0x0A, 0x0D, 0x3000: true
            default: false
            }
        }
    }
}

private struct SearchFocusActivator: UIViewRepresentable {
    let placeholder: String

    func makeUIView(context: Context) -> FocusProbeView {
        FocusProbeView(placeholder: placeholder)
    }

    func updateUIView(_ view: FocusProbeView, context: Context) {
        view.placeholder = placeholder
        view.requestFocus()
    }

    final class FocusProbeView: UIView {
        var placeholder: String
        private var didRequestFocus = false

        init(placeholder: String) {
            self.placeholder = placeholder
            super.init(frame: .zero)
            isUserInteractionEnabled = false
        }

        @available(*, unavailable)
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        override func didMoveToWindow() {
            super.didMoveToWindow()
            requestFocus()
        }

        func requestFocus() {
            guard window != nil, !didRequestFocus else { return }
            didRequestFocus = true
            DispatchQueue.main.async { [weak self] in
                guard let self,
                      let textField = self.window?.firstTextField(placeholder: self.placeholder) else { return }
                textField.becomeFirstResponder()
            }
        }
    }
}

private extension UIView {
    func firstTextField(placeholder: String) -> UITextField? {
        if let textField = self as? UITextField, textField.placeholder == placeholder {
            return textField
        }
        for subview in subviews {
            if let match = subview.firstTextField(placeholder: placeholder) { return match }
        }
        return nil
    }
}

private struct RouteSceneSkeleton: View {
    var body: some View {
        ZStack(alignment: .bottomLeading) {
            LinearGradient(
                colors: [AppColors.surfacePrimary, AppColors.pageBase],
                startPoint: .top,
                endPoint: .bottom
            )

            VStack(alignment: .leading, spacing: Spacing.lg) {
                Spacer()
                RoundedRectangle(cornerRadius: Radius.sm)
                    .fill(AppColors.surfaceGlass)
                    .frame(width: 228, height: 34)
                HStack(spacing: Spacing.xl) {
                    ForEach(0..<3, id: \.self) { _ in
                        RoundedRectangle(cornerRadius: Radius.sm)
                            .fill(AppColors.surfaceGlass)
                            .frame(width: 68, height: 36)
                    }
                }
            }
            .padding(.horizontal, Spacing.pageHorizontal)
            .padding(.bottom, Spacing.xl)
        }
        .accessibilityLabel("路线加载中")
    }
}

private struct RouteRowSkeletonList: View {
    var body: some View {
        VStack(spacing: Spacing.md) {
            ForEach(0..<3, id: \.self) { _ in
                RouteListRow(title: " ") {
                    RouteThumbnailPlaceholder(systemImage: "map")
                } metadata: {
                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        RoundedRectangle(cornerRadius: Radius.sm)
                            .fill(AppColors.surfaceDivider)
                            .frame(width: 110, height: 10)
                        RoundedRectangle(cornerRadius: Radius.sm)
                            .fill(AppColors.surfaceDivider)
                            .frame(width: 150, height: 10)
                    }
                }
                .redacted(reason: .placeholder)
                .accessibilityLabel("路线加载中")
            }
        }
    }
}

private struct RouteArtworkView: View {
    let cover: String?

    var body: some View {
        Group {
            if let value = cover, let url = URL(string: value) {
                AsyncImage(url: url) { phase in
                    if let image = phase.image {
                        image.resizable().scaledToFill()
                    } else {
                        neutralTerrain
                    }
                }
            } else {
                neutralTerrain
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
    }

    private var neutralTerrain: some View {
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

private func nonEmpty(_ value: String?) -> String? {
    guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else {
        return nil
    }
    return value
}

private func distanceText(_ meters: Double) -> String {
    if meters >= 1_000 {
        return "\((meters / 1_000).formatted(.number.precision(.fractionLength(0...1)))) km"
    }
    return metersText(meters)
}

private func metersText(_ meters: Double) -> String {
    "\(meters.formatted(.number.precision(.fractionLength(0...1)))) m"
}

private func durationText(_ seconds: Double) -> String {
    let hours = seconds / 3_600
    if hours >= 24 {
        return "\((hours / 24).formatted(.number.precision(.fractionLength(0...1)))) 天"
    }
    return "\(hours.formatted(.number.precision(.fractionLength(0...1)))) 小时"
}

#if DEBUG
#Preview("Route Discovery") {
    NavigationStack { RouteDiscoveryView(routeService: PreviewHelpers.routeService) }
}
#endif
