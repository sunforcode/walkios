# W4 App / Feature / Service 整理：实施结果

日期：2026-09-25
范围：`specs/README.md` 重构工作拆分 W4（App / Feature / Service 整理）
承接：W3（DebugTools 接入）

## 结论

W4 把 R-DEP 规定的依赖边界落实成了可以自动检查的代码结构。盘点时发现 31 处越界引用：Feature 之间互相引用内部类型，或者 Feature 引用了 App 的类型。这些已全部消除，并由新增的 `FeatureBoundaryTests` 持续把关。

另外三件事：`RootView` 里的认证编排提取成了可单独测试的状态机；只剩测试在用的遗留行程数据链路和其他死代码已删除；页面视觉逐像素没有变化。

用户对本批的两项决定：

- `Features/Shared` 只放被两个及以上业务域使用的导航意图、投影、业务组件和格式化工具，不放页面和 ViewModel。
- 依赖旧模型的测试随旧模型一起删除。其中「旧格式天气响应不能冒充新合同」这层保护本身只依赖新模型，所以保留下来并改了名。

## 盘点结论

Feature 层整体是健康的：没有自己创建客户端，不读取运行模式，也不直接调用 API；除 `RouteDiscoveryView` 外，都通过 Service 协议取数据。本批处理的问题都是依赖方向上的越界，不是职责混乱。

`RouteDetailViewModel` 有 1455 行，但职责单一。规范明确不以文件长度作为拆分依据，所以本批没有拆它。

## 切片与证据

### 1. 边界测试

新增 `Walk/Tests/StructureTests/FeatureBoundaryTests.swift`，包含两条断言：

- Feature 只能引用本域和 `Shared` 的顶层类型，`Shared` 不得引用任何业务域；
- Feature 不得引用 `Walk/App` 下的类型（`Baseline/` 和 `Debug/` 除外）。

红测列出了 31 处违规，和盘点结果一致。

### 2. 导航合同与常量归位

| 内容 | 原位置 | 新位置 |
| --- | --- | --- |
| `PendingAuthIntent`、`AppDestination`（跨域导航意图） | `App/RootNavigation.swift` | `Features/Shared/Navigation/AppDestination.swift` |
| 触控下限 44pt | `RootNavigation.toolButtonHitSize` | `Features/Shared/Navigation/HitTarget.swift` |
| `HomeStyle` | `App/RootNavigation.swift` | `Features/Home/HomeStyle.swift` |
| `EntryPageContract` | `App/RootNavigation.swift` | `Features/Profile/EntryPageContract.swift` |

关于触控下限：它来自 `docs/ui/app-structure.md`「触控目标至少 44 × 44 pt」，是 App 结构规则，不是 Design Token。平台仓不能自行新增 Token，所以它没有进 WalkDesignSystem，而是作为共享常量放在 Shared；`RootNavigation.minimumHitSize` 改为引用这个常量，原有调用方式不变。

`AppShellState` 和 `RootNavigation`（任务栈与外观）继续留在 App 层。

### 3. 跨域组件归入 Shared

新建 `SharedBusinessComponents` 命名空间，迁入以下内容：

- 组件：`GenerationRouteSummaryCard`、`GenerationEquipmentSelection`、`GenerationWaitingView`、`TransportOptionSelection`（原属 Routes，只有 Trips 在用）；`TripCalendarCard`、`HeatmapCalendar`（原属 Trips，Profile 在用）；`InlineEquipmentEditor`（原挂在 Profile 的命名空间下，Trips 在用）。
- 从其他文件中抽出的类型：`AccountEquipmentFormatting`（原在 `EquipmentListRow.swift` 里，三个域都在用）、`RouteGenerationEligibilityPresentation`（原在 `RouteDetailViewModel.swift` 里，Routes 和 Trips 都在用）、`RouteWrapLayout`（布局辅助，不是组件，Routes 和共享生成卡都在用）。

组件 ID、行为和视觉都没有变化。`specs/README.md` 的组件登记路径、测试中的源码路径和组件目录的类型引用都已同步更新，平台登记测试通过。

### 4. 认证编排提取

新增 `Walk/App/AuthenticationFlow.swift`，是一个值类型状态机。它持有待处理意图、来源 tab 和焦点行程确认结果，对外输出三种效果：不做事、弹出登录、在指定 tab 执行意图。`RootView` 原来的 4 个认证相关 `@State` 合并成 1 个，只负责把效果翻译成弹出登录或执行意图。

`AuthenticationFlowTests` 6 项通过，覆盖以下场景：

- 已登录时直接执行，不弹登录；
- 未登录时弹出登录，并记住发起时的 tab；
- 登录完成后回到发起时的 tab 继续，即使期间切换过 tab；
- 取消登录后丢弃意图和确认结果，之后再完成也不会执行旧意图；
- 被动重新认证总是弹出登录；
- 首页「开始」只消费已确认的焦点结果，且只消费一次。

原先检查 RootView 源码字符串的两条断言，已随新写法更新。

### 5. 死代码与遗留模型

删除的文件都没有生产调用方：

- 遗留行程链路：`LegacyTripModels.swift`（旧 `TripAPI`、DTO、`Page`）、`LegacyTripRepository.swift`、`Trip.swift`、`TripStatus.swift`；Mock 中的 `tripFixtures` 和两份打包的旧 JSON；4 份测试 fixture；`MockData.swift`。
- 其他死代码：`RootViewModel.swift`（只有测试在用），`TripRowView.swift`（里面的封面组件和 `TripLayout` 常量都没人用）。

删除的测试都绑定在上述旧类型上：6 个旧行程链路用例，以及 1 个只校验未使用常量的用例。

保留下来的两处调整：

- `testLegacyTripWeatherResponseDoesNotDecodeAsCurrentContract` 改名为 `testRetiredWeatherResponseShapeDoesNotDecodeAsCurrentContract`。它只把旧格式 JSON 交给新的 `PersonalTripAPI.Weather`，断言解码失败，本身不依赖任何旧类型。
- 新数据访问层的隔离检查补充了两条断言：不得引用旧 `TripAPI.` 和 `TripResponseDTO`。其中 `TripAPI.` 用前置字母边界匹配，避免误判 `PersonalTripAPI.`。

`RouteDiscoveryView` / `RouteCollectionView` 改为依赖 `RouteDiscoveryServicing` 协议，不再依赖具体类 `RouteService`。

## 验证

| 项目 | 结果 |
| --- | --- |
| WalkTests 全量 | 436 项，0 失败，1 跳过（需要真实后端，与此前各批一致） |
| 视觉对比 | W4 前（`4638b3c`）与 W4 后在同一台 iPhone 17 / iOS 26.5 上各截 6 个 PAGE-TRIPS 场景，像素差异全部为 0.000% |
| Release 归档与隔离检查 | 13 项全部通过 |
| 平台登记测试 | 通过 |

测试数从 435 变为 436：新增 `FeatureBoundaryTests` 2 项和 `AuthenticationFlowTests` 6 项；删除旧行程链路 6 项和死常量 1 项。

视觉对比说明：仓库里约定的已批准基线目录 `WalkBaselineGoldens/approved/iphone-17-ios-26.5` 并不存在，所以没有和已批准基线比，而是用临时 worktree 在同一设备上拍了改动前后两组截图直接比较。这证明 W4 没有改变这 6 个场景的视觉，但不能替代已批准基线的验收。

### WalkComponents 组

4 项失败，均与 W4 无关：

- 2 项组件目录断言（本地 80 / 权威 79）：这是 W1 就记录的 `DailyWeatherSummaryRow` UI 登记缺口。
- 2 项 `WalkTempBugFlowUITests`：在 W4 之前的提交 `4638b3c` 上复跑，失败完全相同。

这两项临时 UI 测试的原因已经查明：用例用 `label CONTAINS '行程日历'` 判断「已登录」，但未登录时我的页的引导按钮文案里也含「行程日历」，于是用例跳过了登录，后面找不到行程行（失败时的 UI 层级快照可以直接证实）。它们在 W1 能通过，是因为模拟器 Keychain 里还留着早先手动运行时存下的 `auth_token` 登录态；W2 更换认证命名空间（已批准的「升级后需重新登录」）之后，这个隐藏依赖就暴露了。这不是产品回归。该脚本的注释写着「跑完即删」，本批没有修改它。

## 未决与后续

- `WalkTempBugFlowUITests` 依赖模拟器残留登录态，而且登录判定条件有误。建议删除，或者改为显式登录后再作为稳定用例保留。
- 已批准的视觉基线目录缺失，需要单独补齐已批准的截图。
- `DailyWeatherSummaryRow` 的 UI 登记缺口需要走根仓 Change。
- 离线返回能力仍然没有任何生产端点启用；SDK 网络观察仍然关闭。

## 下一批

W5：整理共用基建归属，包括 WalkDesignSystem、Support，以及认证和系统适配入口；只处理有明确收益的重复或越界。
