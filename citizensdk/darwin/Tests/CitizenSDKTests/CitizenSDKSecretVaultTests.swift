import Foundation
import XCTest
@testable import CitizenSDK

final class CitizenSDKSecretVaultTests: XCTestCase {
    func testAcceptedOwnerCopiesExactDekThenCompletes() throws {
        let output = UnsafeMutableRawPointer.allocate(byteCount: 32, alignment: 16)
        defer { output.deallocate() }
        output.initializeMemory(as: UInt8.self, repeating: 0, count: 32)
        var releaseCount = 0
        var completionCount = 0
        let owner = CitizenSDKAcceptedVaultOperation(
            output: UnsafeMutableRawBufferPointer(start: output, count: 32),
            releasePending: { releaseCount += 1 },
            completion: { code in
                XCTAssertEqual(code, .ok)
                completionCount += 1
            }
        )
        let input = Data((0..<32).map(UInt8.init))
        try input.withUnsafeBytes { try owner.copyDEK($0) }
        owner.finish(.ok)
        owner.finish(.internalFailure)

        XCTAssertEqual(Data(bytes: output, count: 32), input)
        XCTAssertEqual(releaseCount, 1)
        XCTAssertEqual(completionCount, 1)
    }

    func testHardwareAvailabilityProbeIsFinite() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = try CitizenSDKSecureStore(directory: directory)
        defer { store.close() }
        let value = CitizenSDKSecretVault(secureStore: store).availability()
        XCTAssertTrue([.available, .noStrongUserAuthentication, .unsupported, .unavailable].contains(value))
    }

    /// Secure Enclave key creation, biometric prompt outcome and this-device-
    /// only Keychain persistence are executed only by the canonical real-device
    /// fixture; simulators must never claim that hardware coverage.
    func testSimulatorDoesNotClaimSecureEnclaveHardware() throws {
        #if targetEnvironment(simulator)
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = try CitizenSDKSecureStore(directory: directory)
        defer { store.close() }
        XCTAssertEqual(CitizenSDKSecretVault(secureStore: store).availability(), .unsupported)
        #else
        throw XCTSkip("Hardware vault behavior is covered by the signed device fixture")
        #endif
    }
}
