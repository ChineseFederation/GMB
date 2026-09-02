package org.citizen.sdk

import android.content.ComponentName
import android.content.pm.PackageManager
import androidx.test.core.app.ApplicationProvider
import org.citizen.sdk.ui.CitizenSdkWalletFlowActivity
import org.junit.Assert.assertFalse
import org.junit.Test

class CitizenSdkLifecycleTest {
    @Test
    @Suppress("DEPRECATION")
    fun `wallet activity is not exported`() {
        val context = ApplicationProvider.getApplicationContext<android.content.Context>()
        val info = context.packageManager.getActivityInfo(
            ComponentName(context, CitizenSdkWalletFlowActivity::class.java),
            0,
        )
        assertFalse(info.exported)
    }
}
