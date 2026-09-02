import Foundation
import XCTest
@testable import CitizenSDK
@testable import CitizenSDKFlutter

#if os(iOS)
import Flutter
#elseif os(macOS)
import FlutterMacOS
#endif

final class CitizenSDKFlutterCodecTests: XCTestCase {
    func testEveryV1MethodHasOneExactPositionalShape() throws {
        XCTAssertEqual(CitizenSdkFlutterCodec.methodChannel, "citizen/sdk/core/v1")
        XCTAssertEqual(CitizenSdkFlutterCodec.eventChannel, "citizen/sdk/events/v1")
        XCTAssertEqual(CitizenSdkFlutterCodec.version, 1)
        let exactMethods: Set<String> = [
            "open", "start", "stop", "close", "getCapabilities", "getFinalizedHead",
            "getAccountBalance", "getAccountNonce", "getFeeSnapshot", "getWalletProfile",
            "createWallet", "importWallet", "addWalletAccounts", "setActiveWalletAccount",
            "renameWalletAccount", "deleteWalletAccount", "deleteWallet",
            "reconcileWalletCleanup", "signWalletPayload", "transferWithRemark",
            "initializeFinalizedHistory", "syncFinalizedHistory",
        ]
        XCTAssertEqual(CitizenSdkFlutterCodec.methods, exactMethods)

        let version = NSNumber(value: 1)
        let sequence = NSNumber(value: 1)
        let account = "0x" + String(repeating: "11", count: 32)
        let destination = "0x" + String(repeating: "22", count: 32)
        var requests: [String: [Any?]] = ["open": [version]]
        for method in [
            "start", "stop", "close", "getCapabilities", "getFinalizedHead",
            "getFeeSnapshot", "getWalletProfile", "importWallet", "deleteWallet",
            "reconcileWalletCleanup",
        ] { requests[method] = [version, "session-1", sequence] }
        for method in [
            "getAccountBalance", "getAccountNonce", "setActiveWalletAccount", "deleteWalletAccount",
        ] { requests[method] = [version, "session-1", sequence, account] }
        requests["createWallet"] = [version, "session-1", sequence, NSNumber(value: 24)]
        requests["addWalletAccounts"] = [version, "session-1", sequence,
                                          [NSNumber(value: 1), NSNumber(value: 7)]]
        requests["renameWalletAccount"] = [version, "session-1", sequence, account, "main"]
        requests["signWalletPayload"] = [version, "session-1", sequence, account,
                                          FlutterStandardTypedData(bytes: Data([1]))]
        requests["transferWithRemark"] = [version, "session-1", sequence, account,
                                           destination, "1", "remark"]
        requests["initializeFinalizedHistory"] = [version, "session-1", sequence, [account]]
        requests["syncFinalizedHistory"] = [version, "session-1", sequence, [account]]

        XCTAssertEqual(Set(requests.keys), exactMethods)
        for (method, tuple) in requests {
            XCTAssertNoThrow(try CitizenSdkFlutterCodec.decode(method: method, arguments: tuple), method)
            XCTAssertThrowsError(try CitizenSdkFlutterCodec.decode(
                method: method, arguments: tuple + ["forbidden-extra-position"]
            ), method)
        }
    }

    func testHashDecoderRejectsUppercaseAndPreservesCorrelation() {
        let uppercase = "0x" + String(repeating: "AA", count: 32)
        XCTAssertThrowsError(try CitizenSdkFlutterCodec.decode(
            method: "getAccountBalance",
            arguments: [NSNumber(value: 1), "session-a", NSNumber(value: 7), uppercase]
        )) { error in
            guard let failure = error as? CitizenSdkFlutterCodec.ContractFailure else {
                return XCTFail("expected correlated contract failure")
            }
            XCTAssertEqual(failure.code, .invalidArgument)
            XCTAssertEqual(failure.session, "session-a")
            XCTAssertEqual(failure.sequence, 7)
        }
    }

    func testU128FailurePreservesSessionAndSequence() {
        let hash = "0x" + String(repeating: "00", count: 32)
        XCTAssertThrowsError(try CitizenSdkFlutterCodec.decode(
            method: "transferWithRemark",
            arguments: [NSNumber(value: 1), "session-b", NSNumber(value: 8), hash, hash,
                        "340282366920938463463374607431768211456", ""]
        )) { error in
            let failure = error as? CitizenSdkFlutterCodec.ContractFailure
            XCTAssertEqual(failure?.session, "session-b")
            XCTAssertEqual(failure?.sequence, 8)
            XCTAssertEqual(failure?.code, .invalidArgument)
        }
    }

    func testSessionUsesExactUtf16BoundaryWithoutNormalization() throws {
        let version = NSNumber(value: 1)
        let sequence = NSNumber(value: 1)
        let allowed = String(repeating: "😀", count: 64)
        let request = try CitizenSdkFlutterCodec.decode(
            method: "start", arguments: [version, allowed, sequence]
        )
        XCTAssertEqual(request.sessionID, allowed)
        XCTAssertThrowsError(try CitizenSdkFlutterCodec.decode(
            method: "start",
            arguments: [version, String(repeating: "😀", count: 65), sequence]
        ))

        let decomposed = String(repeating: "e\u{301}", count: 64)
        XCTAssertEqual(decomposed.utf16.count, 128)
        XCTAssertEqual(try CitizenSdkFlutterCodec.decode(
            method: "start", arguments: [version, decomposed, sequence]
        ).sessionID, decomposed)
        XCTAssertThrowsError(try CitizenSdkFlutterCodec.decode(
            method: "start", arguments: [NSNumber(value: 1.0), "session", sequence]
        ))
    }

    func testTransferTupleRequiresVerifiedFinalizedExecution() throws {
        let execution = CitizenExecution(status: .unverified, reasonOrDispatchVariant: 0,
                                         block: nil, extrinsicIndex: nil,
                                         palletIndex: nil, errorIndex: nil)
        let transfer = CitizenWalletTransfer(transactionHash: Data(repeating: 1, count: 32),
                                             resolution: .finalizedSuccess,
                                             execution: execution, poolRejectionReason: nil)
        XCTAssertThrowsError(try CitizenSdkFlutterCodec.transfer(transfer)) { error in
            XCTAssertEqual((error as? CitizenSDKError)?.code, .integrity)
        }
    }

    func testHistoryRemarkUsesStrictUtf8() throws {
        let block = try CitizenBlockRef(hash: Data(repeating: 2, count: 32),
                                        number: 1, finality: .finalized)
        let record = CitizenHistoryRecord(
            accountID: Data(repeating: 3, count: 32),
            transactionHash: Data(repeating: 4, count: 32), nonce: 0,
            destinationAccountID: Data(repeating: 5, count: 32),
            amountFen: try CitizenU128("1"), status: .pending, block: block,
            execution: nil, createdAtMillis: 1, updatedAtMillis: 1,
            remark: Data([0xff]), poolRejectionReason: nil
        )
        let history = CitizenTransactionHistory(revision: 1, cursors: [], records: [record], transfers: [])
        XCTAssertThrowsError(try CitizenSdkFlutterCodec.history(history)) { error in
            XCTAssertEqual((error as? CitizenSDKError)?.code, .integrity)
        }
    }

    func testEventVocabularyIsClosed() throws {
        XCTAssertEqual(CitizenSdkFlutterCodec.eventTypes,
                       ["lifecycleChanged", "capabilitiesChanged", "transferProgress"])
        XCTAssertNoThrow(try CitizenSdkFlutterCodec.event(
            session: "s", sequence: 1, type: "lifecycleChanged", payload: ["running"]
        ))
        XCTAssertThrowsError(try CitizenSdkFlutterCodec.event(
            session: "s", sequence: 2, type: "debug", payload: []
        ))
    }
}
