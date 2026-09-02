import Foundation

/// Short-lived recovery phrase bytes owned only by the non-exported wallet UI.
internal final class CitizenSDKRecoveryPhrase {
    private let buffer: CitizenSDKSensitiveBuffer
    init(buffer: CitizenSDKSensitiveBuffer) { self.buffer = buffer }

    /// Apple text controls require a Swift String and retain it inside the
    /// non-selectable SDK-owned wallet control until commit/cancel. The flow
    /// clears that control at every terminal path, but Swift/platform text
    /// storage cannot promise in-place erasure. The phrase is never returned
    /// by public API, logged, persisted, or sent through Flutter.
    func render<T>(_ body: (String) throws -> T) throws -> T {
        try buffer.withUnsafeBytes { bytes in
            guard let value = String(bytes: bytes, encoding: .utf8) else {
                throw CitizenSDKError(.integrity, "Core recovery phrase is not UTF-8")
            }
            return try body(value)
        }
    }

    func clear() { buffer.clear() }
    deinit { clear() }
}
