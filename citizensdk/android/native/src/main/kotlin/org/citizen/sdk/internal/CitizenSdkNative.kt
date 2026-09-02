@file:kotlin.jvm.JvmSynthetic

package org.citizen.sdk.internal

import org.citizen.sdk.*
import java.util.concurrent.atomic.AtomicBoolean

/** One private JNI owner; no native identity is returned by a public method. */
internal class CitizenSdkNative private constructor(
    assets: CitizenSdkAssets,
    hostServices: CitizenSdkHostServices,
) : AutoCloseable {
    private val callGate = Any()
    private val closed = AtomicBoolean(false)
    private val bridge = nativeCreate(
        hostServices,
        assets.manifest,
        assets.chainSpec,
        assets.lightSyncState,
    )

    @Volatile
    private var router: CitizenSdkRequestRouter? = null

    @Volatile
    private var eventSink: ((CitizenSdkEvents.Event) -> Unit)? = null

    fun bind(router: CitizenSdkRequestRouter, eventSink: (CitizenSdkEvents.Event) -> Unit) {
        check(this.router == null) { "native callback is already bound" }
        this.router = router
        this.eventSink = eventSink
        router.bindEventPublisher(eventSink)
        try {
            call { nativeBind(it) }
        } catch (error: Throwable) {
            this.router = null
            this.eventSink = null
            router.bindEventPublisher {}
            throw error
        }
    }

    fun lifecycle(): CitizenSdkLifecycle = call { lifecycleFromValue(nativeLifecycle(it)) }
    fun capabilities(): CitizenSdkCapabilities = call {
        CitizenSdkNativeCodec.decodeCapabilities(nativeCapabilities(it))
    }
    fun refreshCapabilities(): Long = call { nativeRefreshCapabilities(it) }
    fun start(): Long = call { nativeStart(it) }
    fun stop(): Long = call { nativeStop(it) }
    fun cancel(coreRequestId: Long): Boolean = call { nativeCancel(it, coreRequestId) }
    fun getFinalizedHead(): Long = call { nativeGetFinalizedHead(it) }
    fun getAccountBalance(accountId: ByteArray): Long = call { nativeGetAccountBalance(it, accountId) }
    fun getAccountNonce(accountId: ByteArray): Long = call { nativeGetAccountNonce(it, accountId) }
    fun getFeeSnapshot(): Long = call { nativeGetFeeSnapshot(it) }
    fun getWalletProfile(): Long = call { nativeGetWalletProfile(it) }
    fun setActiveWalletAccount(accountId: ByteArray): Long = call { nativeSetActiveWalletAccount(it, accountId) }
    fun renameWalletAccount(accountId: ByteArray, name: String): Long =
        call { nativeRenameWalletAccount(it, accountId, name.toByteArray(Charsets.UTF_8)) }
    fun deleteWalletAccount(accountId: ByteArray): Long = call { nativeDeleteWalletAccount(it, accountId) }
    fun deleteWallet(): Long = call { nativeDeleteWallet(it) }
    fun reconcileWalletCleanup(): Long = call { nativeReconcileWalletCleanup(it) }
    fun signWalletPayload(accountId: ByteArray, message: ByteArray): Long =
        call { nativeSignWalletPayload(it, accountId, message) }
    fun transferWithRemark(
        source: ByteArray,
        destination: ByteArray,
        amount: CitizenU128,
        remark: ByteArray,
    ): Long = call { nativeTransferWithRemark(it, source, destination, amount.low, amount.high, remark) }
    fun initializeFinalizedHistory(accountIds: Array<ByteArray>): Long =
        call { nativeInitializeFinalizedHistory(it, flattenAccounts(accountIds), accountIds.size) }
    fun syncFinalizedHistory(accountIds: Array<ByteArray>): Long =
        call { nativeSyncFinalizedHistory(it, flattenAccounts(accountIds), accountIds.size) }
    fun prepareWalletCreation(wordCount: Int, password: ByteArray): Long =
        call { nativePrepareWalletCreation(it, wordCount, password) }
    fun importWallet(mnemonic: ByteArray, password: ByteArray): Long =
        call { nativeImportWallet(it, mnemonic, password) }
    fun addWalletAccounts(mnemonic: ByteArray, password: ByteArray, indices: IntArray): Long =
        call { nativeAddWalletAccounts(it, mnemonic, password, indices) }
    fun copyPreparedMnemonic(token: Long): ByteArray = call { nativeCopyPreparedMnemonic(it, token) }
    fun commitPreparedWallet(token: Long): Long = call { nativeCommitPreparedWallet(it, token) }
    fun releasePreparedWallet(token: Long) {
        synchronized(callGate) {
            // A successful Core destroy releases every uncommitted prepared
            // wallet, so a late secure-Activity teardown is already satisfied.
            if (!closed.get()) nativeReleasePreparedWallet(bridge, token)
        }
    }

    @Suppress("unused") // Called only by citizensdk_jni.
    private fun onNativeRequestCompleted(coreRequestId: Long, encoded: ByteArray) {
        val decoded = try {
            CitizenSdkNativeCodec.decode(encoded)
        } catch (error: Throwable) {
            CitizenSdkNativeCodec.Decoded(
                result = null,
                error = CitizenSdkException(
                    CitizenSdkErrorCode.INTEGRITY,
                    "CitizenSDK returned a malformed result envelope",
                    error,
                ),
            )
        }
        router?.onCompletion(coreRequestId, decoded)
    }

    @Suppress("unused") // Called only by citizensdk_jni.
    private fun onNativeWatch(coreRequestId: Long, sequence: Long, encoded: ByteArray) {
        router?.onProgress(
            coreRequestId,
            java.lang.Long.toUnsignedString(sequence),
            CitizenSdkNativeCodec.decodeWatch(encoded),
        )
    }

    @Suppress("unused") // Called only by citizensdk_jni.
    private fun onNativeCapabilities(sequence: Long, encoded: ByteArray) {
        eventSink?.invoke(
            CitizenSdkEvents.Event.CapabilitiesChanged(
                java.lang.Long.toUnsignedString(sequence),
                CitizenSdkNativeCodec.decodeCapabilities(encoded),
            ),
        )
    }

    @Suppress("unused") // Called only by citizensdk_jni.
    private fun onNativeLifecycle(sequence: Long, lifecycle: Int) {
        eventSink?.invoke(
            CitizenSdkEvents.Event.LifecycleChanged(
                java.lang.Long.toUnsignedString(sequence),
                lifecycleFromValue(lifecycle),
            ),
        )
    }

    override fun close() {
        synchronized(callGate) {
            if (closed.get()) return
            nativeDestroy(bridge)
            closed.set(true)
            router = null
            eventSink = null
        }
    }

    /** Pins the Java-side bridge identity against concurrent destroy. */
    private inline fun <T> call(block: (Long) -> T): T = synchronized(callGate) {
        check(!closed.get()) { "CitizenSDK native bridge is closed" }
        block(bridge)
    }

    private fun flattenAccounts(values: Array<ByteArray>): ByteArray =
        ByteArray(values.size * 32).also { output ->
            values.forEachIndexed { index, value -> value.copyInto(output, index * 32) }
        }

    private fun lifecycleFromValue(value: Int): CitizenSdkLifecycle = when (value) {
        1 -> CitizenSdkLifecycle.CREATED
        2 -> CitizenSdkLifecycle.IMPORTING_STATE
        3 -> CitizenSdkLifecycle.STARTING
        4 -> CitizenSdkLifecycle.RUNNING
        5 -> CitizenSdkLifecycle.START_FAILED
        6 -> CitizenSdkLifecycle.STOPPED
        7 -> CitizenSdkLifecycle.DISPOSED
        else -> throw CitizenSdkException(CitizenSdkErrorCode.INTEGRITY, "unknown Core lifecycle $value")
    }

    private external fun nativeCreate(
        hostServices: CitizenSdkHostServices,
        manifest: ByteArray,
        chainSpec: ByteArray,
        lightSyncState: ByteArray,
    ): Long
    private external fun nativeBind(bridge: Long)
    private external fun nativeLifecycle(bridge: Long): Int
    private external fun nativeCapabilities(bridge: Long): ByteArray
    private external fun nativeRefreshCapabilities(bridge: Long): Long
    private external fun nativeStart(bridge: Long): Long
    private external fun nativeStop(bridge: Long): Long
    private external fun nativeCancel(bridge: Long, coreRequestId: Long): Boolean
    private external fun nativeGetFinalizedHead(bridge: Long): Long
    private external fun nativeGetAccountBalance(bridge: Long, accountId: ByteArray): Long
    private external fun nativeGetAccountNonce(bridge: Long, accountId: ByteArray): Long
    private external fun nativeGetFeeSnapshot(bridge: Long): Long
    private external fun nativeGetWalletProfile(bridge: Long): Long
    private external fun nativeSetActiveWalletAccount(bridge: Long, accountId: ByteArray): Long
    private external fun nativeRenameWalletAccount(bridge: Long, accountId: ByteArray, name: ByteArray): Long
    private external fun nativeDeleteWalletAccount(bridge: Long, accountId: ByteArray): Long
    private external fun nativeDeleteWallet(bridge: Long): Long
    private external fun nativeReconcileWalletCleanup(bridge: Long): Long
    private external fun nativeSignWalletPayload(bridge: Long, accountId: ByteArray, message: ByteArray): Long
    private external fun nativeTransferWithRemark(
        bridge: Long,
        source: ByteArray,
        destination: ByteArray,
        amountLow: Long,
        amountHigh: Long,
        remark: ByteArray,
    ): Long
    private external fun nativeInitializeFinalizedHistory(bridge: Long, accountIds: ByteArray, count: Int): Long
    private external fun nativeSyncFinalizedHistory(bridge: Long, accountIds: ByteArray, count: Int): Long
    private external fun nativePrepareWalletCreation(bridge: Long, wordCount: Int, password: ByteArray): Long
    private external fun nativeImportWallet(bridge: Long, mnemonic: ByteArray, password: ByteArray): Long
    private external fun nativeAddWalletAccounts(
        bridge: Long,
        mnemonic: ByteArray,
        password: ByteArray,
        indices: IntArray,
    ): Long
    private external fun nativeCopyPreparedMnemonic(bridge: Long, token: Long): ByteArray
    private external fun nativeCommitPreparedWallet(bridge: Long, token: Long): Long
    private external fun nativeReleasePreparedWallet(bridge: Long, token: Long)
    private external fun nativeDestroy(bridge: Long)

    companion object {
        init { System.loadLibrary("citizensdk_jni") }

        internal fun create(
            assets: CitizenSdkAssets,
            hostServices: CitizenSdkHostServices,
        ): CitizenSdkNative = CitizenSdkNative(assets, hostServices)

        @JvmStatic
        internal external fun completeVaultUnwrap(nativeBridge: Long, hostOperationId: Long, errorCode: Int)
    }
}
