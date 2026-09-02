import Foundation
import XCTest
@testable import CitizenSDK

final class CitizenSDKApiContractTests: XCTestCase {
    func testU128CanonicalBoundary() throws {
        XCTAssertEqual(try CitizenU128("0").decimal, "0")
        XCTAssertEqual(
            try CitizenU128("340282366920938463463374607431768211455").decimal,
            "340282366920938463463374607431768211455"
        )
        XCTAssertThrowsError(try CitizenU128("01"))
        XCTAssertThrowsError(try CitizenU128("340282366920938463463374607431768211456"))
    }

    func testBlockIdentityRequiresExactlyThirtyTwoBytes() throws {
        XCTAssertNoThrow(try CitizenBlockRef(hash: Data(repeating: 1, count: 32),
                                              number: 7, finality: .finalized))
        XCTAssertThrowsError(try CitizenBlockRef(hash: Data(repeating: 1, count: 31),
                                                 number: 7, finality: .finalized))
    }

    func testCapabilityVocabularyRemainsComplete() {
        XCTAssertEqual(CitizenCapabilityName.allCases.map(\.rawValue), (1...10).map(UInt32.init))
        XCTAssertEqual(CitizenSDKErrorCode.allCases.map(\.rawValue), (0...22).map(Int32.init))
    }
}
