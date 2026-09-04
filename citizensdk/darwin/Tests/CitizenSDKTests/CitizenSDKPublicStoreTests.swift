import Foundation
import SQLite3
import XCTest
@testable import CitizenSDK

final class CitizenSDKPublicStoreTests: XCTestCase {
    func testMalformedPersistentRevisionFailsWithoutTrappingOrWriting() throws {
        // A numeric-looking TEXT literal is converted by this column's SQLite
        // INTEGER affinity, so use non-numeric TEXT to preserve the malformed
        // storage class that the decoder must reject.
        for literal in ["-1", "0", "1.5", "'broken'"] {
            let directory = temporaryDirectory()
            defer { try? FileManager.default.removeItem(at: directory) }
            let store = try CitizenSDKPublicStore(directory: directory)
            store.close()
            try corruptRevision(directory.appendingPathComponent("public-state-v1.sqlite3"),
                                "INSERT INTO singleton_records(domain, revision, record) VALUES(1, \(literal), X'01')")
            let reopened = try CitizenSDKPublicStore(directory: directory)
            XCTAssertThrowsError(try reopened.chainDatabaseLoad(), literal)
            XCTAssertThrowsError(try reopened.chainDatabaseCAS(expected: 0, candidate: Data([2])), literal)
            reopened.close()
        }
    }
    func testHostNamespacesDoNotShareChainOrHistoryState() throws {
        let support = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: support) }
        let firstRoot = try CitizenSDKHostBridge.storageRoot(applicationSupport: support, applicationID: "org.example.first")
        let secondRoot = try CitizenSDKHostBridge.storageRoot(applicationSupport: support, applicationID: "org.example.second")
        let first = try CitizenSDKPublicStore(directory: firstRoot.appendingPathComponent("public"))
        let second = try CitizenSDKPublicStore(directory: secondRoot.appendingPathComponent("public"))
        defer { first.close(); second.close() }
        _ = try first.chainDatabaseCAS(expected: 0, candidate: Data([1]))
        _ = try first.transactionHistoryCAS(expected: 0, candidate: Data([2]))
        XCTAssertFalse(try second.chainDatabaseLoad().present)
        XCTAssertFalse(try second.transactionHistoryLoad().present)
        _ = try second.chainDatabaseCAS(expected: 0, candidate: Data([3]))
        XCTAssertEqual(try first.chainDatabaseLoad().record, Data([1]))
        XCTAssertEqual(try second.chainDatabaseLoad().record, Data([3]))
    }

    func testSingletonCASAndRuntimeCacheRoundTrip() throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = try CitizenSDKPublicStore(directory: directory)
        defer { store.close() }

        XCTAssertFalse(try store.chainDatabaseLoad().present)
        let first = try store.chainDatabaseCAS(expected: 0, candidate: Data([1, 2]))
        XCTAssertEqual(first.revision, 1)
        XCTAssertEqual(first.record, Data([1, 2]))
        XCTAssertEqual(try store.chainDatabaseCAS(expected: 0, candidate: Data([3])).errorCode, .conflict)

        let hash = Data(repeating: 4, count: 32)
        try store.runtimeCacheStore(hash: hash, candidate: Data([5]))
        XCTAssertEqual(try store.runtimeCacheLoad(hash: hash).record, Data([5]))
        try store.runtimeCacheDelete(hash: hash)
        XCTAssertFalse(try store.runtimeCacheLoad(hash: hash).present)
    }

    func testSQLiteFailureCodesNeverMeanAbsent() throws {
        for code in [SQLITE_BUSY, SQLITE_ERROR, SQLITE_CORRUPT] {
            XCTAssertThrowsError(try CitizenSDKSQLite.classifyStepCode(code)) { error in
                XCTAssertEqual((error as? CitizenSDKError)?.code, .storage)
            }
        }
        XCTAssertTrue(try CitizenSDKSQLite.classifyStepCode(SQLITE_ROW))
        XCTAssertFalse(try CitizenSDKSQLite.classifyStepCode(SQLITE_DONE))
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
