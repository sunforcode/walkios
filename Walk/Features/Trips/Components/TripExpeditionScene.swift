import SwiftUI
import UIKit
import WalkData
import WalkDesignSystem

/// 艺术底图与数据层分别提供；画面坐标只用于场景示意，绝不作为 GPS 坐标。
struct TripExpeditionSceneProjection: Equatable {
    let assetName: String
    let artwork: TripSceneArtwork
    let routePath: [TripExpeditionScenePoint]
    let landmarks: [TripExpeditionLandmark]
    let elevationProfile: FrozenRouteElevationProfile?
    let elevationTitle: String
    let elevationUnavailableText: String?
    let elevationQualification: String?
    let elevationSourceDescription: String?
    let notices: [String]
    let isOverview: Bool
    let title: String

    init(presentation: TripExpeditionPresentation) {
        assetName = presentation.assetName
        artwork = presentation.artwork
        routePath = presentation.routePath
        landmarks = presentation.landmarks
        elevationProfile = presentation.elevationProfile
        elevationTitle = presentation.elevationTitle
        elevationUnavailableText = presentation.elevationUnavailableText
        let usesReferenceElevation = presentation.selectedDay?.routeGuide?.referenceTrack?.elevationProfile != nil
        elevationQualification = usesReferenceElevation ? presentation.referenceQualification : nil
        elevationSourceDescription = usesReferenceElevation ? presentation.referenceInformationNotices.joined(separator: "，") : nil
        notices = presentation.source.notices.compactMap(Self.noticeText) + presentation.referenceInformationNotices
        isOverview = presentation.selectedDay == nil
        title = presentation.title
    }

    init(assetName: String, routePath: [TripExpeditionScenePoint], landmarks: [TripExpeditionLandmark],
         elevationProfile: FrozenRouteElevationProfile?, elevationUnavailableText: String?,
         notices: [String] = [], isOverview: Bool, title: String) {
        self.assetName = assetName
        self.artwork = .bundledAsset(assetName)
        self.routePath = routePath
        self.landmarks = landmarks
        self.elevationProfile = elevationProfile
        self.elevationTitle = isOverview ? "全程海拔" : "当日海拔"
        self.elevationUnavailableText = elevationUnavailableText
        self.elevationQualification = nil
        self.elevationSourceDescription = nil
        self.notices = notices
        self.isOverview = isOverview
        self.title = title
    }

    private static func noticeText(_ notice: PersonalTripImportantNotice) -> String? {
        guard let content = tripNonEmpty(notice.content.value) else { return nil }
        guard let status = notice.content.confidence?.status else { return content }
        if status == "preliminary" { return "\(content)（初步信息）" }
        guard ["unknown", "missing", "pending_verification", "stale", "unavailable"].contains(status) else { return content }
        return "\(content)（\(TripContentNotice(field: "信息状态", status: status).message)）"
    }
}

/// 图片与人工示意坐标共用居中 aspect-fill 变换，不移动裁切区外的锚点。
struct TripExpeditionSceneGeometry: Equatable {
    let canvasRect: CGRect
    let artRect: CGRect

    init(size: CGSize, imageAspectRatio: CGFloat = 4.0 / 3.0) {
        let width = size.width.isFinite ? max(0, size.width) : 0
        let height = size.height.isFinite ? max(0, size.height) : 0
        canvasRect = CGRect(x: 0, y: 0, width: width, height: height)
        guard width > 0, height > 0 else {
            artRect = .zero
            return
        }
        let ratio = imageAspectRatio.isFinite && imageAspectRatio > 0 ? imageAspectRatio : 4.0 / 3.0
        let artHeight = max(height, width / ratio)
        let artWidth = artHeight * ratio
        artRect = CGRect(x: (width - artWidth) / 2, y: (height - artHeight) / 2,
                         width: artWidth, height: artHeight)
    }

    func point(x: Double, y: Double) -> CGPoint {
        CGPoint(x: artRect.minX + CGFloat(x) * artRect.width,
                y: artRect.minY + CGFloat(y) * artRect.height)
    }

    func labelCenter(x: Double, y: Double, labelSize: CGSize, viewport: CGRect? = nil) -> CGPoint {
        let bounds = viewport ?? canvasRect
        let point = point(x: x, y: y)
        let halfWidth = min(labelSize.width / 2, bounds.width / 2)
        let halfHeight = min(labelSize.height / 2, bounds.height / 2)
        return CGPoint(x: min(max(point.x, bounds.minX + halfWidth), bounds.maxX - halfWidth),
                       y: min(max(point.y + 22, bounds.minY + halfHeight), bounds.maxY - halfHeight))
    }
}

/// 以实际内容和场景视口裁切标注，不读取或计算系统 inset。
struct TripExpeditionSceneViewportKey: PreferenceKey {
    struct Value {
        var scene: Anchor<CGRect>?
        var content: Anchor<CGRect>?
    }

    static var defaultValue: Value { Value() }

    static func reduce(value: inout Value, nextValue: () -> Value) {
        let next = nextValue()
        value.scene = next.scene ?? value.scene
        value.content = next.content ?? value.content
    }
}

extension TripBusinessComponents {
    struct TripExpeditionScene: View {
        let projection: TripExpeditionSceneProjection
        var onActivate: () -> Void = {}
        var onMove: (Int) -> Void = { _ in }
        @Environment(\.dynamicTypeSize) private var dynamicTypeSize

        var body: some View {
            GeometryReader { geometry in
                let isAccessible = dynamicTypeSize.isAccessibilitySize
                let infoWidth = isAccessible
                    ? max(0, geometry.size.width - Spacing.sm * 2)
                    : min(max(0, geometry.size.width - Spacing.sm * 2), min(204, max(180, geometry.size.width * 0.5)))
                ZStack(alignment: .topLeading) {
                    sceneButton(size: geometry.size)
                    information(width: infoWidth)
                        .frame(width: infoWidth, alignment: .leading)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.leading, Spacing.sm)
                        .padding(.top, Spacing.sm)
                }
                .frame(width: geometry.size.width, height: geometry.size.height)
            }
            .anchorPreference(key: TripExpeditionSceneViewportKey.self, value: .bounds) { .init(scene: $0) }
        }

        private func sceneButton(size: CGSize) -> some View {
            Button(action: onActivate) {
                Color.clear
                    .frame(width: size.width, height: size.height)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(accessibilitySummary)
            .accessibilityHint(projection.isOverview ? "轻点进入第一天摘要" : "轻点打开当天安排，左右滑动切换日期")
            .accessibilityIdentifier("trip-expedition-scene")
            .accessibilityAction(named: "上一天") { onMove(-1) }
            .accessibilityAction(named: "下一天") { onMove(1) }
            .highPriorityGesture(
                DragGesture(minimumDistance: 30)
                    .onEnded { value in
                        // 避开左缘系统返回；垂直滑动不解释为切日。
                        guard value.startLocation.x > 24,
                              abs(value.translation.width) > abs(value.translation.height) * 1.3,
                              abs(value.translation.width) > 45 else { return }
                        onMove(value.translation.width < 0 ? 1 : -1)
                    }
            )
        }

        private func information(width: CGFloat) -> some View {
            elevation
                .frame(width: dynamicTypeSize.isAccessibilitySize ? width : min(146, width), alignment: .leading)
                .shadow(color: AppColors.shadowOverlay, radius: 2, y: 1)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(elevationAccessibilitySummary)
                .accessibilityIdentifier("trip-scene-elevation")
                .allowsHitTesting(false)
        }

        /// Page 与独立组件体验共用的唯一图片承载；不包含按钮、提醒或系统 inset 计算。
        struct Artwork: View {
            let projection: TripExpeditionSceneProjection
            var landmarkViewport: CGRect? = nil

            var body: some View {
                GeometryReader { geometry in
                    let bounds = CGRect(origin: .zero, size: geometry.size)
                    let viewport = bounds.intersection(landmarkViewport ?? bounds)
                    Group {
                        switch projection.artwork {
                        case let .bundledAsset(name):
                            if let image = UIImage(named: name) {
                                renderedImage(Image(uiImage: image), size: geometry.size)
                                    .overlay {
                                        if !viewport.isEmpty && !viewport.isNull {
                                            route(
                                                layout: TripExpeditionSceneGeometry(
                                                    size: geometry.size,
                                                    imageAspectRatio: image.size.width / max(image.size.height, 1)
                                                ),
                                                viewport: viewport
                                            )
                                        }
                                    }
                            } else {
                                neutralArtwork
                            }
                        case let .remoteURL(url):
                            AsyncImage(url: url) { phase in
                                if let image = phase.image {
                                    renderedImage(image, size: geometry.size)
                                } else {
                                    neutralArtwork
                                }
                            }
                            .id(url)
                        case .unavailable:
                            neutralArtwork
                        }
                    }
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .clipped()
                }
                .allowsHitTesting(false)
                .accessibilityHidden(true)
            }

            private func renderedImage(_ image: Image, size: CGSize) -> some View {
                image.resizable()
                    .scaledToFill()
                    .frame(width: size.width, height: size.height)
                    .clipped()
            }

            private var neutralArtwork: some View {
                LinearGradient(colors: [AppColors.pageBase, AppColors.pageMiddle, AppColors.pageBase],
                               startPoint: .topLeading, endPoint: .bottomTrailing)
                    .overlay {
                        Image(systemName: "photo")
                            .font(.ornament(40))
                            .foregroundStyle(AppColors.textWeak.opacity(0.35))
                    }
            }

            private func route(layout: TripExpeditionSceneGeometry, viewport: CGRect) -> some View {
                ZStack {
                    let labelWidth = min(112, viewport.width)
                    let path = Path { path in
                        for (index, point) in projection.routePath.enumerated() {
                            let point = layout.point(x: point.x, y: point.y)
                            if index == 0 { path.move(to: point) } else { path.addLine(to: point) }
                        }
                    }
                    path.stroke(AppColors.interactionPrimary.opacity(0.40), lineWidth: 8)
                        .blur(radius: 4)
                    path.stroke(AppColors.interactionPrimary, style: StrokeStyle(lineWidth: 2.2, lineCap: .round, lineJoin: .round))
                    ForEach(projection.landmarks) { landmark in
                        let point = layout.point(x: landmark.x, y: landmark.y)
                        if viewport.insetBy(dx: 6, dy: 6).contains(point) {
                            Circle()
                                .fill(AppColors.pageBase)
                                .frame(width: 12, height: 12)
                                .overlay(Circle().stroke(AppColors.interactionPrimary, lineWidth: 2))
                                .shadow(color: AppColors.interactionPrimary.opacity(0.7), radius: 6)
                                .position(point)
                            Label(landmark.title, systemImage: landmark.symbol)
                                .font(.microStrong)
                                .foregroundStyle(AppColors.textPrimary)
                                .padding(.horizontal, Spacing.sm)
                                .padding(.vertical, Spacing.xs)
                                .background(AppColors.surfaceControlOverlay, in: Capsule())
                                .frame(width: labelWidth)
                                .fixedSize(horizontal: false, vertical: true)
                                .position(layout.labelCenter(
                                    x: landmark.x, y: landmark.y,
                                    labelSize: CGSize(width: labelWidth, height: 36), viewport: viewport
                                ))
                        }
                    }
                }
                .frame(width: layout.canvasRect.width, height: layout.canvasRect.height)
                .mask {
                    Rectangle()
                        .frame(width: viewport.width, height: viewport.height)
                        .position(x: viewport.midX, y: viewport.midY)
                }
            }
        }

        private var elevation: some View {
            VStack(alignment: .leading, spacing: Spacing.xs / 2) {
                Text(projection.elevationTitle)
                    .font(dynamicTypeSize.isAccessibilitySize ? .appCaption : .microStrong)
                    .foregroundStyle(AppColors.textSecondary)
                if let qualification = projection.elevationQualification {
                    Text(qualification)
                        .font(dynamicTypeSize.isAccessibilitySize ? .appCaption : .micro)
                        .foregroundStyle(AppColors.textSecondary)
                }
                if let profile = projection.elevationProfile, profile.samples.count > 1 {
                    GeometryReader { geometry in
                        let points = profilePoints(profile, size: geometry.size)
                        ZStack {
                            Path { path in
                                guard let first = points.first, let last = points.last else { return }
                                path.move(to: CGPoint(x: first.x, y: geometry.size.height))
                                points.forEach { path.addLine(to: $0) }
                                path.addLine(to: CGPoint(x: last.x, y: geometry.size.height))
                                path.closeSubpath()
                            }
                            .fill(LinearGradient(colors: [AppColors.interactionPrimary.opacity(0.25), AppColors.interactionPrimary.opacity(0.02)], startPoint: .top, endPoint: .bottom))
                            Path { path in
                                for (index, point) in points.enumerated() {
                                    if index == 0 { path.move(to: point) } else { path.addLine(to: point) }
                                }
                            }
                            .stroke(AppColors.interactionPrimary, style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
                        }
                    }
                    .frame(height: 22)
                    HStack(spacing: Spacing.xs / 2) {
                        Text("\(String(Int(profile.minElevation.meters)))–\(String(Int(profile.maxElevation.meters)))m")
                        Spacer(minLength: 0)
                        Text("0–\(((profile.samples.last?.distance.meters ?? 0) / 1000).formatted(.number.precision(.fractionLength(0...1))))km")
                    }
                    .font(.micro)
                    .foregroundStyle(AppColors.textPrimary)
                } else {
                    Text(projection.elevationUnavailableText ?? "海拔数据暂不可用")
                        .font(dynamicTypeSize.isAccessibilitySize ? .appCaption : .micro)
                        .foregroundStyle(AppColors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }

        private func profilePoints(_ profile: FrozenRouteElevationProfile, size: CGSize) -> [CGPoint] {
            let first = profile.samples.first?.distance.meters ?? 0
            let span = max((profile.samples.last?.distance.meters ?? 0) - first, 1)
            let low = profile.minElevation.meters
            let high = max(profile.maxElevation.meters - low, 1)
            return profile.samples.map {
                CGPoint(x: ($0.distance.meters - first) / span * size.width,
                        y: (1 - ($0.elevation.meters - low) / high) * (size.height - 2) + 1)
            }
        }

        private var accessibilitySummary: String {
            let landmarks = projection.landmarks.map(\.title).joined(separator: "，")
            return "\(projection.title)，AIGC 场景示意，\(landmarks)"
        }

        private var elevationAccessibilitySummary: String {
            let scope = projection.elevationTitle
            let elevation = projection.elevationProfile.map {
                "海拔 \(Int($0.minElevation.meters)) 至 \(Int($0.maxElevation.meters)) 米，来自冻结行程数据"
            } ?? projection.elevationUnavailableText ?? "海拔不可用"
            return [scope, elevation, projection.elevationQualification, projection.elevationSourceDescription]
                .compactMap { $0 }.joined(separator: "，")
        }
    }
}

#if DEBUG
extension TripExpeditionSceneProjection {
    static let overview = preview(asset: "TripSceneOverview", isOverview: true)
    static let hikingDay = preview(asset: "TripScenePass", isOverview: false)
    static let arrival = TripExpeditionSceneProjection(
        assetName: "TripSceneArrival", routePath: [], landmarks: [], elevationProfile: nil,
        elevationUnavailableText: "交通日 · 无徒步海拔剖面", isOverview: false, title: "向山而行"
    )
    static let unavailable = TripExpeditionSceneProjection(
        assetName: "TripExpeditionCover", routePath: [], landmarks: [], elevationProfile: nil,
        elevationUnavailableText: "当日海拔数据暂不可用", isOverview: false, title: "每日安排"
    )
    static let noticesLong = preview(asset: "TripSceneOverview", isOverview: true, notices: [
        "最高海拔约 4850 米，出发前确认高反应对方案，并核对同行人的应急联系信息。",
        "日乌且垭口午后易起雾并伴随强风，建议尽早通过；出发前向当地管理方再次核验天气与通行条件。（信息状态：待核验）",
        "营地附近曾有熊踪，食物与有气味物品需悬挂保存；请提前确认食品存放与垃圾带离安排。",
    ])
    static let accessible = noticesLong

    private static func preview(asset: String, isOverview: Bool, notices: [String] = ["最高海拔约 4850 米，出发前确认高反应对方案。"] ) -> Self {
        Self(assetName: asset,
             routePath: [.init(x: 0.15, y: 0.67), .init(x: 0.32, y: 0.5), .init(x: 0.49, y: 0.28), .init(x: 0.66, y: 0.43), .init(x: 0.82, y: 0.66)],
             landmarks: [.init(id: "start", title: "营地", symbol: "tent", x: 0.15, y: 0.67), .init(id: "pass", title: "垭口", symbol: "mountain.2", x: 0.49, y: 0.28), .init(id: "end", title: "抵达", symbol: "flag", x: 0.82, y: 0.66)],
             elevationProfile: FrozenRouteElevationProfile(minElevation: .init(meters: 1900), maxElevation: .init(meters: 4850), samples: [
                .init(distance: .init(meters: 0), elevation: .init(meters: 3520)),
                .init(distance: .init(meters: 10000), elevation: .init(meters: 4850)),
                .init(distance: .init(meters: 30000), elevation: .init(meters: 1900)),
             ]), elevationUnavailableText: nil,
             notices: notices,
             isOverview: isOverview, title: isOverview ? "全程总览" : "翻越垭口")
    }
}

#Preview("TripExpeditionScene.overview") {
    TripBusinessComponents.TripExpeditionScene(projection: .overview).frame(width: 390, height: 365)
        .background { TripBusinessComponents.TripExpeditionScene.Artwork(projection: .overview) }
}
#Preview("TripExpeditionScene.hikingDay") {
    TripBusinessComponents.TripExpeditionScene(projection: .hikingDay).frame(width: 390, height: 365)
        .background { TripBusinessComponents.TripExpeditionScene.Artwork(projection: .hikingDay) }
}
#Preview("TripExpeditionScene.arrival") {
    TripBusinessComponents.TripExpeditionScene(projection: .arrival).frame(width: 390, height: 365)
        .background { TripBusinessComponents.TripExpeditionScene.Artwork(projection: .arrival) }
}
#Preview("TripExpeditionScene.unavailable") {
    TripBusinessComponents.TripExpeditionScene(projection: .unavailable).frame(width: 390, height: 365)
        .background { TripBusinessComponents.TripExpeditionScene.Artwork(projection: .unavailable) }
}
#Preview("TripExpeditionScene.noticesLong") {
    TripBusinessComponents.TripExpeditionScene(projection: .noticesLong).frame(width: 390, height: 365)
        .background { TripBusinessComponents.TripExpeditionScene.Artwork(projection: .noticesLong) }
}
#Preview("TripExpeditionScene.accessible") {
    TripBusinessComponents.TripExpeditionScene(projection: .accessible)
        .environment(\.dynamicTypeSize, .accessibility2)
        .frame(width: 390, height: 440)
        .background { TripBusinessComponents.TripExpeditionScene.Artwork(projection: .accessible) }
}
#Preview("TripExpeditionScene.noticesLong.narrow") {
    TripBusinessComponents.TripExpeditionScene(projection: .noticesLong).frame(width: 320, height: 330)
        .background { TripBusinessComponents.TripExpeditionScene.Artwork(projection: .noticesLong) }
}
#Preview("TripExpeditionScene.noticesLong.wide") {
    TripBusinessComponents.TripExpeditionScene(projection: .noticesLong).frame(width: 700, height: 440)
        .background { TripBusinessComponents.TripExpeditionScene.Artwork(projection: .noticesLong) }
}
#endif
