package org.citizen.sdk.internal

import android.database.sqlite.SQLiteDatabase
import java.io.File
import java.util.concurrent.locks.ReentrantLock
import kotlin.concurrent.withLock

/** Small no-backup SQLite owner with explicit transactional serialization. */
internal abstract class CitizenSdkSqlite(
    directory: File,
    fileName: String,
) : AutoCloseable {
    protected val lock = ReentrantLock(true)
    protected val database: SQLiteDatabase

    init {
        check(directory.exists() || directory.mkdirs()) { "unable to create CitizenSDK storage directory" }
        val file = File(directory, fileName)
        database = SQLiteDatabase.openOrCreateDatabase(file, null).apply {
            execSQL("PRAGMA journal_mode=WAL")
            execSQL("PRAGMA synchronous=FULL")
            execSQL("PRAGMA foreign_keys=ON")
        }
        lock.withLock { createSchema(database) }
    }

    protected abstract fun createSchema(database: SQLiteDatabase)

    protected fun <T> transaction(block: (SQLiteDatabase) -> T): T = lock.withLock {
        database.beginTransaction()
        try {
            block(database).also { database.setTransactionSuccessful() }
        } finally {
            database.endTransaction()
        }
    }

    override fun close() = lock.withLock { database.close() }
}

