package org.citizen.sdk

import androidx.test.core.app.ApplicationProvider
import org.citizen.sdk.internal.CitizenSdkHardwareVault
import org.citizen.sdk.internal.CitizenSdkSecureStore
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File

class CitizenSdkHardwareVaultTest {
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

