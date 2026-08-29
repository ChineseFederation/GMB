package org.citizen.sdk

import org.junit.Assert.assertEquals
import org.junit.Assert.assertThrows
import org.junit.Test

class HardwareSecretVaultTest {
    @Test
    fun `new alias is deterministic and fixed to citizensdk`() {
        val first = AndroidHardwareSecretVault.aliasFor("citizensdk:0")
        assertEquals(first, AndroidHardwareSecretVault.aliasFor("citizensdk:0"))
        assertThrows(AndroidHardwareSecretVault.VaultFailure::class.java) {
            AndroidHardwareSecretVault.aliasFor("otherproduct:0")
        }
    }

    @Test
    fun `scope format is strict`() {
        assertThrows(AndroidHardwareSecretVault.VaultFailure::class.java) {
            AndroidHardwareSecretVault.aliasFor("citizensdk:")
        }
    }
}
