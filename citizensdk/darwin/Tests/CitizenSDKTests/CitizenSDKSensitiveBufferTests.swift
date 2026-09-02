import Foundation
import XCTest
@testable import CitizenSDK

final class CitizenSDKSensitiveBufferTests: XCTestCase {
    func testControlledBufferCopiesAndClearsBeforeTerminalCallback() {
        let first = CitizenSDKSensitiveBuffer(data: Data([1, 2, 3]))
        let second = CitizenSDKSensitiveBuffer(data: Data([4, 5, 6]))
        XCTAssertEqual(first.copyData(), Data([1, 2, 3]))
        XCTAssertFalse(first.isClearedForTesting)

        var callbackObservedClear = false
        citizenSDKAfterClearingSecrets([first, second]) {
            callbackObservedClear = first.isClearedForTesting && second.isClearedForTesting
        }

        XCTAssertTrue(callbackObservedClear)
    }

    func testSensitiveTextRejectsOversizedUtf8() {
        XCTAssertThrowsError(try citizenSDKSensitiveText(String(repeating: "a", count: 1_025),
                                                         label: "password"))
    }
}

