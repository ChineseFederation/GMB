import Foundation
import XCTest
@testable import CitizenSDK

final class CitizenSDKSecureStoreTests: XCTestCase {
    func testProfileAndEncryptedSecretCASAreIsolated() throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = try CitizenSDKSecureStore(directory: directory)
        defer { store.close() }

        XCTAssertFalse(try store.walletProfileLoad().present)
        XCTAssertEqual(try store.walletProfileCAS(expected: 0, candidate: Data([1])).revision, 1)
        XCTAssertEqual(try store.walletProfileCAS(expected: 0, candidate: Data([2])).errorCode, .conflict)

        let generation = Data(repeating: 3, count: 16)
        let owner = Data(repeating: 4, count: 16)
        let account = Data(repeating: 5, count: 32)
        let secret = try store.encryptedSecretCAS(walletIndex: 0, kind: 1, generation: generation,
                                                   owner: owner, accountID: account, expected: 0,
                                                   candidate: Data([6]))
        XCTAssertEqual(secret.revision, 1)
        XCTAssertEqual(try store.encryptedSecretLoad(walletIndex: 0, kind: 1, generation: generation,
                                                      owner: owner, accountID: account).record, Data([6]))
    }

    func testGenerationTombstoneCannotBeReactivated() throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = try CitizenSDKSecureStore(directory: directory)
        defer { store.close() }
        let generation = Data(repeating: 1, count: 16)
        let provision = Data(repeating: 2, count: 16)
        XCTAssertTrue(try store.ensureGeneration(walletIndex: 0, generation: generation,
                                                 operationID: provision))
        XCTAssertFalse(try store.ensureGeneration(walletIndex: 0, generation: generation,
                                                  operationID: Data(repeating: 3, count: 16)))
        try store.retireGeneration(walletIndex: 0, generation: generation,
                                   operationID: Data(repeating: 4, count: 16))
        XCTAssertFalse(try store.isGenerationActive(walletIndex: 0, generation: generation))
        XCTAssertFalse(try store.ensureGeneration(walletIndex: 0, generation: generation,
                                                  operationID: provision))
    }

    private func temporaryDirectory() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    }
}

