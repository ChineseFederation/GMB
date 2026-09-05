import XCTest
@testable import CitizenSDK

private final class CitizenSDKWalletRegistryProbe: @unchecked Sendable { }

final class CitizenSDKWalletFlowTests: XCTestCase {
    func testOptionalPasswordUsesSameValidationForBothApplePresenters() {
        for request in [CitizenSDKWalletFlowRequest.create(wordCount: 12), .importWallet, .addAccounts(indices: [1])] {
            XCTAssertNoThrow(try CitizenSDKWalletInput.validatePassword(""))
            XCTAssertFalse(CitizenSDKWalletInput.requiresRiskConfirmation(password: "", request: request))
        }
        XCTAssertThrowsError(try CitizenSDKWalletInput.validatePassword("x"))
        XCTAssertNoThrow(try CitizenSDKWalletInput.validatePassword("abcdef"))
        XCTAssertTrue(CitizenSDKWalletInput.requiresRiskConfirmation(password: "abcdef", request: .create(wordCount: 24)))
        XCTAssertTrue(CitizenSDKWalletInput.requiresRiskConfirmation(password: "abcdef", request: .importWallet))
        XCTAssertFalse(CitizenSDKWalletInput.requiresRiskConfirmation(password: "abcdef", request: .addAccounts(indices: [1])))
    }

    func testRequestValidationRunsBeforePresentation() {
        XCTAssertNoThrow(try citizenSDKValidateWalletFlowRequest(.create(wordCount: 12)))
        XCTAssertNoThrow(try citizenSDKValidateWalletFlowRequest(.create(wordCount: 24)))
        XCTAssertNoThrow(try citizenSDKValidateWalletFlowRequest(.create(wordCount: 18)))
        XCTAssertThrowsError(try citizenSDKValidateWalletFlowRequest(.create(wordCount: 15)))
        XCTAssertThrowsError(try citizenSDKValidateWalletFlowRequest(.create(wordCount: 21)))
        XCTAssertThrowsError(try citizenSDKValidateWalletFlowRequest(.addAccounts(indices: [])))
        XCTAssertThrowsError(try citizenSDKValidateWalletFlowRequest(.addAccounts(indices: [1, 1])))
        XCTAssertNoThrow(try citizenSDKValidateWalletFlowRequest(.addAccounts(indices: [1, 1_989])))
    }

    func testCancellationDoesNotRelabelIrreversibleFailure() throws {
        let failure = CitizenSDKError(.storage, "fixture failure")
        let irreversible = try XCTUnwrap(citizenSDKCancellationResult(
            cancelRequested: true, irreversible: true, error: failure
        ))
        if case let .failed(error) = irreversible {
            XCTAssertEqual(error, failure)
        } else {
            XCTFail("irreversible failure must remain failed")
        }

        let reversible = try XCTUnwrap(citizenSDKCancellationResult(
            cancelRequested: true, irreversible: false, error: failure
        ))
        if case .cancelled = reversible { } else { XCTFail("reversible work may cancel") }
        XCTAssertNil(citizenSDKCancellationResult(cancelRequested: false,
                                                   irreversible: true, error: failure))
    }

    func testPreparedCancellationRequiresConfirmedRelease() {
        if case .cancelled = citizenSDKPreparedCancellationResult(release: { }) { }
        else { XCTFail("successful release must complete cancellation") }

        let result = citizenSDKPreparedCancellationResult {
            throw CitizenSDKError(.storage, "release fixture failed")
        }
        if case let .failed(error) = result {
            XCTAssertEqual(error.code, .storage)
        } else {
            XCTFail("failed release must not be reported as cancelled")
        }
    }

    func testWalletAndCloseAdmissionAreOneAtomicStateMachine() throws {
        let registry = CitizenSDKWalletFlowRegistry()
        let sdk = CitizenSDKWalletRegistryProbe()
        registry.registerOpen(sdk)
        XCTAssertEqual(registry.status(sdk), .open)

        let wallet = try registry.reserve(sdk)
        XCTAssertEqual(registry.status(sdk), .owned)
        registry.finish(sdk, token: UUID())
        XCTAssertEqual(registry.status(sdk), .owned, "a stale UI token must not release ownership")
        XCTAssertThrowsError(try registry.beginClose(sdk)) { error in
            XCTAssertEqual((error as? CitizenSDKError)?.code, .busy)
        }
        registry.finish(sdk, token: wallet)

        let close = try XCTUnwrap(registry.beginClose(sdk))
        XCTAssertEqual(registry.status(sdk), .closing)
        XCTAssertThrowsError(try registry.beginClose(sdk)) { error in
            XCTAssertEqual((error as? CitizenSDKError)?.code, .busy)
        }
        XCTAssertThrowsError(try registry.reserve(sdk)) { error in
            XCTAssertEqual((error as? CitizenSDKError)?.code, .busy)
        }
        registry.commitClosed(sdk, reservation: close)
        XCTAssertEqual(registry.status(sdk), .closed)
        XCTAssertNil(try registry.beginClose(sdk))
        XCTAssertThrowsError(try registry.reserve(sdk)) { error in
            XCTAssertEqual((error as? CitizenSDKError)?.code, .invalidState)
        }

        registry.forget(sdk)
        XCTAssertNil(registry.status(sdk))
    }

    func testCloseFailureRollsBackOnlyBeforeABITeardownStarts() throws {
        let registry = CitizenSDKWalletFlowRegistry()
        let sdk = CitizenSDKWalletRegistryProbe()
        registry.registerOpen(sdk)

        let preTeardown = try XCTUnwrap(registry.beginClose(sdk))
        XCTAssertFalse(registry.failClose(sdk, reservation: preTeardown, teardownStarted: false))
        XCTAssertEqual(registry.status(sdk), .open)
        let wallet = try registry.reserve(sdk)
        registry.finish(sdk, token: wallet)

        let partialTeardown = try XCTUnwrap(registry.beginClose(sdk))
        XCTAssertFalse(registry.failClose(sdk, reservation: preTeardown, teardownStarted: false),
                       "a stale close token must not alter a newer attempt")
        XCTAssertEqual(registry.status(sdk), .closing)
        XCTAssertTrue(registry.failClose(sdk, reservation: partialTeardown, teardownStarted: true))
        XCTAssertEqual(registry.status(sdk), .closing)
        XCTAssertThrowsError(try registry.reserve(sdk))

        let retry = try XCTUnwrap(registry.beginClose(sdk))
        XCTAssertFalse(registry.failClose(sdk, reservation: retry, teardownStarted: false),
                       "a retry inherited from persistent closing must stay fail-closed")
        XCTAssertEqual(registry.status(sdk), .closing)
        let finalRetry = try XCTUnwrap(registry.beginClose(sdk))
        registry.commitClosed(sdk, reservation: finalRetry)
        XCTAssertEqual(registry.status(sdk), .closed)
    }

    func testSupervisedPreTeardownFailureStaysClosingBetweenRetries() throws {
        let registry = CitizenSDKWalletFlowRegistry()
        let sdk = CitizenSDKWalletRegistryProbe()
        registry.registerOpen(sdk)

        let supervised = try XCTUnwrap(registry.beginClose(sdk, origin: .supervised))
        XCTAssertFalse(registry.failClose(sdk, reservation: supervised, teardownStarted: false),
                       "the existing supervisor owns retry; no second handoff is needed")
        XCTAssertEqual(registry.status(sdk), .closing)
        XCTAssertThrowsError(try registry.reserve(sdk)) { error in
            XCTAssertEqual((error as? CitizenSDKError)?.code, .busy)
        }

        let retry = try XCTUnwrap(registry.beginClose(sdk, origin: .supervised))
        registry.commitClosed(sdk, reservation: retry)
        XCTAssertEqual(registry.status(sdk), .closed)
    }

    func testConcurrentWalletReserveCannotEnterClosePreflightWindow() throws {
        let registry = CitizenSDKWalletFlowRegistry()
        let sdk = CitizenSDKWalletRegistryProbe()
        registry.registerOpen(sdk)
        let closeReserved = DispatchSemaphore(value: 0)
        let permitFailure = DispatchSemaphore(value: 0)
        let closeFinished = DispatchSemaphore(value: 0)

        DispatchQueue.global(qos: .userInitiated).async {
            let reservation = try? registry.beginClose(sdk)
            closeReserved.signal()
            permitFailure.wait()
            if let reservation {
                _ = registry.failClose(sdk, reservation: reservation, teardownStarted: false)
            }
            closeFinished.signal()
        }

        XCTAssertEqual(closeReserved.wait(timeout: .now() + 1), .success)
        XCTAssertEqual(registry.status(sdk), .closing)
        XCTAssertThrowsError(try registry.beginClose(sdk)) { error in
            XCTAssertEqual((error as? CitizenSDKError)?.code, .busy)
        }
        XCTAssertThrowsError(try registry.reserve(sdk)) { error in
            XCTAssertEqual((error as? CitizenSDKError)?.code, .busy)
        }
        permitFailure.signal()
        XCTAssertEqual(closeFinished.wait(timeout: .now() + 1), .success)
        XCTAssertEqual(registry.status(sdk), .open)

        let wallet = try registry.reserve(sdk)
        registry.finish(sdk, token: wallet)
        XCTAssertEqual(registry.status(sdk), .open)
    }
}
