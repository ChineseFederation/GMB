@file:kotlin.jvm.JvmSynthetic

package org.citizen.sdk.internal

import android.content.Context
import androidx.fragment.app.FragmentActivity
import org.citizen.sdk.CitizenSdkErrorCode
import java.io.File
import java.nio.ByteBuffer
import java.util.concurrent.atomic.AtomicBoolean

/** Private JNI target for five typed stores and the KEK/DEK vault. */
internal class CitizenSdkHostServices(context: Context) : AutoCloseable {
    private val closed = AtomicBoolean(false)
    private val root = File(context.noBackupFilesDir, "citizensdk/v1")
    private val publicStore = CitizenSdkPublicStore(File(root, "public"))
    private val secureStore = CitizenSdkSecureStore(File(root, "secure"))
    private val vault = CitizenSdkHardwareVault(context, secureStore)

    fun attachActivity(activity: FragmentActivity) = vault.attachActivity(activity)
    fun detachActivity(activity: FragmentActivity) = vault.detachActivity(activity)
    fun whenActivityReady(callback: () -> Unit): AutoCloseable = vault.whenActivityReady(callback)
    fun setActivityReadinessListener(listener: (() -> Unit)?) = vault.setReadinessListener(listener)

    @Suppress("unused")
    fun chainDatabaseLoad(): CitizenSdkHostRecord = protect(CitizenSdkHostDomain.CHAIN_DATABASE) {
        publicStore.chainDatabaseLoad()
    }

    @Suppress("unused")
    fun chainDatabaseCompareAndSwap(expectedRevision: Long, candidate: ByteArray): CitizenSdkHostRecord =
        protect(CitizenSdkHostDomain.CHAIN_DATABASE) {
            publicStore.chainDatabaseCompareAndSwap(expectedRevision, candidate)
        }

    @Suppress("unused")
    fun runtimeCacheLoad(blockHash: ByteArray): CitizenSdkHostRecord =
        protect(CitizenSdkHostDomain.RUNTIME_CACHE) { publicStore.runtimeCacheLoad(blockHash) }

    @Suppress("unused")
    fun runtimeCacheStore(blockHash: ByteArray, candidate: ByteArray): Int = status {
        publicStore.runtimeCacheStore(blockHash, candidate)
    }

    @Suppress("unused")
    fun runtimeCacheDelete(blockHash: ByteArray): Int = status {
        publicStore.runtimeCacheDelete(blockHash)
    }

    @Suppress("unused")
    fun transactionHistoryLoad(): CitizenSdkHostRecord =
        protect(CitizenSdkHostDomain.TRANSACTION_HISTORY) { publicStore.transactionHistoryLoad() }

    @Suppress("unused")
    fun transactionHistoryCompareAndSwap(expectedRevision: Long, candidate: ByteArray): CitizenSdkHostRecord =
        protect(CitizenSdkHostDomain.TRANSACTION_HISTORY) {
            publicStore.transactionHistoryCompareAndSwap(expectedRevision, candidate)
        }

    @Suppress("unused")
    fun walletProfileLoad(): CitizenSdkHostRecord =
        protect(CitizenSdkHostDomain.WALLET_PROFILE) { secureStore.walletProfileLoad() }

    @Suppress("unused")
    fun walletProfileCompareAndSwap(expectedRevision: Long, candidate: ByteArray): CitizenSdkHostRecord =
        protect(CitizenSdkHostDomain.WALLET_PROFILE) {
            secureStore.walletProfileCompareAndSwap(expectedRevision, candidate)
        }

    @Suppress("unused")
    fun encryptedSecretLoad(
        walletIndex: Int,
        kind: Int,
        generation: ByteArray,
        owner: ByteArray,
        accountId: ByteArray,
    ): CitizenSdkHostRecord = protect(CitizenSdkHostDomain.ENCRYPTED_SECRET_BLOB) {
        secureStore.encryptedSecretLoad(walletIndex, kind, generation, owner, accountId)
    }

    @Suppress("unused")
    fun encryptedSecretCompareAndSwap(
        walletIndex: Int,
        kind: Int,
        generation: ByteArray,
        owner: ByteArray,
        accountId: ByteArray,
        expectedRevision: Long,
        candidate: ByteArray,
    ): CitizenSdkHostRecord = protect(CitizenSdkHostDomain.ENCRYPTED_SECRET_BLOB) {
        secureStore.encryptedSecretCompareAndSwap(
            walletIndex,
            kind,
            generation,
            owner,
            accountId,
            expectedRevision,
            candidate,
        )
    }

    @Suppress("unused")
    fun vaultAvailability(): Int = vault.availability()

    @Suppress("unused")
    fun ensureWalletKek(
        walletIndex: Int,
        generation: ByteArray,
        provisioningOperationId: ByteArray,
    ): Int = status { vault.ensureWalletKek(walletIndex, generation, provisioningOperationId) }

    @Suppress("unused")
    fun hasWalletKek(walletIndex: Int, generation: ByteArray): Boolean =
        vault.hasWalletKek(walletIndex, generation)

    @Suppress("unused")
    fun wrapDek(
        walletIndex: Int,
        generation: ByteArray,
        provisioningOperationId: ByteArray,
        plaintextDek: ByteBuffer,
    ): ByteArray = vault.wrapDek(walletIndex, generation, provisioningOperationId, plaintextDek)

    @Suppress("unused")
    fun unwrapDek(
        nativeBridge: Long,
        hostOperationId: Long,
        walletIndex: Int,
        generation: ByteArray,
        wrappedDek: ByteArray,
        plaintextDekOut: ByteBuffer,
    ): Int = try {
        vault.unwrapDek(walletIndex, generation, wrappedDek, plaintextDekOut) { errorCode ->
            CitizenSdkNative.completeVaultUnwrap(nativeBridge, hostOperationId, errorCode)
        }
        CitizenSdkErrorCode.OK.value
    } catch (error: CitizenSdkHardwareVault.VaultFailure) {
        error.code.value
    } catch (_: Throwable) {
        CitizenSdkErrorCode.INTERNAL.value
    }

    @Suppress("unused")
    fun retireWalletKek(
        walletIndex: Int,
        generation: ByteArray,
        cleanupOperationId: ByteArray,
    ): Int = status { vault.retireWalletKek(walletIndex, generation, cleanupOperationId) }

    override fun close() {
        if (!closed.compareAndSet(false, true)) return
        vault.setReadinessListener(null)
        val publicFailure = runCatching { publicStore.close() }.exceptionOrNull()
        val secureFailure = runCatching { secureStore.close() }.exceptionOrNull()
        when {
            publicFailure != null -> {
                if (secureFailure != null) publicFailure.addSuppressed(secureFailure)
                throw publicFailure
            }
            secureFailure != null -> throw secureFailure
        }
    }

    private inline fun protect(domain: Int, block: () -> CitizenSdkHostRecord): CitizenSdkHostRecord =
        try {
            block()
        } catch (_: Throwable) {
            CitizenSdkHostRecord.failure(domain, CitizenSdkErrorCode.STORAGE.value)
        }

    private inline fun status(block: () -> Unit): Int = try {
        block()
        CitizenSdkErrorCode.OK.value
    } catch (error: CitizenSdkHardwareVault.VaultFailure) {
        error.code.value
    } catch (_: Throwable) {
        CitizenSdkErrorCode.STORAGE.value
    }
}
