@file:kotlin.jvm.JvmSynthetic

package org.citizen.sdk

import java.nio.ByteBuffer
import java.nio.CharBuffer
import java.nio.charset.CodingErrorAction
import java.nio.charset.StandardCharsets
import java.util.concurrent.atomic.AtomicBoolean

/** Short-lived recovery phrase buffer owned exclusively by the secure UI. */
internal class CitizenSdkRecoveryPhrase private constructor(bytes: ByteArray) : AutoCloseable {
    private val closed = AtomicBoolean(false)
    private val value = bytes.clone().also { bytes.fill(0) }

    /** Executes UI rendering without returning a String or retaining a CharBuffer. */
    fun <T> useCharacters(block: (CharBuffer) -> T): T {
        check(!closed.get()) { "recovery phrase is closed" }
        val decoder = StandardCharsets.UTF_8.newDecoder()
            .onMalformedInput(CodingErrorAction.REPORT)
            .onUnmappableCharacter(CodingErrorAction.REPORT)
        val chars = decoder.decode(ByteBuffer.wrap(value))
        return try {
            block(chars.asReadOnlyBuffer())
        } finally {
            for (index in 0 until chars.limit()) chars.put(index, '\u0000')
        }
    }

    override fun close() {
        if (closed.compareAndSet(false, true)) value.fill(0)
    }

    companion object {
        internal fun create(bytes: ByteArray): CitizenSdkRecoveryPhrase = CitizenSdkRecoveryPhrase(bytes)
    }
}
