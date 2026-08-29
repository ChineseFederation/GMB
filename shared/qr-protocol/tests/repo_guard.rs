// 仓库结构守卫读取失败必须立即中止测试，断言式解包仅限本测试目标。
#![allow(clippy::expect_used, clippy::unwrap_used)]

use std::fs;
use std::path::{Path, PathBuf};

#[test]
fn qr_signing_protocol_has_no_second_registry_or_third_state() {
    let repo_root = repo_root();
    let mut violations = Vec::new();

    // 扫描根必须覆盖**全部**参与 QR/签名协议的端。漏一个端 = 守卫报绿而该端悄悄漂移:
    // 2026-08-06 的单字母键统一就因为这里缺了两个 `frontend/`,导致桌面矿工端
    // 「扫码识别账户」链路断掉而守卫毫无反应。新增任何端必须同步加进本列表。
    for root in [
        "citizenapp/lib",
        "citizenwallet/lib",
        "citizenchain/onchina/src",
        "citizenchain/onchina/frontend",
        "citizenchain/node/src",
        "citizenchain/node/frontend",
        "citizenchain/crates",
        "shared",
    ] {
        collect_files(&repo_root.join(root), &mut |path| {
            if should_scan(path) {
                scan_file(&repo_root, path, &mut violations);
            }
        });
    }

    assert!(
        violations.is_empty(),
        "QR 签名协议 guard 发现第二真源或第三状态残留:\n{}",
        violations.join("\n")
    );
}

/// 两个 React 工程的生成校验器必须逐字节相同。
#[test]
fn web_frontend_qr_modules_are_byte_identical() {
    let repo_root = repo_root();
    let node = repo_root.join("citizenchain/node/frontend/shared/qr/generated/qrBodies.g.ts");
    let onchina = repo_root.join("citizenchain/onchina/frontend/core/qr/generated/qrBodies.g.ts");

    let node_text =
        fs::read_to_string(&node).unwrap_or_else(|e| panic!("读取 {} 失败: {e}", node.display()));
    let onchina_text = fs::read_to_string(&onchina)
        .unwrap_or_else(|e| panic!("读取 {} 失败: {e}", onchina.display()));

    assert_eq!(
        node_text,
        onchina_text,
        "两个 React 前端的 QR body 生成校验器必须逐字节相同\n  {}\n  {}",
        node.display(),
        onchina.display()
    );
}

/// 生成器新增码型后，两个 React 业务适配器必须同时补齐类型映射和解析分支。
#[test]
fn web_frontend_qr_adapters_cover_all_registered_kinds() {
    let repo_root = repo_root();
    let kinds = qr_protocol::kinds().expect("读取统一 QrKind 注册表失败");

    for relative in [
        "citizenchain/node/frontend/shared/qr/citizenQr.ts",
        "citizenchain/onchina/frontend/core/citizenQr.ts",
    ] {
        let path = repo_root.join(relative);
        let text = fs::read_to_string(&path)
            .unwrap_or_else(|e| panic!("读取 {} 失败: {e}", path.display()));
        for kind in &kinds {
            assert!(
                text.contains(&format!("  {}:", kind.kind_key)),
                "{relative}: QrBodyByKind 缺少 {}",
                kind.kind_key
            );
            assert!(
                text.contains(&format!("case '{}':", kind.kind_key)),
                "{relative}: parseQrEnvelope 缺少 {}",
                kind.kind_key
            );
        }
    }
}

/// Flutter 产品不得绕过共享适配器直接依赖或导入 `mobile_scanner`。
#[test]
fn flutter_products_use_shared_scanner_adapter() {
    let repo_root = repo_root();
    let mut violations = Vec::new();

    for product in ["citizenapp", "citizenwallet"] {
        let pubspec = repo_root.join(product).join("pubspec.yaml");
        let text = fs::read_to_string(&pubspec)
            .unwrap_or_else(|e| panic!("读取 {} 失败: {e}", pubspec.display()));
        if text
            .lines()
            .any(|line| line.trim_start().starts_with("mobile_scanner:"))
        {
            violations.push(format!(
                "{product}/pubspec.yaml: Flutter 产品必须依赖 shared/scanner-flutter,禁止直连 mobile_scanner"
            ));
        }

        collect_files(&repo_root.join(product).join("lib"), &mut |path| {
            if path.extension().and_then(|ext| ext.to_str()) != Some("dart") {
                return;
            }
            let text = fs::read_to_string(path)
                .unwrap_or_else(|e| panic!("读取 {} 失败: {e}", path.display()));
            if text.contains("package:mobile_scanner/mobile_scanner.dart") {
                let display = path.strip_prefix(&repo_root).unwrap_or(path).display();
                violations.push(format!(
                    "{display}: Flutter 产品禁止直接导入 mobile_scanner"
                ));
            }
        });
    }

    assert!(
        violations.is_empty(),
        "Flutter 扫码适配器守卫失败:\n{}",
        violations.join("\n")
    );
}

/// React 共享扫码器固定使用 jsQR + canvas，不得恢复浏览器原生检测分支。
#[test]
fn react_scanner_uses_only_jsqr_and_canvas() {
    let repo_root = repo_root();
    let scanner_root = repo_root.join("shared/scanner-react/src");
    let mut violations = Vec::new();
    let mut combined = String::new();

    collect_files(&scanner_root, &mut |path| {
        if !should_scan(path) {
            return;
        }
        let text = fs::read_to_string(path)
            .unwrap_or_else(|e| panic!("读取 {} 失败: {e}", path.display()));
        let display = path.strip_prefix(&repo_root).unwrap_or(path).display();
        if text.contains("BarcodeDetector") {
            violations.push(format!(
                "{display}: React 共享扫码器禁止恢复 BarcodeDetector"
            ));
        }
        combined.push_str(&text);
    });

    for required in ["getUserMedia", "drawImage", "getImageData", "jsQR"] {
        if !combined.contains(required) {
            violations.push(format!(
                "shared/scanner-react/src: 缺少统一 jsQR + canvas 路线关键调用 {required}"
            ));
        }
    }

    assert!(
        violations.is_empty(),
        "React 扫码技术路线守卫失败:\n{}",
        violations.join("\n")
    );
}

/// Node 与 OnChina 必须统一消费共享 React 扫码器，不得保留产品内设备实现。
#[test]
fn react_products_use_shared_scanner_adapter() {
    let repo_root = repo_root();
    let mut violations = Vec::new();

    for frontend in [
        "citizenchain/node/frontend",
        "citizenchain/onchina/frontend",
    ] {
        let package_json = repo_root.join(frontend).join("package.json");
        let manifest = fs::read_to_string(&package_json)
            .unwrap_or_else(|e| panic!("读取 {} 失败: {e}", package_json.display()));
        if !manifest.contains("\"@gmb/scanner-react\"") {
            violations.push(format!(
                "{frontend}/package.json: React 产品必须依赖 @gmb/scanner-react"
            ));
        }
        if manifest
            .lines()
            .any(|line| line.trim_start().starts_with("\"jsqr\":"))
        {
            violations.push(format!(
                "{frontend}/package.json: React 产品禁止直接依赖 jsqr"
            ));
        }
        let npmrc = repo_root.join(frontend).join(".npmrc");
        let npmrc_text = fs::read_to_string(&npmrc)
            .unwrap_or_else(|e| panic!("读取 {} 失败: {e}", npmrc.display()));
        if !npmrc_text
            .lines()
            .any(|line| line.trim() == "install-links=true")
        {
            violations.push(format!(
                "{frontend}/.npmrc: 本地共享扫码包必须使用 install-links=true 独立安装"
            ));
        }

        collect_files(&repo_root.join(frontend), &mut |path| {
            if !should_scan(path) {
                return;
            }
            let text = fs::read_to_string(path)
                .unwrap_or_else(|e| panic!("读取 {} 失败: {e}", path.display()));
            let display = path.strip_prefix(&repo_root).unwrap_or(path).display();
            for forbidden in ["BarcodeDetector", "from 'jsqr'", "from \"jsqr\""] {
                if text.contains(forbidden) {
                    violations.push(format!("{display}: React 产品扫码源码禁止恢复 {forbidden}"));
                }
            }
        });

        let old_scanner = repo_root
            .join(frontend)
            .join(if frontend.contains("/node/") {
                "shared/qr/cameraScanner.ts"
            } else {
                "utils/cameraScanner.ts"
            });
        if old_scanner.exists() {
            violations.push(format!(
                "{}: 产品内旧扫码设备实现必须删除",
                old_scanner
                    .strip_prefix(&repo_root)
                    .unwrap_or(&old_scanner)
                    .display()
            ));
        }

        let business_entries: &[&str] = if frontend.contains("/node/") {
            &["shared/qr/QrScanner.tsx"]
        } else {
            &[
                "core/CitizenSignaturePanel.tsx",
                "core/ScanAccountModal.tsx",
            ]
        };
        for entry in business_entries {
            let path = repo_root.join(frontend).join(entry);
            let text = fs::read_to_string(&path)
                .unwrap_or_else(|e| panic!("读取 {} 失败: {e}", path.display()));
            if !text.contains("from '@gmb/scanner-react'") {
                violations.push(format!(
                    "{frontend}/{entry}: React 扫码业务入口必须复用共享适配器"
                ));
            }
        }
    }

    assert!(
        violations.is_empty(),
        "React 产品共享扫码适配器守卫失败:\n{}",
        violations.join("\n")
    );
}

/// 每个移动端 CI 与每个节点端 CI 都必须真实验证共享扫码包。
#[test]
fn product_ci_runs_shared_scanner_gates() {
    let repo_root = repo_root();
    let mut violations = Vec::new();

    for workflow in [
        ".github/workflows/citizenapp/ci-ios.yml",
        ".github/workflows/citizenapp/ci-android.yml",
        ".github/workflows/citizenwallet/ci-ios.yml",
        ".github/workflows/citizenwallet/ci-android.yml",
    ] {
        let path = repo_root.join(workflow);
        let text = fs::read_to_string(&path)
            .unwrap_or_else(|e| panic!("读取 {} 失败: {e}", path.display()));
        for required in [
            "working-directory: shared/scanner-flutter",
            "flutter analyze",
            "flutter test",
        ] {
            if !text.contains(required) {
                violations.push(format!("{workflow}: 缺少 Flutter 共享扫码门禁 {required}"));
            }
        }
    }

    for workflow in [
        ".github/workflows/citizenchain/ci-node-linux-arm.yaml",
        ".github/workflows/citizenchain/ci-node-linux-amd.yml",
        ".github/workflows/citizenchain/ci-node-macos.yml",
        ".github/workflows/citizenchain/ci-node-windows.yml",
    ] {
        let path = repo_root.join(workflow);
        let text = fs::read_to_string(&path)
            .unwrap_or_else(|e| panic!("读取 {} 失败: {e}", path.display()));
        for required in [
            "shared/scanner-react/package-lock.json",
            "npm --prefix shared/scanner-react ci",
            "npm --prefix shared/scanner-react run check",
            "npm --prefix shared/scanner-react test",
            "npm --prefix citizenchain/node/frontend ci",
            "npm --prefix citizenchain/node/frontend run build",
            "npm --prefix citizenchain/onchina/frontend ci",
            "npm --prefix citizenchain/onchina/frontend run build",
        ] {
            if !text.contains(required) {
                violations.push(format!(
                    "{workflow}: 缺少 React 共享扫码或消费者门禁 {required}"
                ));
            }
        }
    }

    assert!(
        violations.is_empty(),
        "共享扫码 CI 门禁失败:\n{}",
        violations.join("\n")
    );
}

/// Node 的 macOS 扫码必须由完整签名 App 承担，禁止恢复裸二进制启动。
#[test]
fn node_macos_camera_capability_is_bundled_and_verified() {
    let repo_root = repo_root();
    // 正式本机 App 必须用动态配置注入资源，再按同一命令顺序传入锁定编译参数。
    let tauri_build_start =
        "node frontend/node_modules/@tauri-apps/cli/tauri.js build --config \"$tauri_override\"";
    let tauri_build_locked = "--no-bundle --ci -- --locked";
    let tauri_bundle_start =
        "node frontend/node_modules/@tauri-apps/cli/tauri.js bundle --config \"$tauri_override\"";
    let tauri_bundle_app = "--bundles app --ci";
    let cases = [
        (
            "citizenchain/node/Entitlements.plist",
            &[
                "com.apple.security.device.camera",
                "com.apple.security.cs.allow-jit",
                "com.apple.security.cs.allow-unsigned-executable-memory",
                "<true/>",
            ][..],
        ),
        (
            "citizenchain/node/tauri.conf.json",
            &["\"entitlements\": \"Entitlements.plist\""][..],
        ),
        (
            "citizenchain/node/Info.plist",
            &["NSCameraUsageDescription"][..],
        ),
        (
            "citizenchain/scripts/run.sh",
            &[
                "APPLE_SIGNING_IDENTITY",
                "MACOS_SIGNING_IDENTITY='Developer ID Application: WEI CHENG (MHYMVRN6FC)'",
                "MACOS_TEAM_ID='MHYMVRN6FC'",
                "cargo build --release -p onchina",
                tauri_build_start,
                tauri_build_locked,
                tauri_bundle_start,
                tauri_bundle_app,
                "$TARGET_DIR/release/bundle/macos/citizenchain.app",
                "codesign --verify --deep --strict",
                "Authority=$MACOS_SIGNING_IDENTITY",
                "TeamIdentifier=$MACOS_TEAM_ID",
                "^Timestamp=",
                "com\\.apple\\.security\\.get-task-allow",
                "entitlement_key_path=",
                "plutil -extract \"$entitlement_key_path\"",
                "open \"${open_args[@]}\" \"$app_bundle\"",
            ][..],
        ),
        (
            ".github/workflows/citizenchain/ci-node-macos.yml",
            &[
                "从最终 DMG 提取并验证 macOS App",
                "com.apple.security.device.camera",
                "com.apple.security.cs.allow-jit",
                "com.apple.security.cs.allow-unsigned-executable-memory",
                "entitlement_key_path=",
                "plutil -extract \"$entitlement_key_path\"",
            ][..],
        ),
    ];

    let mut violations = Vec::new();
    for (relative, required_values) in cases {
        let path = repo_root.join(relative);
        let text = fs::read_to_string(&path)
            .unwrap_or_else(|e| panic!("读取 {} 失败: {e}", path.display()));
        for required in required_values {
            if !text.contains(required) {
                violations.push(format!("{relative}: 缺少 macOS 摄像头宿主门禁 {required}"));
            }
        }
    }

    let run_script = fs::read_to_string(repo_root.join("citizenchain/scripts/run.sh"))
        .expect("读取 Node 启动脚本失败");
    for forbidden in ["-o /dev/stdout", "--stderr /dev/stderr"] {
        if run_script.contains(forbidden) {
            violations.push(format!(
                "citizenchain/scripts/run.sh: 禁止恢复会触发 LaunchServices -10810 的 {forbidden}"
            ));
        }
    }
    for forbidden in [
        "cargo tauri",
        "node frontend/node_modules/@tauri-apps/cli/tauri.js build --bundles app --ci",
        "target/debug/onchina",
        "$TARGET_DIR/debug/bundle/macos/citizenchain.app",
    ] {
        if run_script.contains(forbidden) {
            violations.push(format!(
                "citizenchain/scripts/run.sh: ProgramConsole 产品入口禁止旧命令或 Debug 残留 {forbidden}"
            ));
        }
    }
    let compile_position = run_script
        .find(tauri_build_start)
        .expect("上方必需值检查应已确认 Tauri 编译命令存在");
    let locked_position = run_script[compile_position..]
        .find(tauri_build_locked)
        .map(|position| compile_position + position)
        .expect("上方必需值检查应已确认 Tauri 锁定编译参数存在");
    let bundle_position = run_script
        .find(tauri_bundle_start)
        .expect("上方必需值检查应已确认 Tauri 封装命令存在");
    // 动态封装配置必须先于 App 参数，防止门禁只命中散落字符串却放过错误执行顺序。
    let bundle_app_position = run_script[bundle_position..]
        .find(tauri_bundle_app)
        .map(|position| bundle_position + position)
        .expect("上方必需值检查应已确认 Tauri 封装参数存在");
    if compile_position >= locked_position
        || locked_position >= bundle_position
        || bundle_position >= bundle_app_position
    {
        violations.push(
            "citizenchain/scripts/run.sh: Tauri 必须先完成 Release 编译再封装 macOS App"
                .to_string(),
        );
    }
    for relative in [
        "citizenchain/scripts/run.sh",
        ".github/workflows/citizenchain/ci-node-macos.yml",
    ] {
        let text = fs::read_to_string(repo_root.join(relative))
            .unwrap_or_else(|e| panic!("读取 {relative} 失败: {e}"));
        if text.contains("plutil -extract \"$entitlement\"") {
            violations.push(format!(
                "{relative}: entitlement 点号未转义会被 plutil 误作多层 key path"
            ));
        }
    }

    assert!(
        violations.is_empty(),
        "Node macOS 摄像头宿主门禁失败:\n{}",
        violations.join("\n")
    );
}

fn repo_root() -> PathBuf {
    Path::new(env!("CARGO_MANIFEST_DIR"))
        .parent()
        .and_then(Path::parent)
        .expect("qr-protocol 必须位于 shared/qr-protocol")
        .to_path_buf()
}

fn collect_files(dir: &Path, visit: &mut impl FnMut(&Path)) {
    let Ok(entries) = fs::read_dir(dir) else {
        return;
    };
    for entry in entries.flatten() {
        let path = entry.path();
        if should_skip_path(&path) {
            continue;
        }
        if path.is_dir() {
            collect_files(&path, visit);
        } else {
            visit(&path);
        }
    }
}

fn should_skip_path(path: &Path) -> bool {
    let text = path.to_string_lossy();
    text.contains("/target/")
        || text.contains("/build/")
        || text.contains("/dist/")
        || text.contains("/.dart_tool/")
        || text.contains("/node_modules/")
        || text.contains("/generated/")
        || text.ends_with(".g.dart")
        || text.contains("/shared/qr-protocol/registry/")
        || text.contains("/shared/qr-protocol/tests/")
        || text.ends_with("/shared/qr-protocol/src/export.rs")
}

fn should_scan(path: &Path) -> bool {
    matches!(
        path.extension().and_then(|ext| ext.to_str()),
        Some("dart" | "rs" | "ts" | "tsx" | "js" | "jsx")
    )
}

fn scan_file(repo_root: &Path, path: &Path, violations: &mut Vec<String>) {
    let Ok(text) = fs::read_to_string(path) else {
        return;
    };
    let display = path
        .strip_prefix(repo_root)
        .unwrap_or(path)
        .to_string_lossy()
        .into_owned();

    for forbidden in [
        "gmb://account/",
        "legacyAddress",
        "GMB_ACCOUNT_RE",
        "void _requireExactKeys(",
        "function requireExactKeys(",
    ] {
        if text.contains(forbidden) {
            violations.push(format!(
                "{display}: 扫码生产代码禁止保留旧二维码格式或旧路由 {forbidden}"
            ));
        }
    }

    // 移动端只能消费 GeneratedQrActionRegistry,不得恢复手写 action/字段中文表。
    reject_contains(
        &text,
        &display,
        "actionLabels = {",
        "禁止恢复手写 actionLabels 中文表,必须消费 qr-protocol 生成产物",
        violations,
    );
    reject_contains(
        &text,
        &display,
        "actionKeyByCode = {",
        "禁止恢复手写 actionKeyByCode,必须消费 qr-protocol 生成产物",
        violations,
    );
    reject_contains(
        &text,
        &display,
        "actionLabelZhByKey = {",
        "禁止恢复手写 actionLabelZhByKey,必须消费 qr-protocol 生成产物",
        violations,
    );
    reject_contains(
        &text,
        &display,
        "fieldLabelZhByKey = {",
        "禁止恢复手写 fieldLabelZhByKey,必须消费 qr-protocol 生成产物",
        violations,
    );
    reject_contains(
        &text,
        &display,
        "_squareFieldLabels",
        "禁止在广场动作解码器恢复局部字段中文表",
        violations,
    );

    if text.contains("fieldLabelTextOrNull(String key)") && text.contains("return switch (key)") {
        violations.push(format!(
            "{display}: 禁止在 fieldLabelTextOrNull 中恢复手写字段 switch"
        ));
    }

    // OnChina 非链 action code 必须从 registry 读取,不得恢复 1/2/3 硬编码常量。
    for (symbol, value) in [
        ("ACTION_LOGIN", "1"),
        ("ACTION_CITIZEN_IDENTITY", "2"),
        ("ACTION_ONCHINA_ADMIN", "3"),
    ] {
        for (line_no, line) in text.lines().enumerate() {
            if line.contains(symbol)
                && !line.contains("_CODE")
                && (line.contains(&format!("= {value}"))
                    || line.contains(&format!(": u16 = {value}")))
            {
                violations.push(format!(
                    "{display}:{}: 禁止恢复 {symbol} = {value} 硬编码,必须从 qr-protocol registry 读取",
                    line_no + 1
                ));
            }
        }
    }
    reject_contains(
        &text,
        &display,
        "QR_ACTION_ONCHINA_ADMIN",
        "禁止恢复旧 QR_ACTION_ONCHINA_ADMIN 别名",
        violations,
    );
    reject_contains(
        &text,
        &display,
        "QR_ACTION_SQUARE_ACCOUNT",
        "禁止恢复旧 QR_ACTION_SQUARE_ACCOUNT 别名",
        violations,
    );

    // Runtime hash-only 允许列表来自 registry 生成集合,不得在端侧手写 action == A || action == B。
    if text.contains("isRuntimeHashOnly(int action) =>\n      action ==") {
        violations.push(format!(
            "{display}: 禁止恢复手写 hash-only action 列表,必须消费 GeneratedQrActionRegistry.isHashOnlyAction"
        ));
    }

    // 离线签名只允许 normal / reject 两态。
    if text.contains("enum SignDecisionStatus")
        && !text.contains("enum SignDecisionStatus { normal, reject }")
    {
        violations.push(format!(
            "{display}: SignDecisionStatus 只能是 normal/reject 两态"
        ));
    }
    for forbidden in ["decodeFailed", "partialRecognized", "warningButSignable"] {
        if text.contains(forbidden) {
            violations.push(format!(
                "{display}: 禁止恢复签名第三状态或可签名警告态 {forbidden}"
            ));
        }
    }

    // 用户确认页不得把不可理解内容兜底显示给用户后继续签名。
    for (line_no, line) in text.lines().enumerate() {
        if line.contains("载荷 ${") && line.contains("字节") {
            violations.push(format!(
                "{display}:{}: 禁止展示“载荷 N 字节”作为签名确认兜底",
                line_no + 1
            ));
        }
        let displays_numeric_action = (line.contains("动作 ${") || line.contains("动作：${"))
            && (line.contains("body.action")
                || line.contains("actionCode")
                || line.contains("action.toString")
                || line.contains("request.body.action"));
        if displays_numeric_action {
            violations.push(format!(
                "{display}:{}: 禁止展示动作数字作为签名确认兜底",
                line_no + 1
            ));
        }
    }
}

fn reject_contains(
    text: &str,
    display: &str,
    needle: &str,
    reason: &str,
    violations: &mut Vec<String>,
) {
    if text.contains(needle) {
        violations.push(format!("{display}: {reason}"));
    }
}
