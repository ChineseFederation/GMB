package org.citizen.sdk.internal

import android.content.ContentValues
import android.database.sqlite.SQLiteDatabase
import java.io.File
import kotlin.concurrent.withLock

/** Wallet public profile, authenticated ciphertext and permanent vault tombstones. */
internal class CitizenSdkSecureStore(directory: File) :
    CitizenSdkSqlite(directory, "secure-state-v1.sqlite3") {
    override fun createSchema(database: SQLiteDatabase) {
        database.execSQL(
            "CREATE TABLE IF NOT EXISTS wallet_profile (" +
                "wallet_index INTEGER PRIMARY KEY CHECK(wallet_index = 0), " +
                "revision INTEGER NOT NULL, record BLOB NOT NULL)",
        )
        database.execSQL(
            "CREATE TABLE IF NOT EXISTS encrypted_secret (" +
                "record_key TEXT PRIMARY KEY, revision INTEGER NOT NULL, record BLOB NOT NULL)",
        )
        database.execSQL(
            "CREATE TABLE IF NOT EXISTS vault_generation (" +
                "record_key TEXT PRIMARY KEY, wallet_index INTEGER NOT NULL, generation BLOB NOT NULL, " +
                "state INTEGER NOT NULL, operation_id BLOB NOT NULL)",
        )
    }

    fun walletProfileLoad(): CitizenSdkHostRecord = lock.withLock {
        database.query(
            "wallet_profile",
            arrayOf("revision", "record"),
            "wallet_index = 0",
            null,
            null,
            null,
            null,
        ).use { cursor ->
            if (!cursor.moveToFirst()) CitizenSdkHostRecord.absent(CitizenSdkHostDomain.WALLET_PROFILE)
            else CitizenSdkHostRecord.present(
                CitizenSdkHostDomain.WALLET_PROFILE,
                cursor.getLong(0),
                cursor.getBlob(1),
            )
        }
    }

    fun walletProfileCompareAndSwap(
        expectedRevision: Long,
        candidate: ByteArray,
    ): CitizenSdkHostRecord = transaction { db ->
        val revision = db.query(
            "wallet_profile",
            arrayOf("revision"),
            "wallet_index = 0",
            null,
            null,
            null,
            null,
        ).use { cursor -> if (cursor.moveToFirst()) cursor.getLong(0) else 0L }
        if (revision != expectedRevision || expectedRevision == Long.MAX_VALUE) {
            return@transaction CitizenSdkHostRecord.failure(CitizenSdkHostDomain.WALLET_PROFILE, 8)
        }
        val next = expectedRevision + 1L
        val values = ContentValues().apply {
            put("wallet_index", 0)
            put("revision", next)
            put("record", candidate.clone())
        }
        check(db.insertWithOnConflict("wallet_profile", null, values, SQLiteDatabase.CONFLICT_REPLACE) != -1L)
        CitizenSdkHostRecord.present(CitizenSdkHostDomain.WALLET_PROFILE, next, candidate)
    }

    fun encryptedSecretLoad(
        walletIndex: Int,
        kind: Int,
        generation: ByteArray,
        owner: ByteArray,
        accountId: ByteArray,
    ): CitizenSdkHostRecord = lock.withLock {
        val key = CitizenSdkRecordKey.secret(walletIndex, kind, generation, owner, accountId)
        database.query(
            "encrypted_secret",
            arrayOf("revision", "record"),
            "record_key = ?",
            arrayOf(key),
            null,
            null,
            null,
        ).use { cursor ->
            if (!cursor.moveToFirst()) CitizenSdkHostRecord.absent(CitizenSdkHostDomain.ENCRYPTED_SECRET_BLOB)
            else CitizenSdkHostRecord.present(
                CitizenSdkHostDomain.ENCRYPTED_SECRET_BLOB,
                cursor.getLong(0),
                cursor.getBlob(1),
            )
        }
    }

    fun encryptedSecretCompareAndSwap(
        walletIndex: Int,
        kind: Int,
        generation: ByteArray,
        owner: ByteArray,
        accountId: ByteArray,
        expectedRevision: Long,
        candidate: ByteArray,
    ): CitizenSdkHostRecord = transaction { db ->
        val key = CitizenSdkRecordKey.secret(walletIndex, kind, generation, owner, accountId)
        val revision = db.query(
            "encrypted_secret",
            arrayOf("revision"),
            "record_key = ?",
            arrayOf(key),
            null,
            null,
            null,
        ).use { cursor -> if (cursor.moveToFirst()) cursor.getLong(0) else 0L }
        if (revision != expectedRevision || expectedRevision == Long.MAX_VALUE) {
            return@transaction CitizenSdkHostRecord.failure(CitizenSdkHostDomain.ENCRYPTED_SECRET_BLOB, 8)
        }
        val next = expectedRevision + 1L
        val values = ContentValues().apply {
            put("record_key", key)
            put("revision", next)
            put("record", candidate.clone())
        }
        check(db.insertWithOnConflict("encrypted_secret", null, values, SQLiteDatabase.CONFLICT_REPLACE) != -1L)
        CitizenSdkHostRecord.present(CitizenSdkHostDomain.ENCRYPTED_SECRET_BLOB, next, candidate)
    }

    fun ensureGeneration(
        walletIndex: Int,
        generation: ByteArray,
        provisioningOperationId: ByteArray,
    ): Boolean = transaction { db ->
        val key = CitizenSdkRecordKey.walletGeneration(walletIndex, generation)
        val existing = generationRecord(db, key)
        if (existing?.first == STATE_RETIRED) return@transaction false
        if (existing?.first == STATE_ACTIVE) {
            // A generation is admitted by exactly one provisioning operation.
            // Reusing its bytes under another operation must fail closed.
            return@transaction existing.second.contentEquals(provisioningOperationId)
        }
        val values = ContentValues().apply {
            put("record_key", key)
            put("wallet_index", walletIndex)
            put("generation", generation.clone())
            put("state", STATE_ACTIVE)
            put("operation_id", provisioningOperationId.clone())
        }
        check(db.insertOrThrow("vault_generation", null, values) != -1L)
        true
    }

    fun isGenerationActive(walletIndex: Int, generation: ByteArray): Boolean = lock.withLock {
        generationState(database, CitizenSdkRecordKey.walletGeneration(walletIndex, generation)) == STATE_ACTIVE
    }

    /** Tombstone commits before the caller attempts physical Keystore deletion. */
    fun retireGeneration(
        walletIndex: Int,
        generation: ByteArray,
        cleanupOperationId: ByteArray,
    ) = transaction { db ->
        val key = CitizenSdkRecordKey.walletGeneration(walletIndex, generation)
        val values = ContentValues().apply {
            put("record_key", key)
            put("wallet_index", walletIndex)
            put("generation", generation.clone())
            put("state", STATE_RETIRED)
            put("operation_id", cleanupOperationId.clone())
        }
        check(db.insertWithOnConflict("vault_generation", null, values, SQLiteDatabase.CONFLICT_REPLACE) != -1L)
    }

    private fun generationState(db: SQLiteDatabase, key: String): Int? = db.query(
        "vault_generation",
        arrayOf("state"),
        "record_key = ?",
        arrayOf(key),
        null,
        null,
        null,
    ).use { cursor -> if (cursor.moveToFirst()) cursor.getInt(0) else null }

    private fun generationRecord(db: SQLiteDatabase, key: String): Pair<Int, ByteArray>? = db.query(
        "vault_generation",
        arrayOf("state", "operation_id"),
        "record_key = ?",
        arrayOf(key),
        null,
        null,
        null,
    ).use { cursor -> if (cursor.moveToFirst()) cursor.getInt(0) to cursor.getBlob(1) else null }

    companion object {
        internal const val STATE_ACTIVE = 1
        internal const val STATE_RETIRED = 2
    }
}
