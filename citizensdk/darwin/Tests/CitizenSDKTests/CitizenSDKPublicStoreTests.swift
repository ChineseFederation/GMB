import Foundation
import SQLite3
import XCTest
@testable import CitizenSDK

final class CitizenSDKPublicStoreTests: XCTestCase {
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
}
