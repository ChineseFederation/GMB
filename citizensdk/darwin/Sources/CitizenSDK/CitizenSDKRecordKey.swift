import CryptoKit
import Foundation

internal enum CitizenSDKRecordKey {
    static func blockHash(_ hash: Data) throws -> String {
        try CitizenSDKChecks.require(hash.count == 32, "block hash identity must contain 32 bytes")
        return "block:\(hash.hex)"
    }

    static func secret(walletIndex: UInt32, kind: UInt32, generation: Data, owner: Data, accountID: Data) throws -> String {
        try CitizenSDKChecks.require(generation.count == 16 && owner.count == 16 && accountID.count == 32,
                                     "secret record identity has invalid length")
        return "v1:\(walletIndex):\(kind):\(generation.hex):\(owner.hex):\(accountID.hex)"
    }

    static func generation(walletIndex: UInt32, generation: Data) throws -> String {
        try CitizenSDKChecks.require(generation.count == 16, "vault generation must contain 16 bytes")
        return "v1:\(walletIndex):\(generation.hex)"
    }

    static func keychainTag(walletIndex: UInt32, generation: Data) throws -> Data {
        let identity = try self.generation(walletIndex: walletIndex, generation: generation)
        let digest = SHA256.hash(data: Data(identity.utf8))
        // Product identity intentionally matches Android and the approved
        // hardware-vault namespace; no legacy `citizenapp` tag is accepted.
        return Data("citizensdk_wallet_\(Data(digest).hex)".utf8)
    }
}

internal extension Data {
    var hex: String { map { String(format: "%02x", $0) }.joined() }
}
