# W5 共用基建归属整理：实施结果

日期：2026-09-25
范围：`specs/README.md` 重构工作拆分 W5（共用基建归属整理）
承接：W4（App / Feature / Service 整理）
关联根仓 Change：`add-map-point-category-tokens`

## 结论

W5 把设计系统里混入的业务概念移回了所属 Feature，删除了 4 个没有调用方的类型，补上了 Token 守卫对业务组件目录的漏检，并按上游新增的 Token 统一了两处地图的点位颜色。

新增或加强了 3 条守卫：

- 设计系统公开类型不得以业务域或具体页面命名；
- Feature 源码（含业务组件目录）不得出现数值字面量颜色；
- 字体裸字号检查同样覆盖业务组件目录。

用户对本批的决定：

- 定位权限和 `LocationService` 保留；
- 地图颜色要改；
- 「现在定义标准比定义是什么标准重要」：先确立每个点位类别对应唯一 Token 的结构，取值可以后续再调。过夜点在冻结原型里没有定义，暂时沿用现有生产取值，并在规范中显式标注。

## 盘点结论

基建整体比较干净：WalkDesignSystem 不依赖 WalkData，已登记的 37 个通用组件与上游 ID 一一对应，Release 二进制中没有任何预览、fixture 或组件目录的符号。认证与系统适配入口在 W2 已统一，本批不需要处理。

`SharedPrimitives.swift` 有 1945 行，但内容全部是已登记的通用组件。拆分它只是搬文件，没有实际收益，所以本批不拆。

## 切片与证据

### 1. 根仓 Change：地图点位类别 Token

`openspec/changes/add-map-point-category-tokens/`（proposal + tasks）：

- `docs/ui/tokens.md` 新增 `color.map.keyPoint|interest|camp|overnight|water|supply`，并登记全部地图 Token 的取值与来源。取值来自冻结原型 `5a10c82:app/prototypes/pages/PAGE-ROUTE-DETAIL.css`；原型没有定义的过夜点沿用现值，并标注了来源。
- `route-map/spec.md`：起终点和六类点位改为直接引用 Token；标记内文字使用 `color.text.primary`。

这个 Change 只改 UI 权威文件，没有行为 Delta，因此不带 `specs/` 目录。归档目录中已有 10 个同类先例。行为规范校验 `openspec validate --specs --strict` 为 15/15 通过。单独对这个 Change 做 `openspec validate` 会提示「缺少 delta」，这是 CLI 对纯 UI Change 的固定提示，不是错误。

### 2. 平台 Token 与两处地图统一

- `Color+App.swift` 新增 6 个类别 Token；`mapStart` 由 `statusProgress`（绿）改为 `#2563eb`（蓝）。
- 生产地图 `RouteMapView` 中写死的 6 个颜色改为使用 Token。
- 组件目录里的 `RouteMap` 原来借用 `info`、`statusCompleted`、`interactionPrimary`、`mapRoute` 等语义不相关的 Token，现改为同一组类别 Token；标记文字由 `pageBase` 深色改为 `textPrimary` 白色，和生产地图、原型保持一致。
- 红测：新 Token 不存在，编译失败 → 实现后通过。

**可见变化**，通过组件预览截图对比确认：

- 起点：绿 → 蓝；
- 关键点：浅蓝 → 棕；
- 营地：浅紫 → 紫；
- 水源：浅绿 → 青。

`RouteMap` 预览中共 0.588% 的像素发生变化，全部落在标记区域。生产地图 `RouteMapView` 原本就使用原型色值，所以除起点变蓝外，其余点位颜色不变。截图在 `build/w5-routemap/`。

过程中发现一个问题：改色后第一轮截图里，深色类别底上的 `pageBase` 深色字几乎看不清。查了生产地图和原型，两者都用白字，于是统一为 `textPrimary`，并把这一点写进了规范。

### 3. 设计系统中的业务概念

新增 `DesignSystemBoundaryTests`：按驼峰拆分设计系统公开类型名，不得出现 Route、Trip、Me、Profile、Account、Equipment、Weather、Home、Camp、Hike。红测准确列出了盘点发现的 3 个类型。

| 类型 | 处理方式 |
| --- | --- |
| `RouteListRow`、`RouteThumbnailPlaceholder` | 只有路线发现页的加载骨架在用。移入 `Features/Routes/RouteRowSkeleton.swift`，改名为 `RouteSkeletonRow`、`RouteSkeletonThumbnail`，作为页面私有排版，不建立组件身份，避免和业务组件 `RouteBusinessComponents.RouteListRow` 重名 |
| `MePageBackgroundOverlay` | PAGE-ME 专属背景。移入 `Features/Profile/`，并登记到 Feature 渐变白名单 |

**顺带修正了一处错误的平台登记。** `specs/README.md` 中 `route-list-row` 的承载文件原本写的是设计系统的 `SharedPrimitives.swift`。它能通过校验，只是因为设计系统恰好有一个同名类型。实际的生产承载是 `Walk/Features/Routes/Components/RouteListRow.swift`，现已改正。

### 4. 删除没有调用方的类型

从设计系统删除 `PageHeroHeader`、`GlassIconButton`、`WalkPill`、`Checklist`，共 130 行。它们没有生产调用方，也不在上游通用组件清单中；一并删除了只为构造它们而存在的测试断言。

### 5. Token 守卫漏检

原有的字体检查跳过了 `Features/*/Components/`，理由是页面级规则不约束组件。但 tokens.md 的「使用限制」对页面和组件同样适用，所以新增了 `allFeatureSources()`，专门给 Token 类守卫用，覆盖全部 Feature 源码：

- 新增颜色守卫，拦截 `Color(red:` 和 `UIColor(red:` 数值字面量。数据携带的分段颜色 `colorHex` 属于数据，不在拦截范围内。
- 字体守卫改为同样覆盖业务组件目录，修正了 2 处 `.font(.system(size:))`，改用设计系统已有的 `Font.ornament` 入口，取值不变。

## 验证

| 项目 | 结果 |
| --- | --- |
| WalkTests 全量（经 build.py） | 438 项，0 失败，1 跳过（需要真实后端，与此前各批一致） |
| PAGE-TRIPS 视觉对比 | W5 前（`636a361`）与 W5 后在同一台 iPhone 17 / iOS 26.5 上，6 个场景像素差异全部为 0.000% |
| RouteMap 视觉对比 | 0.588% 像素变化，均为预期的点位颜色和标记文字变化 |
| Release 归档与隔离检查 | 13 项全部通过 |
| Release 定位权限 | 两条 `NSLocation*` 声明仍然存在（按用户决定保留） |
| 平台登记测试 | 通过（修正 `route-list-row` 承载路径后） |
| `openspec validate --specs --strict` | 15/15 通过 |
| 构建入口 / DebugSwift / UI 对比工具测试 | 通过 |

测试数由 436 增加到 438：新增 `DesignSystemBoundaryTests` 2 项、颜色守卫 1 项；删除 `PageHeroHeader` 用例 1 项。

WalkComponents 组本批没有重跑。W1 和 W4 记录的既存问题（`DailyWeatherSummaryRow` 登记缺口、`WalkTempBugFlowUITests` 依赖残留登录态）仍然存在，与本批无关。

## 未决与后续

- 过夜点颜色是暂定值。原型没有定义，需要设计确认后只改 Token 取值，结构不用动。
- `TripWeatherTrendChart` 借用 `color.map.waypoint` 表示降水，属于语义借用，需要另行处理。
- 其余 Token 的逐项分区登记仍然是已知缺口。
- 根仓 Change `add-map-point-category-tokens` 需要用户批准后归档。
- `WalkTempBugFlowUITests` 等待用户决定删除还是改造。

## 下一批

W6：整体验收与记录。汇总架构边界检查、三种数据模式的集成验证、关键流程回归、Debug/Release 分别的证据，并更新当前架构记录。
