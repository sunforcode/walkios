# Flutter Visual Parity Implementation Plan

**Goal:** 让原生 iOS 项目的导航模型、设计令牌、共享状态组件和核心业务页面与当前 Flutter 实现一致，而不是维持通用 SwiftUI 模板风格。

**Architecture:** Flutter 源码是视觉与信息架构基准。iOS 保持 SwiftUI + MVVM，但将根导航改为“首页枢纽 + 左侧抽屉 + NavigationStack”，并按 Flutter 的 immersive / utility 两类页面实现。UIKit 仅继续用于 MapKit 包装。

**Tech Stack:** SwiftUI、MapKit、Alamofire、XcodeGen、XCTest。

## 对标基准

- 导航壳：`walk/lib/theme/main_layout.dart`、`walk/lib/ui/page/drawer/walk_drawer.dart`
- 权威令牌：`walk/lib/theme/tokens/colors.dart`、`spacing.dart`、`radius.dart`、`typography.dart`、`shadows.dart`
- 行程：`walk/lib/ui/page/trip/trip_list_screen.dart`、`trip_detail_screen.dart`
- 路线：`walk/lib/ui/page/route/route_discovery_screen.dart`、`route/detail/route_detail_screen.dart`
- 攻略：`walk/lib/ui/page/home/widgets/hiking_guides_section.dart`、`guide/cards/guide_card.dart`、`guide_detail_screen.dart`
- 装备：`walk/lib/ui/page/equipment/equipment_list_list_screen.dart`、`equipment_list_detail_screen.dart`
- 个人中心：`walk/lib/ui/page/profile/profile_screen.dart` 及其 widgets

## 实施任务

- [ ] 1. 将 iOS 色彩、字号、间距、圆角、阴影令牌改为 Flutter 的精确值，移除不存在的 Asset Color 依赖。
- [ ] 2. 新增 UtilityPage、ImmersivePage、GlassIconButton、WalkPanel、WalkPill 等共享原语，并统一加载、错误、空状态。
- [ ] 3. 将 RootView 从五 Tab 改为首页枢纽 + 280pt 左侧抽屉；抽屉提供路线、行程、攻略、装备和个人中心入口。
- [ ] 4. 将路线发现改为沉浸式径向深绿背景、大标题和单列 Hero 卡；详情保留 MapKit 并对齐地图 + 亮色信息抽屉。
- [ ] 5. 将行程列表改为深色 utility 页面、120pt 封面区、信息胶囊和语义状态徽标；详情使用地图/封面头部和分区面板。
- [ ] 6. 将攻略卡片改为图片主导、圆角 16、作者/阅读/点赞元信息结构；详情补齐固定操作栏视觉。
- [ ] 7. 将装备入口改为“多装备清单列表 → 清单详情”的 Flutter 信息架构；清单详情保留可勾选装备项。
- [ ] 8. 将个人中心改为 utility 深色页面，覆盖未登录/已登录、用户卡、统计卡、功能与设置列表。
- [ ] 9. 运行 XcodeGen、Debug/Release 构建和单元测试，并检查无图片、长标题、小屏、安全区状态。
