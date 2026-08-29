package org.citizen.sdk

import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertThrows
import org.junit.Test

class VaultEnvelopeTest {
    @Test
    fun `parser preserves stable version one envelope`() {
        val wrappedKey = ByteArray(256) { (it and 0xff).toByte() }
        val iv = ByteArray(12) { (it + 1).toByte() }
        val body = ByteArray(17) { (it + 2).toByte() }
        val raw = ByteArray(1 + 2 + wrappedKey.size + iv.size + body.size)
        raw[0] = 1
        raw[1] = 1
        raw[2] = 0
        wrappedKey.copyInto(raw, 3)
        iv.copyInto(raw, 3 + wrappedKey.size)
        body.copyInto(raw, 3 + wrappedKey.size + iv.size)

        val parsed = AndroidHardwareSecretVault.parseEnvelope(raw)
        assertArrayEquals(wrappedKey, parsed.wrappedKey)
        assertArrayEquals(iv, parsed.iv)
        assertArrayEquals(body, parsed.body)

        raw[0] = 2
        assertThrows(AndroidHardwareSecretVault.VaultFailure::class.java) {
            AndroidHardwareSecretVault.parseEnvelope(raw)
        }
        parsed.clear()
        assertArrayEquals(ByteArray(256), parsed.wrappedKey)
        assertArrayEquals(ByteArray(12), parsed.iv)
        assertArrayEquals(ByteArray(17), parsed.body)
    }
}
