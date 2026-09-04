import Foundation

/// 密码可为空；创建时仍必须逐字匹配确认值。派生和长度规则继续由 Core 校验。
internal func citizenSDKValidateWalletPassword(_ password: String, confirmation: String?,
                                               request: CitizenSDKWalletFlowRequest) throws {
    if case .create = request, password != (confirmation ?? "") {
        throw CitizenSDKError(.invalidArgument, "两次输入的钱包密码不一致")
    }
}

#if os(iOS)
import UIKit

public extension CitizenSdk {
    /// Presents the only supported secret-entry/recovery interface. No secret
    /// is an argument or result of this API.
    @MainActor
    func presentWalletFlow(from presenter: UIViewController, request: CitizenSDKWalletFlowRequest,
                           completion: @escaping (CitizenSDKWalletFlowResult) -> Void) throws -> CitizenSDKWalletFlow {
        let request = try citizenSDKValidateWalletFlowRequest(request)
        let token = try CitizenSDKWalletFlowRegistry.shared.reserve(self)
        let controller = CitizenSDKWalletViewController(sdk: self, request: request) { [weak self] result in
            guard let self else { return }
            CitizenSDKWalletFlowRegistry.shared.finish(self, token: token)
            completion(result)
        }
        let navigation = UINavigationController(rootViewController: controller)
        navigation.modalPresentationStyle = .formSheet
        // Interactive dismissal would bypass prepared-secret cleanup and the
        // registry's exactly-once completion boundary.
        navigation.isModalInPresentation = true
        presenter.present(navigation, animated: true)
        return CitizenSDKWalletFlow { [weak controller] in
            DispatchQueue.main.async { controller?.requestCancel() }
        }
    }
}

@MainActor
private final class CitizenSDKWalletViewController: UIViewController {
    private let sdk: CitizenSdk
    private let request: CitizenSDKWalletFlowRequest
    private let completion: (CitizenSDKWalletFlowResult) -> Void
    private let mnemonic = UITextView()
    private let password = UITextField()
    private let passwordConfirmation = UITextField()
    private let action = UIButton(type: .system)
    private let status = UILabel()
    private let backup = UISwitch()
    private let backupLabel = UILabel()
    private var prepared: CitizenSDKPreparedWallet?
    private var phrase: CitizenSDKRecoveryPhrase?
    private var task: Task<Void, Never>?
    private var cancelRequested = false
    private var irreversible = false
    private var finished = false
    private var screenSecurity: CitizenSDKScreenSecurity?

    init(sdk: CitizenSdk, request: CitizenSDKWalletFlowRequest,
         completion: @escaping (CitizenSDKWalletFlowResult) -> Void) {
        self.sdk = sdk
        self.request = request
        self.completion = completion
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable) required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "公民钱包"
        view.backgroundColor = .systemBackground
        navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .cancel,
                                                            target: self, action: #selector(cancelPressed))
        configureControls()
        screenSecurity = CitizenSDKScreenSecurity(view: view)
    }

    private func configureControls() {
        mnemonic.font = .monospacedSystemFont(ofSize: 15, weight: .regular)
        mnemonic.layer.borderWidth = 1
        mnemonic.layer.borderColor = UIColor.separator.cgColor
        mnemonic.layer.cornerRadius = 8
        mnemonic.autocorrectionType = .no
        mnemonic.autocapitalizationType = .none
        mnemonic.spellCheckingType = .no
        mnemonic.smartQuotesType = .no
        mnemonic.smartDashesType = .no
        mnemonic.smartInsertDeleteType = .no
        mnemonic.accessibilityLabel = "助记词"
        mnemonic.heightAnchor.constraint(equalToConstant: 150).isActive = true

        password.placeholder = "钱包密码"
        password.isSecureTextEntry = true
        // This SDK-owned password must never be offered to AutoFill/Keychain.
        password.textContentType = nil
        password.autocorrectionType = .no
        password.smartQuotesType = .no
        password.smartDashesType = .no
        password.smartInsertDeleteType = .no
        passwordConfirmation.placeholder = "再次输入钱包密码"
        passwordConfirmation.isSecureTextEntry = true
        passwordConfirmation.textContentType = nil
        passwordConfirmation.autocorrectionType = .no
        passwordConfirmation.smartQuotesType = .no
        passwordConfirmation.smartDashesType = .no
        passwordConfirmation.smartInsertDeleteType = .no

        status.numberOfLines = 0
        status.textColor = .secondaryLabel
        backupLabel.text = "我已在离线安全位置备份助记词"
        backupLabel.numberOfLines = 0

        action.addTarget(self, action: #selector(actionPressed), for: .touchUpInside)
        action.configuration = .filled()
        let backupRow = UIStackView(arrangedSubviews: [backup, backupLabel])
        backupRow.axis = .horizontal
        backupRow.spacing = 12
        backupRow.alignment = .center

        let stack = UIStackView(arrangedSubviews: [status, mnemonic, password, passwordConfirmation, backupRow, action])
        stack.axis = .vertical
        stack.spacing = 16
        view.addSubview(stack)
        stack.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -20),
            stack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
        ])

        backupRow.isHidden = true
        switch request {
        case .create:
            mnemonic.isHidden = true
            action.setTitle("生成钱包", for: .normal)
            status.text = "助记词只会在本设备生成并显示。请离线备份后确认。"
        case .importWallet:
            passwordConfirmation.isHidden = true
            action.setTitle("导入钱包", for: .normal)
            status.text = "助记词和密码只在本设备的公民 SDK 内使用。"
        case .addAccounts:
            passwordConfirmation.isHidden = true
            action.setTitle("添加账户", for: .normal)
            status.text = "验证现有助记词后添加所选派生账户。"
        }
    }

    @objc private func actionPressed() {
        guard task == nil else { return }
        action.isEnabled = false
        if prepared != nil { commitCreatedWallet() } else { beginOperation() }
    }

    private func beginOperation() {
        do {
            let passwordText = password.text ?? ""
            try citizenSDKValidateWalletPassword(passwordText, confirmation: passwordConfirmation.text,
                                                 request: request)
            let passwordBuffer = try citizenSDKSensitiveText(passwordText, label: "password")
            password.text = nil
            passwordConfirmation.text = nil
            switch request {
            case let .create(wordCount):
                task = Task { [weak self] in
                    guard let self else { return }
                    defer { self.task = nil }
                    do {
                        let prepared = try await self.sdk.prepareWallet(wordCount: wordCount, password: passwordBuffer)
                        passwordBuffer.clear()
                        if self.cancelRequested {
                            self.finish(citizenSDKPreparedCancellationResult { try prepared.release() })
                            return
                        }
                        let phrase = try prepared.recoveryPhrase()
                        self.prepared = prepared
                        self.phrase = phrase
                        try phrase.render { self.mnemonic.text = $0 }
                        self.mnemonic.isEditable = false
                        self.mnemonic.isSelectable = false
                        self.mnemonic.isHidden = false
                        self.password.isHidden = true
                        self.passwordConfirmation.isHidden = true
                        self.backup.superview?.isHidden = false
                        self.action.setTitle("确认备份并创建", for: .normal)
                        self.action.isEnabled = true
                    } catch {
                        passwordBuffer.clear(); self.fail(error)
                    }
                }
            case .importWallet:
                irreversible = true
                let mnemonicBuffer = try citizenSDKSensitiveText(mnemonic.text, label: "mnemonic")
                mnemonic.text = nil
                task = Task { [weak self] in
                    guard let self else { return }
                    defer { mnemonicBuffer.clear(); passwordBuffer.clear(); self.task = nil }
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
                let mnemonicBuffer = try citizenSDKSensitiveText(mnemonic.text, label: "mnemonic")
                mnemonic.text = nil
                task = Task { [weak self] in
                    guard let self else { return }
                    defer { mnemonicBuffer.clear(); passwordBuffer.clear(); self.task = nil }
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
        guard backup.isOn, let prepared else {
            status.text = "请先确认已安全备份助记词。"
            action.isEnabled = true
            return
        }
        mnemonic.text = nil
        phrase?.clear(); phrase = nil
        irreversible = true
        task = Task { [weak self] in
            guard let self else { return }
            defer { self.task = nil }
            do { self.finish(.completed(try await self.sdk.commit(prepared))) }
            catch { self.fail(error) }
        }
    }

    @objc private func cancelPressed() { requestCancel() }
    func requestCancel() {
        guard !finished else { return }
        cancelRequested = true
        mnemonic.text = nil
        password.text = nil
        passwordConfirmation.text = nil
        phrase?.clear(); phrase = nil
        if task == nil {
            let result = prepared.map { prepared in
                citizenSDKPreparedCancellationResult { try prepared.release() }
            } ?? .cancelled
            prepared = nil
            finish(result)
        } else {
            status.text = "正在安全结束当前钱包操作…"
        }
    }

    private func fail(_ error: Error) {
        if let result = citizenSDKCancellationResult(cancelRequested: cancelRequested,
                                                     irreversible: irreversible, error: error) {
            finish(result); return
        }
        status.text = citizenSDKFlowError(error).message
        action.isEnabled = true
    }

    private func finish(_ result: CitizenSDKWalletFlowResult) {
        guard !finished else { return }
        finished = true
        screenSecurity?.finish(); screenSecurity = nil
        mnemonic.text = nil
        password.text = nil
        passwordConfirmation.text = nil
        phrase?.clear(); phrase = nil
        prepared = nil
        dismiss(animated: true) { self.completion(result) }
    }
}
#endif
