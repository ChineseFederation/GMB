package org.citizen.sdk.internal

import android.content.ContentValues
import android.database.sqlite.SQLiteDatabase
import java.io.File
import kotlin.concurrent.withLock

/** Public/reconstructable state; this database never receives wallet secrets. */
internal class CitizenSdkPublicStore(directory: File) :
    CitizenSdkSqlite(directory, "public-state-v1.sqlite3") {
    override fun createSchema(database: SQLiteDatabase) {
        database.execSQL(
            "CREATE TABLE IF NOT EXISTS singleton_records (" +
                "domain INTEGER PRIMARY KEY, revision INTEGER NOT NULL, record BLOB NOT NULL)",
        )
        database.execSQL(
            "CREATE TABLE IF NOT EXISTS runtime_cache (" +
                "record_key TEXT PRIMARY KEY, record BLOB NOT NULL)",
        )
    }

    fun chainDatabaseLoad(): CitizenSdkHostRecord =
        loadSingleton(CitizenSdkHostDomain.CHAIN_DATABASE)

    fun chainDatabaseCompareAndSwap(
        expectedRevision: Long,
        candidate: ByteArray,
    ): CitizenSdkHostRecord = compareAndSwapSingleton(
        CitizenSdkHostDomain.CHAIN_DATABASE,
        expectedRevision,
        candidate,
    )

    fun runtimeCacheLoad(blockHash: ByteArray): CitizenSdkHostRecord = lock.withLock {
        val key = CitizenSdkRecordKey.blockHash(blockHash)
        database.query(
            "runtime_cache",
            arrayOf("record"),
            "record_key = ?",
            arrayOf(key),
            null,
            null,
            null,
        ).use { cursor ->
            if (!cursor.moveToFirst()) CitizenSdkHostRecord.absent(CitizenSdkHostDomain.RUNTIME_CACHE)
            else CitizenSdkHostRecord.present(
                CitizenSdkHostDomain.RUNTIME_CACHE,
                0,
                cursor.getBlob(0),
            )
        }
    }

    fun runtimeCacheStore(blockHash: ByteArray, candidate: ByteArray) = transaction { db ->
        val values = ContentValues().apply {
            put("record_key", CitizenSdkRecordKey.blockHash(blockHash))
            put("record", candidate.clone())
        }
        check(db.insertWithOnConflict("runtime_cache", null, values, SQLiteDatabase.CONFLICT_REPLACE) != -1L) {
            "runtime cache write failed"
        }
    }

    fun runtimeCacheDelete(blockHash: ByteArray) = transaction { db ->
        db.delete("runtime_cache", "record_key = ?", arrayOf(CitizenSdkRecordKey.blockHash(blockHash)))
    }

    fun transactionHistoryLoad(): CitizenSdkHostRecord =
        loadSingleton(CitizenSdkHostDomain.TRANSACTION_HISTORY)

    fun transactionHistoryCompareAndSwap(
        expectedRevision: Long,
        candidate: ByteArray,
    ): CitizenSdkHostRecord = compareAndSwapSingleton(
        CitizenSdkHostDomain.TRANSACTION_HISTORY,
        expectedRevision,
        candidate,
    )

    private fun loadSingleton(domain: Int): CitizenSdkHostRecord = lock.withLock {
        database.query(
            "singleton_records",
            arrayOf("revision", "record"),
            "domain = ?",
            arrayOf(domain.toString()),
            null,
            null,
            null,
        ).use { cursor ->
            if (!cursor.moveToFirst()) CitizenSdkHostRecord.absent(domain)
            else CitizenSdkHostRecord.present(domain, cursor.getLong(0), cursor.getBlob(1))
        }
    }

    private fun compareAndSwapSingleton(
        domain: Int,
        expectedRevision: Long,
        candidate: ByteArray,
    ): CitizenSdkHostRecord = transaction { db ->
        val current = db.query(
            "singleton_records",
            arrayOf("revision", "record"),
            "domain = ?",
            arrayOf(domain.toString()),
            null,
            null,
            null,
        ).use { cursor ->
            if (!cursor.moveToFirst()) null else cursor.getLong(0) to cursor.getBlob(1)
        }
        val actualRevision = current?.first ?: 0L
        if (actualRevision != expectedRevision || expectedRevision == Long.MAX_VALUE) {
            return@transaction CitizenSdkHostRecord.failure(domain, 8)
        }
        val nextRevision = expectedRevision + 1L
        val values = ContentValues().apply {
            put("domain", domain)
            put("revision", nextRevision)
            put("record", candidate.clone())
        }
        check(db.insertWithOnConflict("singleton_records", null, values, SQLiteDatabase.CONFLICT_REPLACE) != -1L) {
            "singleton CAS write failed"
        }
        CitizenSdkHostRecord.present(domain, nextRevision, candidate)
    }
}

