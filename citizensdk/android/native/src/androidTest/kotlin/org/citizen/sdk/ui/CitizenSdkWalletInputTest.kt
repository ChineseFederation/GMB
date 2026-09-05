package org.citizen.sdk.ui

import androidx.test.core.app.ApplicationProvider
import org.citizen.sdk.CitizenSdk
import org.citizen.sdk.CitizenSdkException
import org.citizen.sdk.internal.CitizenSdkSensitiveBytes
import org.junit.Assert.*
import org.junit.Test

class CitizenSdkWalletInputTest {
    @Test fun `only twelve eighteen twenty four are accepted`() {
        for (count in listOf(12, 18, 24)) assertEquals(count, CitizenSdkWalletFlowContract.Request.Create(count).wordCount)
        for (count in listOf(0, 15, 21, 30)) assertThrows(IllegalArgumentException::class.java) {
            CitizenSdkWalletFlowContract.Request.Create(count)
        }
    }

    @Test fun `next account uses maximum and explicit indices are validated`() {
        assertArrayEquals(intArrayOf(8), CitizenSdkWalletInputPolicy.nextIndex(listOf(0, 7, 2)))
        assertArrayEquals(intArrayOf(1, 7, 1989), CitizenSdkWalletInputPolicy.indices("1，7 1989"))
        assertThrows(IllegalArgumentException::class.java) { CitizenSdkWalletInputPolicy.nextIndex(listOf(1989)) }
        for (text in listOf("", "0", "1990", "1,1")) assertThrows(IllegalArgumentException::class.java) {
            CitizenSdkWalletInputPolicy.indices(text)
        }
    }

    @Test fun `JNI calls actual Core password mnemonic and word list contracts`() {
        val sdk = CitizenSdk.open(ApplicationProvider.getApplicationContext())
        try {
            CitizenSdkSensitiveBytes.empty().use { sdk.validateWalletPassword(it) }
            CitizenSdkSensitiveBytes.utf8("abcdef").use { sdk.validateWalletPassword(it) }
            assertThrows(CitizenSdkException::class.java) {
                CitizenSdkSensitiveBytes.utf8("abcde").use { sdk.validateWalletPassword(it) }
            }
            assertEquals(listOf("abandon"), CitizenSdkSensitiveBytes.utf8("aban").use { sdk.walletWordSuggestions(it) })
            // BIP39 公开全零熵向量，仅用于边界验证。
            for ((count, checksum) in listOf(12 to "about", 18 to "agent", 24 to "art")) {
                val phrase = (List(count - 1) { "abandon" } + checksum).joinToString(" ")
                CitizenSdkSensitiveBytes.utf8(phrase).use { sdk.validateWalletMnemonic(it, count) }
                assertThrows(CitizenSdkException::class.java) {
                    CitizenSdkSensitiveBytes.utf8(phrase).use { sdk.validateWalletMnemonic(it, 15) }
                }
            }
        } finally { sdk.close() }
    }

    @Test fun `completion is anchored to caret and preserves subsequent words`() {
        val text = "aban absent ability"
        assertEquals(0 to 4, CitizenSdkWalletInputPolicy.completionRange(text, 4, 4))
        assertEquals(5 to 11, CitizenSdkWalletInputPolicy.completionRange(text, 7, 7))
        assertNull(CitizenSdkWalletInputPolicy.completionRange(text, 5, 5))
        assertNull(CitizenSdkWalletInputPolicy.completionRange(text, 0, 4))
    }
}
