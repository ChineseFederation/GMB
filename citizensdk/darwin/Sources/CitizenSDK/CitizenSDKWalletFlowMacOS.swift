#if os(macOS)
import AppKit

public extension CitizenSDK {
    @MainActor
    func presentWalletFlow(from parent: NSWindow, request: CitizenSDKWalletFlowRequest,
                           completion: @escaping (CitizenSDKWalletFlowResult) -> Void) throws -> CitizenSDKWalletFlow {
        let request = try citizenSDKValidateWalletFlowRequest(request)
        let token = try CitizenSDKWalletFlowRegistry.shared.reserve(self)
        let controller = CitizenSDKWalletViewControllerMacOS(sdk: self, request: request) { [weak self, weak parent] result in
            guard let self else { return }
            CitizenSDKWalletFlowRegistry.shared.finish(self, token: token)
            if let sheet = parent?.attachedSheet { parent?.endSheet(sheet) }
            completion(result)
        }
        let window = NSWindow(contentViewController: controller)
        window.title = "公民钱包"
        window.setContentSize(NSSize(width: 560, height: 560))
        // A sheet must terminate only through the SDK cancel/complete path.
        window.styleMask.remove(.closable)
        window.standardWindowButton(.closeButton)?.isEnabled = false
        controller.security = CitizenSDKScreenSecurity(window: window)
        parent.beginSheet(window)
        return CitizenSDKWalletFlow { [weak controller] in
            DispatchQueue.main.async { controller?.requestCancel() }
        }
    }
}

@MainActor
private final class CitizenSDKWalletViewControllerMacOS: NSViewController {
    let sdk: CitizenSDK
    let request: CitizenSDKWalletFlowRequest
    let completion: (CitizenSDKWalletFlowResult) -> Void
    var security: CitizenSDKScreenSecurity?
    private let mnemonic = NSTextView()
    private let password = NSSecureTextField()
    private let passwordConfirmation = NSSecureTextField()
    private let action = NSButton(title: "", target: nil, action: nil)
    private let cancel = NSButton(title: "取消", target: nil, action: nil)
    private let status = NSTextField(labelWithString: "")
    private let backup = NSButton(checkboxWithTitle: "我已在离线安全位置备份助记词", target: nil, action: nil)
    private var prepared: CitizenSDKPreparedWallet?
    private var phrase: CitizenSDKRecoveryPhrase?
    private var task: Task<Void, Never>?
    private var cancelRequested = false
    private var irreversible = false
    private var finished = false

    init(sdk: CitizenSDK, request: CitizenSDKWalletFlowRequest,
         completion: @escaping (CitizenSDKWalletFlowResult) -> Void) {
        self.sdk = sdk; self.request = request; self.completion = completion
        super.init(nibName: nil, bundle: nil)
    }
    @available(*, unavailable) required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }

    override func loadView() {
        view = NSView()
        status.maximumNumberOfLines = 3
        password.placeholderString = "钱包密码"
        passwordConfirmation.placeholderString = "再次输入钱包密码"
        let scroll = NSScrollView()
        scroll.documentView = mnemonic
        scroll.hasVerticalScroller = true
        scroll.heightAnchor.constraint(equalToConstant: 220).isActive = true
        mnemonic.isAutomaticQuoteSubstitutionEnabled = false
        mnemonic.isAutomaticDashSubstitutionEnabled = false
        mnemonic.isAutomaticTextReplacementEnabled = false
        action.target = self; action.action = #selector(actionPressed)
        action.bezelStyle = .rounded
        cancel.target = self; cancel.action = #selector(cancelPressed)
        let buttons = NSStackView(views: [cancel, action]); buttons.spacing = 12
        let stack = NSStackView(views: [status, scroll, password, passwordConfirmation, backup, buttons])
        stack.orientation = .vertical; stack.spacing = 14; stack.alignment = .leading
        view.addSubview(stack); stack.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            stack.topAnchor.constraint(equalTo: view.topAnchor, constant: 24),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: view.bottomAnchor, constant: -24),
            scroll.widthAnchor.constraint(equalTo: stack.widthAnchor),
            password.widthAnchor.constraint(equalTo: stack.widthAnchor),
            passwordConfirmation.widthAnchor.constraint(equalTo: stack.widthAnchor),
        ])
        backup.isHidden = true
        switch request {
        case .create:
            scroll.isHidden = true; action.title = "生成钱包"
            status.stringValue = "助记词只会在本设备生成并显示。请离线备份后确认。"
        case .importWallet:
            passwordConfirmation.isHidden = true; action.title = "导入钱包"
            status.stringValue = "助记词和密码只在本设备的公民 SDK 内使用。"
        case .addAccounts:
            passwordConfirmation.isHidden = true; action.title = "添加账户"
            status.stringValue = "验证现有助记词后添加所选派生账户。"
        }
    }

    @objc private func actionPressed() {
        guard task == nil else { return }
        action.isEnabled = false
        if prepared != nil { commitCreatedWallet() } else { beginOperation() }
    }

    private func beginOperation() {
        do {
            let passwordText = password.stringValue
            guard !passwordText.isEmpty else { throw CitizenSDKError(.invalidArgument, "请输入钱包密码") }
            if case .create = request, passwordText != passwordConfirmation.stringValue {
                throw CitizenSDKError(.invalidArgument, "两次输入的钱包密码不一致")
            }
            let passwordBuffer = try citizenSDKSensitiveText(passwordText, label: "password")
            password.stringValue = ""; passwordConfirmation.stringValue = ""
            switch request {
            case let .create(wordCount):
                task = Task { [weak self] in
                    guard let self else { return }; defer { self.task = nil }
                    do {
                        let prepared = try await self.sdk.prepareWallet(wordCount: wordCount, password: passwordBuffer)
                        passwordBuffer.clear()
                        if self.cancelRequested {
                            self.finish(citizenSDKPreparedCancellationResult { try prepared.release() })
                            return
                        }
                        let phrase = try prepared.recoveryPhrase(); self.prepared = prepared; self.phrase = phrase
                        try phrase.render { self.mnemonic.string = $0 }
                        self.mnemonic.isEditable = false; self.mnemonic.isSelectable = false
                        self.mnemonic.enclosingScrollView?.isHidden = false
                        self.password.isHidden = true; self.passwordConfirmation.isHidden = true; self.backup.isHidden = false
                        self.action.title = "确认备份并创建"; self.action.isEnabled = true
                    } catch { passwordBuffer.clear(); self.fail(error) }
                }
            case .importWallet:
                irreversible = true
                let mnemonicBuffer = try citizenSDKSensitiveText(mnemonic.string, label: "mnemonic")
                mnemonic.string = ""
                task = Task { [weak self] in
                    guard let self else { return }; defer { mnemonicBuffer.clear(); passwordBuffer.clear(); self.task = nil }
                    do {
                        let profile = try await self.sdk.importWallet(mnemonic: mnemonicBuffer, password: passwordBuffer)
                        citizenSDKAfterClearingSecrets([mnemonicBuffer, passwordBuffer]) {
                            self.finish(.completed(profile))
                        }
                    } catch {
                        citizenSDKAfterClearingSecrets([mnemonicBuffer, passwordBuffer]) { self.fail(error) }
                    }
                }
            case let .addAccounts(indices):
                irreversible = true
                let mnemonicBuffer = try citizenSDKSensitiveText(mnemonic.string, label: "mnemonic")
                mnemonic.string = ""
                task = Task { [weak self] in
                    guard let self else { return }; defer { mnemonicBuffer.clear(); passwordBuffer.clear(); self.task = nil }
                    do {
                        let profile = try await self.sdk.addWalletAccounts(
                            mnemonic: mnemonicBuffer, password: passwordBuffer, indices: indices
                        )
                        citizenSDKAfterClearingSecrets([mnemonicBuffer, passwordBuffer]) {
                            self.finish(.completed(profile))
                        }
                    } catch {
                        citizenSDKAfterClearingSecrets([mnemonicBuffer, passwordBuffer]) { self.fail(error) }
                    }
                }
            }
        } catch { fail(error) }
    }

    private func commitCreatedWallet() {
        guard backup.state == .on, let prepared else { status.stringValue = "请先确认已安全备份助记词。"; action.isEnabled = true; return }
        mnemonic.string = ""; phrase?.clear(); phrase = nil
        irreversible = true
        task = Task { [weak self] in
            guard let self else { return }; defer { self.task = nil }
            do { self.finish(.completed(try await self.sdk.commit(prepared))) }
            catch { self.fail(error) }
        }
    }

    @objc private func cancelPressed() { requestCancel() }
    func requestCancel() {
        guard !finished else { return }
        cancelRequested = true; mnemonic.string = ""; password.stringValue = ""; passwordConfirmation.stringValue = ""
        phrase?.clear(); phrase = nil
        if task == nil {
            let result = prepared.map { prepared in
                citizenSDKPreparedCancellationResult { try prepared.release() }
            } ?? .cancelled
            prepared = nil; finish(result)
        }
        else { status.stringValue = "正在安全结束当前钱包操作…" }
    }

    private func fail(_ error: Error) {
        if let result = citizenSDKCancellationResult(cancelRequested: cancelRequested,
                                                     irreversible: irreversible, error: error) {
            finish(result); return
        }
        status.stringValue = citizenSDKFlowError(error).message; action.isEnabled = true
    }

    private func finish(_ result: CitizenSDKWalletFlowResult) {
        guard !finished else { return }; finished = true
        security?.finish(); security = nil
        mnemonic.string = ""; password.stringValue = ""; passwordConfirmation.stringValue = ""
        phrase?.clear(); phrase = nil
        prepared = nil; completion(result)
    }
}
#endif
