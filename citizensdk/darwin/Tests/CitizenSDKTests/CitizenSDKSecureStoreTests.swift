import Foundation
import SQLite3
import XCTest
@testable import CitizenSDK

final class CitizenSDKSecureStoreTests: XCTestCase {
    func testVaultMutationLockSerializesIndependentStores() throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let first = try CitizenSDKSecureStore(directory: directory)
        let second = try CitizenSDKSecureStore(directory: directory)
        defer { first.close(); second.close() }
        let entered = DispatchSemaphore(value: 0)
        let release = DispatchSemaphore(value: 0)
        let finished = DispatchSemaphore(value: 0)
        DispatchQueue.global().async {
            try? first.withVaultLock {
                entered.signal()
                _ = release.wait(timeout: .now() + 2)
            }
        }
        XCTAssertEqual(entered.wait(timeout: .now() + 2), .success)
        DispatchQueue.global().async {
            _ = try? second.withVaultLock { finished.signal() }
        }
        XCTAssertEqual(finished.wait(timeout: .now() + 0.1), .timedOut)
        release.signal()
        XCTAssertEqual(finished.wait(timeout: .now() + 2), .success)
    }

    func testMalformedSecretRevisionFailsWithoutTrappingOrOverwriting() throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let generation = Data(repeating: 3, count: 16)
        let owner = Data(repeating: 4, count: 16)
        let account = Data(repeating: 5, count: 32)
        let key = try CitizenSDKRecordKey.secret(walletIndex: 0, kind: 1,
                                                  generation: generation, owner: owner,
                                                  accountID: account)
        let store = try CitizenSDKSecureStore(directory: directory)
        store.close()
        let escaped = key.replacingOccurrences(of: "'", with: "''")
        try corruptRevision(directory.appendingPathComponent("secure-state-v1.sqlite3"),
                            "INSERT INTO encrypted_secret(record_key, revision, record) VALUES('\(escaped)', -1, X'01')")
        let reopened = try CitizenSDKSecureStore(directory: directory)
        XCTAssertThrowsError(try reopened.encryptedSecretLoad(walletIndex: 0, kind: 1,
            generation: generation, owner: owner, accountID: account))
        XCTAssertThrowsError(try reopened.encryptedSecretCAS(walletIndex: 0, kind: 1,
            generation: generation, owner: owner, accountID: account, expected: 0,
            candidate: Data([2])))
        reopened.close()
    }
    func testHostNamespacesDoNotShareWalletProfileOrRetirement() throws {
        let support = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: support) }
        let firstRoot = try CitizenSDKHostBridge.storageRoot(applicationSupport: support, applicationID: "org.example.first")
        let secondRoot = try CitizenSDKHostBridge.storageRoot(applicationSupport: support, applicationID: "org.example.second")
        let first = try CitizenSDKSecureStore(directory: firstRoot.appendingPathComponent("secure"))
        let second = try CitizenSDKSecureStore(directory: secondRoot.appendingPathComponent("secure"))
        defer { first.close(); second.close() }
        _ = try first.walletProfileCAS(expected: 0, candidate: Data([1]))
        XCTAssertFalse(try second.walletProfileLoad().present)
        let generation = Data(repeating: 3, count: 16)
        let provision = Data(repeating: 4, count: 16)
        XCTAssertTrue(try first.ensureGeneration(walletIndex: 0, generation: generation, operationID: provision))
        XCTAssertTrue(try second.ensureGeneration(walletIndex: 0, generation: generation, operationID: provision))
        try first.retireGeneration(walletIndex: 0, generation: generation, operationID: Data(repeating: 5, count: 16))
        XCTAssertFalse(try first.isGenerationActive(walletIndex: 0, generation: generation))
        XCTAssertTrue(try second.isGenerationActive(walletIndex: 0, generation: generation))
    }

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

    private func corruptRevision(_ file: URL, _ sql: String) throws {
        var database: OpaquePointer?
        XCTAssertEqual(sqlite3_open_v2(file.path, &database, SQLITE_OPEN_READWRITE, nil), SQLITE_OK)
        guard let database else { return XCTFail("SQLite fixture did not open") }
        defer { sqlite3_close_v2(database) }
        XCTAssertEqual(sqlite3_exec(database, sql, nil, nil, nil), SQLITE_OK)
    }
}
