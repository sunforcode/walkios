import XCTest
import WalkData
import WalkDesignSystem
@testable import Walk

@MainActor
final class ProfileViewModelTests: XCTestCase {
    func testAuthenticationSynchronizationClearsOldAccountBeforeReload() async {
        let session = AuthSessionStub(isLoggedIn: true)
        var calls = 0
        let sut = ProfileViewModel(
            authSession: session,
            loadAccount: { calls += 1; return Self.account },
            loadCalendar: { Self.emptyCalendar }
        )
        await sut.loadProfile()
        XCTAssertNotNil(sut.account)
        session.logout()

        sut.synchronizeAuthentication()

        XCTAssertFalse(sut.isLoggedIn)
        XCTAssertNil(sut.account)
        XCTAssertNil(sut.tripCalendar)
        XCTAssertEqual(calls, 1, "Synchronous invalidation must not start personal requests")
    }

    func testIdentityReplacementClearsPreviousAccountSynchronouslyWithoutFetching() async {
        let session = AuthSessionStub(isLoggedIn: true)
        var calls = 0
        let sut = ProfileViewModel(
            authSession: session,
            loadAccount: { calls += 1; return Self.account },
            loadCalendar: { Self.emptyCalendar }
        )
        await sut.loadProfile()
        session.cacheIdentity = "replacement-user"

        sut.synchronizeAuthentication()

        XCTAssertTrue(sut.isLoggedIn)
        XCTAssertNil(sut.account)
        XCTAssertNil(sut.tripCalendar)
        XCTAssertEqual(calls, 1)
    }

    func testProfileHasNoEquipmentLoadingDependency() throws {
        let source = try productionSource(at: "Features/Profile/ProfileViewModel.swift")
        XCTAssertFalse(source.contains("getPersonalEquipment"))
        XCTAssertFalse(source.contains("EquipmentServicing"))
        XCTAssertFalse(source.contains("loadEquipment"))
    }

    func testGuestProfileDoesNotRequestPersonalResources() async {
        let session = AuthSessionStub(isLoggedIn: false)
        var calls: [String] = []
        let sut = ProfileViewModel(
            authSession: session,
            loadAccount: { calls.append("account"); throw APIClientError.invalidResponse },
            loadCalendar: { calls.append("calendar"); throw APIClientError.invalidResponse }
        )

        await sut.loadProfile()

        XCTAssertFalse(sut.isLoggedIn)
        XCTAssertTrue(calls.isEmpty)
        XCTAssertNil(sut.account)
        XCTAssertNil(sut.tripCalendar)
    }

    func testLoggedInProfileLoadsOnlyAccountAndCalendar() async {
        let session = AuthSessionStub(isLoggedIn: true)
        var calls: [String] = []
        let account = AccountResponse(
            account: AccountProjection(identity: "account-1"),
            profile: ProfileProjection(
                identity: "profile-1",
                maskedPhone: "+86 138****8000",
                nickname: "行者",
                avatar: "media-avatar-1"
            )
        )
        let calendar = PersonalTripCalendar(
            windowStartDate: LocalDate(year: 2025, month: 9, day: 3),
            windowEndDate: LocalDate(year: 2026, month: 9, day: 2),
            days: [PersonalTripCalendarDay(date: LocalDate(year: 2026, month: 8, day: 25), tripCount: 1)]
        )
        let sut = ProfileViewModel(
            authSession: session,
            loadAccount: { calls.append("account"); return account },
            loadCalendar: { calls.append("calendar"); return calendar }
        )

        await sut.loadProfile()

        XCTAssertEqual(Set(calls), ["account", "calendar"])
        XCTAssertEqual(sut.account, account)
        XCTAssertEqual(sut.account?.account.identity, "account-1")
        XCTAssertEqual(sut.account?.profile.identity, "profile-1")
        XCTAssertEqual(sut.account?.profile.maskedPhone, "+86 138****8000")
        XCTAssertEqual(sut.account?.profile.nickname, "行者")
        XCTAssertEqual(sut.account?.profile.avatar, "media-avatar-1")
        XCTAssertEqual(sut.tripCalendar, calendar)
        let weight = AccountEquipmentFormatting.weightParts(grams: 8_420)
        XCTAssertEqual(weight.value, "8.4")
        XCTAssertEqual(weight.unit, "kg")
        XCTAssertNil(sut.errorMessage)
    }

    func testLogoutServerFailureKeepsLocalSessionAndProfile() async {
        let session = AuthSessionStub(isLoggedIn: true)
        let account = AccountResponse(
            account: AccountProjection(identity: "account-1"),
            profile: ProfileProjection(identity: "profile-1", maskedPhone: "+86 138****8000", nickname: nil, avatar: nil)
        )
        let sut = ProfileViewModel(
            authSession: session,
            loadAccount: { account },
            loadCalendar: { Self.emptyCalendar },
            revokeSession: { throw APIClientError.api(code: "logout_failed", message: "退出失败", retryable: true) }
        )
        await sut.loadProfile()

        let result = await sut.logout()

        XCTAssertFalse(result, "本次退出失败不得触发成功回调")
        XCTAssertTrue(session.isLoggedIn)
        XCTAssertFalse(session.didLogout)
        XCTAssertEqual(sut.account, account)
        XCTAssertEqual(sut.errorMessage, "退出失败")
        XCTAssertEqual(sut.logoutErrorMessage, "退出失败")
    }

    func testProfileCalendarMapsFullServerWindowAndSparseTripCounts() {
        let calendar = PersonalTripCalendar(
            windowStartDate: LocalDate(year: 2025, month: 9, day: 2),
            windowEndDate: LocalDate(year: 2026, month: 9, day: 1),
            days: [
                PersonalTripCalendarDay(
                    date: LocalDate(year: 2026, month: 9, day: 1),
                    tripCount: 2
                )
            ]
        )

        let presentation = ProfileCalendarPresentation(calendar: calendar)

        XCTAssertEqual(presentation.days.count, 365)
        XCTAssertEqual(presentation.days.first?.date, calendar.windowStartDate)
        XCTAssertEqual(presentation.days.last?.date, calendar.windowEndDate)
        XCTAssertEqual(presentation.days.last?.tripCount, 2)
        XCTAssertTrue(presentation.hasTrips)

        let componentProjection = presentation.tripCalendarCardProjection
        XCTAssertEqual(componentProjection.days.count, 365)
        XCTAssertEqual(componentProjection.days.first?.businessDate, calendar.windowStartDate.description)
        XCTAssertEqual(componentProjection.days.first?.level, .empty)
        XCTAssertEqual(componentProjection.days.last?.businessDate, calendar.windowEndDate.description)
        XCTAssertEqual(componentProjection.days.last?.level, .medium)
        XCTAssertNil(componentProjection.emptyHint)
    }

    func testSuccessfulEmptyCalendarMapsToProductionCardEmptyState() {
        let presentation = ProfileCalendarPresentation(calendar: Self.emptyCalendar)

        XCTAssertEqual(presentation.days.count, 365)
        XCTAssertFalse(presentation.hasTrips)
        XCTAssertEqual(presentation.tripCalendarCardProjection.days.count, 365)
        XCTAssertEqual(
            presentation.tripCalendarCardProjection.emptyHint,
            "过去 365 天还没有个人行程"
        )
    }

    func testCalendarProjectionDoesNotTruncateAnInvalidServerWindowIntoAValidCard() {
        let invalidCalendar = PersonalTripCalendar(
            windowStartDate: LocalDate(year: 2025, month: 9, day: 1),
            windowEndDate: LocalDate(year: 2026, month: 9, day: 1),
            days: []
        )

        let presentation = ProfileCalendarPresentation(calendar: invalidCalendar)

        XCTAssertEqual(presentation.days.count, 366)
        XCTAssertEqual(presentation.tripCalendarCardProjection.days.count, 366)
    }

    func testProfileSourceKeepsLocalSectionRetries() throws {
        let source = try productionSource(at: "Features/Profile/ProfileView.swift")

        XCTAssertTrue(source.contains("viewModel.retryCalendar()"))
        XCTAssertFalse(source.contains("viewModel.retryEquipment()"))
    }

    func testProfilePageUsesProductionComponentsWithoutPrivateDuplicatesOrMediaParsing() throws {
        let source = try productionSource(at: "Features/Profile/ProfileView.swift")
        let calendarComponentSource = try productionSource(
            at: "Features/Shared/Components/TripCalendarCard.swift"
        )
        let accountMenuSource = try productionSource(
            at: "Features/Profile/AccountMenuView.swift"
        )
        let equipmentComponentSource = try productionSource(
            at: "Features/Shared/Components/PersonalEquipmentSummaryCard.swift"
        )

        XCTAssertTrue(source.contains("SharedBusinessComponents.TripCalendarCard("))
        XCTAssertFalse(source.contains("PersonalEquipmentSummaryCard("))
        XCTAssertTrue(source.contains("onOpenAccountMenu("), "头像入口弹出账户菜单")
        XCTAssertTrue(source.contains("avatarLabel: profile.nickname"))
        XCTAssertFalse(source.contains("fullScreenCover"), "头像入口不再弹覆盖层")
        XCTAssertFalse(source.contains("AccountMenuSheet"), "AccountMenuSheet 已退役，承载迁至 AccountMenuView")
        XCTAssertTrue(calendarComponentSource.contains("SharedBusinessComponents.HeatmapCalendar("))
        XCTAssertTrue(accountMenuSource.contains("AccountEquipmentBusinessComponents.ProfileIdentityHeader("))
        XCTAssertTrue(accountMenuSource.contains("SettingsListRow("))
        XCTAssertTrue(accountMenuSource.contains("viewModel.logout()"), "退出登录在账户菜单页内转发")
        XCTAssertTrue(accountMenuSource.contains("onNavigate"), "设置项经我的页任务栈承接：先关闭菜单再推入目标页")
        XCTAssertTrue(accountMenuSource.contains("ModalBottomSheet("), "账户菜单使用底部模态 Sheet 承载")
        XCTAssertTrue(accountMenuSource.contains("onClose"), "关闭入口回到我的页")
        XCTAssertFalse(accountMenuSource.contains("isCloseActionPresented"), "设置 Modal 不再显示右上角叉号")
        XCTAssertFalse(accountMenuSource.contains("accountSecurity"), "账号与安全已从设置任务移除")
        XCTAssertTrue(equipmentComponentSource.contains("summary.equipmentItemCount"))
        XCTAssertTrue(equipmentComponentSource.contains("summary.equipmentListCount"))
        XCTAssertTrue(equipmentComponentSource.contains("summary.knownTotalWeight.grams"))
        XCTAssertTrue(equipmentComponentSource.contains("summary.missingWeightItemCount"))
        XCTAssertFalse(equipmentComponentSource.contains("ownedQuantity"))
        XCTAssertFalse(source.contains("tripCalendarCardSurface"))
        XCTAssertFalse(source.contains("calendarCardBody"))
        XCTAssertFalse(source.contains("equipmentSummaryCardSurface"))
        XCTAssertFalse(source.contains("equipmentMetrics"))
        XCTAssertFalse(source.contains("ProfileSettingsOverlay"))
        XCTAssertFalse(source.contains("HeatmapCalendar("))
        XCTAssertFalse(source.contains("URL(string:"))
        XCTAssertFalse(source.contains("AsyncImage("))
    }

    func testProfileSourceKeepsTripsBehindCalendarAndRoutesLogoutToRoutesTab() throws {
        let source = try productionSource(at: "Features/Profile/ProfileView.swift")
        let rootSource = try productionSource(at: "App/RootView.swift")
        let menuSource = try productionSource(at: "Features/Profile/AccountMenuView.swift")
        let calendarStart = try XCTUnwrap(source.range(of: "private var tripCalendarSection"))
        let calendarSource = String(source[calendarStart.lowerBound...])

        XCTAssertTrue(calendarSource.contains("onNavigate(.tripList)"))
        XCTAssertFalse(source.contains("我的全部行程"))
        XCTAssertFalse(menuSource.contains("id: .accountSecurity"), "账号与安全不再可达")
        XCTAssertTrue(rootSource.contains("shell.resetAfterLogout()"), "退出成功通过统一重置清空个人任务并返回行程根页")
    }

    func testAccountMenuBindsPhotoReadAndUploadToSelectionTaskLifetime() throws {
        let source = try productionSource(at: "Features/Profile/AccountMenuView.swift")
        let taskStart = try XCTUnwrap(source.range(of: ".task(id: selectedPhoto)"))
        let pickerStart = try XCTUnwrap(source.range(of: ".photosPicker("))
        let photoTask = String(source[taskStart.lowerBound..<pickerStart.lowerBound])
        let normalized = photoTask.split(whereSeparator: { $0.isWhitespace }).joined(separator: " ")

        XCTAssertFalse(source.contains(".onChange(of: selectedPhoto)"))
        XCTAssertFalse(photoTask.contains("Task {"), "选图读取和上传不得脱离菜单及选择项的任务生命周期")
        XCTAssertFalse(photoTask.contains("Task.detached"))
        XCTAssertTrue(normalized.contains("guard let item = selectedPhoto else { return }"))
        XCTAssertTrue(normalized.contains(
            "let data = try await item.loadTransferable(type: Data.self) guard !Task.isCancelled else { return } guard let data else { viewModel.reportAvatarReadFailure() return } await viewModel.updateAvatar(data: data, contentType: \"image/jpeg\")"
        ), "迟到的成功或空数据必须先检查取消，再上传或展示失败")
        XCTAssertTrue(normalized.contains("catch is CancellationError { return }"))
        XCTAssertTrue(normalized.contains(
            "catch { guard !Task.isCancelled else { return }"
        ), "读取抛错后也要排除菜单消失或重新选图造成的取消")
    }

    func testAccountMenuLogoutCallbackConsumesOnlyItsOwnSuccessfulResult() throws {
        let source = try productionSource(at: "Features/Profile/AccountMenuView.swift")
        let actionStart = try XCTUnwrap(source.range(of: "DangerAction("))
        let actionEnd = try XCTUnwrap(source.range(of: ".padding(.top, Spacing.md)", range: actionStart.upperBound..<source.endIndex))
        let action = source[actionStart.lowerBound..<actionEnd.lowerBound]
            .split(whereSeparator: { $0.isWhitespace }).joined(separator: " ")

        XCTAssertFalse(source.contains(".onChange(of: viewModel.isLoggedIn)"))
        XCTAssertTrue(action.contains(
            "action: { Task { if await viewModel.logout() { onLoggedOut() } } }"
        ), "退出保留独立 Task，菜单关闭后仍能按本次成功结果完成导航")
        XCTAssertEqual(source.components(separatedBy: "onLoggedOut()").count - 1, 1)
    }

    func testAccountMenuUpdatesAvatarThroughSharedProfileState() async throws {
        let session = AuthSessionStub(isLoggedIn: true)
        let original = AccountResponse(
            account: AccountProjection(identity: "account-1"),
            profile: ProfileProjection(identity: "profile-1", maskedPhone: "+86 138****8000", nickname: "行者", avatar: nil)
        )
        let updated = ProfileProjection(identity: "profile-1", maskedPhone: "+86 138****8000", nickname: "行者", avatar: "media-avatar-2")
        var receivedUpdate: ProfileUpdate?
        let sut = ProfileViewModel(
            authSession: session,
            loadAccount: { original },
            loadCalendar: { Self.emptyCalendar },
            uploadAvatar: { _, _ in AvatarMediaResponse(mediaReference: "media-avatar-2") },
            updateProfile: { update in
                receivedUpdate = update
                return ProfileResponse(profile: ProfileProjection(identity: "profile-1", maskedPhone: "+86 138****8000", nickname: "行者", avatar: "media-avatar-2"))
            }
        )
        await sut.loadProfile()
        XCTAssertNil(sut.account?.profile.avatar)

        await sut.updateAvatar(data: Data("image".utf8), contentType: "image/jpeg")

        XCTAssertEqual(receivedUpdate?.avatar, .value("media-avatar-2"), "头像更新先上传取得 mediaReference 再写入 Profile")
        XCTAssertEqual(sut.account?.profile, updated, "头像更新成功后共享账号状态立即刷新")
        XCTAssertNil(sut.avatarErrorMessage)
        XCTAssertFalse(sut.isAvatarUpdating)
    }

    func testAccountMenuKeepsAvatarOnFailureAndExposesError() async {
        let session = AuthSessionStub(isLoggedIn: true)
        let original = AccountResponse(
            account: AccountProjection(identity: "account-1"),
            profile: ProfileProjection(identity: "profile-1", maskedPhone: "+86 138****8000", nickname: "行者", avatar: nil)
        )
        let sut = ProfileViewModel(
            authSession: session,
            loadAccount: { original },
            loadCalendar: { Self.emptyCalendar },
            uploadAvatar: { _, _ in throw APIClientError.invalidResponse }
        )
        await sut.loadProfile()

        await sut.updateAvatar(data: Data("image".utf8), contentType: "image/jpeg")

        XCTAssertEqual(sut.account?.profile, original.profile, "上传失败保留原头像")
        XCTAssertNotNil(sut.avatarErrorMessage, "失败暴露给当前 Modal 可见错误")
        XCTAssertFalse(sut.isAvatarUpdating)
    }

    func testCalendarFailureDoesNotDiscardAccount() async {
        let session = AuthSessionStub(isLoggedIn: true)
        let account = AccountResponse(
            account: AccountProjection(identity: "account-1"),
            profile: ProfileProjection(identity: "profile-1", maskedPhone: "+86 138****8000", nickname: nil, avatar: nil)
        )
        let sut = ProfileViewModel(
            authSession: session,
            loadAccount: { account },
            loadCalendar: { throw APIClientError.invalidResponse }
        )

        await sut.loadProfile()

        XCTAssertEqual(sut.account, account)
        XCTAssertNotNil(sut.calendarErrorMessage)
    }

    func testRetryCalendarOnlyReloadsFailedCalendarSection() async {
        let session = AuthSessionStub(isLoggedIn: true)
        var calendarAttempts = 0
        var accountAttempts = 0
        let sut = ProfileViewModel(
            authSession: session,
            loadAccount: {
                accountAttempts += 1
                return AccountResponse(
                    account: AccountProjection(identity: "account-1"),
                    profile: ProfileProjection(identity: "profile-1", maskedPhone: "+86 138****8000", nickname: nil, avatar: nil)
                )
            },
            loadCalendar: {
                calendarAttempts += 1
                if calendarAttempts == 1 { throw APIClientError.invalidResponse }
                return Self.emptyCalendar
            }
        )
        await sut.loadProfile()

        await sut.retryCalendar()

        XCTAssertEqual(calendarAttempts, 2)
        XCTAssertEqual(accountAttempts, 1)
        XCTAssertEqual(sut.tripCalendar, Self.emptyCalendar)
        XCTAssertNil(sut.calendarErrorMessage)
    }

    func testLogoutClearsLocalSessionAndCacheOnlyAfterServerSuccess() async {
        let session = AuthSessionStub(isLoggedIn: true)
        var events: [String] = []
        let sut = ProfileViewModel(
            authSession: session,
            loadAccount: {
                AccountResponse(
                    account: AccountProjection(identity: "account-1"),
                    profile: ProfileProjection(identity: "profile-1", maskedPhone: "+86 138****8000", nickname: nil, avatar: nil)
                )
            },
            loadCalendar: { Self.emptyCalendar },
            revokeSession: { events.append("server") },
            clearCachedResponses: {
                events.append(session.isLoggedIn ? "cache-before-logout" : "cache-after-logout")
            }
        )
        await sut.loadProfile()

        await sut.logout()

        XCTAssertEqual(events, ["server", "cache-after-logout"])
        XCTAssertTrue(session.didLogout)
        XCTAssertFalse(sut.isLoggedIn)
        XCTAssertNil(sut.account)
    }

    func testLogoutSynchronousAuthenticationChangeStillCompletesCacheCleanup() async {
        let session = AuthSessionStub(isLoggedIn: true)
        var events: [String] = []
        var sut: ProfileViewModel!
        sut = ProfileViewModel(
            authSession: session,
            loadAccount: { Self.account },
            loadCalendar: { Self.emptyCalendar },
            revokeSession: {
                events.append("server")
                session.logout()
                // AccountService posts didChange before its logout call returns.
                sut.synchronizeAuthentication()
            },
            clearCachedResponses: { events.append("cache") }
        )
        await sut.loadProfile()

        let result = await sut.logout()

        XCTAssertTrue(result, "The successful operation must still trigger the route-root callback")
        XCTAssertEqual(events, ["server", "cache"])
        XCTAssertFalse(sut.isLoggedIn)
        XCTAssertFalse(sut.isLoggingOut)
        XCTAssertNil(sut.account)
        XCTAssertNil(sut.tripCalendar)
    }

    func testLogoutSuccessCallbackWaitsForCacheCleanupAndIsNotReplayed() async {
        let session = AuthSessionStub(isLoggedIn: true)
        let cacheStarted = expectation(description: "cache cleanup started")
        let gate = ProfileAsyncGate()
        var events: [String] = []
        let sut = ProfileViewModel(
            authSession: session,
            loadAccount: { Self.account },
            loadCalendar: { Self.emptyCalendar },
            revokeSession: { events.append("server") },
            clearCachedResponses: {
                events.append("cache-start")
                cacheStarted.fulfill()
                await gate.wait()
                events.append("cache-end")
            }
        )
        await sut.loadProfile()
        let logout = Task {
            if await sut.logout() { events.append("callback") }
        }
        await fulfillment(of: [cacheStarted], timeout: 1)

        XCTAssertFalse(sut.isLoggedIn, "共享登录状态已清理，但本次退出仍在等待缓存")
        XCTAssertEqual(events, ["server", "cache-start"], "不能把登录状态变化当作退出操作完成")
        await gate.open()
        await logout.value
        XCTAssertEqual(events, ["server", "cache-start", "cache-end", "callback"])

        if await sut.logout() { events.append("callback") }
        XCTAssertEqual(events, ["server", "cache-start", "cache-end", "callback"], "已退出后的拒绝结果不能重放前一次成功回调")
    }

    func testAccountServiceDoesNotMapMaskedPhoneIntoLegacyEmail() throws {
        let testFileURL = URL(fileURLWithPath: #filePath)
        let sourceURL = testFileURL
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("../Packages/WalkData/Sources/WalkData/Repositories/UserService.swift")
        let source = try String(contentsOf: sourceURL, encoding: .utf8)

        XCTAssertFalse(source.contains("email:"))
        XCTAssertFalse(source.contains("final class UserService"))
    }

    func testLogoutPreventsLateSectionsFromRestoringPersonalData() async {
        let session = AuthSessionStub(isLoggedIn: true)
        let started = expectation(description: "sections started")
        started.expectedFulfillmentCount = 2
        let gate = ProfileAsyncGate()
        let sut = ProfileViewModel(
            authSession: session,
            loadAccount: { started.fulfill(); await gate.wait(); return Self.account },
            loadCalendar: { started.fulfill(); await gate.wait(); return Self.emptyCalendar }
        )
        let load = Task { await sut.loadProfile() }
        await fulfillment(of: [started], timeout: 1)
        let loggedOut = await sut.logout()
        XCTAssertTrue(loggedOut)
        await gate.open()
        await load.value
        XCTAssertFalse(sut.isLoggedIn)
        XCTAssertNil(sut.account)
        XCTAssertNil(sut.tripCalendar)
        XCTAssertNil(sut.errorMessage)
        XCTAssertFalse(sut.isLoading)
    }

    func testNewAccountRetryWinsOverOlderAccountResponse() async {
        let session = AuthSessionStub(isLoggedIn: true)
        let started = expectation(description: "old account started")
        let gate = ProfileAsyncGate()
        var attempts = 0
        let sut = ProfileViewModel(
            authSession: session,
            loadAccount: {
                attempts += 1
                if attempts == 1 {
                    started.fulfill()
                    await gate.wait()
                    throw APIClientError.invalidResponse
                }
                return Self.account
            },
            loadCalendar: { Self.emptyCalendar }
        )
        let first = Task { await sut.loadProfile() }
        await fulfillment(of: [started], timeout: 1)
        await sut.retryAccount()
        await gate.open()
        await first.value
        XCTAssertEqual(sut.account, Self.account)
        XCTAssertNil(sut.accountErrorMessage)
        XCTAssertNil(sut.errorMessage)
        XCTAssertFalse(sut.isAccountLoading)
    }

    func testCancelledProfileLoadDoesNotPublishLateSections() async {
        let session = AuthSessionStub(isLoggedIn: true)
        let started = expectation(description: "sections started")
        started.expectedFulfillmentCount = 2
        let gate = ProfileAsyncGate()
        let sut = ProfileViewModel(
            authSession: session,
            loadAccount: { started.fulfill(); await gate.wait(); return Self.account },
            loadCalendar: { started.fulfill(); await gate.wait(); return Self.emptyCalendar }
        )
        let load = Task { await sut.loadProfile() }
        await fulfillment(of: [started], timeout: 1)
        load.cancel()
        await gate.open()
        await load.value
        XCTAssertNil(sut.account)
        XCTAssertNil(sut.tripCalendar)
        XCTAssertNil(sut.errorMessage)
        XCTAssertFalse(sut.isLoading)
    }

    func testCancelledLogoutDoesNotClearSessionOrCache() async {
        let session = AuthSessionStub(isLoggedIn: true)
        var clearCount = 0
        let started = expectation(description: "logout started")
        let gate = ProfileAsyncGate()
        let sut = ProfileViewModel(
            authSession: session,
            loadAccount: { Self.account },
            loadCalendar: { Self.emptyCalendar },
            revokeSession: { started.fulfill(); await gate.wait() },
            clearCachedResponses: { clearCount += 1 }
        )
        await sut.loadProfile()
        let logout = Task { await sut.logout() }
        await fulfillment(of: [started], timeout: 1)
        logout.cancel()
        await gate.open()
        let result = await logout.value
        XCTAssertFalse(result)
        XCTAssertTrue(session.isLoggedIn)
        XCTAssertEqual(sut.account, Self.account)
        XCTAssertEqual(clearCount, 0)
        XCTAssertNil(sut.logoutErrorMessage)
        XCTAssertFalse(sut.isLoggingOut)
    }

    func testLogoutResponseCannotClearReplacementIdentity() async {
        let session = AuthSessionStub(isLoggedIn: true)
        let started = expectation(description: "logout started")
        let gate = ProfileAsyncGate()
        let sut = ProfileViewModel(
            authSession: session,
            loadAccount: { Self.account },
            loadCalendar: { Self.emptyCalendar },
            revokeSession: { started.fulfill(); await gate.wait() }
        )
        await sut.loadProfile()
        let logout = Task { await sut.logout() }
        await fulfillment(of: [started], timeout: 1)
        session.cacheIdentity = "replacement"
        await sut.loadProfile()
        await gate.open()
        let result = await logout.value
        XCTAssertFalse(result)
        XCTAssertTrue(session.isLoggedIn)
        XCTAssertFalse(session.didLogout)
        XCTAssertEqual(sut.account, Self.account)
    }

    func testTransportCancellationDoesNotShowSectionOrLogoutFailure() async {
        let session = AuthSessionStub(isLoggedIn: true)
        let sut = ProfileViewModel(
            authSession: session,
            loadAccount: { throw APIClientError.transport(.cancelled) },
            loadCalendar: { throw CancellationError() },
            revokeSession: { throw APIClientError.transport(.cancelled) }
        )
        await sut.loadProfile()
        let result = await sut.logout()
        XCTAssertFalse(result)
        XCTAssertTrue(session.isLoggedIn)
        XCTAssertNil(sut.accountErrorMessage)
        XCTAssertNil(sut.calendarErrorMessage)
        XCTAssertNil(sut.logoutErrorMessage)
        XCTAssertNil(sut.errorMessage)
        XCTAssertFalse(sut.isLoading)
    }

    func testNicknameTrimsAndClearsWithPerCallResult() async {
        let session = AuthSessionStub(isLoggedIn: true)
        var updates: [ProfileUpdate] = []
        let sut = ProfileViewModel(
            authSession: session,
            loadAccount: { Self.account },
            loadCalendar: { Self.emptyCalendar },
            updateProfile: { update in
                updates.append(update)
                return ProfileResponse(profile: Self.account.profile)
            }
        )
        await sut.loadProfile()
        let saved = await sut.updateNickname("  行者  \n")
        let cleared = await sut.updateNickname(" \n ")
        XCTAssertTrue(saved)
        XCTAssertTrue(cleared)
        XCTAssertEqual(updates.map(\.nickname), [.value("行者"), .clear])
        XCTAssertFalse(sut.isSavingProfile)
    }

    func testAvatarUploadCannotContinueUpdatingProfileAfterLogout() async {
        let session = AuthSessionStub(isLoggedIn: true)
        let started = expectation(description: "upload started")
        let gate = ProfileAsyncGate()
        var updateCount = 0
        let sut = ProfileViewModel(
            authSession: session,
            loadAccount: { Self.account },
            loadCalendar: { Self.emptyCalendar },
            uploadAvatar: { _, _ in
                started.fulfill()
                await gate.wait()
                return AvatarMediaResponse(mediaReference: "late")
            },
            updateProfile: { _ in
                updateCount += 1
                return ProfileResponse(profile: Self.account.profile)
            }
        )
        await sut.loadProfile()
        let upload = Task { await sut.updateAvatar(data: Data(), contentType: "image/jpeg") }
        await fulfillment(of: [started], timeout: 1)
        await sut.logout()
        await gate.open()
        let result = await upload.value
        XCTAssertFalse(result)
        XCTAssertEqual(updateCount, 0)
        XCTAssertNil(sut.account)
        XCTAssertFalse(sut.isAvatarUpdating)
        XCTAssertNil(sut.avatarErrorMessage)
    }

    func testNewCalendarRetryWinsOverLateFailure() async {
        let session = AuthSessionStub(isLoggedIn: true)
        let started = expectation(description: "old calendar started")
        let gate = ProfileAsyncGate()
        var attempts = 0
        let sut = ProfileViewModel(
            authSession: session,
            loadAccount: { Self.account },
            loadCalendar: {
                attempts += 1
                if attempts == 1 {
                    started.fulfill()
                    await gate.wait()
                    throw APIClientError.invalidResponse
                }
                return Self.emptyCalendar
            }
        )
        let first = Task { await sut.loadProfile() }
        await fulfillment(of: [started], timeout: 1)
        await sut.retryCalendar()
        await gate.open()
        await first.value
        XCTAssertEqual(sut.tripCalendar, Self.emptyCalendar)
        XCTAssertNil(sut.calendarErrorMessage)
        XCTAssertFalse(sut.isCalendarLoading)
    }

    func testNicknameResponseCannotRestoreAccountAfterLogout() async {
        let session = AuthSessionStub(isLoggedIn: true)
        let started = expectation(description: "nickname save started")
        let gate = ProfileAsyncGate()
        let sut = ProfileViewModel(
            authSession: session,
            loadAccount: { Self.account },
            loadCalendar: { Self.emptyCalendar },
            updateProfile: { _ in
                started.fulfill()
                await gate.wait()
                return ProfileResponse(profile: Self.account.profile)
            }
        )
        await sut.loadProfile()
        let save = Task { await sut.updateNickname("行者") }
        await fulfillment(of: [started], timeout: 1)
        await sut.logout()
        await gate.open()
        let result = await save.value
        XCTAssertFalse(result)
        XCTAssertNil(sut.account)
        XCTAssertFalse(sut.isLoggedIn)
        XCTAssertFalse(sut.isSavingProfile)
        XCTAssertNil(sut.profileUpdateErrorMessage)
    }

    private static let account = AccountResponse(
        account: AccountProjection(identity: "account-1"),
        profile: ProfileProjection(identity: "profile-1", maskedPhone: "***", nickname: nil, avatar: nil)
    )

    private static let emptyCalendar = PersonalTripCalendar(
        windowStartDate: LocalDate(year: 2025, month: 9, day: 3),
        windowEndDate: LocalDate(year: 2026, month: 9, day: 2),
        days: []
    )

    private func productionSource(at relativePath: String) throws -> String {
        let testFileURL = URL(fileURLWithPath: #filePath)
        let walkRoot = testFileURL
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        return try String(contentsOf: walkRoot.appendingPathComponent(relativePath), encoding: .utf8)
    }

}

private final class AuthSessionStub: AuthSession {
    var isLoggedIn: Bool
    var cacheIdentity = "test-user"
    var didLogout = false

    init(isLoggedIn: Bool) {
        self.isLoggedIn = isLoggedIn
    }

    func logout() {
        didLogout = true
        isLoggedIn = false
    }
}

private actor ProfileAsyncGate {
    private var isOpen = false
    private var continuations: [CheckedContinuation<Void, Never>] = []

    func wait() async {
        guard !isOpen else { return }
        await withCheckedContinuation { continuations.append($0) }
    }

    func open() {
        isOpen = true
        continuations.forEach { $0.resume() }
        continuations.removeAll()
    }
}
