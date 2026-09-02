package org.citizen.sdk

import org.citizen.sdk.ui.CitizenSdkWalletFlowContract
import org.junit.Assert.assertEquals
import org.junit.Assert.assertThrows
import org.junit.Assert.assertTrue
import org.junit.Test
import java.util.concurrent.CountDownLatch
import java.util.concurrent.atomic.AtomicInteger
import java.util.concurrent.atomic.AtomicReference

class CitizenSdkFlutterWalletFlowTest {
    @Test
    fun `wallet requests project only public choices into the sdk owned activity`() {
        val create = CitizenSdkFlutterWalletFlow.contractRequest(
            CitizenSdkFlutterCodec.Request.CreateWallet("session", 1, 24),
        ) as CitizenSdkWalletFlowContract.Request.Create
        assertEquals(24, create.wordCount)

        val imported = CitizenSdkFlutterWalletFlow.contractRequest(
            CitizenSdkFlutterCodec.Request.Empty("importWallet", "session", 2),
        )
        assertTrue(imported is CitizenSdkWalletFlowContract.Request.Import)

        val add = CitizenSdkFlutterWalletFlow.contractRequest(
            CitizenSdkFlutterCodec.Request.AddWalletAccounts("session", 3, listOf(2, 7)),
        ) as CitizenSdkWalletFlowContract.Request.AddAccounts
        assertEquals(listOf(2, 7), add.indices)
    }

    @Test
    fun `non wallet operation cannot enter the secure wallet activity`() {
        assertThrows(CitizenSdkException::class.java) {
            CitizenSdkFlutterWalletFlow.contractRequest(
                CitizenSdkFlutterCodec.Request.Account(
                    "getAccountBalance",
                    "session",
                    1,
                    ByteArray(32),
                ),
            )
        }
    }

    @Test
    fun `synchronous or concurrent completion cannot reinsert a finished flow`() {
        val cancellations = AtomicInteger()
        val registry = CitizenSdkFlutterOneShotRegistry<String, String> { cancellations.incrementAndGet() }

        val synchronous = checkNotNull(registry.reserve("synchronous"))
        assertTrue(registry.finish("synchronous", synchronous))
        registry.bind(synchronous, "already-finished-coordinator")
        assertEquals(0, registry.sizeForTest())

        val entry = checkNotNull(registry.reserve("flow"))
        val start = CountDownLatch(1)
        val threadFailure = AtomicReference<Throwable?>()
        val finishThread = Thread {
            try {
                start.await()
                registry.finish("flow", entry)
            } catch (error: Throwable) {
                threadFailure.compareAndSet(null, error)
            }
        }
        val bindThread = Thread {
            try {
                start.await()
                registry.bind(entry, "coordinator")
            } catch (error: Throwable) {
                threadFailure.compareAndSet(null, error)
            }
        }
        finishThread.start()
        bindThread.start()
        start.countDown()
        finishThread.join()
        bindThread.join()
        threadFailure.get()?.let { throw AssertionError("wallet flow race failed", it) }
        assertEquals(0, registry.sizeForTest())

        val cancelled = checkNotNull(registry.reserve("cancel-before-bind"))
        registry.cancelWhere { it == "cancel-before-bind" }
        registry.bind(cancelled, "coordinator")
        registry.cancelWhere { it == "cancel-before-bind" }
        assertEquals(1, cancellations.get())
    }
}
