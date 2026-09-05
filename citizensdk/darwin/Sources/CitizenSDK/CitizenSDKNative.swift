import Foundation

/// Monotonic teardown contract matching `citizensdk.h` exactly. Once callback
/// clear succeeds the instance enters `destroyOnly` before its first destroy
/// call; every later retry therefore calls destroy and no other control API.
internal final class CitizenSDKABITeardownCoordinator {
    enum Phase: Equatable, Sendable {
        case live
        case monitorStopped
        case destroyOnly
        case closed
    }

    private let lock = NSLock()
    private var phase: Phase = .live
    private var teardownStarted = false

    var snapshot: (phase: Phase, teardownStarted: Bool) {
        lock.lock(); defer { lock.unlock() }
        return (phase, teardownStarted)
    }

    func requireOperational() throws {
        let state = snapshot
        guard state.phase == .live, !state.teardownStarted else {
            throw CitizenSDKError(.invalidState, "CitizenSDK is closing and accepts only teardown retry")
        }
    }

    func perform(
        unsubscribe: () throws -> Void,
        clearCallback: () throws -> Void,
        destroy: () throws -> Void,
        didDestroy: () -> Void
    ) throws {
        lock.lock(); teardownStarted = true; lock.unlock()
        while true {
            switch snapshot.phase {
            case .live:
                // An error is not guessed to be side-effect-free. The phase
                // advances only after a later idempotent success confirms the
                // monitor is absent.
                try unsubscribe()
                advance(from: .live, to: .monitorStopped)
            case .monitorStopped:
                try clearCallback()
                // Persist before the first destroy call. BUSY and every other
                // destroy failure now have the same direct-retry boundary.
                advance(from: .monitorStopped, to: .destroyOnly)
            case .destroyOnly:
                try destroy()
                advance(from: .destroyOnly, to: .closed)
                didDestroy()
                return
            case .closed:
                return
            }
        }
    }

    private func advance(from expected: Phase, to next: Phase) {
        lock.lock(); defer { lock.unlock() }
        precondition(phase == expected, "CitizenSDK ABI teardown phase drifted")
        phase = next
    }
}

/// Explicit +1 ownership handed to the C ABI. `Unmanaged` is intentional here:
/// callback and host vtable contexts are borrowed by Core beyond Swift's normal
/// object graph, so ARC ownership ends only after successful destroy.
internal final class CitizenSDKABIRetainLease<Owner: AnyObject> {
    private let lock = NSLock()
    private var retained: Unmanaged<Owner>?

    init(_ owner: Owner) { retained = Unmanaged.passRetained(owner) }

    var isArmed: Bool {
        lock.lock(); defer { lock.unlock() }
        return retained != nil
    }

    func releaseAfterSuccessfulDestroy() {
        lock.lock()
        let owner = retained
        retained = nil
        lock.unlock()
        owner?.release()
    }
}

/// Couples Core's two borrowed Swift lifetimes: HostBridge and Native's ABI
/// +1. Successful destroy clears HostBridge first (closing its SQLite stores),
/// then releases the self-retain. A still-live closed facade therefore cannot
/// extend host resource ownership beyond Core.
internal final class CitizenSDKABIBorrowedResources<Host: AnyObject, Owner: AnyObject> {
    private let lock = NSLock()
    private var host: Host?
    private var ownerLease: CitizenSDKABIRetainLease<Owner>?

    init(host: Host, owner: Owner) {
        self.host = host
        ownerLease = CitizenSDKABIRetainLease(owner)
    }

    var hasHost: Bool {
        lock.lock(); defer { lock.unlock() }
        return host != nil
    }

    var isOwnerLeaseArmed: Bool {
        lock.lock(); defer { lock.unlock() }
        return ownerLease?.isArmed == true
    }

    func releaseAfterSuccessfulDestroy() {
        lock.lock()
        // Core has promised no later callback/host operation. Drop the host
        // before the owner +1 so stores close even if a closed facade remains.
        host = nil
        let lease = ownerLease
        ownerLease = nil
        lock.unlock()
        lease?.releaseAfterSuccessfulDestroy()
    }
}

/// Shared retry loop used by the production reaper and deterministic XCTest
/// fixtures. Production has no attempt limit; backoff is capped at five seconds.
internal enum CitizenSDKSupervisedRetry {
    static func run(
        maximumAttempts: Int? = nil,
        initialDelayNanoseconds: UInt64 = 250_000_000,
        attempt: @escaping @Sendable () async -> Bool
    ) async -> Bool {
        var attempts = 0
        var delay = initialDelayNanoseconds
        while maximumAttempts == nil || attempts < maximumAttempts! {
            attempts += 1
            if await attempt() { return true }
            if delay != 0 { try? await Task.sleep(nanoseconds: delay) }
            let doubled = delay.multipliedReportingOverflow(by: 2)
            delay = doubled.overflow ? 5_000_000_000 : min(doubled.partialValue, 5_000_000_000)
        }
        return false
    }
}

internal enum CitizenSDKSupervisedCloseAction: Equatable, Sendable {
    case stopThenClose
    case close
}

/// Serial delivery gate for state notifications that need a synchronous Core
/// query. C callbacks only enqueue and return. Close atomically stops admission
/// when no delivery is active; already-queued work is then skipped without a C
/// call, while an active delivery makes close retry with BUSY.
internal final class CitizenSDKDeferredEventGate: @unchecked Sendable {
    struct Snapshot: Equatable, Sendable {
        let accepting: Bool
        let pending: Int
        let active: Int
    }

    private let lock = NSLock()
    private let queue: DispatchQueue
    private var accepting = true
    /// Scheduled work, including the currently active item.
    private var pending = 0
    private var active = 0

    init(label: String) { queue = DispatchQueue(label: label) }
    internal init(queue: DispatchQueue) { self.queue = queue }

    var snapshot: Snapshot {
        lock.lock(); defer { lock.unlock() }
        return Snapshot(accepting: accepting, pending: pending, active: active)
    }

    @discardableResult
    func enqueue(_ work: @escaping @Sendable () -> Void) -> Bool {
        lock.lock()
        guard accepting, pending < Int.max else { lock.unlock(); return false }
        pending += 1
        lock.unlock()
        queue.async { [self] in
            guard claim() else { return }
            defer { finishActive() }
            work()
        }
        return true
    }

    /// Linearizes with `enqueue`. Returning true guarantees no work is active,
    /// no later work can be admitted, and all previously queued work will skip.
    func beginTeardownIfNoActiveDelivery() -> Bool {
        lock.lock(); defer { lock.unlock() }
        if !accepting { return active == 0 }
        guard active == 0 else { return false }
        accepting = false
        return true
    }

    private func claim() -> Bool {
        lock.lock(); defer { lock.unlock() }
        precondition(pending > 0, "CitizenSDK deferred event count underflowed")
        guard accepting else {
            pending -= 1
            return false
        }
        active += 1
        return true
    }

    private func finishActive() {
        lock.lock(); defer { lock.unlock() }
        precondition(active > 0 && pending > 0, "CitizenSDK deferred event count underflowed")
        active -= 1
        pending -= 1
    }
}

/// Owns abandoned facades or native instances until their Core handle reaches
/// successful destruction. Actor dictionaries are the visible recovery owner;
/// Native's ABI lease closes the short handoff interval before actor adoption.
internal actor CitizenSDKLifecycleSupervisor {
    static let shared = CitizenSDKLifecycleSupervisor()
    private var nativeEntries: [ObjectIdentifier: CitizenSDKNative] = [:]
    private var facadeEntries: [ObjectIdentifier: CitizenSdk] = [:]

    func adopt(_ native: CitizenSDKNative) {
        let identity = ObjectIdentifier(native)
        guard nativeEntries[identity] == nil else { return }
        nativeEntries[identity] = native
        Task { await recoverNative(identity) }
    }

    func adopt(_ facade: CitizenSdk) {
        let identity = ObjectIdentifier(facade)
        guard facadeEntries[identity] == nil else { return }
        facadeEntries[identity] = facade
        Task { await recoverFacade(identity) }
    }

    private func recoverNative(_ identity: ObjectIdentifier) async {
        guard let native = nativeEntries[identity] else { return }
        _ = await CitizenSDKSupervisedRetry.run {
            do { try await native.supervisedClose(); return true }
            catch { return false }
        }
        nativeEntries.removeValue(forKey: identity)
    }

    private func recoverFacade(_ identity: ObjectIdentifier) async {
        guard let facade = facadeEntries[identity] else { return }
        _ = await CitizenSDKSupervisedRetry.run {
            do { try await facade.supervisedClose(); return true }
            catch { return false }
        }
        facadeEntries.removeValue(forKey: identity)
    }
}

/// Sole owner of one Core handle, callback, result ownership and host context.
internal final class CitizenSDKNative: @unchecked Sendable {
    private enum DeferredStateEvent: Sendable {
        case capabilities(sequence: UInt64)
        case lifecycle(sequence: UInt64)
    }

    private final class Pending {
        let operationID: String
        let decode: (UInt64) throws -> Any
        let complete: (Result<Any, Error>) -> Void
        let progress: ((CitizenTransferProgress) -> Void)?

        init(operationID: String, decode: @escaping (UInt64) throws -> Any,
             complete: @escaping (Result<Any, Error>) -> Void,
             progress: ((CitizenTransferProgress) -> Void)?) {
            self.operationID = operationID
            self.decode = decode
            self.complete = complete
            self.progress = progress
        }
    }

    private final class Cancellation {
        private let lock = NSLock()
        private var requestID: UInt64?
        func bind(_ value: UInt64) { lock.lock(); requestID = value; lock.unlock() }
        func value() -> UInt64? { lock.lock(); defer { lock.unlock() }; return requestID }
    }

    private let callLock = NSRecursiveLock()
    private let routerLock = NSLock()
    private let deferredStateEvents = CitizenSDKDeferredEventGate(
        label: "org.citizen.sdk.apple.state-events"
    )
    private let teardown = CitizenSDKABITeardownCoordinator()
    private var handle: UInt64
    private var closed = false
    /// Installed before callback binding and cleared only under `callLock` at
    /// successful destroy. It owns HostBridge plus Native's explicit ABI +1.
    private var abiResources: CitizenSDKABIBorrowedResources<CitizenSDKHostBridge, CitizenSDKNative>?
    private var pending: [UInt64: Pending] = [:]
    /// True only while one serialized C admission call may legally callback
    /// before its out_request_id has been observed by Swift.
    private var admissionInProgress = false
    private var earlyCompletions: [UInt64: UInt64] = [:]
    private var earlyWatches: [UInt64: [(sequence: UInt64, result: UInt64)]] = [:]
    /// Includes completion/watch batches removed from maps but not yet fully
    /// decoded, released and delivered to facade observers.
    private var queuedDeliveries = 0
    private var preparedHandles: Set<UInt64> = []
    private var eventListener: ((CitizenSDKEvent) -> Void)?

    private init(handle: UInt64) {
        self.handle = handle
    }

    static func open(assets: CitizenSDKAssets, storageRoot: URL? = nil,
                     applicationID: String? = Bundle.main.bundleIdentifier) throws -> CitizenSDKNative {
        let host = try CitizenSDKHostBridge(root: storageRoot, applicationID: applicationID)
        var handle: UInt64 = 0
        let name = Data("CitizenSDK".utf8)
        let version = Data("1.0.0".utf8)
        let code = host.withServices { services in
            withViews([assets.manifest, assets.chainSpec, assets.lightSyncState, name, version]) { views in
                var options = citizensdk_create_options_t()
                options.struct_size = UInt32(MemoryLayout<citizensdk_create_options_t>.size)
                options.abi_version = 1
                options.asset_manifest = views[0]
                options.chain_spec = views[1]
                options.light_sync_state = views[2]
                options.system_name = views[3]
                options.system_version = views[4]
                return citizensdk_create_with_host(&options, services, &handle)
            }
        }
        try CitizenSDKChecks.requireOK(code, "CitizenSDK Core creation failed")
        guard handle != 0 else { throw CitizenSDKError(.integrity, "Core returned an empty instance handle") }
        let native = CitizenSDKNative(handle: handle)
        // Arm before exposing this object or installing a passUnretained
        // callback context. The lease also keeps every HostBridge context live.
        native.abiResources = CitizenSDKABIBorrowedResources(host: host, owner: native)
        try bindOrRecover(
            bind: native.bindCallback,
            close: native.close,
            supervise: native.enqueueForSupervisedClose
        )
        return native
    }

    /// One setup-failure convergence path for callback installation and
    /// capability subscription. The original setup error is preserved; close
    /// failure transfers the still-retained ABI owner to supervised recovery.
    internal static func bindOrRecover(
        bind: () throws -> Void,
        close: () throws -> Void,
        supervise: () -> Void
    ) throws {
        do { try bind() }
        catch {
            let original = error
            do { try close() }
            catch { supervise() }
            throw original
        }
    }

    func setEventListener(_ listener: ((CitizenSDKEvent) -> Void)?) {
        routerLock.lock(); eventListener = listener; routerLock.unlock()
    }

    func lifecycle() throws -> CitizenSDKLifecycle {
        try callLock.withLock {
            try requireOpen()
            return try readLifecycle()
        }
    }

    func capabilities() throws -> CitizenSDKCapabilities {
        try callLock.withLock {
            try requireOpen()
            var value = citizensdk_capability_snapshot_t()
            value.struct_size = UInt32(MemoryLayout<citizensdk_capability_snapshot_t>.size)
            value.abi_version = 1
            try CitizenSDKChecks.requireOK(citizensdk_get_capabilities(handle, &value), "Core capability query failed")
            return try CitizenSDKNativeCodec.capabilities(value)
        }
    }

    func start() throws -> CitizenSDKOperation<Void> {
        try begin(accept: { citizensdk_start(handle, $0) }, decode: CitizenSDKNativeCodec.empty)
    }
    func stop() throws -> CitizenSDKOperation<Void> {
        try begin(accept: { citizensdk_stop(handle, $0) }, decode: CitizenSDKNativeCodec.empty)
    }
    func refreshCapabilities() throws -> CitizenSDKOperation<Void> {
        try begin(accept: { citizensdk_refresh_capabilities(handle, $0) }, decode: CitizenSDKNativeCodec.empty)
    }
    func finalizedHead() throws -> CitizenSDKOperation<CitizenBlockRef> {
        try begin(accept: { citizensdk_get_finalized_head(handle, $0) }, decode: CitizenSDKNativeCodec.block)
    }
    func feeSnapshot() throws -> CitizenSDKOperation<CitizenFeeSnapshot> {
        try begin(accept: { citizensdk_get_best_fee_snapshot(handle, $0) }, decode: CitizenSDKNativeCodec.fee)
    }
    func walletProfile() throws -> CitizenSDKOperation<CitizenWalletProfile?> {
        try begin(accept: { citizensdk_get_wallet_profile(handle, $0) }, decode: CitizenSDKNativeCodec.profile)
    }

    func accountBalance(_ accountID: Data) throws -> CitizenSDKOperation<CitizenAccountBalance> {
        var account = try cAccount(accountID)
        return try withUnsafePointer(to: &account) { pointer in
            try begin(accept: { citizensdk_get_finalized_account_balance(handle, pointer, $0) },
                      decode: CitizenSDKNativeCodec.balance)
        }
    }

    func accountNonce(_ accountID: Data) throws -> CitizenSDKOperation<CitizenAccountNonce> {
        var account = try cAccount(accountID)
        return try withUnsafePointer(to: &account) { pointer in
            try begin(accept: { citizensdk_get_account_nonce(handle, pointer, $0) }, decode: CitizenSDKNativeCodec.nonce)
        }
    }

    func setActiveAccount(_ accountID: Data) throws -> CitizenSDKOperation<CitizenWalletProfile?> {
        var account = try cAccount(accountID)
        return try withUnsafePointer(to: &account) { pointer in
            try begin(accept: { citizensdk_set_active_wallet_account(handle, pointer, $0) }, decode: CitizenSDKNativeCodec.profile)
        }
    }

    func renameAccount(_ accountID: Data, name: String) throws -> CitizenSDKOperation<CitizenWalletProfile?> {
        var account = try cAccount(accountID)
        let bytes = Data(name.utf8)
        return try withUnsafePointer(to: &account) { pointer in
            try withView(bytes) { view in
                try begin(accept: { citizensdk_rename_wallet_account(handle, pointer, view, $0) }, decode: CitizenSDKNativeCodec.profile)
            }
        }
    }

    func deleteAccount(_ accountID: Data) throws -> CitizenSDKOperation<Void> {
        var account = try cAccount(accountID)
        return try withUnsafePointer(to: &account) { pointer in
            try begin(accept: { citizensdk_delete_wallet_account(handle, pointer, $0) }, decode: CitizenSDKNativeCodec.empty)
        }
    }

    func deleteWallet() throws -> CitizenSDKOperation<Void> {
        try begin(accept: { citizensdk_delete_wallet(handle, $0) }, decode: CitizenSDKNativeCodec.empty)
    }

    func reconcileWalletCleanup() throws -> CitizenSDKOperation<Void> {
        try begin(accept: { citizensdk_reconcile_wallet_cleanup(handle, $0) }, decode: CitizenSDKNativeCodec.empty)
    }

    func sign(accountID: Data, message: Data) throws -> CitizenSDKOperation<CitizenSignature> {
        var account = try cAccount(accountID)
        return try withUnsafePointer(to: &account) { pointer in
            try withView(message) { view in
                try begin(accept: { citizensdk_sign_wallet_payload(handle, pointer, view, $0) }, decode: CitizenSDKNativeCodec.signature)
            }
        }
    }

    func transfer(source: Data, destination: Data, amount: CitizenU128, remark: Data,
                  progress: @escaping (CitizenTransferProgress) -> Void) throws -> CitizenSDKOperation<CitizenWalletTransfer> {
        var sourceAccount = try cAccount(source)
        var destinationAccount = try cAccount(destination)
        var cAmount = citizensdk_u128_t(); cAmount.low = amount.low; cAmount.high = amount.high
        return try withUnsafePointer(to: &sourceAccount) { sourcePointer in
            try withUnsafePointer(to: &destinationAccount) { destinationPointer in
                try withView(remark) { view in
                    try begin(
                        accept: { citizensdk_transfer_with_remark(handle, sourcePointer, destinationPointer, cAmount, view, $0) },
                        decode: CitizenSDKNativeCodec.transfer,
                        progress: progress
                    )
                }
            }
        }
    }

    func initializeHistory(_ accountIDs: [Data]) throws -> CitizenSDKOperation<CitizenTransactionHistory> {
        try withAccounts(accountIDs) { pointer, count in
            try begin(accept: { citizensdk_initialize_finalized_history(handle, pointer, count, $0) },
                      decode: CitizenSDKNativeCodec.history)
        }
    }

    func syncHistory(_ accountIDs: [Data]) throws -> CitizenSDKOperation<CitizenTransactionHistory> {
        try withAccounts(accountIDs) { pointer, count in
            try begin(accept: { citizensdk_sync_finalized_history_batch(handle, pointer, count, $0) },
                      decode: CitizenSDKNativeCodec.history)
        }
    }

    func prepareWallet(wordCount: UInt32, password: CitizenSDKSensitiveBuffer) throws -> CitizenSDKOperation<UInt64> {
        try password.withUnsafeBytes { bytes in
            var view = citizensdk_bytes_view_t()
            view.data = bytes.bindMemory(to: UInt8.self).baseAddress
            view.len = UInt64(bytes.count)
            return try begin(accept: { citizensdk_prepare_wallet_creation(handle, wordCount, view, $0) }, decode: { result in
                let prepared = try CitizenSDKNativeCodec.preparedWallet(result)
                self.routerLock.lock(); self.preparedHandles.insert(prepared); self.routerLock.unlock()
                return prepared
            })
        }
    }

    func importWallet(mnemonic: CitizenSDKSensitiveBuffer,
                      password: CitizenSDKSensitiveBuffer) throws -> CitizenSDKOperation<CitizenWalletProfile?> {
        try withSensitiveViews(mnemonic, password) { mnemonicView, passwordView in
            try begin(accept: { citizensdk_import_wallet(handle, mnemonicView, passwordView, $0) },
                      decode: CitizenSDKNativeCodec.profile)
        }
    }

    func addAccounts(mnemonic: CitizenSDKSensitiveBuffer, password: CitizenSDKSensitiveBuffer,
                     indices: [UInt32]) throws -> CitizenSDKOperation<[CitizenWalletAccount]> {
        try withSensitiveViews(mnemonic, password) { mnemonicView, passwordView in
            try indices.withUnsafeBufferPointer { values in
                try begin(accept: {
                    citizensdk_add_wallet_accounts(handle, mnemonicView, passwordView,
                                                   values.baseAddress, UInt32(values.count), $0)
                }, decode: CitizenSDKNativeCodec.accounts)
            }
        }
    }

    func copyPreparedMnemonic(_ prepared: UInt64) throws -> CitizenSDKSensitiveBuffer {
        try callLock.withLock {
            try requireOpen()
            routerLock.lock(); let owned = preparedHandles.contains(prepared); routerLock.unlock()
            guard owned else { throw CitizenSDKError(.invalidHandle, "prepared wallet is unknown") }
            var required: UInt64 = 0
            try CitizenSDKChecks.requireOK(
                citizensdk_prepared_wallet_copy_mnemonic(handle, prepared, nil, 0, &required),
                "prepared wallet mnemonic size query failed"
            )
            guard required <= 1_024 else { throw CitizenSDKError(.integrity, "prepared mnemonic exceeds the wallet contract") }
            let output = CitizenSDKSensitiveBuffer(count: Int(required))
            var confirmed = required
            let code = output.withUnsafeMutableBytes { bytes in
                citizensdk_prepared_wallet_copy_mnemonic(handle, prepared,
                                                         bytes.bindMemory(to: UInt8.self).baseAddress,
                                                         UInt64(bytes.count), &confirmed)
            }
            do {
                try CitizenSDKChecks.requireOK(code, "prepared wallet mnemonic copy failed")
                guard confirmed == required else { throw CitizenSDKError(.integrity, "prepared mnemonic length changed") }
                return output
            } catch {
                output.clear()
                throw error
            }
        }
    }

    func commitPrepared(_ prepared: UInt64) throws -> CitizenSDKOperation<CitizenWalletProfile?> {
        try callLock.withLock {
            try requireOpen()
            routerLock.lock(); let owned = preparedHandles.contains(prepared); routerLock.unlock()
            guard owned else { throw CitizenSDKError(.invalidHandle, "prepared wallet is unknown") }
            let operation = try begin(accept: { citizensdk_commit_wallet_creation(handle, prepared, $0) },
                                      decode: CitizenSDKNativeCodec.profile)
            routerLock.lock(); preparedHandles.remove(prepared); routerLock.unlock()
            return operation
        }
    }

    func releasePrepared(_ prepared: UInt64) throws {
        try callLock.withLock {
            try requireOpen()
            routerLock.lock(); let owned = preparedHandles.contains(prepared); routerLock.unlock()
            guard owned else { return }
            try CitizenSDKChecks.requireOK(citizensdk_prepared_wallet_release(handle, prepared), "prepared wallet release failed")
            routerLock.lock(); preparedHandles.remove(prepared); routerLock.unlock()
        }
    }

    func close() throws {
        var prepared: Set<UInt64> = []
        try Self.withCheckpointSafeCloseGate(
            lock: callLock,
            checkpointRequired: {
                if closed { return false }
                routerLock.lock()
                let isBusy = !pending.isEmpty || !earlyCompletions.isEmpty ||
                    !earlyWatches.isEmpty || queuedDeliveries != 0
                prepared = preparedHandles
                routerLock.unlock()
                guard !isBusy else {
                    throw CitizenSDKError(.busy, "CitizenSDK has accepted work that has not completed")
                }
                return !teardown.snapshot.teardownStarted
            },
            lifecycle: readLifecycle
        ) {
            if closed { return }
            try Self.releasePreparedBeforeDestroy(
                prepared.sorted(),
                release: { try releasePrepared($0) },
                destroy: {
                    guard deferredStateEvents.beginTeardownIfNoActiveDelivery() else {
                        throw CitizenSDKError(.busy, "CitizenSDK state event delivery is active")
                    }
                    try teardown.perform(
                        unsubscribe: {
                            try CitizenSDKChecks.requireOK(
                                citizensdk_unsubscribe_capability_changes(handle),
                                "Core capability monitor could not stop"
                            )
                        },
                        clearCallback: {
                            try CitizenSDKChecks.requireOK(
                                citizensdk_set_event_callback(handle, nil, nil),
                                "Core callback could not be cleared"
                            )
                        },
                        destroy: {
                            try CitizenSDKChecks.requireOK(
                                citizensdk_destroy(handle),
                                "CitizenSDK Core destruction failed"
                            )
                        },
                        didDestroy: { finishSuccessfulDestroy() }
                    )
                }
            )
        }
    }

    /// Serializes the authoritative lifecycle check and all subsequent close
    /// work with every request admission. Tests inject the same recursive lock
    /// to prove a concurrent start cannot cross this checkpoint.
    internal static func withCheckpointSafeCloseGate<T>(
        lock: NSRecursiveLock,
        checkpointRequired: () throws -> Bool,
        lifecycle: () throws -> CitizenSDKLifecycle,
        body: () throws -> T
    ) throws -> T {
        try lock.withLock {
            if try checkpointRequired() { try requireCheckpointSafeForClose(lifecycle()) }
            return try body()
        }
    }

    /// Rust shutdown is destructive for a running provider; graceful stop and
    /// checkpoint completion must precede the first ABI teardown call.
    internal static func requireCheckpointSafeForClose(_ lifecycle: CitizenSDKLifecycle) throws {
        switch lifecycle {
        case .created, .stopped, .startFailed:
            return
        case .running:
            throw CitizenSDKError(.invalidState, "A running CitizenSDK must complete stop before close")
        case .starting, .importingState:
            throw CitizenSDKError(.busy, "CitizenSDK lifecycle transition is still running")
        case .disposed:
            throw CitizenSDKError(.invalidState, "Core reported disposed before native destruction")
        }
    }

    /// Recovery owns no public facade. A live running instance first attempts
    /// the normal checkpointing stop; partial teardown skips every lifecycle
    /// query/control and resumes the phase machine directly.
    func supervisedClose() async throws {
        switch try Self.supervisedCloseAction(
            teardownStarted: teardown.snapshot.teardownStarted,
            lifecycle: self.lifecycle
        ) {
        case .stopThenClose:
            // Stop/checkpoint failure is retryable and must not silently
            // degrade into destructive teardown of a still-running instance.
            try await stop().value()
        case .close:
            break
        }
        try close()
    }

    /// Chooses recovery from the authoritative C lifecycle, never the facade's
    /// eventually-delivered event cache. Query failure is propagated before
    /// teardown begins; partial teardown bypasses every further control call.
    internal static func supervisedCloseAction(
        teardownStarted: Bool,
        lifecycle: () throws -> CitizenSDKLifecycle
    ) throws -> CitizenSDKSupervisedCloseAction {
        if teardownStarted { return .close }
        switch try lifecycle() {
        case .running:
            return .stopThenClose
        case .starting, .importingState:
            throw CitizenSDKError(.busy, "CitizenSDK lifecycle transition is still running")
        case .created, .stopped, .startFailed, .disposed:
            return .close
        }
    }

    func enqueueForSupervisedClose() {
        Task { await CitizenSDKLifecycleSupervisor.shared.adopt(self) }
    }

    var teardownStarted: Bool { teardown.snapshot.teardownStarted }

    /// Destruction is strictly after every prepared owner is released. A
    /// release failure stops teardown, leaves Native's prepared set intact and
    /// permits a later `close()` retry on the same live Core.
    internal static func releasePreparedBeforeDestroy(
        _ prepared: [UInt64],
        release: (UInt64) throws -> Void,
        destroy: () throws -> Void
    ) throws {
        for handle in prepared { try release(handle) }
        try destroy()
    }

    private func bindCallback() throws {
        try CitizenSDKChecks.requireOK(
            citizensdk_set_event_callback(handle, citizenSDKEventCallback,
                                           Unmanaged.passUnretained(self).toOpaque()),
            "Core callback binding failed"
        )
        try CitizenSDKChecks.requireOK(
            citizensdk_subscribe_capability_changes(handle),
            "Core capability subscription failed"
        )
    }

    private func begin<T: Sendable>(accept: (UnsafeMutablePointer<UInt64>) -> Int32,
                                    decode: @escaping (UInt64) throws -> T,
                                    progress: ((CitizenTransferProgress) -> Void)? = nil) throws -> CitizenSDKOperation<T> {
        try callLock.withLock {
            try requireOpen()
            let cancellation = Cancellation()
            let operationID = UUID().uuidString
            let operation = CitizenSDKOperation<T>(operationID: operationID) { [weak self, cancellation] in
                guard let self, let request = cancellation.value() else { return false }
                return try self.cancel(request)
            }
            routerLock.lock()
            guard !admissionInProgress, earlyCompletions.isEmpty, earlyWatches.isEmpty else {
                routerLock.unlock()
                throw CitizenSDKError(.integrity, "Core admission router is not quiescent")
            }
            admissionInProgress = true
            routerLock.unlock()

            var requestID: UInt64 = 0
            let code = accept(&requestID)
            let pending = Pending(
                operationID: operationID,
                decode: { try decode($0) },
                complete: { result in
                    operation.complete(result.flatMap { value in
                        guard let typed = value as? T else {
                            return .failure(CitizenSDKError(.integrity, "Core result type drifted"))
                        }
                        return .success(typed)
                    })
                },
                progress: progress
            )
            routerLock.lock()
            admissionInProgress = false
            let accepted = code == 0 && requestID != 0 && self.pending[requestID] == nil
            let completion = accepted ? earlyCompletions.removeValue(forKey: requestID) : nil
            let watches = accepted ? (earlyWatches.removeValue(forKey: requestID) ?? []) : []
            let ownsEarlyDelivery = accepted && (completion != nil || !watches.isEmpty)
            if ownsEarlyDelivery { queuedDeliveries += 1 }
            let rejectedCompletions = Array(earlyCompletions.values)
            let rejectedWatches = earlyWatches.values.flatMap { $0.map(\.result) }
            earlyCompletions.removeAll(keepingCapacity: true)
            earlyWatches.removeAll(keepingCapacity: true)
            if accepted && completion == nil { self.pending[requestID] = pending }
            routerLock.unlock()
            rejectedCompletions.forEach { _ = citizensdk_result_release($0) }
            rejectedWatches.forEach { _ = citizensdk_result_release($0) }

            if code != 0 { try CitizenSDKChecks.requireOK(code, "Core request was rejected") }
            guard requestID != 0 else { throw CitizenSDKError(.integrity, "Core returned an empty request identity") }
            guard accepted else { throw CitizenSDKError(.integrity, "Core reused an active request identity") }
            cancellation.bind(requestID)
            defer {
                if ownsEarlyDelivery {
                    routerLock.lock(); queuedDeliveries -= 1; routerLock.unlock()
                }
            }
            watches.forEach { routeWatch(requestID: requestID, sequence: $0.sequence, result: $0.result, pending: pending) }
            if let completion { routeCompletion(result: completion, pending: pending) }
            return operation
        }
    }

    private func cancel(_ requestID: UInt64) throws -> Bool {
        try callLock.withLock {
            try requireOpen()
            let code = citizensdk_cancel_request(handle, requestID)
            if code == CitizenSDKErrorCode.unsupported.rawValue { return false }
            try CitizenSDKChecks.requireOK(code, "Core cancellation was rejected")
            return true
        }
    }

    fileprivate func receive(_ event: citizensdk_event_t) {
        switch event.event_type {
        case 1:
            var release: UInt64?
            routerLock.lock()
            if let pending = pending.removeValue(forKey: event.request_id) {
                // Removal and delivery ownership are one router-lock commit.
                // Close therefore observes either `pending` or queued delivery,
                // so even a synchronously resumed/reentrant completion observer
                // cannot overlap callback teardown.
                queuedDeliveries += 1
                routerLock.unlock(); routeCompletion(result: event.result, pending: pending)
                routerLock.lock(); queuedDeliveries -= 1; routerLock.unlock()
            } else if admissionInProgress {
                if earlyCompletions[event.request_id] == nil {
                    earlyCompletions[event.request_id] = event.result
                } else {
                    release = event.result
                }
                routerLock.unlock()
            } else {
                release = event.result
                routerLock.unlock()
            }
            if let release { _ = citizensdk_result_release(release) }
        case 2:
            var release: UInt64?
            routerLock.lock()
            if let pending = pending[event.request_id] {
                // The request stays pending while progress runs. A concurrent
                // close fails BUSY before unsubscribe/clear and cannot wait on
                // a progress closure that synchronously reenters any SDK API.
                routerLock.unlock(); routeWatch(requestID: event.request_id, sequence: event.sequence,
                                                result: event.result, pending: pending)
            } else if admissionInProgress && earlyCompletions[event.request_id] == nil {
                earlyWatches[event.request_id, default: []].append((event.sequence, event.result))
                routerLock.unlock()
            } else {
                release = event.result
                routerLock.unlock()
            }
            if let release { _ = citizensdk_result_release(release) }
        case 3:
            enqueueDeferredStateEvent(.capabilities(sequence: event.sequence))
        case 4:
            enqueueDeferredStateEvent(.lifecycle(sequence: event.sequence))
        default:
            if event.result != 0 { _ = citizensdk_result_release(event.result) }
        }
    }

    private func routeCompletion(result: UInt64, pending: Pending) {
        let outcome: Result<Any, Error>
        do { outcome = .success(try pending.decode(result)) }
        catch { outcome = .failure(error) }
        let release = citizensdk_result_release(result)
        if release != 0, case .success = outcome {
            pending.complete(.failure(CitizenSDKError(.integrity, "Core result ownership could not be released")))
        } else {
            pending.complete(outcome)
        }
    }

    private func routeWatch(requestID: UInt64, sequence: UInt64, result: UInt64, pending: Pending) {
        defer { _ = citizensdk_result_release(result) }
        guard let progress = pending.progress,
              let value = try? CitizenSDKNativeCodec.watch(result, operationID: pending.operationID, sequence: sequence) else { return }
        progress(value)
    }

    /// Runs only after the C callback has returned. The delivery gate and
    /// `callLock` linearize against close: either this query owns an active
    /// delivery and close returns BUSY, or teardown wins and the work is skipped.
    private func enqueueDeferredStateEvent(_ event: DeferredStateEvent) {
        deferredStateEvents.enqueue { [self] in
            do {
                switch event {
                case let .capabilities(sequence):
                    publish(.capabilitiesChanged(sequence: sequence, capabilities: try capabilities()))
                case let .lifecycle(sequence):
                    publish(.lifecycleChanged(sequence: sequence, lifecycle: try lifecycle()))
                }
            } catch {
                // Lifecycle state is synchronously queryable. A failed or
                // teardown-raced notification is deliberately not invented.
            }
        }
    }

    private func publish(_ event: CitizenSDKEvent) {
        routerLock.lock(); let listener = eventListener; routerLock.unlock()
        listener?(event)
    }

    private func requireOpen() throws {
        if closed || handle == 0 { throw CitizenSDKError(.invalidState, "CitizenSDK native bridge is closed") }
        try teardown.requireOperational()
    }

    /// Caller holds `callLock` (directly or recursively), so the returned value
    /// cannot race request admission or the first teardown phase.
    private func readLifecycle() throws -> CitizenSDKLifecycle {
        var value: UInt32 = 0
        try CitizenSDKChecks.requireOK(citizensdk_get_lifecycle(handle, &value), "Core lifecycle query failed")
        guard let lifecycle = CitizenSDKLifecycle(rawValue: value) else {
            throw CitizenSDKError(.integrity, "Core returned an unknown lifecycle")
        }
        return lifecycle
    }

    private func finishSuccessfulDestroy() {
        handle = 0
        closed = true
        routerLock.lock(); eventListener = nil; routerLock.unlock()
        // Called only from `close()` while `callLock` is held. HostBridge (and
        // its SQLite stores) ends exactly at successful Core destruction, even
        // when the public facade remains strongly reachable afterward.
        let resources = abiResources
        abiResources = nil
        resources?.releaseAfterSuccessfulDestroy()
    }

    private func cAccount(_ data: Data) throws -> citizensdk_account_id_t {
        let checked = try CitizenSDKInputLimits.accountID(data)
        var output = citizensdk_account_id_t()
        _ = withUnsafeMutableBytes(of: &output.bytes) { checked.copyBytes(to: $0) }
        return output
    }

    private func withAccounts<T>(_ values: [Data], body: (UnsafePointer<citizensdk_account_id_t>?, UInt32) throws -> T) throws -> T {
        let accounts = try values.map(cAccount)
        return try accounts.withUnsafeBufferPointer { try body($0.baseAddress, UInt32($0.count)) }
    }

    private func withSensitiveViews<T>(_ first: CitizenSDKSensitiveBuffer, _ second: CitizenSDKSensitiveBuffer,
                                       body: (citizensdk_bytes_view_t, citizensdk_bytes_view_t) throws -> T) rethrows -> T {
        try first.withUnsafeBytes { a in try second.withUnsafeBytes { b in
            var av = citizensdk_bytes_view_t(); av.data = a.bindMemory(to: UInt8.self).baseAddress; av.len = UInt64(a.count)
            var bv = citizensdk_bytes_view_t(); bv.data = b.bindMemory(to: UInt8.self).baseAddress; bv.len = UInt64(b.count)
            return try body(av, bv)
        } }
    }

    private static func withViews<T>(_ values: [Data], body: ([citizensdk_bytes_view_t]) throws -> T) rethrows -> T {
        func descend(_ index: Int, _ collected: [citizensdk_bytes_view_t]) throws -> T {
            if index == values.count { return try body(collected) }
            return try values[index].withUnsafeBytes { bytes in
                var view = citizensdk_bytes_view_t(); view.data = bytes.bindMemory(to: UInt8.self).baseAddress; view.len = UInt64(bytes.count)
                return try descend(index + 1, collected + [view])
            }
        }
        return try descend(0, [])
    }

    private func withView<T>(_ value: Data, body: (citizensdk_bytes_view_t) throws -> T) rethrows -> T {
        try value.withUnsafeBytes { bytes in
            var view = citizensdk_bytes_view_t(); view.data = bytes.bindMemory(to: UInt8.self).baseAddress; view.len = UInt64(bytes.count)
            return try body(view)
        }
    }

    static func lastError(fallback: String) -> String {
        var required: UInt64 = 0
        guard citizensdk_last_error_copy(nil, 0, &required) == 0, required <= UInt64(Int.max) else { return fallback }
        var bytes = Data(count: Int(required))
        var confirmed = required
        let code = bytes.withUnsafeMutableBytes {
            citizensdk_last_error_copy($0.bindMemory(to: UInt8.self).baseAddress, UInt64($0.count), &confirmed)
        }
        guard code == 0, confirmed == required, let value = String(data: bytes, encoding: .utf8), !value.isEmpty else { return fallback }
        return value
    }
}

private func citizenSDKEventCallback(_ context: UnsafeMutableRawPointer?,
                                     _ event: UnsafePointer<citizensdk_event_t>?) {
    guard let context, let event else { return }
    Unmanaged<CitizenSDKNative>.fromOpaque(context).takeUnretainedValue().receive(event.pointee)
}

private extension NSRecursiveLock {
    func withLock<T>(_ body: () throws -> T) rethrows -> T {
        lock(); defer { unlock() }
        return try body()
    }
}
