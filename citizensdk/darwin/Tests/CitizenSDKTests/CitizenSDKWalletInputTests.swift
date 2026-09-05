import XCTest
@testable import CitizenSDK
#if os(macOS)
import AppKit
#endif

/// 真实调用链接的 Rust C ABI，防止界面测试只验证文案或复制另一套密码算法。
final class CitizenSDKWalletInputTests: XCTestCase {
    func testOptionalPasswordAndCoreValidation() throws {
        try CitizenSDKWalletInput.validatePassword("")
        try CitizenSDKWalletInput.validatePassword("六个中性汉字")
        try CitizenSDKWalletInput.validatePassword("abcdef")
        for rejected in ["abcde", String(repeating: "a", count: 31), "abc def", "abcde\n", "abcdef🙂"] {
            XCTAssertThrowsError(try CitizenSDKWalletInput.validatePassword(rejected))
        }
    }

    func testAllThreeWordCountsAndChecksumAreValidatedByCore() throws {
        XCTAssertEqual(CitizenSDKWalletInput.wordCounts, [12, 18, 24])
        // BIP39 公开全零熵测试向量，不是真实用户助记词。
        for (count, checksumWord) in [(12, "about"), (18, "agent"), (24, "art")] {
            let phrase = (Array(repeating: "abandon", count: count - 1) + [checksumWord]).joined(separator: " ")
            try CitizenSDKWalletInput.validateMnemonic(phrase, wordCount: UInt32(count))
            XCTAssertThrowsError(try CitizenSDKWalletInput.validateMnemonic(phrase, wordCount: 15))
            XCTAssertThrowsError(try CitizenSDKWalletInput.validateMnemonic(phrase, wordCount: 21))
            XCTAssertThrowsError(try CitizenSDKWalletInput.validateMnemonic(phrase + " absent", wordCount: UInt32(count)))
        }
        XCTAssertThrowsError(try CitizenSDKWalletInput.validateMnemonic(Array(repeating: "abandon", count: 12).joined(separator: " "), wordCount: 12))
    }

    func testLocalCompletionUsesOnlyOfficialEnglishWords() throws {
        XCTAssertEqual(try CitizenSDKWalletInput.suggestions(""), [])
        XCTAssertEqual(try CitizenSDKWalletInput.suggestions("aban"), ["abandon"])
        let matches = try CitizenSDKWalletInput.suggestions("a")
        XCTAssertEqual(matches.count, 6)
        XCTAssertTrue(matches.allSatisfy { $0.hasPrefix("a") })
        XCTAssertThrowsError(try CitizenSDKWalletInput.suggestions("Ab"))
        XCTAssertThrowsError(try CitizenSDKWalletInput.suggestions("ab cd"))
    }

    func testNextAccountUsesMaximumNotCountAndIndicesAreExplicit() throws {
        XCTAssertEqual(try CitizenSDKWalletInput.nextIndex([0, 7, 2]), [8])
        XCTAssertEqual(try CitizenSDKWalletInput.indices("1，7 1989"), [1, 7, 1989])
        XCTAssertThrowsError(try CitizenSDKWalletInput.nextIndex([1_989]))
        for text in ["", "0", "1990", "1,1", "1,no"] {
            XCTAssertThrowsError(try CitizenSDKWalletInput.indices(text))
        }
    }

    func testCompletionUsesCaretWordWithoutTouchingFollowingWords() throws {
        let text = "aban absent ability"
        let first = try XCTUnwrap(CitizenSDKWalletInput.completion(text, selection: NSRange(location: 4, length: 0)))
        XCTAssertEqual(first.prefix, "aban")
        XCTAssertEqual(first.range, NSRange(location: 0, length: 4))
        let middle = try XCTUnwrap(CitizenSDKWalletInput.completion(text, selection: NSRange(location: 7, length: 0)))
        XCTAssertEqual(middle.prefix, "ab")
        XCTAssertEqual(middle.range, NSRange(location: 5, length: 6))
        XCTAssertNil(CitizenSDKWalletInput.completion(text, selection: NSRange(location: 5, length: 0)))
        XCTAssertNil(CitizenSDKWalletInput.completion(text, selection: NSRange(location: 0, length: 4)))
    }

    func testCancellationBeforeAdmissionClearsBothBuffersBeforeCallback() {
        let mnemonic = CitizenSDKSensitiveBuffer(data: Data([1, 2, 3]))
        let password = CitizenSDKSensitiveBuffer(data: Data([4, 5, 6]))
        var callbacks = 0
        citizenSDKAfterClearingSecrets([mnemonic, password]) {
            XCTAssertTrue(mnemonic.isClearedForTesting)
            XCTAssertTrue(password.isClearedForTesting)
            callbacks += 1
        }
        XCTAssertEqual(callbacks, 1)
    }

    #if os(macOS)
    @MainActor
    func testRealMacOSWalletWindowInputAndRiskCancellation() async throws {
        guard let directory = ProcessInfo.processInfo.environment["CITIZENSDK_WALLET_INPUT_STORAGE"] else {
            throw XCTSkip("真实窗口验收须提供独立中央存储目录和测试 Bundle 身份")
        }
        _ = NSApplication.shared
        let testFile = URL(fileURLWithPath: #filePath)
        let sdkRoot = testFile.deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let assetRoot = sdkRoot.appendingPathComponent("assets/citizenchain", isDirectory: true)
        let assets = try CitizenSDKAssets(manifest: Data(contentsOf: assetRoot.appendingPathComponent("manifest.json")),
                                         chainSpec: Data(contentsOf: assetRoot.appendingPathComponent("chainspec.json")),
                                         lightSyncState: Data(contentsOf: assetRoot.appendingPathComponent("light_sync_state.json")))
        let sdk = try CitizenSdk.open(storageRoot: URL(fileURLWithPath: directory, isDirectory: true),
                                     applicationID: "org.citizen.sdk.wallet-input.tests", assets: assets)
        let parent = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 680, height: 820), styleMask: [.titled], backing: .buffered, defer: false)
        parent.makeKeyAndOrderFront(nil)
        defer { parent.orderOut(nil); try? sdk.close() }
        var terminal: CitizenSDKWalletFlowResult?
        let flow = try sdk.presentWalletFlow(from: parent, request: .create(wordCount: 12)) { terminal = $0 }
        defer { flow.cancel() }
        let sheet = try XCTUnwrap(parent.attachedSheet)
        func descendants(_ view: NSView) -> [NSView] { [view] + view.subviews.flatMap(descendants) }
        let controls = descendants(try XCTUnwrap(sheet.contentView))
        let selector = try XCTUnwrap(controls.compactMap { $0 as? NSPopUpButton }.first { $0.itemTitles == ["12 词", "18 词", "24 词"] })
        for index in 0..<3 { selector.selectItem(at: index); XCTAssertEqual(selector.indexOfSelectedItem, index) }
        let passwords = controls.compactMap { $0 as? NSSecureTextField }
        XCTAssertEqual(passwords.count, 1)
        let password = try XCTUnwrap(passwords.first)
        XCTAssertEqual(password.placeholderString, "钱包密码（选填）")
        password.stringValue = "abcdef" // 公开合成输入，只验证风险取消，不调用钱包创建。
        let generate = try XCTUnwrap(controls.compactMap { $0 as? NSButton }.first { $0.title == "生成钱包" })
        generate.performClick(nil)
        let risk = try XCTUnwrap(sheet.attachedSheet)
        let riskCancel = try XCTUnwrap(descendants(try XCTUnwrap(risk.contentView)).compactMap { $0 as? NSButton }.first { $0.title == "取消" })
        riskCancel.performClick(nil)
        try await Task.sleep(nanoseconds: 100_000_000)
        XCTAssertEqual(password.stringValue, "abcdef", "风险取消保留明确输入，不能静默切换为空密码")
        XCTAssertTrue(generate.isEnabled)
        let profile = try await sdk.walletProfile()
        XCTAssertNil(profile, "风险取消不得持久化钱包")
        flow.cancel()
        try await Task.sleep(nanoseconds: 100_000_000)
        if case .cancelled = terminal { } else { XCTFail("窗口应准确返回取消") }
        XCTAssertEqual(password.stringValue, "")
        terminal = nil
        let importing = try sdk.presentWalletFlow(from: parent, request: .importWallet) { terminal = $0 }
        defer { importing.cancel() }
        let importSheet = try XCTUnwrap(parent.attachedSheet)
        let controller = try XCTUnwrap(importSheet.contentViewController as? CitizenSDKWalletViewControllerMacOS)
        let importControls = descendants(try XCTUnwrap(importSheet.contentView))
        let phrase = try XCTUnwrap(importControls.compactMap { $0 as? NSTextView }.first)
        phrase.string = "aban absent ability"
        phrase.setSelectedRange(NSRange(location: 4, length: 0))
        controller.textDidChange(Notification(name: NSText.didChangeNotification, object: phrase))
        let completion = try XCTUnwrap(descendants(try XCTUnwrap(importSheet.contentView)).compactMap { $0 as? NSButton }.first { $0.title == "abandon" })
        completion.performClick(nil)
        XCTAssertEqual(phrase.string, "abandon absent ability", "补全必须保留后面的单词")
        importing.cancel()
        try await Task.sleep(nanoseconds: 100_000_000)
        XCTAssertEqual(phrase.string, "")
        parent.orderOut(nil)
        try sdk.close()
    }
    #endif
}
