# walkios 目录结构

本仓是 Walk 的 SwiftUI 原生 iOS 实现。产品定位、范围与行为规范不在本仓，权威入口见根仓 `docs/README.md` 与 `docs/prd.md`。

## 目录地图

```text
project.yml                  # XcodeGen 工程定义；改源码结构后必须重新 xcodegen generate
Packages/                    # 本地 Swift Package（独立编译，只暴露 public API）
  WalkData/                  # 数据层：Network / API / Persistence / Repositories / Sources(Mock)；不依赖 Features 与 WalkDesignSystem
  WalkDesignSystem/          # 设计系统：Theme(Token) / Components / 通用 fixture；不引用业务模型
Walk/                        # 主 target 源码
  App/                       # App 入口、根导航、环境配置
    Baseline/                # 视觉基线与组件目录基建（基线场景、截图目录、组件清单）
  Features/                  # 页面按业务域组织（Home/Routes/Trips/Equipment/Profile/Navigation）
    <域>/Components/         # 业务组件沉淀在所属域内，由组件目录与基线体系治理
  Support/                   # 跨域工具（LocationService）
  Preview Content/           # SwiftUI Preview 与业务 Mock 数据（通用 fixture 委托给 WalkDesignSystem）
  Resources/                 # Info.plist、本地化、MockAPI 资源
  Tests/                     # 主 target 的单元测试与 Fixtures
Tests/                       # 独立测试 target
  BaselineTests/  BaselineUITests/  ComponentTests/  ComponentUITests/
scripts/                     # UI 基线截图、对比与组件目录捕获脚本
specs/                       # 平台规范：只承接总规范，不新增产品事实（见 specs/README.md）
```

依赖规则：App → Features → WalkData / WalkDesignSystem；WalkData 不依赖 Features 与 WalkDesignSystem，Features 之间禁止横向依赖，WalkDesignSystem 不 import 业务模型。

## 约定

- 工程由 XcodeGen 生成：修改 `project.yml` 或源码目录结构后运行 `xcodegen generate`，不直接编辑 `Walk.xcodeproj`。
- 页面组件归 `Features/<域>/`，跨页面通用组件归 `DesignSystem/Components/`，绑定业务对象的组件沉淀到 `Features/<域>/Components/`；分类标准见根仓 `docs/ui/`。
- 视觉基线证据与脚本输出进入 `build/`（gitignored），已批准的基线资产目录由 `scripts/compare_ui_baseline.py` 定义。
