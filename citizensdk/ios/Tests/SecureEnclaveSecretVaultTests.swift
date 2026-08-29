import CryptoKit
import XCTest
@testable import citizen_sdk

final class SecureEnclaveSecretVaultTests: XCTestCase {
  func testTagIsDeterministicAndFixedToCitizenSdk() throws {
    let first = try SecureEnclaveSecretVault.applicationTag(scope: "citizensdk:0")
    let second = try SecureEnclaveSecretVault.applicationTag(scope: "citizensdk:0")
    XCTAssertEqual(first, second)
    XCTAssertThrowsError(
      try SecureEnclaveSecretVault.applicationTag(scope: "otherproduct:0")
    )
  }
}
