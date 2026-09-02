import Foundation

/// Stable error vocabulary shared verbatim with `citizensdk_error_code_t`.
public enum CitizenSDKErrorCode: Int32, CaseIterable, Sendable {
    case ok = 0
    case invalidArgument = 1
    case invalidHandle = 2
    case invalidState = 3
    case unsupported = 4
    case unavailable = 5
    case notReady = 6
    case notFound = 7
    case conflict = 8
    case integrity = 9
    case authenticationCancelled = 10
    case authenticationRequired = 11
    case keyInvalidated = 12
    case permissionDenied = 13
    case storage = 14
    case network = 15
    case decode = 16
    case timeout = 17
    case busy = 18
    case queueFull = 19
    case internalFailure = 20
    case panic = 21
    case cancelled = 22

    internal static func checked(_ rawValue: Int32) -> CitizenSDKErrorCode {
        CitizenSDKErrorCode(rawValue: rawValue) ?? .integrity
    }
}

/// Public failures contain neither secrets nor Core request/result identities.
public struct CitizenSDKError: LocalizedError, Sendable, Equatable {
    public let code: CitizenSDKErrorCode
    public let message: String

    public init(_ code: CitizenSDKErrorCode, _ message: String) {
        self.code = code
        self.message = message
    }

    public var errorDescription: String? { message }
}

internal enum CitizenSDKChecks {
    static func requireOK(_ rawCode: Int32, _ fallback: String) throws {
        guard rawCode == CitizenSDKErrorCode.ok.rawValue else {
            throw CitizenSDKError(.checked(rawCode), CitizenSDKNative.lastError(fallback: fallback))
        }
    }

    static func require(_ condition: @autoclosure () -> Bool, _ message: String) throws {
        guard condition() else { throw CitizenSDKError(.invalidArgument, message) }
    }
}
