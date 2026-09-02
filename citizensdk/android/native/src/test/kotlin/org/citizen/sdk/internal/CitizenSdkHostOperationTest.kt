package org.citizen.sdk.internal

import org.citizen.sdk.CitizenSdkErrorCode
import org.citizen.sdk.CitizenSdkException
import org.citizen.sdk.CitizenSdkClosePolicy
import org.citizen.sdk.CitizenSdkLifecycle
import org.citizen.sdk.ui.CitizenSdkWalletFlowAttachmentPolicy
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertThrows
import org.junit.Assert.assertTrue
import org.junit.Test
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit
import java.nio.ByteBuffer
import java.nio.ByteOrder
import kotlin.concurrent.thread

class CitizenSdkHostOperationTest {
    @Test
    fun `claimed wallet Activity cannot cross a concurrent terminal boundary`() {
        assertTrue(
            CitizenSdkWalletFlowAttachmentPolicy.canClaim(
                completionStarted = false,
                finished = false,
                terminalKnown = false,
                claimPending = false,
            ),
        )
        assertFalse(
            CitizenSdkWalletFlowAttachmentPolicy.canClaim(
                completionStarted = false,
                finished = false,
                terminalKnown = false,
                claimPending = true,
            ),
        )
        assertTrue(
            CitizenSdkWalletFlowAttachmentPolicy.finishWithoutContent(
                completionStarted = true,
                finished = false,
                terminalKnown = false,
            ),
        )
    }

    @Test
    fun `wallet secret encoding is bounded before proportional allocation`() {
        CitizenSdkSensitiveBytes.utf8("a".repeat(1024)).use { value ->
            assertEquals(1024, value.size)
        }
        assertEquals(
            CitizenSdkErrorCode.INVALID_ARGUMENT,
            assertThrows(CitizenSdkException::class.java) {
                CitizenSdkSensitiveBytes.utf8("a".repeat(1025))
            }.code,
        )
    }

    @Test
    fun `malformed UTF-8 and unknown errors fail as integrity`() {
        val malformedText = ByteBuffer.allocate(4 * 4 + 1)
            .order(ByteOrder.LITTLE_ENDIAN)
            .putInt(1)
            .putInt(CitizenSdkErrorCode.INVALID_ARGUMENT.value)
            .putInt(0)
            .putInt(1)
            .put(0xc3.toByte())
            .array()
        assertEquals(
            CitizenSdkErrorCode.INTEGRITY,
            assertThrows(CitizenSdkException::class.java) {
                CitizenSdkNativeCodec.decode(malformedText)
            }.code,
        )
        listOf(-1, 23, Int.MAX_VALUE).forEach { unknown ->
            val wire = ByteBuffer.allocate(4 * 4)
                .order(ByteOrder.LITTLE_ENDIAN)
                .putInt(1)
                .putInt(unknown)
                .putInt(0)
                .putInt(0)
                .array()
            assertEquals(
                CitizenSdkErrorCode.INTEGRITY,
                assertThrows(CitizenSdkException::class.java) {
                    CitizenSdkNativeCodec.decode(wire)
                }.code,
            )
        }
        assertEquals(
            CitizenSdkErrorCode.INTEGRITY,
            assertThrows(CitizenSdkException::class.java) {
                CitizenSdkNativeCodec.decodeCapabilities(ByteArray(4))
            }.code,
        )
    }

    @Test
    fun `wallet accounts kind remains distinct from wallet profile`() {
        val wire = ByteBuffer.allocate(4 * 6 + 32 + 4 + 1 + 1 + 8 + 1)
            .order(ByteOrder.LITTLE_ENDIAN)
            .putInt(1) // wire version
            .putInt(0) // error
            .putInt(13) // WALLET_ACCOUNTS
            .putInt(0) // error message length
            .putInt(1) // account count
            .putInt(1) // derivation index
            .put(ByteArray(32) { 7 })
            .putInt(1)
            .put('x'.code.toByte())
            .put(0.toByte()) // no name
            .putLong(9)
            .put(0.toByte()) // add result has no active account projection
            .array()
        val result = CitizenSdkNativeCodec.decode(wire).result
        assertTrue(result is CitizenSdkNativeResult.Accounts)
        assertEquals(1L, (result as CitizenSdkNativeResult.Accounts).value.single().index)
    }

    @Test
    fun `watch codec preserves full unsigned u32 peer count`() {
        val wire = ByteBuffer.allocate(4 + 4 + 4 + 1 + 1)
            .order(ByteOrder.LITTLE_ENDIAN)
            .putInt(1)
            .putInt(1)
            .putInt(-1)
            .put(0.toByte())
            .put(0.toByte())
            .array()
        assertEquals(4_294_967_295L, CitizenSdkNativeCodec.decodeWatch(wire).peerCount)
    }

    @Test
    fun `close policy requires a completed stop checkpoint`() {
        assertEquals(
            CitizenSdkClosePolicy.Decision.DESTROY,
            CitizenSdkClosePolicy.validate(CitizenSdkLifecycle.STOPPED),
        )
        assertEquals(
            CitizenSdkErrorCode.INVALID_STATE,
            assertThrows(CitizenSdkException::class.java) {
                CitizenSdkClosePolicy.validate(CitizenSdkLifecycle.RUNNING)
            }.code,
        )
        assertEquals(
            CitizenSdkErrorCode.BUSY,
            assertThrows(CitizenSdkException::class.java) {
                CitizenSdkClosePolicy.validate(CitizenSdkLifecycle.STARTING)
            }.code,
        )
    }

    @Test
    fun `completion racing before accepting return maps by exact core id`() {
        lateinit var router: CitizenSdkRequestRouter
        router = CitizenSdkRequestRouter { true }
        val operation = router.submitOperation(
            begin = {
                router.onCompletion(41, CitizenSdkNativeCodec.Decoded(CitizenSdkNativeResult.Empty, null))
                41
            },
            decode = { "done" },
            progressListener = null,
        )
        assertEquals("done", operation.future.get(1, TimeUnit.SECONDS))
        assertFalse(operation.cancel())
        router.requireIdle()
    }

    @Test
    fun `cancel remains in admission gate and never completes future locally`() {
        val entered = CountDownLatch(1)
        val release = CountDownLatch(1)
        val router = CitizenSdkRequestRouter { requestId ->
            assertEquals(9L, requestId)
            entered.countDown()
            release.await(1, TimeUnit.SECONDS)
            true
        }
        val operation = router.submitOperation(
            begin = { 9 },
            decode = { Unit },
            progressListener = null,
        )
        val cancelThread = thread { assertTrue(operation.cancel()) }
        assertTrue(entered.await(1, TimeUnit.SECONDS))
        assertThrows(CitizenSdkException::class.java) { router.requireIdle() }.also {
            assertEquals(CitizenSdkErrorCode.BUSY, it.code)
        }
        assertFalse(operation.future.isDone)
        release.countDown()
        cancelThread.join()
        router.onCompletion(
            9,
            CitizenSdkNativeCodec.Decoded(
                null,
                CitizenSdkException(CitizenSdkErrorCode.CANCELLED, "cancelled"),
            ),
        )
        assertTrue(operation.future.isCompletedExceptionally)
        router.requireIdle()
    }
}
