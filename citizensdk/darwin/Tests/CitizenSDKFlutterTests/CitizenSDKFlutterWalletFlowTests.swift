import XCTest
@testable import CitizenSDK
@testable import CitizenSDKFlutter

@MainActor
final class CitizenSDKFlutterWalletFlowTests: XCTestCase {
    func testFlutterRequestsMapOnlyToSdkOwnedWalletFlows() throws {
        XCTAssertEqual(
            try CitizenSdkFlutterWalletFlow.contract(for: .create(session: "s", sequence: 1, wordCount: 12)),
            .create(wordCount: 12)
        )
        XCTAssertEqual(
            try CitizenSdkFlutterWalletFlow.contract(for: .empty(method: "importWallet", session: "s", sequence: 2)),
            .importWallet
        )
        XCTAssertEqual(
            try CitizenSdkFlutterWalletFlow.contract(for: .addAccounts(session: "s", sequence: 3, indices: [1, 2])),
            .addAccounts(indices: [1, 2])
        )
    }

    func testNonWalletRequestCannotOpenSecretUi() {
        XCTAssertThrowsError(try CitizenSdkFlutterWalletFlow.contract(
            for: .empty(method: "start", session: "s", sequence: 1)
        )) { error in
            XCTAssertEqual((error as? CitizenSDKError)?.code, .invalidArgument)
        }
    }
}

