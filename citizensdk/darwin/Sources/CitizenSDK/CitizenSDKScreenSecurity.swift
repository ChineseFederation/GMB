import Foundation

#if os(iOS)
import UIKit

/// Best available iOS screen boundary: obscures on capture/background.
@MainActor
internal final class CitizenSDKScreenSecurity {
    private weak var view: UIView?
    private let cover = UIView()
    private var tokens: [NSObjectProtocol] = []

    init(view: UIView) {
        self.view = view
        cover.backgroundColor = .systemBackground
        cover.isHidden = true
        cover.accessibilityLabel = "钱包内容已隐藏"
        view.addSubview(cover)
        cover.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            cover.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            cover.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            cover.topAnchor.constraint(equalTo: view.topAnchor),
            cover.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
        let center = NotificationCenter.default
        tokens = [
            center.addObserver(forName: UIScreen.capturedDidChangeNotification, object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor [weak self] in self?.refresh() }
            },
            center.addObserver(forName: UIApplication.willResignActiveNotification, object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor [weak self] in self?.cover.isHidden = false }
            },
            center.addObserver(forName: UIApplication.didBecomeActiveNotification, object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor [weak self] in self?.refresh() }
            },
        ]
        refresh()
    }

    private func refresh() { cover.isHidden = !UIScreen.main.isCaptured }

    /// Wallet-flow teardown runs on the main actor before its view is released.
    func finish() {
        tokens.forEach(NotificationCenter.default.removeObserver)
        tokens.removeAll(keepingCapacity: false)
        cover.removeFromSuperview()
    }
}
#elseif os(macOS)
import AppKit

/// macOS can explicitly exclude the SDK-owned wallet window from sharing.
@MainActor
internal final class CitizenSDKScreenSecurity {
    private weak var window: NSWindow?
    init(window: NSWindow) {
        self.window = window
        window.sharingType = .none
    }

    /// The non-closable wallet sheet is destroyed immediately after the flow,
    /// so it must not be made shareable during teardown.
    func finish() { window = nil }
}
#endif
