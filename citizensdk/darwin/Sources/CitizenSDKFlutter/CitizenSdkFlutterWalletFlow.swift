import CitizenSDK
import Foundation

#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

/// Secret-free bridge to the SDK-owned Apple wallet interface.
@MainActor
internal final class CitizenSdkFlutterWalletFlow {
    private struct Key: Hashable { let session: String; let sequence: Int64 }
    private final class Entry {
        var handle: CitizenSDKWalletFlow?
        var cancelRequested = false
        var finished = false
    }
    private var active: [Key: Entry] = [:]

    func launch(sdk: CitizenSDK, request: CitizenSdkFlutterCodec.Request) async throws -> CitizenWalletProfile? {
        guard let session = request.sessionID, let sequence = request.sequence else {
            throw CitizenSDKError(.invalidArgument, "wallet flow requires a session request")
        }
        let contract = try Self.contract(for: request)
        let key = Key(session: session, sequence: sequence)
        guard active[key] == nil else { throw CitizenSDKError(.conflict, "wallet flow request already exists") }
        let entry = Entry(); active[key] = entry
        return try await withCheckedThrowingContinuation { continuation in
            do {
                #if os(iOS)
                guard let presenter = Self.presenter() else { throw CitizenSDKError(.unavailable, "CitizenSDK wallet UI has no foreground presenter") }
                let handle = try sdk.presentWalletFlow(from: presenter, request: contract) { [weak self, weak entry] result in
                    Task { @MainActor in self?.finish(key, entry: entry, result: result, continuation: continuation) }
                }
                #elseif os(macOS)
                guard let window = NSApp.keyWindow ?? NSApp.mainWindow else { throw CitizenSDKError(.unavailable, "CitizenSDK wallet UI has no host window") }
                let handle = try sdk.presentWalletFlow(from: window, request: contract) { [weak self, weak entry] result in
                    Task { @MainActor in self?.finish(key, entry: entry, result: result, continuation: continuation) }
                }
                #endif
                entry.handle = handle
                if entry.cancelRequested { handle.cancel() }
            } catch {
                active.removeValue(forKey: key)
                continuation.resume(throwing: error)
            }
        }
    }

    static func contract(for request: CitizenSdkFlutterCodec.Request) throws -> CitizenSDKWalletFlowRequest {
        switch request {
        case let .create(_, _, words): return .create(wordCount: words)
        case let .empty(method, _, _) where method == "importWallet": return .importWallet
        case let .addAccounts(_, _, indices): return .addAccounts(indices: indices)
        default: throw CitizenSDKError(.invalidArgument, "request is not an SDK-owned wallet flow")
        }
    }

    func cancelSession(_ session: String) {
        active.filter { $0.key.session == session }.forEach { _, entry in
            entry.cancelRequested = true
            entry.handle?.cancel()
        }
    }

    private func finish(_ key: Key, entry: Entry?, result: CitizenSDKWalletFlowResult,
                        continuation: CheckedContinuation<CitizenWalletProfile?, Error>) {
        guard let entry, active[key] === entry, !entry.finished else { return }
        entry.finished = true; active.removeValue(forKey: key)
        switch result {
        case let .completed(profile): continuation.resume(returning: profile)
        case .cancelled: continuation.resume(throwing: CitizenSDKError(.cancelled, "CitizenSDK wallet flow cancelled"))
        case let .failed(error): continuation.resume(throwing: error)
        @unknown default:
            continuation.resume(throwing: CitizenSDKError(.integrity, "CitizenSDK wallet flow returned an unknown result"))
        }
    }

    #if os(iOS)
    private static func presenter() -> UIViewController? {
        let root = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first(where: \.isKeyWindow)?.rootViewController
        var current = root
        while let presented = current?.presentedViewController { current = presented }
        if let navigation = current as? UINavigationController { return navigation.visibleViewController ?? navigation }
        if let tabs = current as? UITabBarController { return tabs.selectedViewController ?? tabs }
        return current
    }
    #endif
}
