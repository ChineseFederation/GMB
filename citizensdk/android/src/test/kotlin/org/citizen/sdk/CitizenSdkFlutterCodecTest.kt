package org.citizen.sdk

import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertEquals
import org.junit.Assert.assertThrows
import org.junit.Test

class CitizenSdkFlutterCodecTest {
    @Test
    fun `wallet word count closure is exactly twelve eighteen twenty four`() {
        for (count in listOf(12, 18, 24)) {
            val request = CitizenSdkFlutterCodec.decode("createWallet", listOf(1, "session", 1L, count))
                as CitizenSdkFlutterCodec.Request.CreateWallet
            assertEquals(count, request.wordCount)
        }
        for (count in listOf(0, 15, 21, 30)) assertThrows(CitizenSdkFlutterCodec.ContractFailure::class.java) {
            CitizenSdkFlutterCodec.decode("createWallet", listOf(1, "session", 1L, count))
        }
    }

    @Test
    fun `v1 method and channel closure is exact`() {
        assertEquals("citizen/sdk/core/v1", CitizenSdkFlutterCodec.METHOD_CHANNEL)
        assertEquals("citizen/sdk/events/v1", CitizenSdkFlutterCodec.EVENT_CHANNEL)
        assertEquals(1, CitizenSdkFlutterCodec.PROTOCOL_VERSION)
        assertEquals(
            linkedSetOf(
                "open", "start", "stop", "close", "getCapabilities",
                "getFinalizedHead", "getAccountBalance", "getAccountNonce",
                "getFeeSnapshot", "getWalletProfile", "createWallet", "importWallet",
                "addWalletAccounts", "setActiveWalletAccount", "renameWalletAccount",
                "deleteWalletAccount", "deleteWallet", "reconcileWalletCleanup",
                "signWalletPayload", "transferWithRemark", "initializeFinalizedHistory",
                "syncFinalizedHistory",
            ),
            CitizenSdkFlutterCodec.methods,
        )
    }

    @Test
    fun `requests reject extra secret and native ownership fields`() {
        // Fixed-position tuples have no field in which any of these values can
        // be represented. Every appended value is rejected by exact length.
        for (forbidden in listOf("mnemonic", "password", "privateKey", "nativeHandle")) {
            assertThrows(CitizenSdkFlutterCodec.ContractFailure::class.java) {
                CitizenSdkFlutterCodec.decode(
                    "importWallet",
                    listOf(1, "session-1", 1L, forbidden),
                )
            }
        }
        assertThrows(CitizenSdkFlutterCodec.ContractFailure::class.java) {
            CitizenSdkFlutterCodec.decode("open", mapOf("protocolVersion" to 1))
        }
    }

    @Test
    fun `every v1 method has one exact positional request shape`() {
        val account = "0x" + "11".repeat(32)
        val destination = "0x" + "22".repeat(32)
        val requests = linkedMapOf<String, List<Any?>>()
        requests["open"] = listOf(1)
        for (method in listOf(
            "start", "stop", "close", "getCapabilities", "getFinalizedHead",
            "getFeeSnapshot", "getWalletProfile", "importWallet", "deleteWallet",
            "reconcileWalletCleanup",
        )) requests[method] = listOf(1, "session-1", 1L)
        for (method in listOf(
            "getAccountBalance", "getAccountNonce", "setActiveWalletAccount",
            "deleteWalletAccount",
        )) requests[method] = listOf(1, "session-1", 1L, account)
        requests["createWallet"] = listOf(1, "session-1", 1L, 24)
        requests["addWalletAccounts"] = listOf(1, "session-1", 1L, listOf(1, 7))
        requests["renameWalletAccount"] = listOf(1, "session-1", 1L, account, "main")
        requests["signWalletPayload"] = listOf(1, "session-1", 1L, account, byteArrayOf(1))
        requests["transferWithRemark"] =
            listOf(1, "session-1", 1L, account, destination, "1", "remark")
        requests["initializeFinalizedHistory"] = listOf(1, "session-1", 1L, listOf(account))
        requests["syncFinalizedHistory"] = listOf(1, "session-1", 1L, listOf(account))

        assertEquals(CitizenSdkFlutterCodec.methods, requests.keys)
        requests.forEach { (method, tuple) ->
            CitizenSdkFlutterCodec.decode(method, tuple)
            assertThrows(CitizenSdkFlutterCodec.ContractFailure::class.java) {
                CitizenSdkFlutterCodec.decode(method, tuple + "forbidden-extra-position")
            }
        }
    }

    @Test
    fun `account bytes decimal amount and utf8 remark are canonical`() {
        val account = "0x" + "ab".repeat(32)
        val request = CitizenSdkFlutterCodec.decode(
            "transferWithRemark",
            listOf(1, "session-1", 7L, account, "0x" + "cd".repeat(32), "100", "citizen"),
        ) as CitizenSdkFlutterCodec.Request.TransferWithRemark
        assertArrayEquals(ByteArray(32) { 0xab.toByte() }, request.sourceAccountId)
        assertEquals(account, CitizenSdkFlutterCodec.encodeHash32(request.sourceAccountId))
        assertEquals("100", request.amountFen)

        for (amount in listOf("", "00", "+1", "-1", "0")) {
            assertThrows(CitizenSdkFlutterCodec.ContractFailure::class.java) {
                CitizenSdkFlutterCodec.decode(
                    "transferWithRemark",
                    listOf(1, "session-1", 8L, account, account, amount, ""),
                )
            }
        }
        assertThrows(CitizenSdkFlutterCodec.ContractFailure::class.java) {
            CitizenSdkFlutterCodec.decode(
                "transferWithRemark",
                listOf(1, "session-1", 9L, account, account, "1", "旅".repeat(34)),
            )
        }
    }

    @Test
    fun `empty signing payload and normalized account name match the Dart encoder`() {
        val account = "0x" + "11".repeat(32)
        val signing = CitizenSdkFlutterCodec.decode(
            "signWalletPayload",
            listOf(1, "session-1", 10L, account, byteArrayOf()),
        ) as CitizenSdkFlutterCodec.Request.SignWalletPayload
        assertEquals(0, signing.payload.size)

        val rename = CitizenSdkFlutterCodec.decode(
            "renameWalletAccount",
            listOf(1, "session-1", 11L, account, "旅行钱包"),
        ) as CitizenSdkFlutterCodec.Request.RenameWalletAccount
        assertEquals("旅行钱包", rename.name)

        for (invalidName in listOf(" 旅行钱包", "旅行钱包 ", "钱包\u001c")) {
            assertThrows(CitizenSdkFlutterCodec.ContractFailure::class.java) {
                CitizenSdkFlutterCodec.decode(
                    "renameWalletAccount",
                    listOf(1, "session-1", 12L, account, invalidName),
                )
            }
        }
        assertThrows(CitizenSdkFlutterCodec.ContractFailure::class.java) {
            CitizenSdkFlutterCodec.decode(
                "addWalletAccounts",
                listOf(1, "session-1", 13L, listOf(0)),
            )
        }
    }

    @Test
    fun `request resource limits are enforced before projection copies`() {
        val account = "0x" + "11".repeat(32)
        assertThrows(CitizenSdkFlutterCodec.ContractFailure::class.java) {
            CitizenSdkFlutterCodec.decode(
                "signWalletPayload",
                listOf(
                    1,
                    "session-1",
                    14L,
                    account,
                    ByteArray(CitizenSdkFlutterCodec.MAXIMUM_SIGNING_PAYLOAD_BYTES + 1),
                ),
            )
        }

        val tooManyAccounts = List(CitizenSdkFlutterCodec.MAXIMUM_HISTORY_ACCOUNTS + 1) {
            account
        }
        assertThrows(CitizenSdkFlutterCodec.ContractFailure::class.java) {
            CitizenSdkFlutterCodec.decode(
                "syncFinalizedHistory",
                listOf(1, "session-1", 15L, tooManyAccounts),
            )
        }

        val tooManyIndices = List(
            CitizenSdkFlutterCodec.MAXIMUM_ADDITIONAL_WALLET_ACCOUNTS + 1,
        ) { 1 }
        assertThrows(CitizenSdkFlutterCodec.ContractFailure::class.java) {
            CitizenSdkFlutterCodec.decode(
                "addWalletAccounts",
                listOf(1, "session-1", 16L, tooManyIndices),
            )
        }
        for (request in listOf(
            listOf(1, "session-1", 17L, account, account, "1", "x".repeat(100)),
            listOf(
                1,
                "session-1",
                18L,
                account,
                account,
                "340282366920938463463374607431768211456",
                "",
            ),
        )) {
            val failure = assertThrows(CitizenSdkFlutterCodec.ContractFailure::class.java) {
                CitizenSdkFlutterCodec.decode("transferWithRemark", request)
            }
            assertEquals("invalidArgument", failure.stableName)
        }
    }

    @Test
    fun `response event and error envelopes expose only public v1 fields`() {
        val response = CitizenSdkFlutterCodec.response(
            "session-1",
            4,
            listOf(ByteArray(64)),
        )
        assertEquals(4, response.size)
        assertEquals(listOf(1, "session-1", 4L), response.take(3))

        val event = CitizenSdkFlutterCodec.event(
            "session-1",
            2,
            "lifecycleChanged",
            listOf("running"),
        )
        assertEquals(5, event.size)
        assertEquals(listOf(1, "session-1", 2L, "lifecycleChanged"), event.take(4))
        assertThrows(IllegalArgumentException::class.java) {
            CitizenSdkFlutterCodec.event("session-1", 3, "debug", emptyList())
        }

        val details = CitizenSdkFlutterCodec.errorDetails(
            CitizenSdkErrorCode.INVALID_ARGUMENT,
            "invalid",
            "session-1",
            4,
        )
        assertEquals(listOf(1, "session-1", 4L, 1, "invalid"), details)
    }
}
