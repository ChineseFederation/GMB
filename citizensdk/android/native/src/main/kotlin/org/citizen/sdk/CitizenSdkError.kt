package org.citizen.sdk

/** Stable error vocabulary shared with `citizensdk_error_code_t`. */
enum class CitizenSdkErrorCode(val value: Int) {
    OK(0),
    INVALID_ARGUMENT(1),
    INVALID_HANDLE(2),
    INVALID_STATE(3),
    UNSUPPORTED(4),
    UNAVAILABLE(5),
    NOT_READY(6),
    NOT_FOUND(7),
    CONFLICT(8),
    INTEGRITY(9),
    AUTHENTICATION_CANCELLED(10),
    AUTHENTICATION_REQUIRED(11),
    KEY_INVALIDATED(12),
    PERMISSION_DENIED(13),
    STORAGE(14),
    NETWORK(15),
    DECODE(16),
    TIMEOUT(17),
    BUSY(18),
    QUEUE_FULL(19),
    INTERNAL(20),
    PANIC(21),
    CANCELLED(22);

    companion object {
        @JvmStatic
        fun fromValue(value: Int): CitizenSdkErrorCode =
            entries.firstOrNull { it.value == value } ?: INTEGRITY
    }
}

/** Public failures never contain secrets or native/result identities. */
class CitizenSdkException(
    val code: CitizenSdkErrorCode,
    message: String,
    cause: Throwable? = null,
) : RuntimeException(message, cause)
