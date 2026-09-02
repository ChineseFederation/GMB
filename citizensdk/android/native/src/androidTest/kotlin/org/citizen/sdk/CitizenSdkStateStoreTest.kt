package org.citizen.sdk

import androidx.test.core.app.ApplicationProvider
import org.citizen.sdk.internal.CitizenSdkPublicStore
import org.citizen.sdk.internal.CitizenSdkSecureStore
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File

class CitizenSdkStateStoreTest {
    @Test
    fun `chain state CAS returns exact durable revision`() {
        val context = ApplicationProvider.getApplicationContext<android.content.Context>()
        val directory = File(context.noBackupFilesDir, "citizensdk-test/public-${System.nanoTime()}")
        CitizenSdkPublicStore(directory).use { store ->
            assertFalse(store.chainDatabaseLoad().present)
            val first = store.chainDatabaseCompareAndSwap(0, byteArrayOf(1, 2, 3))
            assertTrue(first.present)
            assertEquals(1L, first.revision)
            assertEquals(8, store.chainDatabaseCompareAndSwap(0, byteArrayOf(4)).errorCode)
        }
    }

    @Test
    fun `retired generation cannot be resurrected or rebound`() {
        val context = ApplicationProvider.getApplicationContext<android.content.Context>()
        val directory = File(context.noBackupFilesDir, "citizensdk-test/secure-${System.nanoTime()}")
        val generation = ByteArray(16) { 1 }
        val provisioning = ByteArray(16) { 2 }
        CitizenSdkSecureStore(directory).use { store ->
            assertTrue(store.ensureGeneration(0, generation, provisioning))
            assertFalse(store.ensureGeneration(0, generation, ByteArray(16) { 3 }))
            store.retireGeneration(0, generation, ByteArray(16) { 4 })
            assertFalse(store.ensureGeneration(0, generation, provisioning))
        }
    }
}
