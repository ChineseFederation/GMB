import Foundation

/// Native Swift facade for one CitizenSDK Core instance.
///
/// C handles, result handles, prepared-wallet handles, mnemonics and passwords
/// are absent from this public surface. Wallet creation/import/add-account
/// secrets are accepted only by the SDK-owned Apple UI.
public final class CitizenSdk: @unchecked Sendable {
    public let sessionID = UUID().uuidString
    private let stateLock = NSLock()
    private let native: CitizenSDKNative
    private var lifecycleValue: CitizenSDKLifecycle
    private var closed = false
    private var eventHandler: ((CitizenSDKEvent) -> Void)?

    private init(native: CitizenSDKNative, lifecycle: CitizenSDKLifecycle) {
        self.native = native
        lifecycleValue = lifecycle
        CitizenSDKWalletFlowRegistry.shared.registerOpen(self)
    }

    public static func open() throws -> CitizenSdk {
        let native = try CitizenSDKNative.open(assets: CitizenSDKAssets.load())
        return try finishOpen(native)
    }

    internal static func open(storageRoot: URL, applicationID: String? = Bundle.main.bundleIdentifier,
                              assets: CitizenSDKAssets? = nil) throws -> CitizenSdk {
        let native = try CitizenSDKNative.open(assets: assets ?? CitizenSDKAssets.load(), storageRoot: storageRoot,
                                              applicationID: applicationID)
        return try finishOpen(native)
    }

    private static func finishOpen(_ native: CitizenSDKNative) throws -> CitizenSdk {
        try finalizeOpen(
            lifecycle: native.lifecycle,
            install: { lifecycle in
            let sdk = CitizenSdk(native: native, lifecycle: lifecycle)
            native.setEventListener { [weak sdk] event in sdk?.receive(event) }
            return sdk
            },
            cleanup: {
            // A freshly created instance is still in the destroyable CREATED
            // state. Preserve the initialization error while closing Core and
            // all host resources best-effort.
            native.setEventListener(nil)
            do { try native.close() }
            catch { native.enqueueForSupervisedClose() }
            }
        )
    }

    deinit {
        stateLock.lock()
        let needsRecovery = !closed
        stateLock.unlock()
        if needsRecovery { native.enqueueForSupervisedClose() }
        CitizenSDKWalletFlowRegistry.shared.forget(self)
    }

    /// One cleanup gate shared by the production constructor and source-level
    /// fault-injection tests. Any lifecycle or listener-install failure must
    /// close the freshly-created Core exactly once while preserving the
    /// original error.
    internal static func finalizeOpen<T>(
        lifecycle: () throws -> CitizenSDKLifecycle,
        install: (CitizenSDKLifecycle) throws -> T,
        cleanup: () -> Void
    ) throws -> T {
        do { return try install(lifecycle()) }
        catch { cleanup(); throw error }
    }

    public var lifecycle: CitizenSDKLifecycle {
        stateLock.lock(); defer { stateLock.unlock() }
        return lifecycleValue
    }

    public func setEventHandler(_ handler: ((CitizenSDKEvent) -> Void)?) throws {
        stateLock.lock(); defer { stateLock.unlock() }
        guard !closed else { throw CitizenSDKError(.invalidState, "CitizenSDK is closed") }
        eventHandler = handler
    }

    public func start() async throws {
        try await native.start().value()
    }

    public func stop() async throws {
        try await native.stop().value()
    }

    public func refreshCapabilities() async throws {
        try await native.refreshCapabilities().value()
    }

    public func capabilities() throws -> CitizenSDKCapabilities { try native.capabilities() }
    public func finalizedHead() async throws -> CitizenBlockRef { try await native.finalizedHead().value() }

    public func accountBalance(accountID: Data) async throws -> CitizenAccountBalance {
        try await native.accountBalance(CitizenSDKInputLimits.accountID(accountID)).value()
    }

    public func accountNonce(accountID: Data) async throws -> CitizenAccountNonce {
        try await native.accountNonce(CitizenSDKInputLimits.accountID(accountID)).value()
    }

    public func feeSnapshot() async throws -> CitizenFeeSnapshot { try await native.feeSnapshot().value() }
    public func walletProfile() async throws -> CitizenWalletProfile? { try await native.walletProfile().value() }

    public func setActiveWalletAccount(accountID: Data) async throws -> CitizenWalletProfile {
        try await CitizenSDKWalletMutationGate.shared.perform {
            guard let profile = try await native.setActiveAccount(CitizenSDKInputLimits.accountID(accountID)).value() else {
                throw CitizenSDKError(.integrity, "set active account returned no wallet profile")
            }
            return profile
        }
    }

    public func renameWalletAccount(accountID: Data, name: String) async throws -> CitizenWalletProfile {
        let checkedName = try CitizenSDKInputLimits.accountName(name)
        return try await CitizenSDKWalletMutationGate.shared.perform {
            guard let profile = try await native.renameAccount(CitizenSDKInputLimits.accountID(accountID), name: checkedName).value() else {
                throw CitizenSDKError(.integrity, "rename account returned no wallet profile")
            }
            return profile
        }
    }

    /// Returns the post-delete profile under the same process mutation gate.
    public func deleteWalletAccount(accountID: Data) async throws -> CitizenWalletProfile? {
        try await CitizenSDKWalletMutationGate.shared.perform {
            try await native.deleteAccount(CitizenSDKInputLimits.accountID(accountID)).value()
            return try await native.walletProfile().value()
        }
    }

    public func deleteWallet() async throws -> CitizenWalletProfile? {
        try await CitizenSDKWalletMutationGate.shared.perform {
            try await native.deleteWallet().value()
            return try await native.walletProfile().value()
        }
    }

    public func reconcileWalletCleanup() async throws -> CitizenWalletProfile? {
        try await CitizenSDKWalletMutationGate.shared.perform {
            try await native.reconcileWalletCleanup().value()
            return try await native.walletProfile().value()
        }
    }

    public func signWalletPayload(accountID: Data, message: Data) async throws -> CitizenSignature {
        try await native.sign(accountID: CitizenSDKInputLimits.accountID(accountID),
                              message: CitizenSDKInputLimits.signingPayload(message)).value()
    }

    public func transferWithRemark(sourceAccountID: Data, destinationAccountID: Data,
                                   amountFen: CitizenU128, remark: Data,
                                   progress: @escaping (CitizenTransferProgress) -> Void) throws
        -> CitizenSDKOperation<CitizenWalletTransfer> {
        guard amountFen.low != 0 || amountFen.high != 0 else {
            throw CitizenSDKError(.invalidArgument, "transfer amount must be positive")
        }
        return try native.transfer(
            source: CitizenSDKInputLimits.accountID(sourceAccountID, label: "sourceAccountID"),
            destination: CitizenSDKInputLimits.accountID(destinationAccountID, label: "destinationAccountID"),
            amount: amountFen,
            remark: CitizenSDKInputLimits.transferRemark(remark),
            progress: progress
        )
    }

    public func initializeFinalizedHistory(accountIDs: [Data]) async throws -> CitizenTransactionHistory {
        try await native.initializeHistory(CitizenSDKInputLimits.accountIDs(accountIDs)).value()
    }

    public func syncFinalizedHistory(accountIDs: [Data]) async throws -> CitizenTransactionHistory {
        try await native.syncHistory(CitizenSDKInputLimits.accountIDs(accountIDs)).value()
    }

    /// Destroys only checkpoint-safe Core state. A running instance must first
    /// complete `stop`; accepted requests and secure wallet UI fail BUSY.
    public func close() throws {
        stateLock.lock()
        if closed { stateLock.unlock(); return }
        let state = lifecycleValue
        stateLock.unlock()
        switch state {
        case .created, .stopped, .startFailed: break
        case .disposed: return
        case .running:
            throw CitizenSDKError(.invalidState, "A running CitizenSDK must complete stop before close")
        case .starting, .importingState:
            throw CitizenSDKError(.busy, "CitizenSDK lifecycle transition is still running")
        }
        try finishClose()
    }

    private func finishClose() throws {
        let registry = CitizenSDKWalletFlowRegistry.shared
        guard let reservation = try registry.beginClose(self) else {
            commitClosedFacade(reservation: nil)
            return
        }
        do {
            try native.close()
        } catch {
            let requiresSupervisor = registry.failClose(
                self, reservation: reservation, teardownStarted: native.teardownStarted
            )
            if requiresSupervisor { enqueueForSupervisedClose() }
            throw error
        }
        commitClosedFacade(reservation: reservation)
    }

    /// Used only by the detach supervisor. Unlike Native-only recovery this
    /// retains the facade, respects active SDK wallet UI ownership, and runs a
    /// normal checkpointing stop before close when the Core is running.
    @_spi(CitizenSDKFlutter)
    public func supervisedClose() async throws {
        // Recovery must not consult `lifecycleValue`: the Core can complete a
        // stop before its lifecycle event reaches this facade. Native queries
        // the authoritative C lifecycle and resumes any partial ABI teardown.
        let registry = CitizenSDKWalletFlowRegistry.shared
        guard let reservation = try registry.beginClose(self, origin: .supervised) else {
            commitClosedFacade(reservation: nil)
            return
        }
        do {
            try await native.supervisedClose()
        } catch {
            // This method already runs under the lifecycle supervisor, so even
            // a pre-teardown failure stays closing between actor retries.
            _ = registry.failClose(
                self, reservation: reservation, teardownStarted: native.teardownStarted
            )
            throw error
        }
        commitClosedFacade(reservation: reservation)
    }

    /// Official Flutter adapter SPI; not part of the application-facing API.
    @_spi(CitizenSDKFlutter)
    public func enqueueForSupervisedClose() {
        Task { await CitizenSDKLifecycleSupervisor.shared.adopt(self) }
    }

    /// Commits public disposal only after successful Core destruction. The
    /// idempotent gate also makes concurrent explicit/reaper completion commit
    /// the registry tombstone exactly once.
    private func commitClosedFacade(
        reservation: CitizenSDKWalletFlowRegistry.CloseReservation?
    ) {
        // Publish the destroyed tombstone first, without holding `stateLock`,
        // so no wallet UI can enter while facade disposal is being committed.
        CitizenSDKWalletFlowRegistry.shared.commitClosed(self, reservation: reservation)
        stateLock.lock()
        let didCommit = !closed
        if didCommit {
            lifecycleValue = .disposed
            closed = true
            eventHandler = nil
        }
        stateLock.unlock()
    }

    /// Secret-bearing wallet mutation entry points are main-actor isolated:
    /// only the SDK-owned Apple UI may construct their buffers, and the native
    /// admission call borrows them synchronously before the returned operation
    /// is awaited.
    @MainActor
    internal func prepareWallet(wordCount: UInt32, password: CitizenSDKSensitiveBuffer) async throws -> CitizenSDKPreparedWallet {
        guard [12, 18, 24].contains(wordCount) else { throw CitizenSDKError(.invalidArgument, "word count must be 12, 18 or 24") }
        let operation = try native.prepareWallet(wordCount: wordCount, password: password)
        password.clear()
        return CitizenSDKPreparedWallet(native: native, handle: try await operation.value())
    }

    @MainActor
    internal func importWallet(mnemonic: CitizenSDKSensitiveBuffer,
                               password: CitizenSDKSensitiveBuffer) async throws -> CitizenWalletProfile? {
        try CitizenSDKWalletMutationGate.shared.enterWalletUI()
        defer { CitizenSDKWalletMutationGate.shared.leaveWalletUI() }
        // Admission borrows both buffers synchronously on MainActor. Only the
        // Sendable operation result crosses the suspension point.
        let operation = try native.importWallet(mnemonic: mnemonic, password: password)
        mnemonic.clear(); password.clear()
        return try await operation.value()
    }

    @MainActor
    internal func addWalletAccounts(mnemonic: CitizenSDKSensitiveBuffer, password: CitizenSDKSensitiveBuffer,
                                    indices: [UInt32]) async throws -> CitizenWalletProfile {
        let checked = try CitizenSDKInputLimits.additionalIndices(indices)
        try CitizenSDKWalletMutationGate.shared.enterWalletUI()
        defer { CitizenSDKWalletMutationGate.shared.leaveWalletUI() }
        let operation = try native.addAccounts(mnemonic: mnemonic, password: password, indices: checked)
        mnemonic.clear(); password.clear()
        let added = try await operation.value()
        guard added.count == checked.count, Set(added.map(\.index)) == Set(checked) else {
            throw CitizenSDKError(.integrity, "add accounts result does not match requested indices")
        }
        guard let profile = try await native.walletProfile().value(),
              added.allSatisfy({ account in profile.accounts.contains(where: { $0.accountID == account.accountID }) }) else {
            throw CitizenSDKError(.integrity, "updated wallet profile is missing an added account")
        }
        return profile
    }

    @MainActor
    internal func commit(_ prepared: CitizenSDKPreparedWallet) async throws -> CitizenWalletProfile? {
        try CitizenSDKWalletMutationGate.shared.enterWalletUI()
        defer { CitizenSDKWalletMutationGate.shared.leaveWalletUI() }
        return try await prepared.commit()
    }

    private func receive(_ event: CitizenSDKEvent) {
        stateLock.lock()
        if case let .lifecycleChanged(_, lifecycle) = event { lifecycleValue = lifecycle }
        let handler = eventHandler
        stateLock.unlock()
        handler?(event)
    }
}

/// Process-wide mutation serialization. Every mutable field is reached only
/// through the synchronous `enter`/`leave` helpers while `lock` is held, so
/// async callers never directly share unprotected state across executors.
private final class CitizenSDKWalletMutationGate: @unchecked Sendable {
    static let shared = CitizenSDKWalletMutationGate()
    private let lock = NSLock()
    private var active = false

    func perform<T>(_ operation: () async throws -> T) async throws -> T {
        try enter()
        defer { leave() }
        return try await operation()
    }

    private func enter() throws {
        lock.lock()
        guard !active else { lock.unlock(); throw CitizenSDKError(.busy, "another wallet mutation is active") }
        active = true
        lock.unlock()
    }

    private func leave() {
        lock.lock(); active = false; lock.unlock()
    }

    /// SDK-owned Apple wallet UI uses an explicit synchronous gate so secret
    /// buffers are admitted on MainActor before any async suspension.
    func enterWalletUI() throws { try enter() }
    func leaveWalletUI() { leave() }
}
