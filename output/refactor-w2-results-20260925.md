# W2 App 配置与依赖装配：实施结果

日期：2026-09-25
范围：`specs/README.md` 重构工作拆分 W2（App 配置与依赖装配）
承接：W1（数据能力与缓存）

## 结论

W2 四个切片均已完成，每个切片都先写失败测试再实现。App 现在分别解析数据模式、服务器身份和执行上下文三个维度，按规范优先级冻结为一次启动的有效配置，再用这份配置统一生成客户端、缓存和认证依赖。

WalkTests 共 414 项，0 失败，1 跳过。W0 留下的两项 `-WalkDataMode` 启动参数红测已经转绿。

**范围前提**：用户确认现有登录态、Debug 设置和启动键都是临时状态，可以直接修改。因此本批没有保留旧启动键的兼容别名，没有迁移旧 Debug 预设，也没有迁移旧登录态。旧键传入时会直接报错，防止被静默忽略。

## 切片与证据

### 1. 配置解析

问题：规范要求的优先级是「启动参数 > 环境变量 > Debug 设置 > 构建配置 > 代码默认值」，但原实现把 UserDefaults 覆盖放在了环境变量前面。原实现还把模式、URL、环境名绑成一个预设，并靠 `WALK_ENVIRONMENT=test` 猜测当前是否在跑测试。

实现：

- `AppConfiguration` 拆分为 `dataMode`、`baseURL` 加 `environmentName`（服务器身份）、`executionContext` 和 `offlinePolicy` 四个字段。其中 `offlinePolicy` 首版固定为 `.fail`。
- 每个维度独立按优先级取值，未被覆盖的维度回落到下一级来源。切换服务器不会改变模式，切换模式也不会改变服务器。
- 执行上下文不再根据服务器名推断：单元测试宿主由系统注入的 `XCTestConfigurationFilePath` 识别，Baseline 由 `-WalkBaselineScenario` 识别。非 `.app` 上下文会忽略个人 Debug 设置。
- 以下显式输入都会报错：未知值、空白值、参数缺值、同一参数出现两次且值不同、退役键（`-DataSourceMode`、`WALK_DATA_SOURCE_MODE`、`WalkDataSourceMode`）、`local`，以及旧值 `remote`。
- Release 只读取构建配置，不读启动参数、环境变量或 Debug 设置，并且要求模式为 `real`。
- 代码默认模式改为 `real`。真实模式（`real` / `remoteOnly`）使用占位地址时报错，不会自动退回 Mock。
- 删除了 WalkData 中的 `DataSourceMode`，App 统一使用 W1 的 `WalkDataMode`。

迁移：`project.yml` 的 Info 键和构建设置改为 `WalkDataMode` / `WALK_DATA_MODE`（Release 的值为 `real`）；4 个测试文件共 8 处启动参数改为 `-WalkDataMode`。

**Run action 的一处调整**：Walk scheme 的 Run action 原来注入了 `WALK_DATA_MODE` 等环境变量。按规范优先级，环境变量高于 Debug 设置，这会让 Debug 页的选择永远不生效，所以我移除了这些注入，默认值改由 Debug 构建配置（mock）提供。**影响**：在 Xcode 里直接 Run，默认进入 Mock，不再是原来的「测试服真实数据」。需要真实数据时，在 Debug 页选择「测试服」，然后重启 App。

红测编译失败（缺少类型）后实现，`AppConfigurationParsingTests` 21 项通过。

### 2. Debug 设置

实现：新增 `DebugSettings`，带版本号，模式与服务器两个维度都可以不设置；`DebugSettingsStore` 以单一记录 `walk.debug.settings` 保存。无法读取的记录、版本更高的记录都会被忽略，不做猜测；旧的 `walk.debug.environment` 不再读取。删除了 `DebugEnvironment` 预设。

Debug 页仍然提供「Mock / 测试服 / 线上」三个快捷项，按两个维度分解后写入新记录。页面显示当前生效值，并在保存值与生效值不同时提示需要重启（R-SWITCH）。按维度分别选择、以及选择 `useCache` 的完整调试界面归 W3。

`DebugSettingsStoreTests` 5 项通过。Release 二进制中检索不到 `DebugSettingsStore`、`DebugEnvironmentView` 和 `walk.debug.settings` 字符串。

### 3. 认证注入

问题：`AuthManager.shared` 的私有初始化器会自己读取 `WALK_DATA_SOURCE_MODE` 来选择 namespace。`HomeViewModel`、`ProfileViewModel`、`RootViewModel`、`AccountService` 的默认参数，以及 `AlamofireRemoteAPIClient` 的默认闭包都指向 `shared`，所以 App 注入的认证实例和实际在用的实例可能不是同一个。

实现：

- 删除 `AuthManager.shared` 和它的自读逻辑。新增 `AuthManager.namespace(for:isMock:)`，以服务身份为基础区分 Mock 与真实。
- 由 `AppEnvironment` 按最终配置创建唯一的认证实例，并注入客户端、`AccountService`、`HomeViewModel`、`ProfileViewModel`。
- 上述类型的认证参数都改为必传，不再保留默认值。`AlamofireRemoteAPIClient` 的 `accessToken` 也改为必传。
- 删除无调用方的 `AuthAdapter`。
- 预览使用独立 Keychain 服务的 `PreviewHelpers.authManager`，不会读写 App 的真实凭据。

触及的 Feature 构造代码只有 `RootView`、`HomeView`、`AccountMenuView`（预览），改动仅限认证依赖的传入方式。

`AuthNamespaceTests` 4 项通过，覆盖以下几点：real 与 remoteOnly 共用会话；Mock 会话独立；同一地址但环境标识不同时隔离；不同主机隔离；账号服务与客户端共用同一注入实例。

**已知影响**：认证 Keychain 键变了，升级后需要重新登录一次。旧键的数据没有删除，只是不再读取。

### 4. real / remoteOnly 装配与启动失效

实现：`AppEnvironment` 对 `real` 和 `remoteOnly` 使用同一个 `AlamofireRemoteAPIClient`，差异只通过 `mode.responseCachePolicy` 与 `mode.effectiveOfflinePolicy(selected:)` 装配。

新增 `ResponseCacheLifecycle`，记录「上次清理之后是否以 remoteOnly 启动过」。以 `real` 启动时，如果这个标记为真，会在创建存储之前同步删除响应缓存目录，保证本次启动的任何请求都读不到旧条目（R-INVALIDATION）。即使中间隔着一次 mock 启动，也不会漏掉。只有 `WalkApp` 在 `.app` 上下文中启用这个生命周期；测试和预览构造的环境不会读写宿主的真实状态。

`ResponseCacheLifecycleTests` 5 项通过。

## 验证

环境：iPhone 17 Pro 模拟器 `D48F449A-B85E-4E73-BE25-C8BF6A4BDE44`，签名参数为 `CODE_SIGN_IDENTITY=-`。

| 项目 | 结果 |
| --- | --- |
| WalkTests 全量 | 414 项，0 失败，1 跳过 |
| WalkBaseline（单元测试 + 截图 UI 测试） | 全部通过，UI 截图用例使用新键启动 |
| Release 构建 | BUILD SUCCEEDED |
| Release Info.plist | `WalkDataMode=real`、`WalkEnvironment=production`，无 `WalkDataSourceMode` |
| Release 二进制 | 不含 Debug 设置与 Debug 页符号 |
| `test_platform_spec_registry.py` | 通过（本记录写入前曾因 `specs/README.md` 链接指向尚不存在的本文件而失败，写入后复跑通过） |
| `test_debugswift_probe_entry.py` | 通过 |
| `test_compare_ui_baseline.py` | 通过 |
| 旧入口检索 | 除退役键拒绝逻辑及其测试外，没有残留 |

跳过项 `testLiveBackendStatusMigrationAndCancellationFlow` 需要真实后端，情况与 W0、W1 相同。

WalkComponents 组本批没有重跑。W1 记录的 `DailyWeatherSummaryRow` UI 登记缺口仍然存在，与本批无关。

## 测试断言的修正

`testDebugRemoteOnlyLaunchModeOverridesMockEnvironment` 原来断言结果为 `.remote`，这会丢失 remoteOnly 的语义，与 R-MODE 冲突，已修正为断言 `.remoteOnly`。这是修正错误的测试预期，不是为了让测试通过而放宽条件。

`AppEnvironmentTests` 中依赖旧模型的用例按新模型重写，覆盖面没有缩减：旧的 `local` 装配用例改由 `AppConfigurationParsingTests` 中的 `unsupportedDataMode` 覆盖；遍历模式装配的用例改为遍历全部三个 `WalkDataMode`。

## 未决与后续

- Debug 页目前只有三个快捷组合。按维度分别选择、选择 `useCache`、清缓存等动作归 W3 的 DebugTools 统一承载。
- `OfflinePolicy` 在配置中固定为 `.fail`，没有开放启动键。
- 离线返回能力仍然没有任何生产端点启用。
- `DailyWeatherSummaryRow` 的 UI 登记缺口需要走根仓 Change。

## 下一批

W3：接入 DebugTools。把 DebugSwift 正式接入 App，调试 UI 改用 W2 的同一配置入口（`DebugSettingsStore` 加有效配置快照）；验证 Debug 可用、Release 隔离，以及观察工具不会改变 remoteOnly 的缓存语义。
