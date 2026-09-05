package org.citizen.sdk

import android.content.Context
import androidx.fragment.app.FragmentActivity
import org.citizen.sdk.internal.CitizenSdkAssets
import org.citizen.sdk.internal.CitizenSdkHostServices
import org.citizen.sdk.internal.CitizenSdkNative
import org.citizen.sdk.internal.CitizenSdkNativeResult
import org.citizen.sdk.internal.CitizenSdkRequestRouter
import org.citizen.sdk.ui.CitizenSdkWalletFlowContract
import org.citizen.sdk.ui.CitizenSdkWalletFlowCoordinator
import java.util.UUID
import java.util.concurrent.CompletableFuture
import java.util.concurrent.CompletionException
import java.util.concurrent.ExecutionException
import java.util.concurrent.atomic.AtomicBoolean

/**
 * Java/Kotlin facade for the one CitizenSDK Core instance.
 *
 * The facade exposes public chain facts and wallet operations. Native handles,
 * result handles, prepared-wallet handles, recovery phrases and passwords are
 * deliberately absent from this surface.
 */
class CitizenSdk private constructor(
    context: Context,
    listener: CitizenSdkEvents.Listener?,
) : AutoCloseable {
    val sessionId: String = UUID.randomUUID().toString()

    private val lifecycleGate = Any()
    private val closed = AtomicBoolean(false)
    private val closing = AtomicBoolean(false)
    private var closeActive = false
    private val hostServices = CitizenSdkHostServices(context.applicationContext)
    private val native = CitizenSdkNative.create(
        assets = CitizenSdkAssets.load(context.applicationContext),
        hostServices = hostServices,
    )
    private val requests = CitizenSdkRequestRouter(native::cancel)

    @Volatile
    private var eventListener: CitizenSdkEvents.Listener? = listener

    @Volatile
    var lifecycle: CitizenSdkLifecycle = native.lifecycle()
        private set

    // Dynamic Activity readiness is a generation, not an untracked fire-and-
    // forget request. Edges coalesce; BUSY retries after the accepted request
    // that owns the exclusive Core gate reaches terminal completion.
    private var readinessDesiredGeneration = 0L
    private var readinessAppliedGeneration = 0L
    private var readinessInFlight = false
    private var readinessRetryPending = false
    private var readinessConvergence = CompletableFuture.completedFuture<Void>(null)

    init {
        try {
            native.bind(requests) { event ->
                if (event is CitizenSdkEvents.Event.LifecycleChanged) {
                    lifecycle = event.lifecycle
                }
                eventListener?.onEvent(event)
            }
            hostServices.setActivityReadinessListener {
                readinessChanged()
            }
            readinessChanged()
        } catch (error: Throwable) {
            runCatching { native.close() }
            runCatching { requests.close() }
            runCatching { hostServices.close() }
            closed.set(true)
            throw error
        }
    }

    fun setEventListener(listener: CitizenSdkEvents.Listener?) {
        synchronized(lifecycleGate) {
            requireOpen()
            eventListener = listener
        }
    }

    fun attachActivity(activity: FragmentActivity) {
        synchronized(lifecycleGate) {
            requireOpen()
            hostServices.attachActivity(activity)
        }
    }

    fun detachActivity(activity: FragmentActivity) {
        synchronized(lifecycleGate) {
            if (!closed.get()) hostServices.detachActivity(activity)
        }
    }

    fun start(): CompletableFuture<Void> = exclusiveAfterReadiness { native.start() }

    fun stop(): CompletableFuture<Void> = exclusiveAfterReadiness { native.stop() }

    fun getCapabilities(): CitizenSdkCapabilities {
        return synchronized(lifecycleGate) {
            requireOpen()
            native.capabilities()
        }
    }

    fun getFinalizedHead(): CompletableFuture<CitizenBlockRef> =
        request({ native.getFinalizedHead() }) { (it as CitizenSdkNativeResult.Block).value }

    fun getAccountBalance(accountId: ByteArray): CompletableFuture<CitizenAccountBalance> =
        request({ native.getAccountBalance(accountId.requireSize(32, "accountId")) }) {
            (it as CitizenSdkNativeResult.Balance).value
        }

    fun getAccountNonce(accountId: ByteArray): CompletableFuture<CitizenAccountNonce> =
        request({ native.getAccountNonce(accountId.requireSize(32, "accountId")) }) {
            (it as CitizenSdkNativeResult.Nonce).value
        }

    fun getFeeSnapshot(): CompletableFuture<CitizenFeeSnapshot> =
        request({ native.getFeeSnapshot() }) { (it as CitizenSdkNativeResult.Fee).value }

    fun getWalletProfile(): CompletableFuture<CitizenWalletProfile?> =
        request({ native.getWalletProfile() }) { (it as CitizenSdkNativeResult.Profile).value }

    fun setActiveWalletAccount(accountId: ByteArray): CompletableFuture<CitizenWalletProfile> =
        walletMutation {
            request({ native.setActiveWalletAccount(accountId.requireSize(32, "accountId")) }) {
                requireWalletProfile(it, "set active wallet account")
            }
        }

    fun renameWalletAccount(accountId: ByteArray, name: String): CompletableFuture<CitizenWalletProfile> {
        CitizenSdkInputLimits.requireWalletAccountNameInput(name)
        require(name.codePoints().noneMatch { value ->
            value in 0x00..0x1f || value in 0x7f..0x9f
        }) { "wallet account name must not contain control characters" }
        val normalized = name.trim()
        require(normalized.codePointCount(0, normalized.length) in 1..30) {
            "wallet account name must contain 1..30 Unicode scalars"
        }
        return walletMutation {
            request({
                native.renameWalletAccount(accountId.requireSize(32, "accountId"), normalized)
            }) {
                requireWalletProfile(it, "rename wallet account")
            }
        }
    }

    /** Atomically returns the post-delete profile under the process mutation gate. */
    fun deleteWalletAccount(accountId: ByteArray): CompletableFuture<CitizenWalletProfile?> =
        walletMutationWithProfile {
            native.deleteWalletAccount(accountId.requireSize(32, "accountId"))
        }

    /** Returns `null` only after Core deletion and the same gated profile read complete. */
    fun deleteWallet(): CompletableFuture<CitizenWalletProfile?> =
        walletMutationWithProfile { native.deleteWallet() }

    /** Returns the post-reconciliation profile without a host-side query window. */
    fun reconcileWalletCleanup(): CompletableFuture<CitizenWalletProfile?> =
        walletMutationWithProfile { native.reconcileWalletCleanup() }

    fun signWalletPayload(accountId: ByteArray, message: ByteArray): CompletableFuture<CitizenSignature> {
        CitizenSdkInputLimits.requireSignPayload(message.size)
        return request({
            native.signWalletPayload(accountId.requireSize(32, "accountId"), message.clone())
        }) { (it as CitizenSdkNativeResult.Signature).value }
    }

    fun transferWithRemark(
        sourceAccountId: ByteArray,
        destinationAccountId: ByteArray,
        amountFen: CitizenU128,
        remark: ByteArray,
    ): CompletableFuture<CitizenWalletTransfer> {
        CitizenSdkInputLimits.requirePositiveTransferAmount(amountFen)
        CitizenSdkInputLimits.requireTransferRemark(remark.size)
        return request({
            native.transferWithRemark(
                sourceAccountId.requireSize(32, "sourceAccountId"),
                destinationAccountId.requireSize(32, "destinationAccountId"),
                amountFen,
                remark.clone(),
            )
        }) { (it as CitizenSdkNativeResult.Transfer).value }
    }

    /**
     * Progress-aware form used by Flutter and native hosts that need exact
     * pre-registered correlation. The listener is never called after the
     * operation future reaches a terminal state.
     */
    fun transferWithRemarkOperation(
        sourceAccountId: ByteArray,
        destinationAccountId: ByteArray,
        amountFen: CitizenU128,
        remark: ByteArray,
        progressListener: CitizenSdkEvents.TransferProgressListener,
    ): CitizenSdkOperation<CitizenWalletTransfer> {
        CitizenSdkInputLimits.requirePositiveTransferAmount(amountFen)
        CitizenSdkInputLimits.requireTransferRemark(remark.size)
        return synchronized(lifecycleGate) {
            requireOpen()
            requests.submitOperation(
                begin = {
                    native.transferWithRemark(
                        sourceAccountId.requireSize(32, "sourceAccountId"),
                        destinationAccountId.requireSize(32, "destinationAccountId"),
                        amountFen,
                        remark.clone(),
                    )
                },
                decode = { (it as CitizenSdkNativeResult.Transfer).value },
                progressListener = progressListener,
            )
        }
    }

    fun initializeFinalizedHistory(
        accountIds: List<ByteArray>,
    ): CompletableFuture<CitizenTransactionHistory> = request({
        native.initializeFinalizedHistory(validateAccountIds(accountIds))
    }) { (it as CitizenSdkNativeResult.History).value }

    fun syncFinalizedHistory(
        accountIds: List<ByteArray>,
    ): CompletableFuture<CitizenTransactionHistory> = request({
        native.syncFinalizedHistory(validateAccountIds(accountIds))
    }) { (it as CitizenSdkNativeResult.History).value }

    /** Starts a non-exported FLAG_SECURE flow; no secret is an API argument. */
    fun launchWalletFlow(
        activity: FragmentActivity,
        request: CitizenSdkWalletFlowContract.Request,
        callback: CitizenSdkWalletFlowContract.Callback,
    ): CitizenSdkWalletFlowCoordinator {
        return synchronized(lifecycleGate) {
            requireOpen()
            hostServices.attachActivity(activity)
            CitizenSdkWalletFlowCoordinator.launch(this, activity, request, callback)
        }
    }

    @JvmSynthetic
    internal fun prepareWalletCreation(wordCount: Int, password: ByteArray): CompletableFuture<CitizenSdkPreparedWallet> =
        request({
            CitizenSdkInputLimits.requireWalletSecret("password", password.size)
            native.prepareWalletCreation(wordCount, password)
        }) {
            CitizenSdkPreparedWallet.create(native, (it as CitizenSdkNativeResult.Prepared).token)
        }

    @JvmSynthetic
    internal fun importWallet(mnemonic: ByteArray, password: ByteArray): CompletableFuture<CitizenWalletProfile?> =
        walletMutation {
            request({
                CitizenSdkInputLimits.requireWalletSecret("mnemonic", mnemonic.size)
                CitizenSdkInputLimits.requireWalletSecret("password", password.size)
                native.importWallet(mnemonic, password)
            }) {
                (it as CitizenSdkNativeResult.Profile).value
            }
        }

    @JvmSynthetic
    internal fun addWalletAccounts(
        mnemonic: ByteArray,
        password: ByteArray,
        indices: IntArray,
    ): CompletableFuture<CitizenWalletProfile> = walletMutation {
        CitizenSdkInputLimits.requireAddAccountIndices(indices)
        request({
            CitizenSdkInputLimits.requireWalletSecret("mnemonic", mnemonic.size)
            CitizenSdkInputLimits.requireWalletSecret("password", password.size)
            native.addWalletAccounts(mnemonic, password, indices)
        }) {
            (it as CitizenSdkNativeResult.Accounts).value
        }.thenCompose { added ->
            if (added.size != indices.size ||
                added.map { it.index }.toSet() != indices.map(Int::toLong).toSet()
            ) {
                return@thenCompose failedFuture<CitizenWalletProfile>(
                    CitizenSdkException(
                        CitizenSdkErrorCode.INTEGRITY,
                        "add accounts result does not match the requested indices",
                    ),
                )
            }
            request({ native.getWalletProfile() }) { result ->
                val profile = requireWalletProfile(result, "add wallet accounts")
                if (added.any { addedAccount ->
                        profile.accounts.none { profileAccount ->
                            profileAccount.accountId().contentEquals(addedAccount.accountId())
                        }
                    }
                ) {
                    throw CitizenSdkException(
                        CitizenSdkErrorCode.INTEGRITY,
                        "updated wallet profile is missing an added account",
                    )
                }
                profile
            }
        }
    }

    @JvmSynthetic
    internal fun commitPreparedWallet(prepared: CitizenSdkPreparedWallet): CompletableFuture<CitizenWalletProfile?> =
        walletMutation {
            request({ prepared.commitRequest() }) { (it as CitizenSdkNativeResult.Profile).value }
        }

    @JvmSynthetic
    internal fun whenActivityReady(callback: (Throwable?) -> Unit): AutoCloseable =
        hostServices.whenActivityReady {
            val convergence = synchronized(lifecycleGate) { readinessBarrierLocked() }
            convergence.whenComplete { _, failure ->
                callback(failure?.let(::unwrapCompletion))
            }
        }

    /**
     * Destroys only a checkpoint-safe Core state.
     *
     * A RUNNING instance must first complete [stop], which persists the exact
     * host checkpoint. STARTING/IMPORTING or any accepted request fails closed.
     * START_FAILED is intentionally destroyable without stop, as required by
     * the one-way imported-state failure contract. An SDK-owned wallet flow
     * must first be cancelled and reach its callback; close returns BUSY while
     * its secure Activity or managed secret buffers are still owned.
     */
    override fun close() {
        synchronized(lifecycleGate) {
            if (closed.get()) return
            if (closeActive) throw CitizenSdkException(CitizenSdkErrorCode.BUSY, "CitizenSDK close is active")
            // 不在事件回调线程等待后续事件完成；未静止时拒绝，调用方在终态后重试。
            if (readinessInFlight || readinessRetryPending) throw CitizenSdkException(
                CitizenSdkErrorCode.BUSY, "CitizenSDK capability refresh is active",
            )
            if (!closing.get()) {
                requests.requireIdle()
                CitizenSdkWalletFlowCoordinator.requireCloseReady(this)
                CitizenSdkClosePolicy.validate(native.lifecycle())
            }
            closing.set(true)
            closeActive = true
        }
        try {
            // 回调可以同步重入公开门面。屏障期间只保留 closing 状态，不占 lifecycleGate。
            native.close()
            // Core destroy 是 prepared mnemonic 清理的唯一成功依据。
            CitizenSdkWalletFlowCoordinator.onCoreDestroyed(this)
            requests.close()
            eventListener = null
            try {
                hostServices.close()
            } finally {
                // Native destruction is the irreversible commit point.
                lifecycle = CitizenSdkLifecycle.DISPOSED
                closed.set(true)
            }
        } finally {
            synchronized(lifecycleGate) { closeActive = false }
        }
    }

    private fun unitRequest(
        begin: () -> Long,
        notifyReadinessBoundary: Boolean = true,
    ): CompletableFuture<Void> {
        val source = request(begin, notifyReadinessBoundary) {
            if (it !is CitizenSdkNativeResult.Empty) throw CitizenSdkException(
                CitizenSdkErrorCode.INTEGRITY,
                "Core returned a non-empty result for an empty operation",
            )
            Unit
        }
        val target = CompletableFuture<Void>()
        source.whenComplete { _, error ->
            if (error == null) target.complete(null) else target.completeExceptionally(error)
        }
        return target
    }

    private fun readinessChanged() {
        synchronized(lifecycleGate) {
            if (closed.get() || closing.get()) return
            check(readinessDesiredGeneration != Long.MAX_VALUE) {
                "CitizenSDK readiness generation space is exhausted"
            }
            readinessDesiredGeneration += 1
            if (readinessConvergence.isDone) readinessConvergence = CompletableFuture()
            ensureReadinessRefreshLocked()
        }
    }

    /** Starts at most one refresh and preserves the newest requested edge. */
    private fun ensureReadinessRefreshLocked() {
        if (closed.get() || closing.get() || readinessInFlight ||
            readinessAppliedGeneration == readinessDesiredGeneration
        ) return
        val targetGeneration = readinessDesiredGeneration
        readinessInFlight = true
        readinessRetryPending = false
        val refresh = try {
            unitRequest({ native.refreshCapabilities() }, notifyReadinessBoundary = false)
        } catch (error: Throwable) {
            readinessInFlight = false
            handleReadinessFailureLocked(error)
            return
        }
        refresh.whenComplete { _, failure ->
            synchronized(lifecycleGate) {
                readinessInFlight = false
                if (failure == null) {
                    readinessAppliedGeneration = maxOf(readinessAppliedGeneration, targetGeneration)
                    if (readinessAppliedGeneration == readinessDesiredGeneration) {
                        readinessConvergence.complete(null)
                    } else {
                        ensureReadinessRefreshLocked()
                    }
                } else {
                    handleReadinessFailureLocked(failure)
                }
            }
        }
    }

    private fun handleReadinessFailureLocked(failure: Throwable) {
        val cause = unwrapCompletion(failure)
        if (cause is CitizenSdkException && cause.code == CitizenSdkErrorCode.BUSY) {
            readinessRetryPending = true
        } else {
            readinessConvergence.completeExceptionally(cause)
        }
    }

    private fun readinessBoundaryCompleted() {
        synchronized(lifecycleGate) {
            if (!closed.get() && readinessRetryPending) ensureReadinessRefreshLocked()
        }
    }

    private fun readinessBarrierLocked(): CompletableFuture<Void> {
        ensureReadinessRefreshLocked()
        return readinessConvergence
    }

    private fun readinessSettledLocked(): Boolean =
        !readinessInFlight && !readinessRetryPending &&
            readinessAppliedGeneration == readinessDesiredGeneration

    private fun awaitReadinessBarrier() {
        while (true) {
            val barrier = synchronized(lifecycleGate) {
                if (closed.get()) return
                readinessBarrierLocked()
            }
            try {
                barrier.get()
            } catch (error: ExecutionException) {
                throw unwrapCompletion(error)
            }
            if (synchronized(lifecycleGate) { closed.get() || readinessSettledLocked() }) return
        }
    }

    private fun exclusiveAfterReadiness(begin: () -> Long): CompletableFuture<Void> {
        val result = CompletableFuture<Void>()
        lateinit var attempt: () -> Unit
        attempt = {
            val barrier = synchronized(lifecycleGate) { readinessBarrierLocked() }
            barrier.whenComplete { _, barrierFailure ->
                if (barrierFailure != null) {
                    result.completeExceptionally(unwrapCompletion(barrierFailure))
                } else {
                    val operation = try {
                        synchronized(lifecycleGate) {
                            if (!readinessSettledLocked()) null else unitRequest(begin)
                        }
                    } catch (error: Throwable) {
                        result.completeExceptionally(error)
                        null
                    }
                    if (operation == null && !result.isDone) {
                        attempt()
                    } else {
                        operation?.whenComplete { _, error ->
                            if (error == null) result.complete(null)
                            else result.completeExceptionally(unwrapCompletion(error))
                        }
                    }
                }
            }
        }
        attempt()
        return result
    }

    private fun unwrapCompletion(error: Throwable): Throwable = when (error) {
        is CompletionException, is ExecutionException -> error.cause ?: error
        else -> error
    }

    private fun <T> request(
        begin: () -> Long,
        notifyReadinessBoundary: Boolean = true,
        decode: (CitizenSdkNativeResult) -> T,
    ): CompletableFuture<T> {
        val future = synchronized(lifecycleGate) {
            requireOpen()
            requests.submit(begin, decode)
        }
        if (notifyReadinessBoundary) future.whenComplete { _, _ -> readinessBoundaryCompleted() }
        return future
    }

    /**
     * Admits one process-wide profile mutation sequence. Concurrent sessions
     * fail BUSY instead of interleaving with add-accounts' exact profile read.
     */
    private fun <T> walletMutation(operation: () -> CompletableFuture<T>): CompletableFuture<T> {
        synchronized(walletMutationGate) {
            if (walletMutationActive) return failedFuture(
                CitizenSdkException(CitizenSdkErrorCode.BUSY, "another wallet mutation is active"),
            )
            walletMutationActive = true
        }
        val internal = try {
            operation()
        } catch (error: Throwable) {
            synchronized(walletMutationGate) { walletMutationActive = false }
            throw error
        }
        val outward = CompletableFuture<T>()
        internal.whenComplete { value, error ->
            synchronized(walletMutationGate) { walletMutationActive = false }
            if (error == null) outward.complete(value)
            else outward.completeExceptionally(unwrapCompletion(error))
        }
        return outward
    }

    /** Keeps the mutation and its resulting profile snapshot under one process gate. */
    private fun walletMutationWithProfile(
        begin: () -> Long,
    ): CompletableFuture<CitizenWalletProfile?> = walletMutation {
        unitRequest(begin).thenCompose {
            request({ native.getWalletProfile() }) {
                (it as CitizenSdkNativeResult.Profile).value
            }
        }
    }

    // 仅 SDK 安全 Activity 调用。校验和词表来自同一个 Rust Core，不向 Flutter 导出秘密参数。
    @JvmSynthetic
    internal fun validateWalletPassword(password: ByteArray) = native.validateWalletPassword(password)

    @JvmSynthetic
    internal fun validateWalletMnemonic(mnemonic: ByteArray, wordCount: Int) = native.validateWalletMnemonic(mnemonic, wordCount)

    @JvmSynthetic
    internal fun walletWordSuggestions(prefix: ByteArray): List<String> {
        val bytes = native.walletWordSuggestions(prefix)
        return try { bytes.toString(Charsets.UTF_8).split('\n').filter { it.isNotEmpty() } }
        finally { bytes.fill(0) }
    }

    private fun requireWalletProfile(
        result: CitizenSdkNativeResult,
        operation: String,
    ): CitizenWalletProfile = (result as? CitizenSdkNativeResult.Profile)?.value
        ?: throw CitizenSdkException(
            CitizenSdkErrorCode.INTEGRITY,
            "$operation returned no wallet profile",
        )

    private fun <T> failedFuture(error: Throwable): CompletableFuture<T> =
        CompletableFuture<T>().also { it.completeExceptionally(error) }

    private fun validateAccountIds(values: List<ByteArray>): Array<ByteArray> {
        CitizenSdkInputLimits.requireHistoryAccountCount(values.size)
        val validated = values.map { it.requireSize(32, "accountId") }.toTypedArray()
        CitizenSdkInputLimits.requireUniqueHistoryAccountIds(validated)
        return validated
    }

    private fun requireOpen() {
        check(!closed.get() && !closing.get()) { "CitizenSdk is closing or closed" }
    }

    companion object {
        private val walletMutationGate = Any()
        private var walletMutationActive = false

        @JvmStatic
        @JvmOverloads
        fun open(context: Context, listener: CitizenSdkEvents.Listener? = null): CitizenSdk {
            val sdk = CitizenSdk(context, listener)
            return try {
                sdk.awaitReadinessBarrier()
                sdk
            } catch (error: Throwable) {
                runCatching { sdk.close() }
                throw error
            }
        }
    }
}

/** Bounded input validation applied before every proportional clone/flatten/JNI copy. */
internal object CitizenSdkInputLimits {
    const val MAX_HISTORY_ACCOUNTS = 1990
    const val MAX_SIGN_PAYLOAD_BYTES = 16 * 1024 * 1024
    const val MAX_WALLET_SECRET_BYTES = 1024
    const val MAX_ADD_ACCOUNT_INDICES = 1989
    const val MAX_TRANSFER_REMARK_BYTES = 99
    const val MAX_WALLET_ACCOUNT_NAME_CODE_UNITS = 128

    @JvmSynthetic
    fun requireHistoryAccountCount(count: Int) {
        if (count !in 1..MAX_HISTORY_ACCOUNTS) throw CitizenSdkException(
            CitizenSdkErrorCode.INVALID_ARGUMENT,
            "history accountIds must contain 1..$MAX_HISTORY_ACCOUNTS entries",
        )
    }

    @JvmSynthetic
    fun requireUniqueHistoryAccountIds(accountIds: Array<ByteArray>) {
        val seen = HashSet<CitizenSdkAccountIdKey>(accountIds.size)
        if (accountIds.any { !seen.add(CitizenSdkAccountIdKey(it)) }) throw CitizenSdkException(
            CitizenSdkErrorCode.INVALID_ARGUMENT,
            "history accountIds must be unique",
        )
    }

    @JvmSynthetic
    fun requireSignPayload(size: Int) {
        if (size !in 0..MAX_SIGN_PAYLOAD_BYTES) throw CitizenSdkException(
            CitizenSdkErrorCode.INVALID_ARGUMENT,
            "sign payload exceeds $MAX_SIGN_PAYLOAD_BYTES bytes",
        )
    }

    @JvmSynthetic
    fun requireWalletSecret(label: String, size: Int) {
        if (size !in 0..MAX_WALLET_SECRET_BYTES) throw CitizenSdkException(
            CitizenSdkErrorCode.INVALID_ARGUMENT,
            "$label exceeds $MAX_WALLET_SECRET_BYTES UTF-8 bytes",
        )
    }

    @JvmSynthetic
    fun requireAddAccountIndices(indices: IntArray) {
        if (indices.size !in 1..MAX_ADD_ACCOUNT_INDICES) throw CitizenSdkException(
            CitizenSdkErrorCode.INVALID_ARGUMENT,
            "wallet index list must contain 1..$MAX_ADD_ACCOUNT_INDICES items",
        )
        val seen = BooleanArray(MAX_ADD_ACCOUNT_INDICES + 1)
        for (index in indices) {
            if (index !in 1..MAX_ADD_ACCOUNT_INDICES || seen[index]) throw CitizenSdkException(
                CitizenSdkErrorCode.INVALID_ARGUMENT,
                "wallet indices must be unique values in 1..$MAX_ADD_ACCOUNT_INDICES",
            )
            seen[index] = true
        }
    }

    @JvmSynthetic
    fun requireTransferRemark(size: Int) {
        if (size !in 0..MAX_TRANSFER_REMARK_BYTES) throw CitizenSdkException(
            CitizenSdkErrorCode.INVALID_ARGUMENT,
            "transfer remark exceeds $MAX_TRANSFER_REMARK_BYTES UTF-8 bytes",
        )
    }

    /** Rejects zero before request admission, authentication or JNI. */
    @JvmSynthetic
    fun requirePositiveTransferAmount(amount: CitizenU128) {
        if (amount.low == 0L && amount.high == 0L) throw CitizenSdkException(
            CitizenSdkErrorCode.INVALID_ARGUMENT,
            "transfer amount must be positive",
        )
    }

    @JvmSynthetic
    fun requireWalletAccountNameInput(name: String) {
        if (name.length !in 1..MAX_WALLET_ACCOUNT_NAME_CODE_UNITS) throw CitizenSdkException(
            CitizenSdkErrorCode.INVALID_ARGUMENT,
            "wallet account name input exceeds $MAX_WALLET_ACCOUNT_NAME_CODE_UNITS UTF-16 code units",
        )
    }
}

/** Content identity for public 32-byte account ids; never owns secret material. */
private class CitizenSdkAccountIdKey(private val value: ByteArray) {
    override fun equals(other: Any?): Boolean =
        other is CitizenSdkAccountIdKey && value.contentEquals(other.value)

    override fun hashCode(): Int = value.contentHashCode()
}

/** Pure, testable close-state contract shared by the facade and JVM tests. */
internal object CitizenSdkClosePolicy {
    enum class Decision { DESTROY, ALREADY_DISPOSED }

    fun validate(lifecycle: CitizenSdkLifecycle): Decision = when (lifecycle) {
        CitizenSdkLifecycle.CREATED,
        CitizenSdkLifecycle.STOPPED,
        CitizenSdkLifecycle.START_FAILED -> Decision.DESTROY
        CitizenSdkLifecycle.RUNNING -> throw CitizenSdkException(
            CitizenSdkErrorCode.INVALID_STATE,
            "A running CitizenSDK must complete stop/checkpoint before close",
        )
        CitizenSdkLifecycle.STARTING,
        CitizenSdkLifecycle.IMPORTING_STATE -> throw CitizenSdkException(
            CitizenSdkErrorCode.BUSY,
            "CitizenSDK lifecycle transition is still running",
        )
        CitizenSdkLifecycle.DISPOSED -> Decision.ALREADY_DISPOSED
    }
}
