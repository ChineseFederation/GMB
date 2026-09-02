import Foundation

/// Private one-shot ownership used only by the SDK-owned Apple wallet UI.
internal final class CitizenSDKPreparedWallet {
    private enum State { case open, committing, committed, releasing, released }
    private let lock = NSLock()
    private let native: CitizenSDKNative
    private let handle: UInt64
    private var state: State = .open

    init(native: CitizenSDKNative, handle: UInt64) {
        self.native = native
        self.handle = handle
    }

    func recoveryPhrase() throws -> CitizenSDKRecoveryPhrase {
        let isOpen = lock.withLock { state == .open }
        guard isOpen else { throw CitizenSDKError(.invalidState, "prepared wallet is already consumed") }
        return CitizenSDKRecoveryPhrase(buffer: try native.copyPreparedMnemonic(handle))
    }

    /// Commit remains on the SDK wallet UI actor; the prepared owner is never
    /// sent into an unrelated executor while its mnemonic can still exist.
    @MainActor
    func commit() async throws -> CitizenWalletProfile? {
        try lock.withLock {
            guard state == .open else { throw CitizenSDKError(.invalidState, "prepared wallet is already consumed") }
            state = .committing
        }
        do {
            let operation = try native.commitPrepared(handle)
            // Acceptance consumes the independent Core prepared handle even if
            // its later durable wallet mutation reports an error.
            lock.withLock { state = .committed }
            return try await operation.value()
        } catch {
            lock.withLock { if state == .committing { state = .open } }
            throw error
        }
    }

    func release() throws {
        let shouldRelease = try lock.withLock { () -> Bool in
            switch state {
            case .open: state = .releasing; return true
            case .committing, .releasing:
                throw CitizenSDKError(.busy, "prepared wallet cleanup is already running")
            case .committed, .released: return false
            }
        }
        guard shouldRelease else { return }
        do {
            try native.releasePrepared(handle)
            lock.withLock { state = .released }
        } catch {
            lock.withLock { state = .open }
            throw error
        }
    }

    deinit { try? release() }
}

private extension NSLock {
    func withLock<T>(_ body: () throws -> T) rethrows -> T {
        lock(); defer { unlock() }
        return try body()
    }
}
