package org.citizen.sdk

import androidx.test.core.app.ApplicationProvider
import org.citizen.sdk.internal.CitizenSdkHardwareVault
import org.citizen.sdk.internal.CitizenSdkSecureStore
import org.junit.Assert.assertTrue
import org.junit.Assert.assertEquals
import org.junit.Test
import java.io.File
import android.os.Looper
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicReference

class CitizenSdkHardwareVaultTest {
    @Test
    fun `vault mutation lock serializes independent stores`() {
        val context = ApplicationProvider.getApplicationContext<android.content.Context>()
        val directory = File(context.noBackupFilesDir, "citizensdk-test/lock-${System.nanoTime()}")
        try {
            CitizenSdkSecureStore(directory).use { first ->
                CitizenSdkSecureStore(directory).use { second ->
                    val entered = CountDownLatch(1)
                    val release = CountDownLatch(1)
                    val finished = CountDownLatch(1)
                    val owner = Thread {
                        first.withVaultLock {
                            entered.countDown()
                            check(release.await(2, TimeUnit.SECONDS))
                        }
                    }
                    owner.start()
                    assertTrue(entered.await(2, TimeUnit.SECONDS))
                    val waiter = Thread { second.withVaultLock { finished.countDown() } }
                    waiter.start()
                    assertTrue(!finished.await(100, TimeUnit.MILLISECONDS))
                    release.countDown()
                    assertTrue(finished.await(2, TimeUnit.SECONDS))
                    owner.join(2_000)
                    waiter.join(2_000)
                    assertTrue(!owner.isAlive && !waiter.isAlive)
                }
            }
        } finally { directory.deleteRecursively() }
    }

    @Test
    fun `Rust worker authentication dispatch reaches Android main looper`() {
        val context = ApplicationProvider.getApplicationContext<android.content.Context>()
        val directory = File(context.noBackupFilesDir, "citizensdk-test/dispatch-${System.nanoTime()}")
        try {
            CitizenSdkSecureStore(directory).use { store ->
                val vault = CitizenSdkHardwareVault(context, store)
                val completed = CountDownLatch(1)
                val actual = AtomicReference<Looper>()
                val worker = Thread {
                    vault.dispatchAuthentication {
                        actual.set(Looper.myLooper())
                        completed.countDown()
                    }
                }
                worker.start()
                worker.join()
                assertTrue(completed.await(2, TimeUnit.SECONDS))
                assertEquals(Looper.getMainLooper(), actual.get())
            }
        } finally { directory.deleteRecursively() }
    }

    @Test
    fun `device reports a stable fail-closed vault availability`() {
        val context = ApplicationProvider.getApplicationContext<android.content.Context>()
        val directory = File(context.noBackupFilesDir, "citizensdk-test/secure-${System.nanoTime()}")
        CitizenSdkSecureStore(directory).use { store ->
            val availability = CitizenSdkHardwareVault(context, store).availability()
            assertTrue(availability in 1..4)
        }
    }
}
