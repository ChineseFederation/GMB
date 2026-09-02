import Foundation
import XCTest
@testable import CitizenSDK

final class CitizenSDKRecordKeyTests: XCTestCase {
    func testKeychainIdentityUsesCitizenSdkNamespaceOnly() throws {
        let tag = try XCTUnwrap(String(data: CitizenSDKRecordKey.keychainTag(
            walletIndex: 0, generation: Data(repeating: 1, count: 16)
        ), encoding: .utf8))
        XCTAssertTrue(tag.hasPrefix("citizensdk_wallet_"))
        XCTAssertFalse(tag.contains("citizenapp"))
        XCTAssertFalse(tag.contains("org.citizen.sdk"))
    }

    func testGenerationChangesKeychainIdentity() throws {
        let first = try CitizenSDKRecordKey.keychainTag(walletIndex: 0,
                                                         generation: Data(repeating: 1, count: 16))
        let second = try CitizenSDKRecordKey.keychainTag(walletIndex: 0,
                                                          generation: Data(repeating: 2, count: 16))
        XCTAssertNotEqual(first, second)
        XCTAssertEqual(first, try CitizenSDKRecordKey.keychainTag(
            walletIndex: 0, generation: Data(repeating: 1, count: 16)
        ))
    }

    func testMalformedIdentitiesFailClosed() {
        XCTAssertThrowsError(try CitizenSDKRecordKey.keychainTag(
            walletIndex: 0, generation: Data(repeating: 1, count: 15)
        ))
        XCTAssertThrowsError(try CitizenSDKRecordKey.secret(
            walletIndex: 0, kind: 1, generation: Data(repeating: 0, count: 16),
            owner: Data(repeating: 0, count: 16), accountID: Data(repeating: 0, count: 31)
        ))
    }
}

