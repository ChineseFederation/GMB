@file:kotlin.jvm.JvmSynthetic

package org.citizen.sdk

import org.citizen.sdk.internal.CitizenSdkNative

/**
 * Private one-shot ownership used only by the SDK wallet UI.
 *
 * The numeric Core handle stays inside the internal native bridge. This object
 * carries only a random bridge token and releases the Rust mnemonic on every
 * uncommitted terminal path.
 */
internal class CitizenSdkPreparedWallet private constructor(
    private val native: CitizenSdkNative,
    private val token: Long,
) : AutoCloseable {
    private val ownership = CitizenSdkPreparedOwnership()

    fun openRecoveryPhrase(): CitizenSdkRecoveryPhrase {
        check(!ownership.isConsumed()) { "prepared wallet is already consumed" }
        return CitizenSdkRecoveryPhrase.create(native.copyPreparedMnemonic(token))
    }

    fun commitRequest(): Long = ownership.consume {
        native.commitPreparedWallet(token)
    }

    @JvmSynthetic
    internal fun releaseForCleanup(): CitizenSdkPreparedReleaseStatus = ownership.release {
        native.releasePreparedWallet(token)
    }

    override fun close() {
        releaseForCleanup()
    }

    companion object {
        internal fun create(native: CitizenSdkNative, token: Long): CitizenSdkPreparedWallet =
            CitizenSdkPreparedWallet(native, token)
    }
}

/**
 * Retryable one-shot state shared by commit and release.
 *
 * Native rejects do not consume the Core prepared handle. The state therefore
 * rolls back on every exception so the same owner can retry instead of losing
 * the last reference to mnemonic memory.
 */
internal class CitizenSdkPreparedOwnership {
    private val gate = Any()
    private var state = State.OPEN

    fun isConsumed(): Boolean = synchronized(gate) { state != State.OPEN }

    fun <T> consume(action: () -> T): T {
        synchronized(gate) {
            check(state == State.OPEN) { "prepared wallet is already consumed" }
            state = State.COMMITTING
        }
        return try {
            action().also { synchronized(gate) { state = State.COMMITTED } }
        } catch (error: Throwable) {
            synchronized(gate) { state = State.OPEN }
            throw error
        }
    }

    fun release(action: () -> Unit): CitizenSdkPreparedReleaseStatus {
        synchronized(gate) {
            when (state) {
                State.OPEN -> state = State.RELEASING
                State.COMMITTING,
                State.RELEASING -> return CitizenSdkPreparedReleaseStatus.IN_PROGRESS
                State.COMMITTED,
                State.RELEASED -> return CitizenSdkPreparedReleaseStatus.TERMINAL
            }
        }
        try {
            action()
            synchronized(gate) { state = State.RELEASED }
            return CitizenSdkPreparedReleaseStatus.TERMINAL
        } catch (error: Throwable) {
            synchronized(gate) { state = State.OPEN }
            throw error
        }
    }

    private enum class State { OPEN, COMMITTING, COMMITTED, RELEASING, RELEASED }
}

internal enum class CitizenSdkPreparedReleaseStatus { IN_PROGRESS, TERMINAL }
