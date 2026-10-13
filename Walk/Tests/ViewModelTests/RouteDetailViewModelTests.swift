import XCTest
import Observation
import WalkData
import WalkDesignSystem
@testable import Walk

@MainActor
final class RouteDetailViewModelTests: XCTestCase {
    func testDiscoveryLoadsFeaturedPublicSummaries() async {
        let service = RouteDiscoveryServiceStub(
            featured: PublicRouteDiscoveryResult(items: [Self.browseSummary])
        )
        let sut = RouteDiscoveryViewModel(service: service)

        await sut.loadRoutes()

        XCTAssertEqual(sut.routes, [Self.browseSummary])
        XCTAssertFalse(sut.isLoading)
        XCTAssertNil(sut.errorMessage)
    }

    func testDiscoverySearchKeepsInitialStateForEmptyQuery() async {
        let service = RouteDiscoveryServiceStub(
            search: PublicRouteSearchResult(state: .initial, items: [])
        )
        let sut = RouteDiscoveryViewModel(service: service)

        await sut.search(query: "")

        XCTAssertEqual(sut.searchState, .initial)
        XCTAssertTrue(sut.searchResults.isEmpty)
    }

    func testSearchEmptyInputClearsPreviousResultsWithoutCallingServerAgain() async {
        let service = RouteDiscoveryServiceStub(
            searchResults: [
                PublicRouteSearchResult(state: .completed, items: [Self.searchSummary])
            ]
        )
        let sut = RouteDiscoveryViewModel(service: service)

        await sut.search(query: "贡嘎")
        await sut.search(query: nil)

        XCTAssertEqual(sut.searchState, .initial)
        XCTAssertTrue(sut.searchResults.isEmpty)
        XCTAssertEqual(service.searchQueries, ["贡嘎"])
    }

    func testSearchWhitespaceEquivalentQueryKeepsInitialStateWithoutCallingService() async {
        let service = RouteDiscoveryServiceStub(
            searchError: APIClientError.transport(.other("搜索服务不应被调用"))
        )
        let sut = RouteDiscoveryViewModel(service: service)

        await sut.search(query: " \t\n\r\u{3000}")

        XCTAssertEqual(sut.searchState, .initial)
        XCTAssertTrue(sut.searchResults.isEmpty)
        XCTAssertNil(sut.searchErrorMessage)
        XCTAssertFalse(sut.isSearching)
        XCTAssertTrue(service.searchQueries.isEmpty)
    }

    func testSearchPassesNonEmptyQueryToServiceUnchanged() async {
        let service = RouteDiscoveryServiceStub(
            search: PublicRouteSearchResult(state: .completed, items: [])
        )
        let sut = RouteDiscoveryViewModel(service: service)
        let query = " \t贡嘎\u{3000}\n"

        await sut.search(query: query)

        XCTAssertEqual(service.searchQueries, [query])
    }

    func testCollectionLoadsAllPublicRoutes() async {
        let service = RouteDiscoveryServiceStub(
            all: PublicRouteCollectionResult(items: [Self.browseSummary])
        )
        let sut = RouteCollectionViewModel(service: service)

        await sut.loadRoutes()

        XCTAssertEqual(sut.routes, [Self.browseSummary])
        XCTAssertFalse(sut.isLoading)
        XCTAssertNil(sut.errorMessage)
    }

    func testSearchRestoresAWhileBIsPendingIncludingEmptyResults() async {
        for items in [[Self.searchSummary], []] {
            let bStarted = expectation(description: "B started")
            let gate = RouteAsyncGate()
            let service = RouteDiscoveryServiceStub()
            service.searchHandler = { query in
                if query == "B" {
                    bStarted.fulfill()
                    await gate.wait()
                    throw APIClientError.transport(.other("迟到错误"))
                }
                return PublicRouteSearchResult(state: .completed, items: items)
            }
            let sut = RouteDiscoveryViewModel(service: service)
            await sut.search(query: "A", immediate: true)
            let b = Task { await sut.search(query: "B", immediate: true) }
            await fulfillment(of: [bStarted], timeout: 1)
            XCTAssertTrue(sut.isSearching)
            XCTAssertTrue(sut.searchResults.isEmpty, "不能用 A 的结果冒充当前 B")

            await sut.search(query: "A")
            XCTAssertFalse(sut.isSearching, "恢复已完成查询必须结束 B 的 loading")
            XCTAssertEqual(sut.searchState, .completed)
            XCTAssertEqual(sut.searchResults, items)
            XCTAssertEqual(service.searchQueries, ["A", "B"])

            await gate.open()
            await b.value
            XCTAssertFalse(sut.isSearching)
            XCTAssertNil(sut.searchErrorMessage)
            XCTAssertEqual(sut.searchResults, items)
        }
    }

    func testSearchRestoresNoResultsWithoutAnotherRequestButSubmitRefreshes() async {
        let service = RouteDiscoveryServiceStub(searchResults: [
            PublicRouteSearchResult(state: .completed, items: []),
            PublicRouteSearchResult(state: .completed, items: [Self.searchSummary]),
        ])
        let sut = RouteDiscoveryViewModel(service: service)
        await sut.search(query: "A", immediate: true)
        await sut.search(query: "A")
        XCTAssertEqual(service.searchQueries, ["A"])
        XCTAssertEqual(sut.searchState, .completed)
        XCTAssertTrue(sut.searchResults.isEmpty)
        XCTAssertFalse(sut.isSearching)

        await sut.search(query: "A", immediate: true)
        XCTAssertEqual(service.searchQueries, ["A", "A"])
        XCTAssertEqual(sut.searchResults, [Self.searchSummary])
    }

    func testSearchIgnoresOldSuccessEmptyResultAndFailure() async {
        let lateResults: [Result<PublicRouteSearchResult, Error>] = [
            .success(PublicRouteSearchResult(state: .completed, items: [Self.searchSummary])),
            .success(PublicRouteSearchResult(state: .completed, items: [])),
            .failure(APIClientError.transport(.other("旧错误"))),
        ]
        for lateResult in lateResults {
            let started = expectation(description: "old search started")
            let gate = RouteAsyncGate()
            let service = RouteDiscoveryServiceStub()
            service.searchHandler = { query in
                if query == "A" {
                    started.fulfill()
                    await gate.wait()
                    return try lateResult.get()
                }
                return PublicRouteSearchResult(state: .completed, items: [])
            }
            let sut = RouteDiscoveryViewModel(service: service)
            let old = Task { await sut.search(query: "A", immediate: true) }
            await fulfillment(of: [started], timeout: 1)
            await sut.search(query: "B", immediate: true)
            await gate.open()
            await old.value
            XCTAssertEqual(sut.lastSearchQuery, "B")
            XCTAssertEqual(sut.searchState, .completed)
            XCTAssertTrue(sut.searchResults.isEmpty)
            XCTAssertNil(sut.searchErrorMessage)
            XCTAssertFalse(sut.isSearching)
        }
    }

    func testClearingSearchInvalidatesPendingResult() async {
        let started = expectation(description: "search started")
        let gate = RouteAsyncGate()
        let service = RouteDiscoveryServiceStub()
        service.searchHandler = { _ in
            started.fulfill()
            await gate.wait()
            return PublicRouteSearchResult(state: .completed, items: [Self.searchSummary])
        }
        let sut = RouteDiscoveryViewModel(service: service)
        let task = Task { await sut.search(query: "A", immediate: true) }
        await fulfillment(of: [started], timeout: 1)
        await sut.search(query: " \t\n\r\u{3000}")
        XCTAssertFalse(sut.isSearching)
        await gate.open()
        await task.value
        XCTAssertEqual(sut.searchState, .initial)
        XCTAssertTrue(sut.searchResults.isEmpty)
        XCTAssertNil(sut.searchErrorMessage)
    }

    func testSearchCancellationDoesNotPublishLateSuccess() async {
        let started = expectation(description: "search started")
        let gate = RouteAsyncGate()
        let service = RouteDiscoveryServiceStub()
        service.searchHandler = { _ in
            started.fulfill()
            await gate.wait()
            return PublicRouteSearchResult(state: .completed, items: [Self.searchSummary])
        }
        let sut = RouteDiscoveryViewModel(service: service)
        let task = Task { await sut.search(query: "A", immediate: true) }
        await fulfillment(of: [started], timeout: 1)
        let cancelled = expectation(description: "search cancellation published")
        withObservationTracking { _ = sut.isSearching } onChange: { cancelled.fulfill() }
        task.cancel()
        await fulfillment(of: [cancelled], timeout: 1)
        XCTAssertFalse(sut.isSearching)
        await gate.open()
        await task.value
        XCTAssertFalse(sut.isSearching)
        XCTAssertTrue(sut.searchResults.isEmpty)
        XCTAssertNil(sut.searchErrorMessage)
        XCTAssertNil(sut.lastSearchQuery)
    }

    func testSearchContentOwnsAndCancelsManualSearchTaskAcrossLifecycle() throws {
        let source = try productionSource(at: "Features/Routes/RouteDiscoveryView.swift")
        let start = try XCTUnwrap(source.range(of: "private struct RouteSearchContent: View {"))
        let end = try XCTUnwrap(source.range(of: "private struct SearchFocusActivator:", range: start.upperBound..<source.endIndex))
        func normalized(_ value: String) -> String {
            value.split(separator: "\n")
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .joined(separator: "\n")
        }
        let content = normalized(String(source[start.lowerBound..<end.lowerBound]))

        XCTAssertTrue(content.contains("@State private var manualSearchTask: Task<Void, Never>?"))
        XCTAssertTrue(content.contains(normalized("""
        .task(id: boundQuery.wrappedValue) {
            await viewModel.search(query: boundQuery.wrappedValue)
        }
        """)), "query 变化仍走模型默认的 300ms 防抖")
        XCTAssertTrue(content.contains(normalized("""
        .onChange(of: boundQuery.wrappedValue) { _, _ in
            cancelManualSearch()
        }
        """)))
        XCTAssertTrue(content.contains(".onDisappear(perform: cancelManualSearch)"))
        XCTAssertTrue(content.contains(normalized("""
        private func submitSearch() {
            cancelManualSearch()
            let query = boundQuery.wrappedValue
            manualSearchTask = Task {
                await viewModel.search(query: query, immediate: true)
            }
        }
        """)), "再次提交先取消旧任务，再立即搜索本次输入")
        XCTAssertTrue(content.contains(normalized("""
        private func cancelManualSearch() {
            manualSearchTask?.cancel()
            manualSearchTask = nil
        }
        """)))
        XCTAssertFalse(content.contains("defer"), "旧任务结束不能清空新任务句柄")
    }

    func testOldSearchCancellationCannotEndNewLoading() async {
        let aStarted = expectation(description: "A started")
        let bStarted = expectation(description: "B started")
        let aGate = RouteAsyncGate()
        let bGate = RouteAsyncGate()
        let service = RouteDiscoveryServiceStub()
        service.searchHandler = { query in
            if query == "A" {
                aStarted.fulfill()
                await aGate.wait()
            } else {
                bStarted.fulfill()
                await bGate.wait()
            }
            return PublicRouteSearchResult(state: .completed, items: [])
        }
        let sut = RouteDiscoveryViewModel(service: service)
        let a = Task { await sut.search(query: "A", immediate: true) }
        await fulfillment(of: [aStarted], timeout: 1)
        let b = Task { await sut.search(query: "B", immediate: true) }
        await fulfillment(of: [bStarted], timeout: 1)
        a.cancel()
        await aGate.open()
        await a.value
        XCTAssertTrue(sut.isSearching)
        await bGate.open()
        await b.value
        XCTAssertFalse(sut.isSearching)
        XCTAssertEqual(sut.lastSearchQuery, "B")
    }

    func testSearchBlankPredicateDoesNotExpandUnicodeWhitespace() async {
        XCTAssertTrue(RouteDiscoveryViewModel.isEmptyQuery(" \t\n\r\u{3000}"))
        XCTAssertFalse(RouteDiscoveryViewModel.isEmptyQuery("\u{00A0}"))
        XCTAssertFalse(RouteDiscoveryViewModel.isEmptyQuery("\u{2003}"))
        let service = RouteDiscoveryServiceStub()
        let sut = RouteDiscoveryViewModel(service: service)
        await sut.search(query: "\u{00A0}", immediate: true)
        XCTAssertEqual(service.searchQueries, ["\u{00A0}"])
    }

    func testDiscoveryAndSearchHaveIndependentLoadingAndErrors() async {
        let started = expectation(description: "discovery started")
        let gate = RouteAsyncGate()
        let service = RouteDiscoveryServiceStub(searchError: APIClientError.transport(.other("搜索失败")))
        service.featuredHandler = {
            started.fulfill()
            await gate.wait()
            return PublicRouteDiscoveryResult(items: [Self.browseSummary])
        }
        let sut = RouteDiscoveryViewModel(service: service)
        let task = Task { await sut.loadRoutes() }
        await fulfillment(of: [started], timeout: 1)
        await sut.search(query: "A", immediate: true)
        XCTAssertTrue(sut.isLoading)
        XCTAssertNil(sut.errorMessage)
        XCTAssertFalse(sut.isSearching)
        XCTAssertEqual(sut.searchErrorMessage, "搜索失败")
        await gate.open()
        await task.value
        XCTAssertEqual(sut.routes, [Self.browseSummary])
        XCTAssertEqual(sut.searchErrorMessage, "搜索失败")
    }

    func testDiscoveryCancellationRejectsLateDataAndAllowsRetry() async {
        let started = expectation(description: "discovery started")
        let gate = RouteAsyncGate()
        let service = RouteDiscoveryServiceStub(featured: PublicRouteDiscoveryResult(items: [Self.browseSummary]))
        service.featuredHandler = {
            started.fulfill()
            await gate.wait()
            return PublicRouteDiscoveryResult(items: [Self.browseSummary])
        }
        let sut = RouteDiscoveryViewModel(service: service)
        let task = Task { await sut.loadRoutes() }
        await fulfillment(of: [started], timeout: 1)
        task.cancel()
        await gate.open()
        await task.value
        XCTAssertFalse(sut.isLoading)
        XCTAssertTrue(sut.routes.isEmpty)
        XCTAssertNil(sut.errorMessage)
        service.featuredHandler = nil
        await sut.retry()
        XCTAssertEqual(sut.routes, [Self.browseSummary])
        XCTAssertEqual(service.featuredCallCount, 2)
    }

    func testCollectionCancellationRejectsLateDataAndAllowsRetry() async {
        let started = expectation(description: "collection started")
        let gate = RouteAsyncGate()
        let service = RouteDiscoveryServiceStub(all: PublicRouteCollectionResult(items: [Self.browseSummary]))
        service.collectionHandler = {
            started.fulfill()
            await gate.wait()
            return PublicRouteCollectionResult(items: [Self.browseSummary])
        }
        let sut = RouteCollectionViewModel(service: service)
        let task = Task { await sut.loadRoutes() }
        await fulfillment(of: [started], timeout: 1)
        task.cancel()
        await gate.open()
        await task.value
        XCTAssertFalse(sut.isLoading)
        XCTAssertTrue(sut.routes.isEmpty)
        XCTAssertNil(sut.errorMessage)
        service.collectionHandler = nil
        await sut.retry()
        XCTAssertEqual(sut.routes, [Self.browseSummary])
        XCTAssertEqual(service.collectionCallCount, 2)
    }

    func testDiscoveryCancellationFinishesBeforeServiceAndOldFailureCannotEndRetry() async {
        let firstStarted = expectation(description: "first discovery started")
        let secondStarted = expectation(description: "second discovery started")
        let cancelled = expectation(description: "discovery cancellation published")
        let firstGate = RouteAsyncGate()
        let secondGate = RouteAsyncGate()
        let service = RouteDiscoveryServiceStub()
        var calls = 0
        service.featuredHandler = {
            calls += 1
            if calls == 1 {
                firstStarted.fulfill()
                await firstGate.wait()
                throw APIClientError.transport(.other("旧错误"))
            }
            secondStarted.fulfill()
            await secondGate.wait()
            return PublicRouteDiscoveryResult(items: [Self.browseSummary])
        }
        let sut = RouteDiscoveryViewModel(service: service)
        let first = Task { await sut.loadRoutes() }
        await fulfillment(of: [firstStarted], timeout: 1)
        await sut.loadRoutes()
        XCTAssertEqual(calls, 1, "进行中的重复加载不另起请求")
        withObservationTracking { _ = sut.isLoading } onChange: { cancelled.fulfill() }
        first.cancel()
        await fulfillment(of: [cancelled], timeout: 1)
        XCTAssertFalse(sut.isLoading, "不等待不合作的 Service 才结束取消状态")
        let second = Task { await sut.retry() }
        await fulfillment(of: [secondStarted], timeout: 1)
        await firstGate.open()
        await first.value
        XCTAssertTrue(sut.isLoading)
        XCTAssertNil(sut.errorMessage)
        await secondGate.open()
        await second.value
        XCTAssertEqual(sut.routes, [Self.browseSummary])
    }

    func testCollectionCancellationFinishesBeforeServiceAndOldSuccessCannotEndRetry() async {
        let firstStarted = expectation(description: "first collection started")
        let secondStarted = expectation(description: "second collection started")
        let cancelled = expectation(description: "collection cancellation published")
        let firstGate = RouteAsyncGate()
        let secondGate = RouteAsyncGate()
        let service = RouteDiscoveryServiceStub()
        var calls = 0
        service.collectionHandler = {
            calls += 1
            if calls == 1 {
                firstStarted.fulfill()
                await firstGate.wait()
                return PublicRouteCollectionResult(items: [Self.browseSummary])
            }
            secondStarted.fulfill()
            await secondGate.wait()
            return PublicRouteCollectionResult(items: [])
        }
        let sut = RouteCollectionViewModel(service: service)
        let first = Task { await sut.loadRoutes() }
        await fulfillment(of: [firstStarted], timeout: 1)
        await sut.loadRoutes()
        XCTAssertEqual(calls, 1)
        withObservationTracking { _ = sut.isLoading } onChange: { cancelled.fulfill() }
        first.cancel()
        await fulfillment(of: [cancelled], timeout: 1)
        XCTAssertFalse(sut.isLoading)
        let second = Task { await sut.retry() }
        await fulfillment(of: [secondStarted], timeout: 1)
        await firstGate.open()
        await first.value
        XCTAssertTrue(sut.isLoading, "旧 defer 不得结束新 loading")
        XCTAssertTrue(sut.routes.isEmpty, "已取消请求的迟到结果不得发布")
        await secondGate.open()
        await second.value
        XCTAssertTrue(sut.routes.isEmpty)
        XCTAssertFalse(sut.isLoading)
    }

    func testSearchCancellationAtQueryChangeSkipsDebounceRequestAndPreservesRestoration() async {
        let service = RouteDiscoveryServiceStub(search: PublicRouteSearchResult(state: .completed, items: [Self.searchSummary]))
        let sut = RouteDiscoveryViewModel(service: service)
        await sut.search(query: "A", immediate: true)
        withObservationTracking {
            _ = sut.searchContext.query
        } onChange: {
            // Observation 在写入任务内同步通知；精确取消 B，不靠抢在 300ms 前唤醒测试。
            withUnsafeCurrentTask { $0?.cancel() }
        }
        let task = Task { await sut.search(query: "B") }
        await task.value
        XCTAssertFalse(sut.isSearching)
        XCTAssertTrue(sut.searchResults.isEmpty)
        XCTAssertNil(sut.searchErrorMessage)
        XCTAssertEqual(service.searchQueries, ["A"])
        await sut.search(query: "A")
        XCTAssertEqual(sut.searchResults, [Self.searchSummary])
    }

    func testDetailOldSuccessAndFailureCannotFinishNewLoading() async {
        let aDetail = Self.detail(routeID: "A", availability: .missing, mainTrack: nil)
        let bDetail = Self.detail(routeID: "B", availability: .missing, mainTrack: nil)
        let lateResults: [Result<PublicRouteDetail, Error>] = [
            .success(aDetail), .failure(APIClientError.transport(.other("旧错误"))),
        ]
        for lateResult in lateResults {
            let aStarted = expectation(description: "detail A started")
            let bStarted = expectation(description: "detail B started")
            let aGate = RouteAsyncGate()
            let bGate = RouteAsyncGate()
            let service = RouteDetailServiceStub(detail: bDetail)
            service.loadHandler = { id in
                if id == "A" {
                    aStarted.fulfill()
                    await aGate.wait()
                    return try lateResult.get()
                }
                bStarted.fulfill()
                await bGate.wait()
                return bDetail
            }
            let sut = RouteDetailViewModel(service: service)
            let a = Task { await sut.loadRoute(id: "A") }
            await fulfillment(of: [aStarted], timeout: 1)
            let b = Task { await sut.loadRoute(id: "B") }
            await fulfillment(of: [bStarted], timeout: 1)
            await aGate.open()
            await a.value
            XCTAssertTrue(sut.isLoading, "旧 defer 不得结束 B 的 loading")
            XCTAssertNil(sut.route)
            XCTAssertNil(sut.errorMessage)
            await bGate.open()
            await b.value
            XCTAssertEqual(sut.route, bDetail)
            service.loadHandler = nil
            await sut.retry()
            XCTAssertEqual(service.loadedIDs, ["A", "B", "B"])
        }
    }

    func testDetailLatestResultSurvivesLateOldSuccess() async {
        let aDetail = Self.detail(routeID: "A", availability: .missing, mainTrack: nil)
        let bDetail = Self.detail(routeID: "B", availability: .missing, mainTrack: nil)
        let started = expectation(description: "old detail started")
        let gate = RouteAsyncGate()
        let service = RouteDetailServiceStub(detail: bDetail)
        service.loadHandler = { id in
            guard id == "A" else { return bDetail }
            started.fulfill()
            await gate.wait()
            return aDetail
        }
        let sut = RouteDetailViewModel(service: service)
        let old = Task { await sut.loadRoute(id: "A") }
        await fulfillment(of: [started], timeout: 1)
        await sut.loadRoute(id: "B")
        await gate.open()
        await old.value
        XCTAssertEqual(sut.route, bDetail)
        XCTAssertFalse(sut.isLoading)
        XCTAssertNil(sut.errorMessage)
    }

    func testDetailSwitchClearsPreviousRouteProjectionAndCancelledResult() async {
        let aDetail = Self.detail(routeID: "A", availability: .valid, mainTrack: PublicRouteMainTrack(
            identity: "track-A",
            path: [PublicRouteGeoPosition(latitude: 29, longitude: 101, referenceSystem: "WGS84")]
        ))
        let bDetail = Self.detail(routeID: "B", availability: .missing, mainTrack: nil)
        let service = RouteDetailServiceStub(detail: aDetail)
        let sut = RouteDetailViewModel(service: service)
        await sut.loadRoute(id: "A")
        sut.togglePointHighlight(for: "point-1")
        XCTAssertFalse(sut.mapCoordinates.isEmpty)
        let started = expectation(description: "new detail started")
        let gate = RouteAsyncGate()
        service.loadHandler = { _ in
            started.fulfill()
            await gate.wait()
            return bDetail
        }
        let task = Task { await sut.loadRoute(id: "B") }
        await fulfillment(of: [started], timeout: 1)
        XCTAssertNil(sut.route)
        XCTAssertTrue(sut.mapCoordinates.isEmpty)
        XCTAssertTrue(sut.waypointAnnotations.isEmpty)
        XCTAssertNil(sut.highlightedPointIdentity)
        let cancelled = expectation(description: "detail cancellation published")
        withObservationTracking { _ = sut.isLoading } onChange: { cancelled.fulfill() }
        task.cancel()
        await fulfillment(of: [cancelled], timeout: 1)
        XCTAssertFalse(sut.isLoading)
        await gate.open()
        await task.value
        XCTAssertNil(sut.route)
        XCTAssertFalse(sut.isLoading)
        XCTAssertNil(sut.errorMessage)
    }

    func testDetailSameIDReloadRejectsOldResponseByGeneration() async {
        let oldDetail = Self.detail(availability: .missing, mainTrack: nil)
        let newDetail = Self.detail(availability: .pendingReview, mainTrack: nil)
        let started = expectation(description: "first same ID load started")
        let gate = RouteAsyncGate()
        let service = RouteDetailServiceStub(detail: newDetail)
        var calls = 0
        service.loadHandler = { _ in
            calls += 1
            guard calls == 1 else { return newDetail }
            started.fulfill()
            await gate.wait()
            return oldDetail
        }
        let sut = RouteDetailViewModel(service: service)
        let old = Task { await sut.loadRoute(id: "route-1") }
        await fulfillment(of: [started], timeout: 1)
        await sut.loadRoute(id: "route-1")
        await gate.open()
        await old.value
        XCTAssertEqual(sut.route, newDetail)
        XCTAssertFalse(sut.isLoading)
    }

    func testCancelledOldDetailCannotEndNewLoading() async {
        let detail = Self.detail(routeID: "B", availability: .missing, mainTrack: nil)
        let aStarted = expectation(description: "detail A started")
        let bStarted = expectation(description: "detail B started")
        let aGate = RouteAsyncGate()
        let bGate = RouteAsyncGate()
        let service = RouteDetailServiceStub(detail: detail)
        service.loadHandler = { id in
            if id == "A" {
                aStarted.fulfill()
                await aGate.wait()
                throw CancellationError()
            }
            bStarted.fulfill()
            await bGate.wait()
            return detail
        }
        let sut = RouteDetailViewModel(service: service)
        let a = Task { await sut.loadRoute(id: "A") }
        await fulfillment(of: [aStarted], timeout: 1)
        let b = Task { await sut.loadRoute(id: "B") }
        await fulfillment(of: [bStarted], timeout: 1)
        a.cancel()
        await aGate.open()
        await a.value
        XCTAssertTrue(sut.isLoading)
        XCTAssertNil(sut.errorMessage)
        await bGate.open()
        await b.value
        XCTAssertEqual(sut.route, detail)
        XCTAssertFalse(sut.isLoading)
    }

    func testServiceCancellationDoesNotFailDiscoveryWithoutTaskCancellation() async {
        let service = RouteDiscoveryServiceStub(featured: PublicRouteDiscoveryResult(items: [Self.browseSummary]))
        service.featuredHandler = { throw APIClientError.transport(.cancelled) }
        let sut = RouteDiscoveryViewModel(service: service)
        await sut.loadRoutes()
        XCTAssertFalse(Task.isCancelled)
        XCTAssertFalse(sut.isLoading)
        XCTAssertNil(sut.errorMessage)
        XCTAssertTrue(sut.routes.isEmpty)
        service.featuredHandler = nil
        await sut.retry()
        XCTAssertEqual(sut.routes, [Self.browseSummary])
    }

    func testServiceCancellationDoesNotFailSearchWithoutTaskCancellation() async {
        let service = RouteDiscoveryServiceStub(search: PublicRouteSearchResult(state: .completed, items: [Self.searchSummary]))
        let sut = RouteDiscoveryViewModel(service: service)
        await sut.search(query: "A", immediate: true)
        service.searchHandler = { _ in throw APIClientError.transport(.cancelled) }
        await sut.search(query: "B", immediate: true)
        XCTAssertFalse(Task.isCancelled)
        XCTAssertFalse(sut.isSearching)
        XCTAssertNil(sut.searchErrorMessage)
        XCTAssertTrue(sut.searchResults.isEmpty)
        await sut.search(query: "A")
        XCTAssertEqual(sut.searchResults, [Self.searchSummary])
    }

    func testServiceCancellationDoesNotFailCollectionWithoutTaskCancellation() async {
        let service = RouteDiscoveryServiceStub(all: PublicRouteCollectionResult(items: [Self.browseSummary]))
        service.collectionHandler = { throw APIClientError.transport(.cancelled) }
        let sut = RouteCollectionViewModel(service: service)
        await sut.loadRoutes()
        XCTAssertFalse(Task.isCancelled)
        XCTAssertFalse(sut.isLoading)
        XCTAssertNil(sut.errorMessage)
        service.collectionHandler = nil
        await sut.retry()
        XCTAssertEqual(sut.routes, [Self.browseSummary])
    }

    func testServiceCancellationDoesNotFailDetailAndKeepsSnapshotOnRefresh() async {
        let detail = Self.detail(availability: .missing, mainTrack: nil)
        let service = RouteDetailServiceStub(detail: detail, loadErrors: [APIClientError.transport(.cancelled)])
        let sut = RouteDetailViewModel(service: service)
        await sut.loadRoute(id: detail.routeId)
        XCTAssertFalse(Task.isCancelled)
        XCTAssertFalse(sut.isLoading)
        XCTAssertNil(sut.errorMessage)
        XCTAssertNil(sut.route)
        await sut.retry()
        let snapshot = sut.state.snapshot
        service.loadHandler = { _ in throw APIClientError.transport(.cancelled) }
        await sut.retry()
        XCTAssertFalse(sut.isLoading)
        XCTAssertNil(sut.errorMessage)
        XCTAssertEqual(sut.route, detail)
        XCTAssertEqual(sut.state.snapshot?.waypointAnnotations, snapshot?.waypointAnnotations)
    }

    func testDetailSnapshotIsPublishedWithRouteAndUnaffectedBySelection() async throws {
        let detail = Self.detail(availability: .valid, mainTrack: PublicRouteMainTrack(
            identity: "track", path: [
                PublicRouteGeoPosition(latitude: 29, longitude: 101, referenceSystem: "WGS84"),
                PublicRouteGeoPosition(latitude: 30, longitude: 102, referenceSystem: "WGS84"),
            ]
        ))
        let sut = RouteDetailViewModel(service: RouteDetailServiceStub(detail: detail))
        await sut.loadRoute(id: detail.routeId)
        let snapshot = try XCTUnwrap(sut.state.snapshot)
        XCTAssertEqual(snapshot.route, sut.route)
        XCTAssertEqual(snapshot.mapCoordinates.map(\.latitude), [29, 30])
        XCTAssertEqual(snapshot.waypointAnnotations, sut.waypointAnnotations)
        sut.togglePointHighlight(for: "point-1")
        XCTAssertEqual(sut.state.snapshot?.route, snapshot.route)
        XCTAssertEqual(sut.mapCoordinates.map(\.latitude), snapshot.mapCoordinates.map(\.latitude))
        XCTAssertFalse(sut.highlightedAnnotationIDs.isEmpty)
    }

    func testDetailHeavyProjectionUsesStoredSnapshotAndNonisolatedBuilder() throws {
        let source = try productionSource(at: "Features/Routes/RouteDetailViewModel.swift")
        let state = try productionSource(at: "Features/Routes/RouteDetailState.swift")
        XCTAssertTrue(source.contains("nonisolated static func makeSnapshot"))
        XCTAssertTrue(source.contains("await Self.makeSnapshot(from: detail)"))
        XCTAssertTrue(source.contains("state.snapshot?.mapCoordinates ?? []"))
        XCTAssertTrue(source.contains("state.snapshot?.mapSegments ?? []"))
        XCTAssertTrue(source.contains("state.snapshot?.poiAnnotations ?? []"))
        XCTAssertTrue(source.contains("state.snapshot?.elevationSamples ?? []"))
        XCTAssertTrue(state.contains("let route: PublicRouteDetail"))
        XCTAssertTrue(state.contains("let mapCoordinates: [CLLocationCoordinate2D]"))
        XCTAssertTrue(state.contains("let mapSegments: [RouteMapSegment]"))
        XCTAssertTrue(source.contains("state.snapshot?.dayMapSegments ?? []"))
        XCTAssertTrue(source.contains("state.snapshot?.coloredMapSegments ?? []"))
        let page = try productionSource(at: "Features/Routes/RouteDetailView.swift")
        let overlay = try productionSource(at: "Features/Routes/RouteDetailViewSupport.swift")
        XCTAssertTrue(page.contains("elevationProfile: viewModel.elevationProfileProjection"))
        XCTAssertTrue(overlay.contains("let elevationProfile: ElevationProfileProjection?"))
        XCTAssertFalse(overlay.contains("presentation.elevationProfileProjection"))
        XCTAssertFalse(source.contains("guard let profile = elevationProfile else"), "章节元数据不能重建海拔采样数组")
    }

    func testRootOwnsRouteListSearchAndDetailNavigation() throws {
        let rootSource = try productionSource(at: "App/RootView.swift")
        let routeSource = try productionSource(at: "Features/Routes/RouteDiscoveryView.swift")

        XCTAssertTrue(rootSource.contains("case .routeSearch:"))
        XCTAssertTrue(rootSource.contains("RouteSearchView("))
        XCTAssertTrue(routeSource.contains("onNavigate(.routeSearch)"))
        XCTAssertTrue(routeSource.contains("onNavigate(.routeDetail(route.routeId))"))
        XCTAssertFalse(routeSource.contains("NavigationLink(destination: RouteSearchView"))
    }

    func testSelectingSegmentAgainRestoresFullRoute() async {
        let path = [
            PublicRouteGeoPosition(latitude: 29.0, longitude: 101.0, referenceSystem: "WGS84"),
            PublicRouteGeoPosition(latitude: 30.0, longitude: 102.0, referenceSystem: "WGS84"),
            PublicRouteGeoPosition(latitude: 31.0, longitude: 103.0, referenceSystem: "WGS84"),
        ]
        let ranged = PublicRouteSegment(
            identity: "segment-ranged",
            order: 1,
            name: "明确范围",
            mainTrackRange: PublicRouteMainTrackRange(
                startPathPosition: .init(precedingPositionIndex: 0, progressToNextPosition: 0.5),
                endPathPosition: .init(precedingPositionIndex: 2, progressToNextPosition: nil)
            )
        )
        let unranged = PublicRouteSegment(identity: "segment-unranged", order: 2, name: "无范围")
        let detail = Self.detail(
            availability: .valid,
            mainTrack: PublicRouteMainTrack(identity: "track-1", path: path),
            segments: [ranged, unranged]
        )
        let sut = RouteDetailViewModel(service: RouteDetailServiceStub(detail: detail))
        await sut.loadRoute(id: detail.routeId)

        sut.selectSegment("segment-ranged")
        XCTAssertEqual(sut.selectedSegmentID, "segment-ranged")

        sut.selectSegment("segment-ranged")
        XCTAssertNil(sut.selectedSegmentID)

        sut.selectSegment("segment-unranged")
        XCTAssertNil(sut.selectedSegmentID)
    }

    func testHighlightingInfoPointTargetsAllMapMarkersOfSameObject() async {
        let path = [
            PublicRouteGeoPosition(latitude: 29.6, longitude: 101.8, referenceSystem: "WGS84"),
            PublicRouteGeoPosition(latitude: 29.7, longitude: 101.9, referenceSystem: "WGS84"),
        ]
        let detail = Self.detail(
            availability: .valid,
            mainTrack: PublicRouteMainTrack(identity: "track-1", path: path),
            keyPoints: [
                PublicRouteNamedPoint(identity: "point-1", name: "埄口", positions: [path[0], path[1]])
            ]
        )
        let sut = RouteDetailViewModel(service: RouteDetailServiceStub(detail: detail))
        await sut.loadRoute(id: detail.routeId)

        sut.togglePointHighlight(for: "point-1")
        XCTAssertEqual(sut.highlightedAnnotationIDs.count, 2)

        sut.togglePointHighlight(for: "point-1")
        XCTAssertTrue(sut.highlightedAnnotationIDs.isEmpty)
    }

    func testReloadingRouteClearsMapHighlight() async {
        let detail = Self.detail(availability: .valid, mainTrack: PublicRouteMainTrack(
            identity: "track-1",
            path: [
                PublicRouteGeoPosition(latitude: 29.6, longitude: 101.8, referenceSystem: "WGS84"),
                PublicRouteGeoPosition(latitude: 29.7, longitude: 101.9, referenceSystem: "WGS84"),
            ]
        ))
        let sut = RouteDetailViewModel(service: RouteDetailServiceStub(detail: detail))
        await sut.loadRoute(id: detail.routeId)
        sut.togglePointHighlight(for: "point-1")
        XCTAssertFalse(sut.highlightedAnnotationIDs.isEmpty)

        await sut.retry()

        XCTAssertTrue(sut.highlightedAnnotationIDs.isEmpty)
        XCTAssertNil(sut.selectedSegmentID)
    }

    func testRouteDetailRequiresGenerateCallback() throws {
        let source = try productionSource(at: "Features/Routes/RouteDetailView.swift")

        XCTAssertFalse(source.contains("onGenerateTrip: @escaping (String) -> Void = { _ in }"))
        XCTAssertTrue(source.contains("onGenerateTrip(routeId)"))
    }

    func testRouteDetailUsesProductionComponentsForEveryAuditedSafeSection() throws {
        let source = try routeDetailPageSources()
        let componentCalls = [
            "RouteBusinessComponents.RouteSummary(",
            "RouteBusinessComponents.RouteIntroduction(",
            "RouteBusinessComponents.RouteReferenceDayList(",
            "RouteBusinessComponents.RouteSegmentList(",
            "RouteBusinessComponents.RoutePointSection(",
            "RouteBusinessComponents.RouteFactSection(",
            // 海拔曲线固定在信息面最底部（信息面迭代）。
            "RouteBusinessComponents.ElevationProfile(",
        ]

        let ranges = try componentCalls.map { call in
            try XCTUnwrap(source.range(of: call), "Missing production component call: \(call)")
        }
        for (earlier, later) in zip(ranges, ranges.dropFirst()) {
            XCTAssertLessThan(earlier.lowerBound, later.lowerBound)
        }

        XCTAssertFalse(source.contains("private struct RouteDetailSummary"))
        XCTAssertFalse(source.contains("private struct RouteElevationProfileChart"))
        XCTAssertFalse(source.contains("private struct RouteDetailItemList"))
    }

    func testRouteDetailKeepsPausedMapPointDetailAndMediaStructuresUnchanged() throws {
        let source = try productionSource(at: "Features/Routes/RouteDetailView.swift")

        XCTAssertTrue(source.contains("RouteMapView("))
        XCTAssertFalse(source.contains("private struct RoutePointBottomDetail"), "6.3 后页面不再持有私有点位详情")
        XCTAssertTrue(source.contains("RouteBusinessComponents.RoutePointDetail("), "点位详情使用生产 RoutePointDetail 组件")
        XCTAssertFalse(source.contains("private struct RouteImageGrid"), "6.3 后页面不保留私有图片网格")
        XCTAssertFalse(source.contains("private struct RouteImageViewer"), "6.3 后页面不保留图片查看器")
        XCTAssertFalse(source.contains("@State private var selectedImage: RouteDetailImagePresentation?"), "6.3 后页面不持有图片覆盖层状态")
    }

    func testRouteDetailSafeProjectionAPIsPreserveOptionalityAndConfidence() throws {
        let viewModelSource = try productionSource(at: "Features/Routes/RouteDetailViewModel.swift")
        let introductionSource = try productionSource(
            at: "Features/Routes/Components/RouteIntroduction.swift"
        )
        let referenceDaySource = try productionSource(
            at: "Features/Routes/Components/RouteReferenceDayList.swift"
        )
        let segmentSource = try productionSource(
            at: "Features/Routes/Components/RouteSegmentList.swift"
        )

        [
            "var routeSummaryProjection: RouteSummaryProjection",
            "var routeIntroductionProjection: RouteIntroductionProjection?",
            "var elevationProfileProjection: ElevationProfileProjection?",
            "var referenceDayProjections: [RouteReferenceDayProjection]",
            "var routeSegmentListProjection: RouteSegmentListProjection?",
            "var routePointSectionProjections: [RoutePointSectionProjection]",
            "var routeFactSectionProjections: [RouteFactSectionProjection]",
        ].forEach { declaration in
            XCTAssertTrue(viewModelSource.contains(declaration), "Missing projection: \(declaration)")
        }
        XCTAssertTrue(introductionSource.contains("var confidence: InformationConfidence?"))
        XCTAssertTrue(referenceDaySource.contains("var title: String?"))
        XCTAssertTrue(segmentSource.contains("var start: String?"))
        XCTAssertTrue(segmentSource.contains("var end: String?"))
    }

    func testRouteDetailKeepsMapLayerBehindLoadingErrorAndContentStates() throws {
        let source = try productionSource(at: "Features/Routes/RouteDetailView.swift")
        let mapLayer = try XCTUnwrap(source.range(of: "mapLayer(viewportHeight: geometry.size.height)"))
        let loading = try XCTUnwrap(source.range(of: "if viewModel.isLoading", range: mapLayer.upperBound..<source.endIndex))
        let error = try XCTUnwrap(source.range(of: "else if let message = viewModel.errorMessage", range: loading.upperBound..<source.endIndex))
        let content = try XCTUnwrap(source.range(of: "else if let presentation = viewModel.presentation", range: error.upperBound..<source.endIndex))

        XCTAssertLessThan(mapLayer.lowerBound, loading.lowerBound)
        XCTAssertLessThan(loading.lowerBound, error.lowerBound)
        XCTAssertLessThan(error.lowerBound, content.lowerBound)
    }

    func testDetailProjectsTrackOnlyWhenServerDeclaresValid() async {
        let detail = Self.detail(
            availability: .valid,
            mainTrack: PublicRouteMainTrack(
                identity: "track-1",
                path: [
                    PublicRouteGeoPosition(latitude: 29.6, longitude: 101.8, referenceSystem: "WGS84"),
                    PublicRouteGeoPosition(latitude: 29.7, longitude: 101.9, referenceSystem: "WGS84"),
                ]
            )
        )
        let sut = RouteDetailViewModel(service: RouteDetailServiceStub(detail: detail))

        await sut.loadRoute(id: detail.routeId)

        XCTAssertEqual(sut.route, detail)
        XCTAssertEqual(sut.mapCoordinates.map(\.latitude), [29.6, 29.7])
        XCTAssertFalse(sut.hasUnavailableTrack)
    }

    func testOnlyServerDeclaredValidMainTrackRangesCreateSelectableSegments() async {
        let path = [
            PublicRouteGeoPosition(latitude: 29.0, longitude: 101.0, referenceSystem: "WGS84"),
            PublicRouteGeoPosition(latitude: 30.0, longitude: 102.0, referenceSystem: "WGS84"),
            PublicRouteGeoPosition(latitude: 31.0, longitude: 103.0, referenceSystem: "WGS84"),
        ]
        let ranged = PublicRouteSegment(
            identity: "segment-ranged",
            order: 1,
            name: "明确范围",
            mainTrackRange: PublicRouteMainTrackRange(
                startPathPosition: .init(precedingPositionIndex: 0, progressToNextPosition: 0.5),
                endPathPosition: .init(precedingPositionIndex: 2, progressToNextPosition: nil)
            )
        )
        let unranged = PublicRouteSegment(identity: "segment-unranged", order: 2, name: "无范围")
        let invalid = PublicRouteSegment(
            identity: "segment-invalid",
            order: 3,
            name: "越界范围",
            mainTrackRange: PublicRouteMainTrackRange(
                startPathPosition: .init(precedingPositionIndex: 2, progressToNextPosition: nil),
                endPathPosition: .init(precedingPositionIndex: 8, progressToNextPosition: nil)
            )
        )
        let detail = Self.detail(
            availability: .valid,
            mainTrack: PublicRouteMainTrack(identity: "track-1", path: path),
            segments: [ranged, unranged, invalid]
        )
        let sut = RouteDetailViewModel(service: RouteDetailServiceStub(detail: detail))

        await sut.loadRoute(id: detail.routeId)

        XCTAssertEqual(sut.mapSegments.map(\.id), ["segment-ranged"])
        XCTAssertEqual(sut.selectableSegments.map(\.id), ["segment-ranged"])
        XCTAssertEqual(sut.mapSegments[0].coordinates.map(\.latitude), [29.5, 30.0, 31.0])
        XCTAssertTrue(sut.canSelectSegment("segment-ranged"))
        XCTAssertFalse(sut.canSelectSegment("segment-unranged"))
        sut.selectSegment("segment-ranged")
        XCTAssertEqual(sut.selectedSegmentID, "segment-ranged")
    }

    func testDetailOmitsPendingOrInvalidTrackButKeepsReliablyPositionedPoints() async {
        let position = PublicRouteGeoPosition(
            latitude: 29.65,
            longitude: 101.85,
            referenceSystem: "WGS84"
        )

        for availability in [MainTrackAvailability.pendingReview, .invalidated] {
            let detail = Self.detail(
                availability: availability,
                mainTrack: nil,
                segments: [
                    PublicRouteSegment(
                        identity: "segment-1",
                        order: 1,
                        name: "不可选分段",
                        mainTrackRange: PublicRouteMainTrackRange(
                            startPathPosition: .init(precedingPositionIndex: 0, progressToNextPosition: 0),
                            endPathPosition: .init(precedingPositionIndex: 1, progressToNextPosition: nil)
                        )
                    )
                ],
                keyPoints: [
                    PublicRouteNamedPoint(identity: "point-1", name: "垭口", positions: [position])
                ],
                interestPoints: [
                    PublicRouteNamedPoint(identity: "poi-1", name: "冰川", positions: [position])
                ],
                overnightPlaces: [
                    PublicRouteOvernightPlace(
                        identity: "overnight-1",
                        name: "山屋",
                        positions: [position],
                        elevation: RouteElevation(meters: 3_200),
                        type: "山屋",
                        facilities: ["床位"],
                        details: "需提前确认",
                        status: "待核验"
                    )
                ]
            )
            let sut = RouteDetailViewModel(service: RouteDetailServiceStub(detail: detail))

            await sut.loadRoute(id: detail.routeId)

            XCTAssertTrue(sut.mapCoordinates.isEmpty)
            XCTAssertTrue(sut.mapSegments.isEmpty)
            XCTAssertEqual(sut.waypointAnnotations.map(\.title), ["垭口"])
            XCTAssertEqual(Set(sut.poiAnnotations.map(\.title)), ["冰川", "山屋"])
            XCTAssertTrue(sut.hasUnavailableTrack)
        }
    }

    func testOvernightPlacesBecomeSelectableMapAnnotations() async {
        let position = PublicRouteGeoPosition(
            latitude: 29.65,
            longitude: 101.85,
            referenceSystem: "WGS84"
        )
        let detail = Self.detail(
            availability: .valid,
            mainTrack: PublicRouteMainTrack(identity: "track-1", path: [position]),
            overnightPlaces: [
                PublicRouteOvernightPlace(
                    identity: "overnight-1",
                    name: "山屋",
                    positions: [position],
                    elevation: RouteElevation(meters: 3_200),
                    type: "山屋",
                    facilities: ["床位"],
                    details: "需提前确认",
                    status: "待核验"
                )
            ]
        )
        let sut = RouteDetailViewModel(service: RouteDetailServiceStub(detail: detail))

        await sut.loadRoute(id: detail.routeId)

        let annotation = sut.poiAnnotations.first { $0.id.hasPrefix("overnight-1-") }
        XCTAssertEqual(annotation?.title, "山屋")
        XCTAssertEqual(annotation?.category, "过夜点")
        XCTAssertEqual(annotation?.subCategory, "山屋")
        XCTAssertEqual(annotation?.detail, "床位 · 需提前确认 · 待核验")
    }

    func testInvalidMainTrackDoesNotExposeElevationCurve() {
        let detail = Self.detail(
            availability: .invalidated,
            mainTrack: nil,
            elevationProfile: PublicRouteElevationProfile(
                minElevation: RouteElevation(meters: 3_000),
                maxElevation: RouteElevation(meters: 3_200),
                samples: [
                    PublicRouteElevationSample(
                        identity: "sample-1",
                        distance: RouteDistance(meters: 0),
                        elevation: RouteElevation(meters: 3_000)
                    ),
                    PublicRouteElevationSample(
                        identity: "sample-2",
                        distance: RouteDistance(meters: 1_000),
                        elevation: RouteElevation(meters: 3_200)
                    ),
                ]
            )
        )

        let presentation = RouteDetailPresentation(route: detail)

        XCTAssertNil(presentation.elevationProfile)
        XCTAssertFalse(presentation.sections.contains { $0.id == .elevation })
    }

    func testDetailProjectsElevationSamplesAndNamedPointMedia() async throws {
        let path = [
            PublicRouteGeoPosition(latitude: 29.6, longitude: 101.8, referenceSystem: "WGS84"),
            PublicRouteGeoPosition(latitude: 29.7, longitude: 101.9, referenceSystem: "WGS84"),
        ]
        let detail = Self.detail(
            availability: .valid,
            mainTrack: PublicRouteMainTrack(identity: "track-1", path: path),
            elevationProfile: PublicRouteElevationProfile(
                minElevation: RouteElevation(meters: 3_000),
                maxElevation: RouteElevation(meters: 3_200),
                samples: [
                    PublicRouteElevationSample(
                        identity: "sample-1",
                        distance: RouteDistance(meters: 0),
                        elevation: RouteElevation(meters: 3_000)
                    ),
                    PublicRouteElevationSample(
                        identity: "sample-2",
                        distance: RouteDistance(meters: 1_000),
                        elevation: RouteElevation(meters: 3_200)
                    ),
                ]
            ),
            keyPoints: [
                PublicRouteNamedPoint(
                    identity: "point-1",
                    name: "垭口",
                    positions: [path[0]],
                    media: ["https://example.test/pass.jpg"]
                )
            ],
            interestPoints: [
                PublicRouteNamedPoint(
                    identity: "poi-1",
                    name: "冰川",
                    positions: [path[1]],
                    media: ["https://example.test/glacier.jpg"]
                )
            ]
        )
        let sut = RouteDetailViewModel(service: RouteDetailServiceStub(detail: detail))

        await sut.loadRoute(id: detail.routeId)

        XCTAssertEqual(sut.elevationSamples.map(\.elevation), [3_000, 3_200])
        let sampleDistances = sut.elevationSamples.compactMap { sample in
            Mirror(reflecting: sample).children.first(where: { $0.label == "distance" })?.value as? Double
        }
        XCTAssertEqual(sampleDistances, [0, 1_000])
        XCTAssertEqual(sut.waypointAnnotations.first?.imageURL?.absoluteString, "https://example.test/pass.jpg")
        XCTAssertEqual(sut.poiAnnotations.first?.imageURL?.absoluteString, "https://example.test/glacier.jpg")

        let presentation = RouteDetailPresentation(route: detail)
        XCTAssertEqual(presentation.elevationProfile?.samples, sut.elevationSamples)
        XCTAssertEqual(presentation.elevationProfile?.minElevation, 3_000)
        XCTAssertEqual(presentation.elevationProfile?.maxElevation, 3_200)
        let snapshot = try XCTUnwrap(sut.state.snapshot)
        XCTAssertEqual(snapshot.elevationSamples, sut.elevationSamples)
        XCTAssertEqual(snapshot.elevationProfile, presentation.elevationProfileProjection)
        XCTAssertEqual(sut.elevationProfileProjection, snapshot.elevationProfile)
        XCTAssertEqual(sut.pureMapDockProjection.elevation, snapshot.elevationProfile)
        sut.togglePointHighlight(for: "point-1")
        XCTAssertEqual(sut.elevationProfileProjection, snapshot.elevationProfile)
        XCTAssertEqual(sut.elevationSamples, snapshot.elevationSamples)
        let source = try routeDetailPageSources()
        XCTAssertTrue(source.contains("RouteBusinessComponents.ElevationProfile("))
    }

    func testOneDayPresentationNeverBuildsReferenceDaysSection() {
        let referenceDay = PublicRouteReferenceDay(
            identity: "reference-day-1",
            dayNumber: 1,
            title: "D1",
            start: nil,
            end: nil,
            distance: nil,
            estimatedDuration: nil,
            ascent: nil,
            descent: nil,
            maxElevation: nil,
            minElevation: nil,
            accommodation: nil,
            notes: nil
        )
        let detail = Self.detail(
            routeType: .oneDay,
            availability: .missing,
            mainTrack: nil,
            referenceDays: [referenceDay]
        )

        let presentation = RouteDetailPresentation(route: detail)

        XCTAssertFalse(presentation.sections.contains { $0.id == .referenceDays })
        XCTAssertTrue(presentation.referenceDayProjections.isEmpty)
    }

    func testSafeComponentProjectionsPreserveOptionalityConfidenceAndServerOrder() {
        let confidence = InformationConfidence(status: "verified", category: .publicRouteFact)
        let referenceDays = [
            PublicRouteReferenceDay(
                identity: "day-1",
                dayNumber: 1,
                title: nil,
                start: PublicRoutePlace(name: "甲"),
                end: nil,
                distance: RouteDistance(meters: 1_000),
                estimatedDuration: nil,
                ascent: nil,
                descent: nil,
                maxElevation: nil,
                minElevation: nil,
                accommodation: "营地",
                notes: "先到先得"
            ),
            PublicRouteReferenceDay(
                identity: "day-2",
                dayNumber: 2,
                title: "翻越垭口",
                start: nil,
                end: PublicRoutePlace(name: "乙"),
                distance: nil,
                estimatedDuration: nil,
                ascent: nil,
                descent: nil,
                maxElevation: nil,
                minElevation: nil,
                accommodation: nil,
                notes: nil
            ),
        ]
        let segments = [
            PublicRouteSegment(identity: "segment-2", order: 2, name: "第二段", notes: "保留备注"),
            PublicRouteSegment(
                identity: "segment-1",
                order: 1,
                name: "第一段",
                start: PublicRoutePlace(name: "起点"),
                end: PublicRoutePlace(name: "终点")
            ),
        ]
        let detail = Self.detail(
            availability: .missing,
            mainTrack: nil,
            professionalAnalysis: PublicRouteProfessionalAnalysis(
                fitnessRequirement: QualifiedString(value: "高负重能力", confidence: confidence),
                experienceRequirement: nil,
                mainTerrain: nil,
                technicalDifficulty: nil,
                highAltitudeImpact: nil,
                exposedSections: nil,
                dangerAreas: nil,
                signalCoverage: nil,
                evacuationDifficulty: nil
            ),
            referenceDays: referenceDays,
            segments: segments,
            campsites: [
                PublicRouteCampsite(
                    identity: "camp-1",
                    name: "河谷营地",
                    positions: [],
                    elevation: RouteElevation(meters: 3_100),
                    details: "近水源",
                    status: "开放"
                )
            ],
            waterSources: [
                PublicRouteWaterSource(
                    identity: "water-1",
                    name: "溪流",
                    positions: [],
                    elevation: nil,
                    sourceType: "季节性溪流",
                    seasonalReliability: "雨季稳定",
                    treatmentRecommended: true,
                    treatmentAdvice: "过滤",
                    description: "流量较小"
                )
            ]
        )

        let presentation = RouteDetailPresentation(route: detail)

        XCTAssertEqual(
            presentation.routeIntroductionProjection?.analysisItems.first?.confidence,
            confidence
        )
        XCTAssertEqual(presentation.referenceDayProjections.map(\.id), ["day-1", "day-2"])
        XCTAssertNil(presentation.referenceDayProjections.first?.title)
        XCTAssertEqual(presentation.routeSegmentListProjection?.segments.map(\.id), ["segment-2", "segment-1"])
        XCTAssertNil(presentation.routeSegmentListProjection?.segments.first?.start)
        XCTAssertNil(presentation.routeSegmentListProjection?.segments.first?.end)
        XCTAssertEqual(presentation.routeSegmentListProjection?.segments.first?.description, "保留备注")
        XCTAssertEqual(
            presentation.routePointSectionProjections.map(\.title),
            ["关键点", "水源", "营地"]
        )
        XCTAssertEqual(presentation.routePointSectionProjections[1].points.first?.description,
                       "雨季稳定 · 建议处理后饮用 · 过滤 · 流量较小")
        XCTAssertEqual(
            presentation.routePointSectionProjections[2].points.first?.type,
            "开放"
        )
        XCTAssertEqual(presentation.routeFactSectionProjections.map(\.title), ["通信与安全"])
    }

    func testPointGroupsPreserveFixedGroupAndCategoryOrder() {
        let detail = Self.detail(
            availability: .missing,
            mainTrack: nil,
            campsites: [
                PublicRouteCampsite(
                    identity: "camp-1",
                    name: "河谷营地",
                    positions: [],
                    elevation: RouteElevation(meters: 3_100),
                    details: "近水源",
                    status: "开放"
                )
            ],
            waterSources: [
                PublicRouteWaterSource(
                    identity: "water-1",
                    name: "溪流",
                    positions: [],
                    elevation: nil,
                    sourceType: "季节性溪流",
                    seasonalReliability: "雨季稳定",
                    treatmentRecommended: true,
                    treatmentAdvice: "过滤",
                    description: "流量较小"
                )
            ]
        )

        let presentation = RouteDetailPresentation(route: detail)

        XCTAssertEqual(presentation.routePointGroupProjections.map(\.id), [.journey, .support])
        XCTAssertEqual(presentation.routePointGroupProjections[0].sections.map(\.title), ["关键点"])
        XCTAssertEqual(presentation.routePointGroupProjections[1].sections.map(\.title), ["水源", "营地"])
    }

    func testPointGroupsOmitMissingCategoriesAndEmptyGroups() {
        let detail = Self.detail(
            availability: .missing,
            mainTrack: nil,
            keyPoints: [],
            interestPoints: [],
            campsites: [],
            overnightPlaces: [],
            waterSources: []
        )

        let presentation = RouteDetailPresentation(route: detail)

        XCTAssertTrue(presentation.routePointGroupProjections.isEmpty)
    }

    func testDetailProjectsOnlyApprovedPublicFacts() async {
        let detail = Self.detail(availability: .missing, mainTrack: nil)
        let presentation = RouteDetailPresentation(route: detail)

        XCTAssertEqual(presentation.name, "贡嘎环线")
        XCTAssertEqual(presentation.summaryMetrics.map(\.title), ["距离", "预计用时", "累计爬升", "累计下降"])
        XCTAssertEqual(presentation.sections.map(\.title), ["路线介绍与专业分析", "路线分段", "关键点", "通信与安全", "路线影像"])
        XCTAssertFalse(presentation.sections.flatMap(\.items).contains { ["收藏", "评分", "热度", "使用次数", "创建者", "拼车联系人", "相关路线"].contains($0.title) })
    }

    func testGenerationActionIsEnabledOnlyWhenServerDeclaresRouteEligible() {
        let detail = Self.detail(
            availability: .valid,
            mainTrack: PublicRouteMainTrack(
                identity: "track-1",
                path: [PublicRouteGeoPosition(latitude: 29.6, longitude: 101.8, referenceSystem: "WGS84")]
            )
        )

        let action = RouteDetailPresentation(route: detail).generationAction

        XCTAssertEqual(action.title, "生成我的行程")
        XCTAssertTrue(action.isEnabled)
        XCTAssertNil(action.unavailableMessage)
    }

    func testGenerationActionExplainsServerOrderedMissingReasonsWhenDisabled() {
        let detail = Self.detail(availability: .missing, mainTrack: nil)

        let action = RouteDetailPresentation(route: detail).generationAction

        XCTAssertEqual(action.title, "生成我的行程")
        XCTAssertFalse(action.isEnabled)
        XCTAssertEqual(action.unavailableMessage, "缺少：有效主轨迹")
    }

    func testLoadFailureCanBeRetried() async {
        let detail = Self.detail(availability: .missing, mainTrack: nil)
        let service = RouteDetailServiceStub(
            detail: detail,
            loadErrors: [APIClientError.transport(.other("暂时不可用"))]
        )
        let sut = RouteDetailViewModel(service: service)

        await sut.loadRoute(id: detail.routeId)
        XCTAssertEqual(sut.errorMessage, "暂时不可用")

        await sut.retry()
        XCTAssertEqual(sut.route, detail)
        XCTAssertNil(sut.errorMessage)
        XCTAssertEqual(service.loadedIDs, [detail.routeId, detail.routeId])
    }

    private func productionSource(at relativePath: String) throws -> String {
        let testFileURL = URL(fileURLWithPath: #filePath)
        let walkRoot = testFileURL
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        return try String(contentsOf: walkRoot.appendingPathComponent(relativePath), encoding: .utf8)
    }

    /// 聚合页面与其实际消费的支持结构，避免把文件拆分误报为生产组件缺失。
    private func routeDetailPageSources(file: StaticString = #filePath, line: UInt = #line) throws -> String {
        let page = try productionSource(at: "Features/Routes/RouteDetailView.swift")
        let support = try productionSource(at: "Features/Routes/RouteDetailViewSupport.swift")
        XCTAssertTrue(page.contains("RouteDetailScrollOverlay("), "页面必须消费被审计的信息滚动层", file: file, line: line)
        return [page, support].joined(separator: "\n")
    }

    private static let browseSummary = PublicRouteBrowseSummary(
        routeId: "route-1",
        currentVersionId: "version-1",
        cover: "https://example.test/cover.jpg",
        name: "贡嘎环线",
        region: "四川甘孜",
        difficulty: "中等",
        distance: RouteDistance(meters: 42_500),
        ascent: RouteElevationGain(meters: 2_300),
        estimatedDuration: RouteDuration(seconds: 259_200)
    )

    private static let searchSummary = PublicRouteSearchSummary(
        routeId: "route-1",
        currentVersionId: "version-1",
        cover: nil,
        name: "贡嘎环线",
        region: "四川甘孜",
        difficulty: "中等",
        distance: RouteDistance(meters: 42_500),
        estimatedDuration: RouteDuration(seconds: 259_200)
    )

    private static func detail(
        routeID: String = "route-1",
        routeType: PublicRouteType = .multiDay,
        availability: MainTrackAvailability,
        mainTrack: PublicRouteMainTrack?,
        professionalAnalysis: PublicRouteProfessionalAnalysis? = nil,
        referenceDays: [PublicRouteReferenceDay]? = nil,
        segments: [PublicRouteSegment]? = nil,
        elevationProfile: PublicRouteElevationProfile? = nil,
        keyPoints: [PublicRouteNamedPoint]? = nil,
        interestPoints: [PublicRouteNamedPoint]? = nil,
        campsites: [PublicRouteCampsite]? = nil,
        overnightPlaces: [PublicRouteOvernightPlace]? = nil,
        waterSources: [PublicRouteWaterSource]? = nil
    ) -> PublicRouteDetail {
        PublicRouteDetail(
            routeId: routeID,
            currentVersion: PublicRouteVersionDetail(
                versionId: "version-1",
                summary: PublicRouteSummary(
                    routeType: routeType,
                    name: "贡嘎环线",
                    region: "四川甘孜",
                    start: PublicRoutePlace(name: "起点"),
                    end: PublicRoutePlace(name: "终点"),
                    estimatedDuration: RouteDuration(seconds: 259_200),
                    difficulty: "中等",
                    direction: "环线",
                    distance: RouteDistance(meters: 42_500),
                    ascent: RouteElevationGain(meters: 2_300),
                    descent: RouteElevationLoss(meters: 2_200),
                    introduction: "高山徒步路线"
                ),
                mainTrackAvailability: availability,
                generationEligibility: RouteGenerationEligibility(
                    eligible: availability == .valid,
                    missingReasons: availability == .valid ? nil : [.validMainTrack]
                ),
                mainTrack: mainTrack,
                elevationProfile: elevationProfile,
                professionalAnalysis: professionalAnalysis,
                referenceDays: referenceDays,
                segments: segments ?? [
                    PublicRouteSegment(identity: "segment-1", order: 1, name: "第一段")
                ],
                keyPoints: keyPoints ?? [
                    PublicRouteNamedPoint(
                        identity: "point-1",
                        name: "垭口",
                        positions: [PublicRouteGeoPosition(latitude: 29.65, longitude: 101.85, referenceSystem: "WGS84")]
                    )
                ],
                interestPoints: interestPoints,
                campsites: campsites,
                overnightPlaces: overnightPlaces,
                waterSources: waterSources,
                communicationAndSafety: PublicRouteCommunicationAndSafety(
                    notices: [
                        PublicRouteSafetyNotice(
                            identity: "notice-1",
                            kind: "signal",
                            title: "通信提示",
                            description: "部分路段无信号",
                            positions: nil
                        )
                    ]
                ),
                images: [
                    PublicRouteImage(identity: "image-1", mediaReference: "https://example.test/cover.jpg", role: .cover)
                ]
            )
        )
    }
}

@MainActor
private final class RouteDetailServiceStub: RouteDetailServicing {
    private let detail: PublicRouteDetail
    private var loadErrors: [Error]
    private(set) var loadedIDs: [String] = []
    var loadHandler: ((String) async throws -> PublicRouteDetail)?

    init(detail: PublicRouteDetail, loadErrors: [Error] = []) {
        self.detail = detail
        self.loadErrors = loadErrors
    }

    func getRouteDetail(id: String) async throws -> PublicRouteDetail {
        loadedIDs.append(id)
        if let loadHandler { return try await loadHandler(id) }
        if !loadErrors.isEmpty { throw loadErrors.removeFirst() }
        return detail
    }
}

@MainActor
private final class RouteDiscoveryServiceStub: RouteDiscoveryServicing {
    private let featured: PublicRouteDiscoveryResult
    private let allRoutes: PublicRouteCollectionResult
    private var searchResults: [PublicRouteSearchResult]
    private let searchError: Error?
    private(set) var searchQueries: [String?] = []
    private(set) var featuredCallCount = 0
    private(set) var collectionCallCount = 0
    var featuredHandler: (() async throws -> PublicRouteDiscoveryResult)?
    var collectionHandler: (() async throws -> PublicRouteCollectionResult)?
    var searchHandler: ((String?) async throws -> PublicRouteSearchResult)?

    init(
        featured: PublicRouteDiscoveryResult = PublicRouteDiscoveryResult(items: []),
        all: PublicRouteCollectionResult = PublicRouteCollectionResult(items: []),
        search: PublicRouteSearchResult = PublicRouteSearchResult(state: .initial, items: []),
        searchResults: [PublicRouteSearchResult]? = nil,
        searchError: Error? = nil
    ) {
        self.featured = featured
        self.allRoutes = all
        self.searchResults = searchResults ?? [search]
        self.searchError = searchError
    }

    func getFeaturedRoutes() async throws -> PublicRouteDiscoveryResult {
        featuredCallCount += 1
        if let featuredHandler { return try await featuredHandler() }
        return featured
    }

    func getRoutes() async throws -> PublicRouteCollectionResult {
        collectionCallCount += 1
        if let collectionHandler { return try await collectionHandler() }
        return allRoutes
    }

    func searchRoutes(query: String?) async throws -> PublicRouteSearchResult {
        searchQueries.append(query)
        if let searchHandler { return try await searchHandler(query) }
        if let searchError { throw searchError }
        guard !searchResults.isEmpty else {
            return PublicRouteSearchResult(state: .initial, items: [])
        }
        return searchResults.removeFirst()
    }
}

/// 故意不响应 Task 取消，以覆盖 Service 不合作取消时的迟到结果。
private actor RouteAsyncGate {
    private var isOpen = false
    private var continuation: CheckedContinuation<Void, Never>?

    func wait() async {
        guard !isOpen else { return }
        await withCheckedContinuation { continuation in
            self.continuation = continuation
        }
    }

    func open() {
        isOpen = true
        continuation?.resume()
        continuation = nil
    }
}
