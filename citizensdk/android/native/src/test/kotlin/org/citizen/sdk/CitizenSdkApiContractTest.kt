package org.citizen.sdk

import org.junit.Assert.assertNotNull
import org.junit.Assert.assertTrue
import org.junit.Assert.assertEquals
import org.junit.Assert.assertThrows
import org.junit.Test

class CitizenSdkApiContractTest {
    @Test
    fun `native facade enforces history and sign allocation boundaries`() {
        CitizenSdkInputLimits.requireHistoryAccountCount(1)
        CitizenSdkInputLimits.requireHistoryAccountCount(1990)
        CitizenSdkInputLimits.requireUniqueHistoryAccountIds(
            arrayOf(ByteArray(32) { 1 }, ByteArray(32) { 2 }),
        )
        assertEquals(
            CitizenSdkErrorCode.INVALID_ARGUMENT,
            assertThrows(CitizenSdkException::class.java) {
                CitizenSdkInputLimits.requireUniqueHistoryAccountIds(
                    arrayOf(ByteArray(32) { 1 }, ByteArray(32) { 1 }),
                )
            }.code,
        )
        assertEquals(
            CitizenSdkErrorCode.INVALID_ARGUMENT,
            assertThrows(CitizenSdkException::class.java) {
                CitizenSdkInputLimits.requireHistoryAccountCount(1991)
            }.code,
        )
        CitizenSdkInputLimits.requireSignPayload(16 * 1024 * 1024)
        CitizenSdkInputLimits.requireSignPayload(0)
        assertEquals(
            CitizenSdkErrorCode.INVALID_ARGUMENT,
            assertThrows(CitizenSdkException::class.java) {
                CitizenSdkInputLimits.requireSignPayload(16 * 1024 * 1024 + 1)
            }.code,
        )
        CitizenSdkInputLimits.requireWalletSecret("mnemonic", 1024)
        assertEquals(
            CitizenSdkErrorCode.INVALID_ARGUMENT,
            assertThrows(CitizenSdkException::class.java) {
                CitizenSdkInputLimits.requireWalletSecret("mnemonic", 1025)
            }.code,
        )
        CitizenSdkInputLimits.requireAddAccountIndices(intArrayOf(1, 1989))
        assertEquals(
            CitizenSdkErrorCode.INVALID_ARGUMENT,
            assertThrows(CitizenSdkException::class.java) {
                CitizenSdkInputLimits.requireAddAccountIndices(IntArray(1990) { 1 })
            }.code,
        )
        assertEquals(
            CitizenSdkErrorCode.INVALID_ARGUMENT,
            assertThrows(CitizenSdkException::class.java) {
                CitizenSdkInputLimits.requireAddAccountIndices(intArrayOf(1, 1))
            }.code,
        )
        CitizenSdkInputLimits.requireTransferRemark(99)
        assertEquals(
            CitizenSdkErrorCode.INVALID_ARGUMENT,
            assertThrows(CitizenSdkException::class.java) {
                CitizenSdkInputLimits.requireTransferRemark(100)
            }.code,
        )
        CitizenSdkInputLimits.requirePositiveTransferAmount(CitizenU128("1"))
        assertEquals(
            CitizenSdkErrorCode.INVALID_ARGUMENT,
            assertThrows(CitizenSdkException::class.java) {
                CitizenSdkInputLimits.requirePositiveTransferAmount(CitizenU128("0"))
            }.code,
        )
        CitizenSdkInputLimits.requireWalletAccountNameInput("x".repeat(128))
        assertEquals(
            CitizenSdkErrorCode.INVALID_ARGUMENT,
            assertThrows(CitizenSdkException::class.java) {
                CitizenSdkInputLimits.requireWalletAccountNameInput("x".repeat(129))
            }.code,
        )
        assertThrows(IllegalArgumentException::class.java) {
            CitizenU128("1".repeat(40))
        }
    }

    @Test
    fun `public facade contains no native handle getter`() {
        val type = Class.forName("org.citizen.sdk.CitizenSdk", false, javaClass.classLoader)
        val names = type.methods.map { it.name }
        assertTrue("start" in names)
        assertTrue("stop" in names)
        assertTrue("transferWithRemarkOperation" in names)
        assertTrue(names.none { it.contains("handle", ignoreCase = true) })
        assertNotNull(CitizenSdkOperation::class.java.getMethod("cancel"))
    }
}
