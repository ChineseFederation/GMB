package org.citizen.sdk.ui

import org.citizen.sdk.CitizenSdkErrorCode
import org.citizen.sdk.CitizenSdkException
import org.junit.Assert.assertSame
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertThrows
import org.junit.Assert.assertTrue
import org.junit.Test

class CitizenSdkWalletFlowCancellationTest {
    @Test
    fun `wallet flow defaults and derivation indices match Core`() {
        assertEquals(12, CitizenSdkWalletFlowContract.Request.Create().wordCount)
        assertThrows(IllegalArgumentException::class.java) {
            CitizenSdkWalletFlowContract.Request.AddAccounts(listOf(0))
        }
        assertThrows(IllegalArgumentException::class.java) {
            CitizenSdkWalletFlowContract.Request.AddAccounts(List(1990) { 1 })
        }
        assertEquals(
            listOf(1, 1989),
            CitizenSdkWalletFlowContract.Request.AddAccounts(listOf(1, 1989)).indices,
        )
    }

    @Test
    fun `cancelled result is a secret-free singleton`() {
        assertSame(
            CitizenSdkWalletFlowContract.Result.Cancelled,
            CitizenSdkWalletFlowContract.Result.Cancelled,
        )
    }

    @Test
    fun `accepted irreversible mutation cannot be reported as cancelled`() {
        assertEquals(
            CitizenSdkWalletFlowTerminalPolicy.CancellationDecision.FINISH_CANCELLED,
            CitizenSdkWalletFlowTerminalPolicy.cancellation(irreversibleAccepted = false),
        )
        assertEquals(
            CitizenSdkWalletFlowTerminalPolicy.CancellationDecision.WAIT_FOR_MUTATION,
            CitizenSdkWalletFlowTerminalPolicy.cancellation(irreversibleAccepted = true),
        )
        assertEquals(
            CitizenSdkWalletFlowTerminalPolicy.CancellationDecision.WAIT_FOR_MUTATION,
            CitizenSdkWalletFlowTerminalPolicy.cancellation(
                irreversibleAccepted = false,
                preparationInFlight = true,
            ),
        )
        assertEquals(
            true,
            CitizenSdkWalletFlowTerminalPolicy.awaitRecreation(
                configurationChange = true,
                detachCancellation = false,
            ),
        )
        assertEquals(
            false,
            CitizenSdkWalletFlowTerminalPolicy.awaitRecreation(
                configurationChange = true,
                detachCancellation = true,
            ),
        )
        assertEquals(
            true,
            CitizenSdkWalletFlowTerminalPolicy.releasePrepared(
                CitizenSdkWalletFlowContract.Result.Failed(
                    CitizenSdkException(CitizenSdkErrorCode.BUSY, "process wallet gate is busy"),
                ),
            ),
        )
        assertEquals(250L, CitizenSdkPreparedCleanupPolicy.delayMillis(0))
        assertEquals(30_000L, CitizenSdkPreparedCleanupPolicy.delayMillis(7))
        assertEquals(30_000L, CitizenSdkPreparedCleanupPolicy.delayMillis(Int.MAX_VALUE))
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
                completionStarted = true,
                finished = false,
                terminalKnown = false,
                claimPending = false,
            ),
        )
        assertTrue(
            CitizenSdkWalletFlowAttachmentPolicy.finishWithoutContent(
                completionStarted = true,
                finished = false,
                terminalKnown = false,
            ),
        )
        assertFalse(
            CitizenSdkWalletFlowAttachmentPolicy.finishWithoutContent(
                completionStarted = true,
                finished = false,
                terminalKnown = true,
            ),
        )
        CitizenSdkWalletFlowClosePolicy.validate(activeFlow = false)
        val closeBusy = assertThrows(CitizenSdkException::class.java) {
            CitizenSdkWalletFlowClosePolicy.validate(activeFlow = true)
        }
        assertEquals(CitizenSdkErrorCode.BUSY, closeBusy.code)

        val retention = CitizenSdkCleanupRetention<Any>()
        val owner = Any()
        retention.retain(7, owner)
        retention.retain(7, owner) // repeated release failures retain the same owner
        assertEquals(true, retention.owns(7, owner))
        assertEquals(true, retention.contains(7))
        assertEquals(listOf(owner), retention.snapshot())
        assertThrows(IllegalStateException::class.java) {
            retention.retain(7, Any())
        }
        assertEquals(false, retention.resolve(7, Any()))
        assertEquals(true, retention.owns(7, owner))
        assertEquals(true, retention.resolve(7, owner))
        assertEquals(false, retention.owns(7, owner))
        assertEquals(false, retention.contains(7))
        assertTrue(retention.snapshot().isEmpty())
    }
}
