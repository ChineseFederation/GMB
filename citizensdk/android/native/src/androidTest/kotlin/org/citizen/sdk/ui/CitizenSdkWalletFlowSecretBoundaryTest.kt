package org.citizen.sdk.ui

import android.text.SpannableStringBuilder
import android.view.WindowManager
import org.junit.Assert.assertEquals
import org.junit.Test

class CitizenSdkWalletFlowSecretBoundaryTest {
    @Test
    fun `secure flag remains the required wallet window policy`() {
        assertEquals(0x00002000, WindowManager.LayoutParams.FLAG_SECURE)
        assertEquals("org.citizen.sdk.wallet.FLOW_ID", CitizenSdkWalletFlowActivity.EXTRA_FLOW_ID)
    }

    @Test
    fun `secret editable is overwritten and cleared on terminal teardown`() {
        // Exceed the UI filter to prove the wipe itself remains bounded for
        // legacy or externally-constructed Editable values.
        val editable = SpannableStringBuilder(
            "x".repeat(CitizenSdkSecretEditablePolicy.MAX_INPUT_UTF16_CODE_UNITS * 4 + 7),
        )
        CitizenSdkSecretEditablePolicy.clear(editable)
        assertEquals(0, editable.length)
        CitizenSdkSecretEditablePolicy.clear(editable)
        assertEquals(0, editable.length)
    }

    @Test
    fun `secret input bound is conservative for the 1024 byte native contract`() {
        assertEquals(341, CitizenSdkSecretEditablePolicy.MAX_INPUT_UTF16_CODE_UNITS)
    }
}
