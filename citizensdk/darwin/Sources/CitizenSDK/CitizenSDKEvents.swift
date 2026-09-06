import Foundation

public enum CitizenTransferProgressStatus: UInt32, Sendable {
    case ready = 1, broadcast = 2, future = 3, inBlock = 4, finalized = 5
    case retracted = 6, finalityTimeout = 7, dropped = 8, invalid = 9, usurped = 10
}

public struct CitizenTransferProgress: Equatable, Sendable {
    /// Facade identity, never a Core request or result handle.
    public let operationID: String
    public let sequence: UInt64
    public let status: CitizenTransferProgressStatus
    public let block: CitizenBlockRef?
    public let replacementHash: Data?
    public let peerCount: UInt32
}

public enum CitizenSDKEvent: Equatable, Sendable {
    /// Invalidation only; read the latest state with the existing history API.
    case historyChanged(sequence: UInt64)
    case lifecycleChanged(sequence: UInt64, lifecycle: CitizenSDKLifecycle)
    case capabilitiesChanged(sequence: UInt64, capabilities: CitizenSDKCapabilities)
}
