package org.citizen.sdk

import androidx.test.core.app.ApplicationProvider
import org.junit.Assert.assertEquals
import org.junit.Test

class CitizenSdkNativeAbiTest {
    @Test
    fun `official AAR loads ABI version one Core`() {
        val sdk = CitizenSdk.open(ApplicationProvider.getApplicationContext())
        assertEquals(CitizenSdkLifecycle.CREATED, sdk.lifecycle)
        sdk.close()
    }
}

