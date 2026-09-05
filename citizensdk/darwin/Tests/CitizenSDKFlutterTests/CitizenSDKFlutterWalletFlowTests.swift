import XCTest
@testable import CitizenSDK
@testable import CitizenSDKFlutter

@MainActor
final class CitizenSDKFlutterWalletFlowTests: XCTestCase {
    func testFlutterRequestsMapOnlyToSdkOwnedWalletFlows() throws {
        for count: UInt32 in [12, 18, 24] {
            XCTAssertEqual(
                try CitizenSdkFlutterWalletFlow.contract(for: .create(session: "s", sequence: 1, wordCount: count)),
                .create(wordCount: count)
            )
        }
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
