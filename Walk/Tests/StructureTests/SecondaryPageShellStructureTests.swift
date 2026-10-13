import XCTest

/// 结构测试强制：Features 下二级页实现必须经统一页面壳（UtilityPage）承载，
/// 不得自建替代骨架（safeAreaInset 自绘导航、裸 overlay 返回等）。
///
/// 不变量由三张登记表维护：走壳清单、豁免登记、范围外登记；
/// 反向扫描保证新增 `*View.swift` / `*Page.swift` 文件必须登记后才能合入。
final class SecondaryPageShellStructureTests: XCTestCase {

    // MARK: 登记

    /// 走壳清单：二级页实现文件（相对 `Walk/Features` 路径），必须经 `UtilityPage(` 承载。
    private static let shellRequiredFiles: Set<String> = [
        "Equipment/AddEquipmentView.swift",
        "Equipment/EquipmentListView.swift",
        "Profile/AboutPage.swift",
        "Profile/EntryFormPage.swift",
        "Profile/HelpFeedbackPage.swift",
        "Profile/NotificationSettingsPage.swift",
        "Profile/PrivacySettingsPage.swift",
        "Profile/ProfileDetailsPage.swift",
        "Routes/RouteDiscoveryView.swift",
        "Trips/CreateTripView.swift",
        "Trips/TripEquipment.swift",
        "Trips/TripDayWeatherViews.swift",
        "Trips/TripListView.swift",
    ]

    /// 豁免登记：二级页但返回入口/导航另有承载（附理由）。
    private static let exemptFiles: [String: String] = [
        // 沉浸地图详情：返回入口属地图 dock，非页面导航行（change 批准豁免）。
        "Routes/RouteDetailView.swift": "返回入口属地图 dock，非页面导航行",
        // 沉浸行程详情：场景与日期固定、时间线独滚（PAGE-TRIP-DETAIL 自定义承载）。
        "Trips/TripDetailView.swift": "沉浸场景自定义承载：固定日期与场景，时间线独滚，返回常驻顶部",
        // 逐日阅读嵌套分页容器：外层分页容器一日一页，返回固定于浏览头（PAGE-TRIP-BROWSE 自定义承载）。
        "Trips/TripBrowseView.swift": "嵌套分页容器自定义承载：外层一日一页分页，返回固定于浏览头",
    ]

    /// 范围外登记：非任务栈二级页或非页面组件，不适用壳合同（附理由）。
    private static let outOfScopeFiles: [String: String] = [
        "Home/HomeView.swift": "行程 tab 根页，非二级页",
        "Profile/ProfileView.swift": "tab 根页，非二级页",
        "Profile/AccountMenuView.swift": "PAGE-ACCOUNT-MENU 以底部模态 Sheet 承载，不进入任务栈",
        "Profile/LoginView.swift": "登录模态流程页，非任务栈二级页",
        "Shared/Components/GenerationWaitingView.swift": "SharedBusinessComponents 业务组件（生成等待态），非页面",
        "Routes/RouteMapView.swift": "地图组件，非页面",
    ]

    // MARK: 断言

    func testShellRequiredPagesUseUnifiedShell() throws {
        for relativePath in Self.shellRequiredFiles.sorted() {
            let source = try featuresSource(relativePath)
            XCTAssertTrue(
                source.contains("UtilityPage("),
                "\(relativePath) 未走统一页面壳（UtilityPage）；二级页不得自建替代骨架。" +
                "如确有独立承载理由，请在豁免登记表中登记并附理由。"
            )
        }
    }

    func testExemptFilesKeepTheirRegisteredReason() {
        for (file, reason) in Self.exemptFiles {
            XCTAssertFalse(reason.isEmpty, "豁免登记 \(file) 必须附理由")
        }
    }

    func testEquipmentRootAndTaskHaveDistinctScrollOwners() throws {
        let source = try featuresSource("Equipment/EquipmentListView.swift")
        XCTAssertTrue(source.contains("PageShell("), "一级装备根页由 PageShell 承载")
        XCTAssertTrue(source.contains("UtilityPage("), "行程内管理使用同一个页面的任务壳")
        let scrolls = source.components(separatedBy: "ScrollView(showsIndicators:").count - 1
        XCTAssertEqual(scrolls, 1, "根页拥有一个滚动区，任务分支沿用 UtilityPage 滚动")
    }

    /// 反向强制：页面命名文件及既有非标准文件名页面必须登记；不得残留已退役文件。
    func testEveryPageNamedFileIsRegistered() throws {
        let allFiles = try Self.pageNamedFeatureFiles()
        let registered = Self.shellRequiredFiles
            .union(Self.exemptFiles.keys)
            .union(Self.outOfScopeFiles.keys)

        let unregistered = allFiles.subtracting(registered)
        XCTAssertTrue(
            unregistered.isEmpty,
            "以下页面命名的文件未登记（走壳清单 / 豁免登记 / 范围外登记）：\(unregistered.sorted())。" +
            "二级页请迁移到 UtilityPage 并加入走壳清单；其余承载请在对应登记表附理由登记。"
        )

        let missing = registered.subtracting(allFiles)
        XCTAssertTrue(
            missing.isEmpty,
            "登记表中存在已不存在的文件，请清理：\(missing.sorted())"
        )
    }

    // MARK: 文件发现

    private static func pageNamedFeatureFiles() throws -> Set<String> {
        let root = try featuresRootURL().standardizedFileURL
        var files: Set<String> = []
        let enumerator = FileManager.default.enumerator(at: root, includingPropertiesForKeys: nil)
        for case let url as URL in enumerator ?? NSEnumerator() {
            guard url.pathExtension == "swift" else { continue }
            let name = url.lastPathComponent
            let relative = String(url.standardizedFileURL.path.dropFirst(root.path.count + 1))
            let isExistingPageContainer = relative == "Trips/TripEquipment.swift"
                || relative == "Trips/TripDayWeatherViews.swift"
            guard name.hasSuffix("View.swift") || name.hasSuffix("Page.swift") || isExistingPageContainer else { continue }
            files.insert(relative)
        }
        return files
    }

    /// 本文件位于 `Walk/Tests/StructureTests/` → 上三级为 Walk，再进 Features。
    private static func featuresRootURL() throws -> URL {
        let testFileURL = URL(fileURLWithPath: #filePath)
        return testFileURL
            .deletingLastPathComponent()   // StructureTests
            .deletingLastPathComponent()   // Tests
            .deletingLastPathComponent()   // Walk
            .appendingPathComponent("Features")
    }

    private func featuresSource(_ relativePath: String) throws -> String {
        let root = try Self.featuresRootURL()
        return try String(
            contentsOf: root.appendingPathComponent(relativePath),
            encoding: .utf8
        )
    }
}
