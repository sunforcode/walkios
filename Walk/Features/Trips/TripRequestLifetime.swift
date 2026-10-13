import Foundation
import WalkData

/// A per-request cancellation signal, not page state or a shared task scheduler.
/// Cancellation handlers run off MainActor; the lock makes invalidation immediate so
/// a returning page can start a new read before an uncooperative old service finishes.
final class TripRequestLifetime: @unchecked Sendable {
    private let lock = NSLock()
    private var cancelled = false

    var isCancelled: Bool {
        lock.lock()
        defer { lock.unlock() }
        return cancelled
    }

    func cancel() {
        lock.lock()
        defer { lock.unlock() }
        cancelled = true
    }
}

func tripRequestWasCancelled(_ error: Error) -> Bool {
    error is CancellationError || (error as? APIClientError) == .transport(.cancelled)
}
