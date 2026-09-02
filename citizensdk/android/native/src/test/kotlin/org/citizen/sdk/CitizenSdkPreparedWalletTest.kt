package org.citizen.sdk

import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertThrows
import org.junit.Assert.assertTrue
import org.junit.Test
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicReference
import kotlin.concurrent.thread

class CitizenSdkPreparedWalletTest {
    @Test
    fun `recovery phrase takes ownership and clears caller buffer`() {
        val input = "alpha beta gamma".toByteArray()
        val phrase = CitizenSdkRecoveryPhrase.create(input)
        assertArrayEquals(ByteArray(input.size), input)
        phrase.useCharacters { chars -> assertEquals("alpha beta gamma", chars.toString()) }
        phrase.close()
    }

    @Test
    fun `prepared release failure restores ownership for exact retry`() {
        val ownership = CitizenSdkPreparedOwnership()
        var attempts = 0
        assertThrows(IllegalStateException::class.java) {
            ownership.release {
                attempts += 1
                throw IllegalStateException("release rejected")
            }
        }
        assertFalse(ownership.isConsumed())
        assertEquals(
            CitizenSdkPreparedReleaseStatus.TERMINAL,
            ownership.release { attempts += 1 },
        )
        assertTrue(ownership.isConsumed())
        assertEquals(2, attempts)
        ownership.release { attempts += 1 }
        assertEquals(2, attempts)
    }

    @Test
    fun `concurrent release in progress never clears retry ownership`() {
        val ownership = CitizenSdkPreparedOwnership()
        val entered = CountDownLatch(1)
        val resume = CountDownLatch(1)
        val failure = AtomicReference<Throwable?>()
        val first = thread {
            try {
                ownership.release {
                    entered.countDown()
                    resume.await(1, TimeUnit.SECONDS)
                    throw IllegalStateException("release rejected")
                }
            } catch (error: Throwable) {
                failure.set(error)
            }
        }
        assertTrue(entered.await(1, TimeUnit.SECONDS))
        assertEquals(
            CitizenSdkPreparedReleaseStatus.IN_PROGRESS,
            ownership.release { error("must not run a concurrent release") },
        )
        resume.countDown()
        first.join()
        assertTrue(failure.get() is IllegalStateException)
        assertFalse(ownership.isConsumed())
        assertEquals(
            CitizenSdkPreparedReleaseStatus.TERMINAL,
            ownership.release { },
        )
    }

    @Test
    fun `release cannot clear owner while commit is still settling`() {
        val ownership = CitizenSdkPreparedOwnership()
        val entered = CountDownLatch(1)
        val resume = CountDownLatch(1)
        val failure = AtomicReference<Throwable?>()
        val commit = thread {
            try {
                ownership.consume<Unit> {
                    entered.countDown()
                    resume.await(1, TimeUnit.SECONDS)
                    throw IllegalStateException("commit rejected")
                }
            } catch (error: Throwable) {
                failure.set(error)
            }
        }
        assertTrue(entered.await(1, TimeUnit.SECONDS))
        assertEquals(
            CitizenSdkPreparedReleaseStatus.IN_PROGRESS,
            ownership.release { error("must not release during commit") },
        )
        resume.countDown()
        commit.join()
        assertTrue(failure.get() is IllegalStateException)
        assertFalse(ownership.isConsumed())
        assertEquals(
            CitizenSdkPreparedReleaseStatus.TERMINAL,
            ownership.release { },
        )
    }
}
