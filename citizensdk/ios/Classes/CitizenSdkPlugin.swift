import Flutter
import UIKit

/// Registers the CitizenSDK byte-only hardware-vault channel.
public final class CitizenSdkPlugin: NSObject, FlutterPlugin {
  private static let channelName = "citizen/sdk/hardware_secretvault"

  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: channelName,
      binaryMessenger: registrar.messenger()
    )
    registrar.addMethodCallDelegate(CitizenSdkPlugin(), channel: channel)
  }

  private let vault = SecureEnclaveSecretVault()

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    vault.handle(call, result: result)
  }
}
