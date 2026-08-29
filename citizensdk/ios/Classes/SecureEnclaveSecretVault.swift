import CryptoKit
import Flutter
import LocalAuthentication
import Security

/// CitizenSDK iOS hardware vault.
///
/// The Secure Enclave private key is fixed to
/// `biometryCurrentSet + privateKeyUsage`. Adding or removing biometrics makes
/// old ciphertext permanently unavailable. The authenticated envelope format
/// and ECIES algorithm remain unchanged.
final class SecureEnclaveSecretVault {
  private static let keyPrefix = "org.citizensdk.hardware-secretvault."
  private static let namespace = "citizensdk"
  private static let envelopeVersion: UInt8 = 1
  private static let aadHashLength = 32
  private static let secretLengthBytes = 4

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    do {
      switch call.method {
      case "securityStatus":
        let context = LAContext()
        var error: NSError?
        let enrolled = context.canEvaluatePolicy(
          .deviceOwnerAuthenticationWithBiometrics,
          error: &error
        )
        result(["supported": true, "strongBiometricEnrolled": enrolled])
      case "encrypt":
        let arguments = try requiredArguments(call)
        let scope = try requiredString(arguments, "scope")
        try requireNamespace(arguments)
        var aad = try requiredData(arguments, "associatedData")
        var plaintext = try requiredData(arguments, "plaintext")
        defer {
          aad.resetBytes(in: 0..<aad.count)
          plaintext.resetBytes(in: 0..<plaintext.count)
        }
        let ciphertext = try encrypt(
          scope: scope,
          aad: aad,
          plaintext: plaintext
        )
        result(FlutterStandardTypedData(bytes: ciphertext))
      case "decrypt":
        let arguments = try requiredArguments(call)
        let scope = try requiredString(arguments, "scope")
        try requireNamespace(arguments)
        var aad = try requiredData(arguments, "associatedData")
        var ciphertext = try requiredData(arguments, "ciphertext")
        var plaintext = Data()
        defer {
          aad.resetBytes(in: 0..<aad.count)
          ciphertext.resetBytes(in: 0..<ciphertext.count)
          plaintext.resetBytes(in: 0..<plaintext.count)
        }
        plaintext = try decrypt(
          scope: scope,
          aad: aad,
          ciphertext: ciphertext
        )
        result(FlutterStandardTypedData(bytes: plaintext))
      case "deleteKey":
        let arguments = try requiredArguments(call)
        try requireNamespace(arguments)
        try deleteKey(scope: requiredString(arguments, "scope"))
        result(nil)
      case "containsKey":
        let arguments = try requiredArguments(call)
        try requireNamespace(arguments)
        result(try containsKey(scope: requiredString(arguments, "scope")))
      default:
        result(FlutterMethodNotImplemented)
      }
    } catch let failure as VaultFailure {
      result(FlutterError(code: failure.code, message: failure.message, details: nil))
    } catch {
      result(FlutterError(code: "vaultFailure", message: error.localizedDescription, details: nil))
    }
  }

  private func encrypt(
    scope: String,
    aad: Data,
    plaintext: Data
  ) throws -> Data {
    guard !aad.isEmpty, !plaintext.isEmpty else {
      throw VaultFailure(code: "badArgs", message: "AAD/机密不能为空")
    }
    let privateKey = try loadPrivateKey(
      scope: scope,
      createIfMissing: true
    )
    guard let publicKey = SecKeyCopyPublicKey(privateKey) else {
      throw VaultFailure(code: "hardwareUnavailable", message: "Secure Enclave 公钥不可用")
    }
    var envelope = Self.makeEnvelope(aad: aad, plaintext: plaintext)
    defer { envelope.resetBytes(in: 0..<envelope.count) }

    var error: Unmanaged<CFError>?
    guard let encrypted = SecKeyCreateEncryptedData(
      publicKey,
      .eciesEncryptionCofactorX963SHA256AESGCM,
      envelope as CFData,
      &error
    ) else {
      throw map(error?.takeRetainedValue(), missingKeyIsInvalidated: false)
    }
    return encrypted as Data
  }

  private func decrypt(
    scope: String,
    aad: Data,
    ciphertext: Data
  ) throws -> Data {
    let context = LAContext()
    context.localizedReason = "验证身份以解锁钱包机密"
    context.localizedCancelTitle = "取消"
    let privateKey = try loadPrivateKey(
      scope: scope,
      createIfMissing: false,
      authenticationContext: context
    )
    var error: Unmanaged<CFError>?
    guard let decrypted = SecKeyCreateDecryptedData(
      privateKey,
      .eciesEncryptionCofactorX963SHA256AESGCM,
      ciphertext as CFData,
      &error
    ) else {
      throw map(error?.takeRetainedValue(), missingKeyIsInvalidated: true)
    }
    var envelope = decrypted as Data
    defer { envelope.resetBytes(in: 0..<envelope.count) }
    return try Self.parseEnvelope(aad: aad, envelope: envelope)
  }

  internal static func makeEnvelope(aad: Data, plaintext: Data) -> Data {
    var envelope = Data([envelopeVersion])
    envelope.append(Data(SHA256.hash(data: aad)))
    var length = UInt32(plaintext.count).bigEndian
    withUnsafeBytes(of: &length) { envelope.append(contentsOf: $0) }
    envelope.append(plaintext)
    return envelope
  }

  internal static func parseEnvelope(aad: Data, envelope: Data) throws -> Data {
    let headerLength = 1 + aadHashLength + secretLengthBytes
    guard envelope.count > headerLength, envelope[0] == envelopeVersion else {
      throw VaultFailure(code: "badBlob", message: "硬件金库密文格式无效")
    }
    let expectedHash = Data(SHA256.hash(data: aad))
    let storedHash = envelope.subdata(in: 1..<(1 + aadHashLength))
    guard storedHash == expectedHash else {
      throw VaultFailure(code: "badBlob", message: "密文与钱包账户身份不匹配")
    }
    let lengthStart = 1 + aadHashLength
    let lengthData = envelope.subdata(in: lengthStart..<(lengthStart + secretLengthBytes))
    let secretLength = lengthData.reduce(UInt32(0)) { ($0 << 8) | UInt32($1) }
    guard secretLength > 0, Int(secretLength) == envelope.count - headerLength else {
      throw VaultFailure(code: "badBlob", message: "硬件金库机密长度无效")
    }
    return envelope.subdata(in: headerLength..<envelope.count)
  }

  private func loadPrivateKey(
    scope: String,
    createIfMissing: Bool,
    authenticationContext: LAContext? = nil
  ) throws -> SecKey {
    let tag = try Self.applicationTag(scope: scope)
    var query = baseQuery(tag: tag)
    query[kSecReturnRef as String] = true
    if let authenticationContext {
      query[kSecUseAuthenticationContext as String] = authenticationContext
      query[kSecUseAuthenticationUI as String] = kSecUseAuthenticationUIAllow
    } else {
      query[kSecUseAuthenticationUI as String] = kSecUseAuthenticationUIFail
    }
    var item: CFTypeRef?
    let status = SecItemCopyMatching(query as CFDictionary, &item)
    if status == errSecSuccess, let item {
      return item as! SecKey
    }
    if status != errSecItemNotFound {
      throw map(status: status, missingKeyIsInvalidated: !createIfMissing)
    }
    guard createIfMissing else {
      throw VaultFailure(
        code: "keyPermanentlyInvalidated",
        message: "Secure Enclave 私钥不存在或已失效"
      )
    }
    return try createPrivateKey(tag: tag)
  }

  private func createPrivateKey(tag: Data) throws -> SecKey {
    var accessError: Unmanaged<CFError>?
    guard let accessControl = SecAccessControlCreateWithFlags(
      nil,
      kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
      [.privateKeyUsage, .biometryCurrentSet],
      &accessError
    ) else {
      throw map(accessError?.takeRetainedValue(), missingKeyIsInvalidated: false)
    }
    let attributes: [String: Any] = [
      kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom,
      kSecAttrKeySizeInBits as String: 256,
      kSecAttrTokenID as String: kSecAttrTokenIDSecureEnclave,
      kSecPrivateKeyAttrs as String: [
        kSecAttrIsPermanent as String: true,
        kSecAttrApplicationTag as String: tag,
        kSecAttrAccessControl as String: accessControl,
      ],
    ]
    var error: Unmanaged<CFError>?
    guard let key = SecKeyCreateRandomKey(attributes as CFDictionary, &error) else {
      throw map(error?.takeRetainedValue(), missingKeyIsInvalidated: false)
    }
    return key
  }

  private func containsKey(scope: String) throws -> Bool {
    var query = baseQuery(tag: try Self.applicationTag(scope: scope))
    query[kSecReturnAttributes as String] = true
    query[kSecUseAuthenticationUI as String] = kSecUseAuthenticationUIFail
    let status = SecItemCopyMatching(query as CFDictionary, nil)
    if status == errSecSuccess { return true }
    if status == errSecItemNotFound { return false }
    throw map(status: status, missingKeyIsInvalidated: false)
  }

  private func deleteKey(scope: String) throws {
    let tag = try Self.applicationTag(scope: scope)
    let status = SecItemDelete(baseQuery(tag: tag) as CFDictionary)
    if status != errSecSuccess && status != errSecItemNotFound {
      throw map(status: status, missingKeyIsInvalidated: false)
    }
  }

  private func baseQuery(tag: Data) -> [String: Any] {
    [
      kSecClass as String: kSecClassKey,
      kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom,
      kSecAttrKeyClass as String: kSecAttrKeyClassPrivate,
      kSecAttrApplicationTag as String: tag,
      kSecUseDataProtectionKeychain as String: true,
    ]
  }

  internal static func applicationTag(scope: String) throws -> Data {
    guard scope.range(
      of: "^[a-z][a-z0-9]{2,31}:[a-z0-9._:-]{1,80}$",
      options: .regularExpression
    ) != nil else {
      throw VaultFailure(code: "badArgs", message: "硬件密钥作用域格式无效")
    }
    guard scope.hasPrefix("citizensdk:") else {
      throw VaultFailure(code: "badArgs", message: "硬件密钥产品标识必须为 citizensdk")
    }
    let digest = SHA256.hash(data: Data(scope.utf8))
      .map { String(format: "%02x", $0) }
      .joined()
    return Data((keyPrefix + digest).utf8)
  }

  private func requiredArguments(_ call: FlutterMethodCall) throws -> [String: Any] {
    guard let arguments = call.arguments as? [String: Any] else {
      throw VaultFailure(code: "badArgs", message: "参数缺失")
    }
    return arguments
  }

  private func requiredString(_ arguments: [String: Any], _ name: String) throws -> String {
    guard let value = arguments[name] as? String else {
      throw VaultFailure(code: "badArgs", message: "\(name) 缺失")
    }
    return value
  }

  private func requireNamespace(_ arguments: [String: Any]) throws {
    let value = try requiredString(arguments, "keyNamespace")
    guard value == Self.namespace else {
      throw VaultFailure(code: "badArgs", message: "硬件密钥命名空间必须为 citizensdk")
    }
  }

  private func requiredData(_ arguments: [String: Any], _ name: String) throws -> Data {
    if let value = arguments[name] as? FlutterStandardTypedData {
      return value.data
    }
    if let value = arguments[name] as? Data {
      return value
    }
    throw VaultFailure(code: "badArgs", message: "\(name) 缺失")
  }

  private func map(_ error: CFError?, missingKeyIsInvalidated: Bool) -> VaultFailure {
    guard let error else {
      return VaultFailure(code: "vaultFailure", message: "Secure Enclave 操作失败")
    }
    return map(
      status: OSStatus(CFErrorGetCode(error)),
      missingKeyIsInvalidated: missingKeyIsInvalidated
    )
  }

  private func map(status: OSStatus, missingKeyIsInvalidated: Bool) -> VaultFailure {
    switch status {
    case errSecUserCanceled, errSecAuthFailed:
      return VaultFailure(code: "userCancelled", message: "生物识别未完成")
    case errSecInteractionNotAllowed:
      return VaultFailure(code: "notEnrolled", message: "设备未录入可用生物识别")
    case errSecItemNotFound where missingKeyIsInvalidated:
      return VaultFailure(
        code: "keyPermanentlyInvalidated",
        message: "Secure Enclave 私钥不存在或已失效"
      )
    case errSecNotAvailable, errSecUnimplemented:
      return VaultFailure(code: "hardwareUnavailable", message: "Secure Enclave 不可用")
    default:
      let message = SecCopyErrorMessageString(status, nil) as String?
      return VaultFailure(code: "vaultFailure", message: message ?? "安全存储错误 \(status)")
    }
  }

  internal struct VaultFailure: Error {
    let code: String
    let message: String
  }
}
