package org.citizen.sdk

import androidx.fragment.app.FragmentActivity
import org.citizen.sdk.ui.CitizenSdkWalletFlowContract
import org.citizen.sdk.ui.CitizenSdkWalletFlowCoordinator
import java.util.concurrent.CompletableFuture
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.atomic.AtomicBoolean
import java.util.concurrent.atomic.AtomicReference

/** One-shot ownership registry whose callback may win before handle binding. */
internal class CitizenSdkFlutterOneShotRegistry<K : Any, H : Any>(
    private val cancelHandle: (H) -> Unit,
) {
    internal class Entry<H : Any> {
        val handle = AtomicReference<H?>()
        val finished = AtomicBoolean(false)
        val cancelRequested = AtomicBoolean(false)
    }

    private val entries = ConcurrentHashMap<K, Entry<H>>()

    fun reserve(key: K): Entry<H>? = Entry<H>().takeIf { entries.putIfAbsent(key, it) == null }

    fun bind(entry: Entry<H>, handle: H) {
        check(entry.handle.compareAndSet(null, handle))
        if (entry.cancelRequested.get()) cancelHandle(handle)
    }

    fun finish(key: K, entry: Entry<H>): Boolean {
        if (!entry.finished.compareAndSet(false, true)) return false
        return entries.remove(key, entry)
    }

    fun cancelWhere(predicate: (K) -> Boolean) {
        entries.entries.filter { predicate(it.key) }.forEach { (_, entry) ->
            if (entry.cancelRequested.compareAndSet(false, true)) {
                entry.handle.get()?.let(cancelHandle)
            }
        }
    }

    internal fun sizeForTest(): Int = entries.size
}

/**
 * Secret-free Flutter projection of the SDK-owned wallet Activity.
 *
 * Flutter selects only the operation, word count, or public derivation
 * indices. Recovery phrases and passwords are entered/rendered by the
 * non-exported FLAG_SECURE Activity and never enter this object.
 */
internal class CitizenSdkFlutterWalletFlow {
    private data class Key(val sessionId: String, val requestSequence: Long)
    private val active = CitizenSdkFlutterOneShotRegistry<Key, CitizenSdkWalletFlowCoordinator> {
        it.cancel()
    }

    fun launch(
        sdk: CitizenSdk,
        activity: FragmentActivity?,
        request: CitizenSdkFlutterCodec.Request.SessionRequest,
    ): CompletableFuture<CitizenWalletProfile?> {
        val host = activity ?: return failed(
            CitizenSdkException(
                CitizenSdkErrorCode.UNAVAILABLE,
                "CitizenSDK wallet UI requires a FragmentActivity",
            ),
        )
        val contract = contractRequest(request)
        val key = Key(request.sessionId, request.requestSequence)
        val completion = CompletableFuture<CitizenWalletProfile?>()
        val owner = active.reserve(key) ?: return failed(
            CitizenSdkException(CitizenSdkErrorCode.CONFLICT, "Wallet flow request already exists"),
        )
        try {
            val coordinator = sdk.launchWalletFlow(host, contract) { result ->
                if (!active.finish(key, owner)) return@launchWalletFlow
                when (result) {
                    is CitizenSdkWalletFlowContract.Result.Completed -> completion.complete(result.profile)
                    CitizenSdkWalletFlowContract.Result.Cancelled -> completion.completeExceptionally(
                        CitizenSdkException(CitizenSdkErrorCode.CANCELLED, "CitizenSDK wallet flow cancelled"),
                    )
                    is CitizenSdkWalletFlowContract.Result.Failed -> completion.completeExceptionally(result.error)
                }
            }
            active.bind(owner, coordinator)
        } catch (error: Throwable) {
            if (active.finish(key, owner)) completion.completeExceptionally(error)
        }
        return completion
    }

    /** Cancels every SDK-owned UI flow before supervised session destruction. */
    fun cancelSession(sessionId: String) {
        active.cancelWhere { it.sessionId == sessionId }
    }

    companion object {
        internal fun contractRequest(
            request: CitizenSdkFlutterCodec.Request.SessionRequest,
        ): CitizenSdkWalletFlowContract.Request = when (request) {
            is CitizenSdkFlutterCodec.Request.CreateWallet ->
                CitizenSdkWalletFlowContract.Request.Create(request.wordCount)
            is CitizenSdkFlutterCodec.Request.AddWalletAccounts ->
                CitizenSdkWalletFlowContract.Request.AddAccounts(request.indices)
            is CitizenSdkFlutterCodec.Request.Empty -> {
                require(request.method == "importWallet")
                CitizenSdkWalletFlowContract.Request.Import()
            }
            else -> throw CitizenSdkException(
                CitizenSdkErrorCode.INVALID_ARGUMENT,
                "Request is not an SDK-owned wallet flow",
            )
        }

        private fun <T> failed(error: Throwable): CompletableFuture<T> =
            CompletableFuture<T>().also { it.completeExceptionally(error) }
    }
}
