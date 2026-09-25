# W6 整体验收与记录：实施结果

日期：2026-09-25
范围：`specs/README.md` 重构工作拆分 W6（整体验收与记录）
承接：W0–W5

## 结论

W0–W6 全部完成。W6 按 R-VERIFY 的验收面逐项收集了新鲜证据，其中两项此前只有单元层面的证据，这次补齐了正式 App 层面的证据：三种数据模式的端到端行为，以及五个业务域主链路加登录。

**W6 发现并修复了一个真实缺陷**：`real` 模式下，URLSession 自带的 HTTP 缓存会按响应头 `Cache-Control: max-age` 直接返回旧响应，请求根本没有到达服务端，违反 R-CACHE-POLICY「网络优先」和 R-STORAGE「HTTP 客户端不得另外绕过所选策略返回缓存」。W1 的单元测试使用注入的 Session，覆盖不到默认 Session 的配置，所以一直没暴露。现已改为任何模式下 HTTP 客户端都不持有响应缓存，应用响应缓存是唯一的复用来源，并补了回归测试。

平台规范新增「当前架构」一节，逐层列出承载位置与对应的强制测试，并列出全部验收入口。

## 验收证据

环境：iPhone 17 Pro 模拟器 `D48F449A-B85E-4E73-BE25-C8BF6A4BDE44`（iOS 26.5）；视觉基线对比使用 iPhone 17 `774CF7E7-…`。

### 1. 架构依赖

新增 `ArchitectureDependencyTests`（4 项），补齐 R-DEP 中此前没有测试强制的依赖方向：

- WalkData 只依赖 Foundation、Alamofire、CryptoKit、Security，manifest 不声明设计系统或调试工具；
- WalkDesignSystem 只依赖 UI 框架；
- Feature 不创建客户端、存储或认证实例，也不读取 `WalkDataMode`、`AppConfiguration`、`ProcessInfo` 或 Debug 设置；
- 生产依赖只由 `AppEnvironment` 装配。

**反向校验**：人为植入 4 处违规，分别是 Feature 读取模式和环境变量、WalkData import SwiftUI、设计系统 import Combine、App 另一处创建存储。4 项测试全部失败，并准确指出了违规文件，之后删除植入代码。这证明守卫不是恒真的。

加上前几批已有的 `FeatureBoundaryTests`、`DebugToolsBoundaryTests`、`DesignSystemBoundaryTests`，R-DEP 表中的每一行都有对应的自动检查（见平台规范「当前架构」）。

### 2. 三种数据模式 E2E

`scripts/run_data_mode_e2e.sh`：在宿主局域网地址启动受控服务，只在运行期间监听，结束后确认端口已释放。依次以各模式启动正式 App，记录页面实际展示的路线（OCR 识别）、受控服务收到的新增请求数和应用响应缓存文件数。之所以不用 127.0.0.1，是因为真实网络模式按 R-CONFIG 会拒绝 localhost / 127.0.0.1 占位地址。

| 步骤 | UI 测试 | 页面路线（OCR） | 受控服务新增请求 | 应用响应缓存文件 |
|---|---|---|---|---|
| Mock | passed | 长海子 | +0 | 0 → 0 |
| Real | passed | W6 受控服务路线 | +1 | 0 → 1 |
| Real | passed | W6 受控服务路线 | +1 | 1 → 1 |
| RemoteOnly | passed | W6 受控服务路线 | +1 | 1 → 1 |
| RemoteOnlyFromEmpty | passed | W6 受控服务路线 | +1 | 0 → 0 |

逐项对照规范：

- Mock：真实业务请求为 0，不触碰响应缓存。
- Real：网络优先。第二次启动在已有缓存的情况下仍然真实到达服务端（修复前这一步是 +0），并写入应用缓存。
- remoteOnly：真实到达受控服务。在已有缓存时数量不变，从空缓存开始仍为 0，说明它不写应用响应缓存。

这满足 R-VERIFY「remoteOnly 真实到达受控服务的证据；仅有页面显示成功不算证据」。

### 3. HTTP 客户端缓存缺陷

- 发现方式：修复前，real 模式第二次启动时受控服务收到的请求为 +0，页面却显示了受控服务的数据。
- 红测：`HTTPClientCacheBypassTests` 断言任何模式的默认 Session 都没有 `urlCache`，且请求缓存策略为 `reloadIgnoringLocalCacheData`。在 `.enabled` 下断言失败。
- 修复（`AlamofireRemoteAPIClient`）：默认 Session 一律 `urlCache = nil`，使用 `reloadIgnoringLocalCacheData` 和 `ResponseCacher.doNotCache`；每个请求都设置 `cachePolicy = .reloadIgnoringLocalCacheData` 并调用 `cacheResponse(using: .doNotCache)`，注入的 Session 同样适用。remoteOnly 额外发送 `Cache-Control: no-cache, no-store`。
- 验证：红测转绿，全量通过，E2E 两次 real 启动都是 +1。

### 4. 关键流程回归

`scripts/run_key_flow_regression.sh` 会卸载 App 并重置目标模拟器的 Keychain，然后运行 `WalkKeyFlowUITests`，确保每次都从未登录状态开始、显式登录。Keychain 在卸载 App 后仍会保留登录态，W4 记录的临时 UI 脚本失败正是这个原因。

一次走完的链路：路线发现 → 全部路线 → 路线详情 →「立即出发」触发登录 → 登录完成后回到创建行程任务 → 首页焦点行程 → 行程详情 → 行程天气 → 行程装备 → 我的 → 我的装备。

9 张截图经 OCR 逐张确认页面正确，依次为：路线、全部路线、路线详情、生成行程、首页「出发」、贡嘎环线三日计划、行程天气、行程装备、我的、装备与清单。这证明 W4 提取出的认证编排在正式 App 中工作正常：登录后回到发起时的任务继续执行。

### 5. Debug / Release

| 项目 | 结果 |
|---|---|
| WalkTests 全量（经 build.py） | 443 项，0 失败，1 跳过（需要真实后端，与各批一致） |
| WalkBaseline | 通过 |
| WalkDebugTools（摇一摇面板与配置动作） | 通过 |
| Release 归档与隔离检查 | 13 项全部通过 |
| Release Info.plist | `WalkDataMode=real`、`WalkEnvironment=production`、`WalkAPIBaseURL=https://vialu.cn/walkbg/api/v1` |
| 平台登记 / 构建入口 / DebugSwift / UI 对比工具脚本测试 | 通过 |
| `openspec validate --specs --strict`（根仓） | 15/15 通过 |

测试数由 438 增加到 443：新增 `ArchitectureDependencyTests` 4 项和 `HTTPClientCacheBypassTests` 1 项。收尾修复又新增 `RouteDiscoveryAccessibilityTests` 2 项，WalkTests 最终为 445 项，0 失败；关键流程两项 UI 测试均通过。

服务器切换：Debug 设置在服务器维度的写入与解析由 W2、W3 的单元测试和 UI 测试覆盖；三种数据模式 E2E 另外证明了通过启动参数指定的服务地址会被正式 App 真实使用。

## 问题分类

### 本轮（W0–W6）发现并修复

- HTTP 客户端缓存绕过所选策略（W6，见上文）。
- W1 至 W5 各批记录中已修复的问题，见对应记录。

### 存量问题（重构前即存在，本轮没有修复）

1. **路线发现页的路线卡片不在无障碍树中——W6 收尾已修复。**
   - 根因：`.accessibilityHidden(index != activeIndex)` 在 `activeIndex == nil` 时对每张卡片都成立。`activeRouteID` 只在 `onChange(of: routes)` 中初始化，而路线在分页视图挂载前就已加载完成时，这个 onChange 不会触发，于是所有卡片都被隐藏。`d6654ec`（重构前）就是这段相同的代码。
   - 定位：先写失败的 UI 断言 `testDiscoveryCurrentRouteIsAccessible`；再临时去掉隐藏修饰，断言转为通过，由此确认根因。
   - 修复：新增 `hidesFromAccessibility(index:activeIndex:)`，未定位当前页时不隐藏任何卡片；分页挂载时（`onAppear`）同样定位首条路线。补充 2 项单元测试，UI 断言转绿。
   - 视觉：改动前后的发现页截图只有状态栏时钟区域不同（0.08% 像素，y 79–117），页面本身无变化。
   - 关键流程回归已改回直接从发现页卡片进入路线详情。
2. **`DailyWeatherSummaryRow` 的 UI 登记缺口**（W1 记录）：需要走根仓 Change。WalkComponents 组仍因此失败 2 项目录断言（本地 80 / 权威 79），这是唯一剩余的失败。
3. **`WalkTempBugFlowUITests`：已删除。** 它依赖模拟器残留登录态，登录判定也有误，覆盖的场景已由 `WalkKeyFlowUITests` 取代。

### 未验证范围

- **真实后端联调**：`testLiveBackendStatusMigrationAndCancellationFlow` 需要真实后端和账号，本轮一直跳过。三种数据模式 E2E 使用的是受控服务，证明的是客户端行为，不是后端合同。
- **断网回退的端到端验证**：`useCache` 已在单元层面完整验证，但目前没有任何生产端点登记离线资格，正式 App 中没有可观察的离线返回场景。
- **SDK 网络观察**：保持关闭，没有验证它对请求、缓存、认证和取消的影响。
- **签名、真机与分发**：Release 归档不签名，没有验证真机安装、TestFlight 或 App Store 流程。
- **已批准视觉基线**：仓库中缺少 `WalkBaselineGoldens/approved/`。W4 和 W5 只做了改动前后的自对比，没有与已批准基线比较。

## 后续建议

- 补齐已批准视觉基线目录。
- 设计确认过夜点颜色后，只需修改 `color.map.overnight` 的取值。
- 如果要启用离线返回，先在根仓规定离线读取行为，再逐个端点登记离线资格。
