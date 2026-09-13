import SwiftUI
import UIKit
import WalkData
import WalkDesignSystem

// MARK: - View

/// PAGE-TRIP-BROWSE 逐日阅读：一日一页的嵌套滚动容器——
/// 外层纵向分页 CollectionView（一日一页，isPagingEnabled）+ 内层日内容 CollectionView（页内滚动）；
/// 内层滚动到边界后继续拖拽，由外层自然接管翻页；首尾不循环。
struct TripBrowseView: View {
    let tripID: String
    let initialDayNumber: Int
    @StateObject private var viewModel: TripBrowseViewModel
    @State private var dayIndex = 0
    @Environment(\.dismiss) private var dismiss

    init(
        tripID: String,
        service: any PersonalTripServicing,
        initialDayNumber: Int
    ) {
        self.tripID = tripID
        self.initialDayNumber = initialDayNumber
        _viewModel = StateObject(wrappedValue: TripBrowseViewModel(service: service))
    }

    init(
        tripID: String,
        viewModel: TripBrowseViewModel,
        initialDayNumber: Int = 1
    ) {
        self.tripID = tripID
        self.initialDayNumber = initialDayNumber
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        // 自定义承载（对比路线详情页同款结构）：分页容器全屏铺底，
        // 浏览头仅悬浮返回入口，不单独占条；隐藏系统导航栏。
        ZStack(alignment: .top) {
            stateContent
            browseHeader
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppColors.pageBase.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .task {
            guard viewModel.pages.isEmpty, viewModel.trip == nil else { return }
            await viewModel.loadTrip(id: tripID)
            dayIndex = viewModel.initialDayIndex(dayNumber: initialDayNumber)
        }
    }

    // MARK: 状态

    @ViewBuilder
    private var stateContent: some View {
        if viewModel.errorMessage != nil, viewModel.trip == nil {
            ErrorView(
                message: "不会用其他行程或当前公开路线补齐。",
                title: "暂时无法加载行程",
                variant: .page,
                retry: { Task { await viewModel.loadTrip(id: tripID) } }
            )
        } else if viewModel.isLoading, viewModel.trip == nil {
            LoadingView(message: "正在加载逐日安排", variant: .page)
        } else if viewModel.trip != nil {
            if viewModel.pages.isEmpty {
                EmptyStateView(
                    title: "暂无可阅读的自然日",
                    message: "不会根据起止日期或默认模板补造自然日。",
                    icon: "calendar",
                    variant: .default
                )
            } else {
                TripBrowsePagerView(
                    pages: viewModel.pages,
                    initialIndex: viewModel.initialDayIndex(dayNumber: initialDayNumber),
                    dayIndex: $dayIndex
                )
                .accessibilityIdentifier("baseline.trip-browse.pager")
            }
        } else {
            LoadingView(message: "正在加载逐日安排", variant: .page)
        }
    }

    // MARK: 浏览头：悬浮返回入口 + 当前日身份标题（紧凑单行，对比路线详情页工具条）

    private var browseHeader: some View {
        HStack(alignment: .center, spacing: Spacing.md) {
            IconButton(
                systemName: "chevron.left",
                accessibilityLabel: "返回",
                variant: .overlay,
                action: { dismiss() }
            )

            if let page = currentBrowsePage {
                HStack(alignment: .center, spacing: Spacing.sm) {
                    Text("D\(page.dayNumber)")
                        .font(.sequenceCompact)
                        .foregroundStyle(AppColors.interactionPrimary)
                        .frame(width: 34, height: 34)
                        .background(
                            AppColors.interactionBackground,
                            in: RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                        )

                    VStack(alignment: .leading, spacing: Spacing.xs) {
                        HStack(alignment: .firstTextBaseline, spacing: Spacing.sm) {
                            Text(page.date)
                                .font(.dateTitle)
                                .foregroundStyle(AppColors.textPrimary)
                                .lineLimit(1)
                            if let hikingDayNumber = page.hikingDayNumber {
                                TripBusinessComponents.TrekDayBadge(
                                    projection: TrekDayBadgeProjection(
                                        trekDayNumber: hikingDayNumber,
                                        totalTrekDays: page.totalTrekDays
                                    )
                                )
                            }
                        }
                        Text(page.primaryStage)
                            .font(.listTitle)
                            .foregroundStyle(AppColors.textPrimary)
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }
                }
                .accessibilityElement(children: .combine)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, Spacing.pageHorizontal)
        .padding(.top, Spacing.sm)
        .padding(.bottom, Spacing.xs)
        .accessibilityElement(children: .contain)
    }

    private var currentBrowsePage: TripBrowsePage? {
        guard viewModel.pages.indices.contains(dayIndex) else { return nil }
        return viewModel.pages[dayIndex]
    }
}

// MARK: - 嵌套分页容器（UIViewControllerRepresentable）

/// 外层纵向分页 CollectionView 一日一页；内层日内容 CollectionView 页内滚动。
/// 日索引由外层滚动位置驱动回传 SwiftUI（浏览头日位置），外部索引变化时定位对应分页。
struct TripBrowsePagerView: UIViewControllerRepresentable {
    let pages: [TripBrowsePage]
    let initialIndex: Int
    @Binding var dayIndex: Int

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIViewController(context: Context) -> TripBrowsePagerController {
        let controller = TripBrowsePagerController()
        controller.onIndexChange = { index in
            context.coordinator.parent.dayIndex = index
        }
        return controller
    }

    func updateUIViewController(_ controller: TripBrowsePagerController, context: Context) {
        context.coordinator.parent = self
        controller.update(pages: pages, externalIndex: dayIndex)
    }

    final class Coordinator {
        var parent: TripBrowsePagerView

        init(_ parent: TripBrowsePagerView) {
            self.parent = parent
        }
    }
}

// MARK: - 分页控制器（外层）

final class TripBrowsePagerController: UIViewController {
    var onIndexChange: ((Int) -> Void)?
    private var pages: [TripBrowsePage] = []
    private var currentIndex = 0
    private var lastAppliedIndex: Int?

    private lazy var outerLayout: UICollectionViewFlowLayout = {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .vertical
        layout.minimumLineSpacing = 0
        layout.minimumInteritemSpacing = 0
        return layout
    }()

    private lazy var outerCollectionView: UICollectionView = {
        let view = UICollectionView(frame: .zero, collectionViewLayout: outerLayout)
        view.isPagingEnabled = true
        view.showsVerticalScrollIndicator = false
        view.backgroundColor = .clear
        view.register(DayPageCell.self, forCellWithReuseIdentifier: DayPageCell.reuseIdentifier)
        view.dataSource = self
        view.delegate = self
        return view
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
        view.addSubview(outerCollectionView)
        outerCollectionView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            outerCollectionView.topAnchor.constraint(equalTo: view.topAnchor),
            outerCollectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            outerCollectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            outerCollectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        ])
    }

    /// SwiftUI 侧更新：数据变化整表重载并定位；仅索引变化（外部驱动）时翻页。
    func update(pages newPages: [TripBrowsePage], externalIndex: Int) {
        let needsReload = newPages != pages
        pages = newPages
        guard !pages.isEmpty else {
            currentIndex = 0
            lastAppliedIndex = nil
            outerCollectionView.reloadData()
            return
        }

        if needsReload {
            currentIndex = max(0, min(externalIndex, pages.count - 1))
            lastAppliedIndex = currentIndex
            outerCollectionView.reloadData()
            DispatchQueue.main.async { [weak self] in
                guard let self, self.pages.indices.contains(self.currentIndex) else { return }
                self.outerCollectionView.scrollToItem(
                    at: IndexPath(item: self.currentIndex, section: 0),
                    at: .top,
                    animated: false
                )
            }
        } else if externalIndex != lastAppliedIndex, pages.indices.contains(externalIndex) {
            // 外部索引驱动（如初始定位）；自身滚动回传的索引已在 lastAppliedIndex 中，不触发二次滚动。
            currentIndex = externalIndex
            lastAppliedIndex = externalIndex
            outerCollectionView.scrollToItem(
                at: IndexPath(item: externalIndex, section: 0),
                at: .top,
                animated: true
            )
        }
    }

    /// 由内层边界越界触发：翻到相邻分页（首尾不循环）。翻页后内层回位由外层滚动接管。
    fileprivate func flipPage(from index: Int, delta: Int) {
        let target = index + delta
        guard pages.indices.contains(target), target != currentIndex else { return }
        currentIndex = target
        lastAppliedIndex = target
        onIndexChange?(target)
        outerCollectionView.scrollToItem(
            at: IndexPath(item: target, section: 0),
            at: .top,
            animated: true
        )
    }

    /// 日尾提示三形态（与 SwiftUI 侧文案一致）。
    fileprivate func boundaryCue(for page: TripBrowsePage) -> String? {
        let isLastPage = page.id == pages.last?.id
        let isFirstPage = page.id == pages.first?.id
        if isFirstPage && isLastPage { return "本次行程只有一天" }
        if isLastPage { return "已到行程最后一天" }
        return "到达底部后继续上滑查看下一日"
    }
}

extension TripBrowsePagerController: UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        pages.count
    }

    func collectionView(
        _ collectionView: UICollectionView,
        cellForItemAt indexPath: IndexPath
    ) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(
            withReuseIdentifier: DayPageCell.reuseIdentifier,
            for: indexPath
        )
        let dayCell = cell as? DayPageCell ?? DayPageCell(frame: cell.frame)
        let page = pages[indexPath.item]
        dayCell.configure(
            page: page,
            pager: self,
            pageIndex: indexPath.item,
            boundaryCue: boundaryCue(for: page)
        )
        return dayCell
    }

    func collectionView(
        _ collectionView: UICollectionView,
        layout collectionViewLayout: UICollectionViewLayout,
        sizeForItemAt indexPath: IndexPath
    ) -> CGSize {
        collectionView.bounds.size
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        guard scrollView === outerCollectionView, view.bounds.height > 0 else { return }
        let index = Int((scrollView.contentOffset.y / view.bounds.height).rounded())
        let clamped = max(0, min(pages.count - 1, index))
        guard clamped != currentIndex else { return }
        currentIndex = clamped
        lastAppliedIndex = clamped
        onIndexChange?(clamped)
    }
}

// MARK: - 分页单元（外层 cell + 内层日内容）

/// 外层分页单元：承载内层日内容 CollectionView（页内纵向滚动），
/// 滚动到边界后继续拖拽超过阈值时，通知外层翻页（内层回位到边界）。
final class DayPageCell: UICollectionViewCell {
    static let reuseIdentifier = "DayPageCell"
    private static let contentReuseIdentifier = "DayPageCellContent"
    /// 内层边界越界翻页阈值（pt）。
    private static let handoffThreshold: CGFloat = 44

    private var pageIndex = 0
    private var pageContent: TripBrowsePage?
    private var cueText: String?
    private weak var pagerController: TripBrowsePagerController?

    private lazy var innerCollectionView: UICollectionView = {
        var listConfiguration = UICollectionLayoutListConfiguration(appearance: .plain)
        listConfiguration.showsSeparators = false
        let layout = UICollectionViewCompositionalLayout.list(using: listConfiguration)
        let view = UICollectionView(frame: .zero, collectionViewLayout: layout)
        view.backgroundColor = .clear
        view.register(UICollectionViewCell.self, forCellWithReuseIdentifier: Self.contentReuseIdentifier)
        view.dataSource = self
        view.delegate = self
        return view
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        contentView.addSubview(innerCollectionView)
        innerCollectionView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            innerCollectionView.topAnchor.constraint(equalTo: contentView.topAnchor),
            innerCollectionView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            innerCollectionView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            innerCollectionView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(page: TripBrowsePage, pager: TripBrowsePagerController, pageIndex: Int, boundaryCue: String?) {
        self.pageIndex = pageIndex
        self.pageContent = page
        self.cueText = boundaryCue
        self.pagerController = pager
        innerCollectionView.reloadData()
    }

    /// 内层日内容单元格的 SwiftUI 内容（随 reloadData 重建）。
    private var dayContent: UIHostingConfiguration<TripBrowsePageView, EmptyView>? {
        guard let page = pageContent else { return nil }
        return UIHostingConfiguration {
            TripBrowsePageView(page: page, boundaryCue: cueText)
        }
        .margins(.all, 0)
    }
}

extension DayPageCell: UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        1
    }

    func collectionView(
        _ collectionView: UICollectionView,
        cellForItemAt indexPath: IndexPath
    ) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: Self.contentReuseIdentifier, for: indexPath)
        if let content = dayContent {
            cell.contentConfiguration = content
        }
        return cell
    }

    /// 内层边界越界判定：越过底部阈值继续拖拽 → 下一日；越过顶部阈值 → 上一日。
    func scrollViewWillEndDragging(
        _ scrollView: UIScrollView,
        withVelocity velocity: CGPoint,
        targetContentOffset: UnsafeMutablePointer<CGPoint>
    ) {
        let maxOffset = max(0, scrollView.contentSize.height - scrollView.bounds.height)
        let target = targetContentOffset.pointee.y
        if target > maxOffset + Self.handoffThreshold {
            targetContentOffset.pointee.y = maxOffset
            pagerController?.flipPage(from: pageIndex, delta: 1)
        } else if target < -Self.handoffThreshold {
            targetContentOffset.pointee.y = 0
            pagerController?.flipPage(from: pageIndex, delta: -1)
        }
    }
}

// MARK: - 单页内容

/// 单个自然日分页内容：整日内容块（或不可用状态）+ 浏览尾提示；不拆页、不自带滚动，
/// 滚动由内层 CollectionView 承担，翻页由内层边界越界交给外层分页。
/// 日身份区（D 序 + 日期 + 徽章 + 阶段）已上移至悬浮浏览头，随翻页更新。
struct TripBrowsePageView: View {
    let page: TripBrowsePage
    var boundaryCue: String?

    /// 悬浮浏览头侵入内容区的高度净空（对比 RouteDetailLayout.toolbarTop 的承载方式）。
    fileprivate static let headerClearance: CGFloat = 56

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            if page.hasContent {
                TripBusinessComponents.TripDayArrangement(
                    projection: TripDayArrangementProjection(blocks: page.blocks)
                )
            } else {
                UnavailableStateView(
                    title: "该日安排暂不可用",
                    message: "不会根据日期范围或默认模板补造当日内容。",
                    icon: "calendar",
                    variant: .section
                )
            }

            if let boundaryCue {
                Text(boundaryCue)
                    .font(.micro)
                    .foregroundStyle(AppColors.textWeak)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .accessibilityHidden(true)
            }
        }
        .padding(.horizontal, Spacing.pageHorizontal)
        .padding(.top, Self.headerClearance)
        .padding(.bottom, Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(page.date)，第 \(page.dayNumber) 日")
    }
}
