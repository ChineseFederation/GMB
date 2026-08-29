import XCTest
@testable import citizen_sdk

final class VaultEnvelopeTests: XCTestCase {
  func testStableVersionOneEnvelopeRoundTrip() throws {
    let aad = Data("GMB\ncitizensdk\n0\naccount\naccount_mini_secret".utf8)
    let plaintext = Data(repeating: 7, count: 32)
    let envelope = SecureEnclaveSecretVault.makeEnvelope(aad: aad, plaintext: plaintext)
    XCTAssertEqual(try SecureEnclaveSecretVault.parseEnvelope(aad: aad, envelope: envelope), plaintext)
    XCTAssertThrowsError(
      try SecureEnclaveSecretVault.parseEnvelope(aad: Data("wrong".utf8), envelope: envelope)
    )
  }
}
