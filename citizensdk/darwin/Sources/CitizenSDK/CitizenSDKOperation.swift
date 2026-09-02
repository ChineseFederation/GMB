import Foundation

/// One accepted operation with a facade-owned correlation identity.
public final class CitizenSDKOperation<Value: Sendable>: @unchecked Sendable {
    public let operationID: String
    private let lock = NSLock()
    private var outcome: Result<Value, Error>?
    private var waiters: [(Result<Value, Error>) -> Void] = []
    private let cancelAction: () throws -> Bool

    internal init(operationID: String = UUID().uuidString, cancel: @escaping () throws -> Bool) {
        self.operationID = operationID
        self.cancelAction = cancel
    }

    public func value() async throws -> Value {
        try await withCheckedThrowingContinuation { continuation in
            observe { result in
                switch result {
                case let .success(value): continuation.resume(returning: value)
                case let .failure(error): continuation.resume(throwing: error)
                }
            }
        }
    }

    @discardableResult
    public func cancel() throws -> Bool { try cancelAction() }

    internal func observe(_ observer: @escaping (Result<Value, Error>) -> Void) {
        lock.lock()
        if let outcome {
            lock.unlock()
            observer(outcome)
        } else {
            waiters.append(observer)
            lock.unlock()
        }
    }

    internal func complete(_ result: Result<Value, Error>) {
        lock.lock()
        guard outcome == nil else { lock.unlock(); return }
        outcome = result
        let callbacks = waiters
        waiters.removeAll(keepingCapacity: false)
        lock.unlock()
        callbacks.forEach { $0(result) }
    }
}
