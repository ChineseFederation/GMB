import Foundation

/// Secret-free selection for the SDK-owned wallet interface.
public enum CitizenSDKWalletFlowRequest: Sendable, Equatable {
    case create(wordCount: UInt32)
    case importWallet
    case addAccounts(indices: [UInt32])
}

public enum CitizenSDKWalletFlowResult: Sendable {
    case completed(CitizenWalletProfile?)
    case cancelled
    case failed(CitizenSDKError)
}

/// One-shot controller for a non-exported Apple wallet window/view controller.
public final class CitizenSDKWalletFlow: @unchecked Sendable {
    private let lock = NSLock()
    private var cancelled = false
    private let cancelAction: () -> Void

    internal init(cancel: @escaping () -> Void) { cancelAction = cancel }

    public func cancel() {
        lock.lock()
        let shouldCancel = !cancelled
        cancelled = true
        lock.unlock()
        if shouldCancel { cancelAction() }
    }
}

/// Process ownership prevents Core destroy while secret controls or a prepared
/// mnemonic are still retained by an SDK-owned Apple flow.
/// Wallet admission and close admission share one state machine and one lock,
/// so a flow cannot reserve the interval between a close preflight and Core
/// destruction. No dictionary access is performed outside these methods.
internal final class CitizenSDKWalletFlowRegistry: @unchecked Sendable {
    enum Status: Equatable, Sendable {
        case open
        case owned
        case closing
        case closed
    }

    struct CloseReservation: Equatable, Sendable {
        fileprivate let token: UUID
        /// True once a lifecycle supervisor has committed to retrying this
        /// close, including every attempt resumed from persistent closing.
        fileprivate let retryCommitted: Bool
    }

    enum CloseOrigin: Equatable, Sendable {
        case explicit
        case supervised
    }

    private enum State {
        case open
        case owned(UUID)
        /// A token means one close attempt is currently admitted. `nil` means
        /// ABI teardown or supervised recovery has committed to fail-closed
        /// retry, but no attempt currently owns the Native call.
        case closing(CloseReservation?)
        case closed

        var status: Status {
            switch self {
            case .open: return .open
            case .owned: return .owned
            case .closing: return .closing
            case .closed: return .closed
            }
        }
    }

    static let shared = CitizenSDKWalletFlowRegistry()
    private let lock = NSLock()
    private var states: [ObjectIdentifier: State] = [:]

    func registerOpen(_ sdk: AnyObject) {
        lock.lock(); defer { lock.unlock() }
        let key = ObjectIdentifier(sdk)
        precondition(states[key] == nil, "CitizenSDK wallet registry identity was reused before deinit")
        states[key] = .open
    }

    func reserve(_ sdk: AnyObject) throws -> UUID {
        lock.lock(); defer { lock.unlock() }
        let key = ObjectIdentifier(sdk)
        switch states[key] {
        case .open:
            let token = UUID()
            states[key] = .owned(token)
            return token
        case .owned:
            throw CitizenSDKError(.busy, "a wallet UI flow is already active")
        case .closing:
            throw CitizenSDKError(.busy, "CitizenSDK is closing")
        case .closed:
            throw CitizenSDKError(.invalidState, "CitizenSDK is closed")
        case nil:
            throw CitizenSDKError(.invalidState, "CitizenSDK is not registered")
        }
    }

    func finish(_ sdk: AnyObject, token: UUID) {
        lock.lock(); defer { lock.unlock() }
        let key = ObjectIdentifier(sdk)
        if case let .owned(current) = states[key], current == token { states[key] = .open }
    }

    /// Atomically excludes new wallet UI before any Core teardown call. A
    /// `nil` result means another successful attempt already committed closed.
    func beginClose(_ sdk: AnyObject, origin: CloseOrigin = .explicit) throws -> CloseReservation? {
        lock.lock(); defer { lock.unlock() }
        let key = ObjectIdentifier(sdk)
        switch states[key] {
        case .open:
            let reservation = CloseReservation(
                token: UUID(), retryCommitted: origin == .supervised
            )
            states[key] = .closing(reservation)
            return reservation
        case .owned:
            throw CitizenSDKError(.busy, "CitizenSDK wallet UI must finish before close")
        case .closing(nil):
            // Persistent closing exists only after partial ABI teardown or a
            // supervisor-owned retry. Any caller resuming it inherits that
            // fail-closed recovery commitment.
            let reservation = CloseReservation(token: UUID(), retryCommitted: true)
            states[key] = .closing(reservation)
            return reservation
        case .closing:
            throw CitizenSDKError(.busy, "another CitizenSDK close attempt is active")
        case .closed:
            return nil
        case nil:
            throw CitizenSDKError(.invalidState, "CitizenSDK is not registered")
        }
    }

    /// Ends one failed close attempt. Only a first explicit pre-teardown failure
    /// reopens; partial teardown and every supervisor-owned retry stay closed to
    /// wallet admission until another close attempt succeeds.
    /// The return value tells an explicit caller to hand ownership to the
    /// lifecycle supervisor.
    @discardableResult
    func failClose(_ sdk: AnyObject, reservation: CloseReservation,
                   teardownStarted: Bool) -> Bool {
        lock.lock(); defer { lock.unlock() }
        let key = ObjectIdentifier(sdk)
        guard case let .closing(current?) = states[key], current == reservation else { return false }
        let remainsClosing = teardownStarted || reservation.retryCommitted
        states[key] = remainsClosing ? .closing(nil) : .open
        return teardownStarted && !reservation.retryCommitted
    }

    /// Core destruction is the only transition to closed. The closed marker
    /// remains until facade deinit so a still-reachable facade cannot reopen UI.
    func commitClosed(_ sdk: AnyObject, reservation: CloseReservation?) {
        lock.lock(); defer { lock.unlock() }
        let key = ObjectIdentifier(sdk)
        if case .closed = states[key] { return }
        guard let reservation else {
            preconditionFailure("only an existing closed tombstone accepts an idempotent nil commit")
        }
        guard case let .closing(current?) = states[key], current == reservation else {
            preconditionFailure("CitizenSDK close reservation drifted before Core destruction commit")
        }
        states[key] = .closed
    }

    func forget(_ sdk: AnyObject) {
        lock.lock(); states.removeValue(forKey: ObjectIdentifier(sdk)); lock.unlock()
    }

    internal func status(_ sdk: AnyObject) -> Status? {
        lock.lock(); defer { lock.unlock() }
        return states[ObjectIdentifier(sdk)]?.status
    }
}

internal func citizenSDKSensitiveText(_ value: String, label: String) throws -> CitizenSDKSensitiveBuffer {
    // UIKit/AppKit owns the source String and cannot provide an in-place
    // zeroizable buffer. The one SDK-created UTF-8 copy is therefore mutable,
    // copied immediately into the controlled buffer, and cleared on return.
    var bytes = Data(value.utf8)
    defer { bytes.resetBytes(in: 0..<bytes.count) }
    guard bytes.count <= CitizenSDKInputLimits.maximumWalletSecretBytes else {
        throw CitizenSDKError(.invalidArgument, "\(label) exceeds 1024 UTF-8 bytes")
    }
    return CitizenSDKSensitiveBuffer(data: bytes)
}

internal func citizenSDKValidateWalletFlowRequest(_ request: CitizenSDKWalletFlowRequest) throws
    -> CitizenSDKWalletFlowRequest {
    switch request {
    case let .create(wordCount):
        guard wordCount == 12 || wordCount == 24 else {
            throw CitizenSDKError(.invalidArgument, "word count must be 12 or 24")
        }
    case .importWallet:
        break
    case let .addAccounts(indices):
        _ = try CitizenSDKInputLimits.additionalIndices(indices)
    }
    return request
}

internal func citizenSDKFlowError(_ error: Error) -> CitizenSDKError {
    if let sdk = error as? CitizenSDKError { return sdk }
    return CitizenSDKError(.internalFailure, "CitizenSDK wallet interface failed")
}

/// Cancellation can only relabel work that has not crossed an irreversible
/// Core admission/commit point. Once crossed, its real failure must be reported
/// even when the user requested cancellation while waiting.
internal func citizenSDKCancellationResult(
    cancelRequested: Bool,
    irreversible: Bool,
    error: Error
) -> CitizenSDKWalletFlowResult? {
    guard cancelRequested else { return nil }
    return irreversible ? .failed(citizenSDKFlowError(error)) : .cancelled
}

/// A prepared mnemonic is owned by Core until release succeeds. Native keeps
/// failed-release handles in its prepared set so a later `close()` can retry;
/// the UI must report failure instead of claiming cancellation completed.
internal func citizenSDKPreparedCancellationResult(
    release: () throws -> Void
) -> CitizenSDKWalletFlowResult {
    do { try release(); return .cancelled }
    catch { return .failed(citizenSDKFlowError(error)) }
}

/// Establishes the terminal-callback commit point: controlled secrets are
/// cleared before registry release, SDK close, FlutterResult, or host code can
/// reenter from the supplied body.
internal func citizenSDKAfterClearingSecrets<T>(
    _ buffers: [CitizenSDKSensitiveBuffer],
    _ body: () throws -> T
) rethrows -> T {
    buffers.forEach { $0.clear() }
    return try body()
}
