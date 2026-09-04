import Foundation
import SQLite3

/// Reconstructable chain state; this database never receives wallet secrets.
internal final class CitizenSDKPublicStore: CitizenSDKSQLite {
    init(directory: URL) throws {
        try super.init(
            directory: directory,
            fileName: "public-state-v1.sqlite3",
            schema: [
                "CREATE TABLE IF NOT EXISTS singleton_records (domain INTEGER PRIMARY KEY, revision INTEGER NOT NULL, record BLOB NOT NULL)",
                "CREATE TABLE IF NOT EXISTS runtime_cache (record_key TEXT PRIMARY KEY, record BLOB NOT NULL)",
            ],
            secure: false
        )
    }

    func chainDatabaseLoad() throws -> CitizenSDKHostRecord { try loadSingleton(.chainDatabase) }
    func transactionHistoryLoad() throws -> CitizenSDKHostRecord { try loadSingleton(.transactionHistory) }

    func chainDatabaseCAS(expected: UInt64, candidate: Data) throws -> CitizenSDKHostRecord {
        try compareAndSwapSingleton(.chainDatabase, expected: expected, candidate: candidate)
    }

    func transactionHistoryCAS(expected: UInt64, candidate: Data) throws -> CitizenSDKHostRecord {
        try compareAndSwapSingleton(.transactionHistory, expected: expected, candidate: candidate)
    }

    func runtimeCacheLoad(hash: Data) throws -> CitizenSDKHostRecord {
        let key = try CitizenSDKRecordKey.blockHash(hash)
        return try read { database in
            let statement = try Self.prepare(database, "SELECT record FROM runtime_cache WHERE record_key = ?")
            defer { sqlite3_finalize(statement) }
            try Self.bind(statement, 1, key)
            if try Self.stepRowOrDone(statement) {
                return .present(.runtimeCache, revision: 0, record: Self.data(statement, 0))
            }
            return .absent(.runtimeCache)
        }
    }

    func runtimeCacheStore(hash: Data, candidate: Data) throws {
        let key = try CitizenSDKRecordKey.blockHash(hash)
        try transaction { database in
            let statement = try Self.prepare(database, "INSERT OR REPLACE INTO runtime_cache(record_key, record) VALUES(?, ?)")
            defer { sqlite3_finalize(statement) }
            try Self.bind(statement, 1, key)
            try Self.bind(statement, 2, candidate)
            guard sqlite3_step(statement) == SQLITE_DONE else { throw CitizenSDKError(.storage, "runtime cache write failed") }
        }
    }

    func runtimeCacheDelete(hash: Data) throws {
        let key = try CitizenSDKRecordKey.blockHash(hash)
        try transaction { database in
            let statement = try Self.prepare(database, "DELETE FROM runtime_cache WHERE record_key = ?")
            defer { sqlite3_finalize(statement) }
            try Self.bind(statement, 1, key)
            guard sqlite3_step(statement) == SQLITE_DONE else { throw CitizenSDKError(.storage, "runtime cache delete failed") }
        }
    }

    private func loadSingleton(_ domain: CitizenSDKHostDomain) throws -> CitizenSDKHostRecord {
        try read { database in
            let statement = try Self.prepare(database, "SELECT revision, record FROM singleton_records WHERE domain = ?")
            defer { sqlite3_finalize(statement) }
            try Self.bind(statement, 1, Int64(domain.rawValue))
            if try Self.stepRowOrDone(statement) {
                return .present(domain, revision: try Self.revision(statement, 0), record: Self.data(statement, 1))
            }
            return .absent(domain)
        }
    }

    private func compareAndSwapSingleton(_ domain: CitizenSDKHostDomain, expected: UInt64,
                                         candidate: Data) throws -> CitizenSDKHostRecord {
        guard expected < UInt64(Int64.max) else { return .failure(domain, .conflict) }
        return try transaction { database in
            let query = try Self.prepare(database, "SELECT revision FROM singleton_records WHERE domain = ?")
            defer { sqlite3_finalize(query) }
            try Self.bind(query, 1, Int64(domain.rawValue))
            let actual = try Self.stepRowOrDone(query) ? try Self.revision(query, 0) : 0
            guard actual == expected else { return .failure(domain, .conflict) }
            let next = expected + 1
            let write = try Self.prepare(database, "INSERT OR REPLACE INTO singleton_records(domain, revision, record) VALUES(?, ?, ?)")
            defer { sqlite3_finalize(write) }
            try Self.bind(write, 1, Int64(domain.rawValue))
            try Self.bind(write, 2, Int64(next))
            try Self.bind(write, 3, candidate)
            guard sqlite3_step(write) == SQLITE_DONE else { throw CitizenSDKError(.storage, "singleton CAS failed") }
            return .present(domain, revision: next, record: candidate)
        }
    }
}
