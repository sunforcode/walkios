# W1 数据能力与缓存 — 实施结果

日期：2026-09-25
范围：`specs/README.md` 重构工作拆分 W1（数据能力与缓存）
承接：W0（工程与验证基线、DebugSwift 构建隔离验证）

## 结论

W1 五个切片全部完成，每片先建失败测试再实现。WalkData 从「remote / local / mock 三个并列客户端」
改造为「Mock 与真实两类能力 + 可组合策略」，`fail / useCache`、`real / remoteOnly` 成为数据层
可验证的真实行为。App 侧的配置解析与依赖装配仍归 W2，本批未实现。

**重要边界：本批次没有为任何生产端点开启离线返回。** 上游 `openspec/specs/` 目前不存在离线读取
的行为规定，因此 W1 只建立能力并用测试专用端点验证；`testNoProductionEndpointDeclaresOfflineEligibilityYet`
将这一事实固化为断言。不得将本批次理解为「离线能力已上线」。

## 切片与证据

### 1. 结构化传输错误

问题：`mapTransportError` 把所有 `URLError` 压成 `.transport(String)` 本地化文案，
而 R-CACHE-POLICY 要求断网判定来自结构化原因、不解析文案。不先修此项，`useCache` 无法判断是否该回退。

实现：新增 `APITransportFailure`，分 `notConnected / connectionLost / timedOut / cancelled / other`。
`isDisconnection` 只对前两者为真。展示文案移入 `displayMessage`，与判定依据分离。
`APIClientError.transport` 关联值由 `String` 改为该类型。

踩到的点：Alamofire 主动取消不一定携带 `underlyingError`，仅靠 `URLError` 分支会退化为 `.other`。
补 `error.isExplicitlyCancelledError` 前置判断后正确归类。

红测 3 项编译失败（`APITransportFailure` 不存在）→ 绿测 7/7。

### 2. 缓存记录元数据与服务身份命名空间

问题：`JSONFileAPIStorage` 存裸响应 Data，没有保存时间、Cache-Control、验证器与请求匹配信息；
命名空间只有 schema / environmentName / userID / request，缺服务地址身份。

实现：
- `APIServiceIdentity` 按协议、主机、有效端口、API 基路径构成身份。显式默认端口与省略端口、
  尾斜杠、主机大小写归一化为同一服务；环境名相同但地址不同，或地址相同但环境名不同，都是不同服务。
- `CachedResponseRecord` 带 `formatVersion`，包含 payload、savedAt、请求标识、服务命名空间、
  userID、`APICacheControl`、`APIResponseValidators`。
- 旧的纯 JSON 快照解码为 `.unreadable`，按 R-STORAGE 判定不可用，不做隐式升级；
  高版本记录报 `.unsupportedFormatVersion`，不误报为旧快照。
- `no-store` 作为 RFC 9111 硬约束写入 `isPersistable`，端点保存资格不能覆盖。

注：现有 `DebugEnvironment` 的 testServer 与 production 恰好同地址不同环境名，
是「不能仅比较显示名称」的现成反例，已固化为用例。

红测 9 类编译错误 → 绿测 11/11。

### 3. OfflinePolicy 与端点离线资格

实现：`OfflinePolicy`（`fail` 为默认值）与 `OfflineEligibility`（登记上游依据与有效期）。
`APIRequest.offlineEligibility` 默认 `nil`，所有现有端点自动保持「无离线资格」。

回退严格要求四者同时成立：所选策略为 `useCache`、端点已登记资格、缓存存在且身份匹配未损坏、
仍在有效期内。任一不成立即保留原始连接错误。

已验证不回退的情形：超时、取消、HTTP 503、无缓存、缓存过期、缓存属于其他身份、缓存记录损坏、
端点无资格（即使全局选了 `useCache`）。

红测 15 类编译错误 → 绿测 12/12。

### 4. remoteOnly 真实装配路径与 local 下线

实现：`WalkDataMode`（`mock / real / remoteOnly`，无 `local`）。`real` 与 `remoteOnly` 共用
同一真实实现，差异来自 `responseCachePolicy` 与 `effectiveOfflinePolicy` 的装配。
`remoteOnly` 是模式硬约束：任何所选策略都被压为 `.fail`，不能被注入的默认策略或 DebugTools 覆盖。

对照用例证明差异确实来自装配而非端点：同一端点、同一份合格缓存、同样断网，
`real + useCache` 返回缓存，`remoteOnly` 返回网络错误且 loads 与 saves 均为 0。

`local` 下线：删除 `LocalAPIClient` 与 `localDataNotFound`；`AppEnvironment` 对 `.local`
抛 `AppConfigurationError.unsupportedDataSourceMode`，不静默降级。原先借 `LocalAPIClient`
间接验证「远端确实写了缓存」的 3 处测试，改为直接断言 storage 中的记录内容。

连带影响：`testEnvironmentAssemblesExactlyConfiguredTargetServices` 原本遍历 `allCases`，
现改为只覆盖受支持模式，另加一例断言 `.local` 显式报错。这是 `local` 下线的合理后果，
按新事实调整测试，未恢复旧能力。

红测 10 类编译错误 → 绿测 7/7。

### 5. 修改后失效与结果来源语义

实现：
- `APIResultProvenance`（`remote` / `cache(savedAt:fallbackReason:)`）与 `APIResult`。
  `executeWithProvenance` 成为主实现，`execute` 委托它，每次调用各自携带来源，
  不使用共享的「最后一次请求来源」。
- R-INVALIDATION：成功修改与结果不确定（传输失败、5xx）都触发 `invalidateResponseCache`，
  推进存储世代并清空当前服务与会话的响应缓存。确定性失败（400）不失效。
- 修改响应形状与 GET 缓存不同，成功修改后直接返回，不写入响应缓存（saves 断言为 0）。

踩到的点：并发来源用例最初失败，根因是两个 harness 共用同一个静态 URLProtocol handler，
后构造的覆盖了前者，导致本该断网的请求变成成功。这是测试设计缺陷而非实现缺陷；
改为按 host 注册 handler、每个 harness 使用独立随机 host 后通过。

红测 3 类编译错误 → 绿测 7/7。

## 验证

环境：iPhone 17 Pro 模拟器 `D48F449A-B85E-4E73-BE25-C8BF6A4BDE44`，与 W0 证据环境一致。
沿用 W0 结论使用 `CODE_SIGN_IDENTITY=-`（`CODE_SIGNING_ALLOWED=NO` 会导致 Keychain -34018 假失败）。

| 项目 | 结果 |
| --- | --- |
| WalkTests 全量 | 384 项，1 跳过，2 失败 |
| WalkBaselineTests | 15 项全通过 |
| Release 构建 | BUILD SUCCEEDED |
| `test_platform_spec_registry.py` | 8 项通过 |
| `test_debugswift_probe_entry.py` | 9 项通过 |
| `test_compare_ui_baseline.py` | 9 项通过 |

WalkTests 从 W0 的 340 项增至 384 项，本批新增 44 项。

### 未通过项的归属

两项 WalkTests 失败是 W0 已记录的 `-WalkDataMode` 启动参数红测
（`testDebugMockLaunchModeOverridesRemoteEnvironment`、`testDebugRemoteOnlyLaunchModeOverridesMockEnvironment`）。
启动参数解析归 W2，本批未实现，因此保持失败。**未为了让它们变绿而提前实现解析。**

跳过项 `testLiveBackendStatusMigrationAndCancellationFlow` 需要真实后端，与 W0 一致。

WalkComponents 组 3 项失败，经核查与 W1 无关：
- 2 项目录断言失败源于 `DailyWeatherSummaryRow` 已在平台 `ComponentCatalog.swift` 登记
  但未写入总 UI 索引（本地 80 / 权威 79）。涉及文件均不在 W1 改动清单内。
  这是 UI 对象登记缺口，应走根仓 OpenSpec Change，不属于数据层范围。
- 1 项 UI 用例 `WalkTempBugFlowUITests` 是临时排查脚本，非稳定验收入口。

## 未决与后续

- W1 建立的离线能力当前零生产端点启用。要真正启用，需先在 `openspec/specs/` 确立离线读取的
  行为规定，再按 R-CACHE-VALIDITY 逐端点登记上游依据、有效期与失效事件。
- `AuthManager.shared` 仍自行读环境变量选 namespace，违反 R-AUTH。W1 已把 WalkData 侧做成可注入，
  实际装配改在 W2。
- `DataSourceMode` 枚举仍保留 `.local` 值（配置解析归 W2 迁移），运行期已显式拒绝。
- 缓存记录格式变更使现有本机缓存全部失效，首次启动回落到网络。符合 R-STORAGE 对旧快照的规定。
- `DailyWeatherSummaryRow` 的 UI 登记缺口需单独提 Change。

## 下一批

W2：App 配置与依赖装配。包含启动参数解析（可让上述 2 项红测转绿）、`WalkDataMode` 与
`DataSourceMode` 的收敛、AuthManager 注入化改造。
