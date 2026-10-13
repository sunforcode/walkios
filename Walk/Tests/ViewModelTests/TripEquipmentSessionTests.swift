import XCTest
import WalkData
@testable import Walk

@MainActor
final class TripEquipmentSessionTests: XCTestCase {
    func testDelayedMutationPublishesRevisionWithoutMountedPage() async {
        let client = TripSessionAPIClient()
        let session = TripEquipmentSession()
        var revisions: [String] = []
        let model = session.model(tripID: "trip-1", service: TripEquipmentService(apiClient: client),
            equipmentService: EquipmentService(apiClient: client), onRevisionChange: { revisions.append($0) })
        await model.load()
        revisions.removeAll()
        let started = expectation(description: "mutation started")
        var continuation: CheckedContinuation<TripEquipmentProjection, Never>?
        client.writeHandler = {
            await withCheckedContinuation { continuation = $0; started.fulfill() }
        }
        let task = Task { await model.addItem(input: .init(name: "修补贴", quantity: 1)) }
        await fulfillment(of: [started], timeout: 1)
        // No TripEquipmentView exists: the session owns the completion observer.
        continuation?.resume(returning: Self.snapshot("completed-revision"))
        let succeeded = await task.value
        XCTAssertTrue(succeeded)
        XCTAssertEqual(revisions, ["completed-revision"])
    }

    func testClearedSessionIgnoresOldCompletionForSameTrip() async {
        let oldClient = TripSessionAPIClient()
        let session = TripEquipmentSession()
        var oldRevisions: [String] = []
        var newRevisions: [String] = []
        let oldModel = session.model(tripID: "trip-1", service: TripEquipmentService(apiClient: oldClient),
            equipmentService: EquipmentService(apiClient: oldClient), onRevisionChange: { oldRevisions.append($0) })
        await oldModel.load()
        oldRevisions.removeAll()
        let started = expectation(description: "old session mutation started")
        var continuation: CheckedContinuation<TripEquipmentProjection, Never>?
        oldClient.writeHandler = {
            await withCheckedContinuation { continuation = $0; started.fulfill() }
        }
        let oldTask = Task { await oldModel.addItem(input: .init(name: "旧会话装备", quantity: 1)) }
        await fulfillment(of: [started], timeout: 1)
        session.clear()
        let newClient = TripSessionAPIClient()
        let newModel = session.model(tripID: "trip-1", service: TripEquipmentService(apiClient: newClient),
            equipmentService: EquipmentService(apiClient: newClient), onRevisionChange: { newRevisions.append($0) })
        await newModel.load()
        newRevisions.removeAll()
        continuation?.resume(returning: Self.snapshot("old-late-revision"))
        _ = await oldTask.value
        XCTAssertTrue(oldRevisions.isEmpty)
        XCTAssertTrue(newRevisions.isEmpty)
        XCTAssertEqual(newModel.projection?.revision, "initial-revision")
        newClient.writeResult = Self.snapshot("new-session-revision")
        _ = await newModel.addItem(input: .init(name: "新会话装备", quantity: 1))
        XCTAssertEqual(newRevisions, ["new-session-revision"])
    }

    func testCachedLookupUsesCurrentRevisionObserver() async {
        let client = TripSessionAPIClient()
        let session = TripEquipmentSession()
        let service = TripEquipmentService(apiClient: client)
        let equipment = EquipmentService(apiClient: client)
        var originalRevisions: [String] = []
        var currentRevisions: [String] = []
        let original = session.model(tripID: "trip-1", service: service, equipmentService: equipment,
                                     onRevisionChange: { originalRevisions.append($0) })
        await original.load()
        originalRevisions.removeAll()
        let current = session.model(tripID: "trip-1", service: service, equipmentService: equipment,
                                    onRevisionChange: { currentRevisions.append($0) })
        XCTAssertTrue(original === current)
        client.writeResult = Self.snapshot("latest-revision")
        _ = await current.recheckOwnership()
        XCTAssertTrue(originalRevisions.isEmpty)
        XCTAssertEqual(currentRevisions, ["latest-revision"])
    }

    fileprivate static func snapshot(_ revision: String) -> TripEquipmentProjection {
        .init(trip: .init(identity: "trip-1", status: .planned, routeName: "路线",
                          startDate: .init(year: 2026, month: 10, day: 1), endDate: .init(year: 2026, month: 10, day: 2)),
              revision: revision, editable: true,
              snapshot: .init(identity: "snapshot-1", items: [],
                  summary: .init(itemCount: 0, knownTotalWeight: .init(grams: 0), missingWeightItemCount: 0,
                                 ownedItemCount: 0, unconfirmedOwnedItemCount: 0)))
    }
}

@MainActor
private final class TripSessionAPIClient: APIClient {
    var writeResult = TripEquipmentSessionTests.snapshot("write-revision")
    var writeHandler: (() async -> TripEquipmentProjection)?

    func execute<Request: APIRequest>(_ request: Request) async throws -> Request.Response {
        let result: TripEquipmentProjection
        if request.method == .get {
            result = TripEquipmentSessionTests.snapshot("initial-revision")
        } else {
            result = await writeHandler?() ?? writeResult
        }
        return try JSONDecoder().decode(Request.Response.self, from: JSONEncoder().encode(result))
    }
}
