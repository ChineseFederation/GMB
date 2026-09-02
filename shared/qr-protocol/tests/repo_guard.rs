// 仓库结构守卫读取失败必须立即中止测试，断言式解包仅限本测试目标。
#![allow(clippy::expect_used, clippy::unwrap_used)]

use std::collections::BTreeSet;
use std::path::{Path, PathBuf};
use std::{env, fs};

use serde_json::Value;

/// GMB 只保留 GitHub 可发现的固定入口，产品流水线统一由冻结的 TATA 提交提供。
///
/// 这里仅验证公开委派边界，不复制 TATA 内部产品矩阵或 CI/Release 实现合同；后者由
/// TATA 仓库自己的测试负责，避免两个仓库维护两份会漂移的流程真源。
#[test]
fn github_workflow_entrypoints_delegate_to_single_tata_flow() {
    let repo_root = repo_root();
    let workflow_root = repo_root.join(".github/workflows");
    let mut violations = Vec::new();
    let mut entry_names = Vec::new();

    let entries = fs::read_dir(&workflow_root)
        .unwrap_or_else(|e| panic!("读取 {} 失败: {e}", workflow_root.display()));
    for entry in entries {
        let entry = entry.unwrap_or_else(|e| panic!("读取 GitHub Workflow 目录项失败: {e}"));
        let file_type = entry
            .file_type()
            .unwrap_or_else(|e| panic!("读取 {} 类型失败: {e}", entry.path().display()));
        let name = entry
            .file_name()
            .into_string()
            .unwrap_or_else(|_| panic!("{} 的文件名不是 UTF-8", entry.path().display()));
        if !file_type.is_file() {
            violations.push(format!(
                ".github/workflows/{name}: 统一入口目录只允许普通 Workflow 文件"
            ));
        }
        entry_names.push(name);
    }
    entry_names.sort();
    let expected_entries = vec!["flow.yml".to_string(), "repository.yml".to_string()];
    if entry_names != expected_entries {
        violations.push(format!(
            ".github/workflows 必须精确包含 flow.yml、repository.yml，实际为 {entry_names:?}"
        ));
    }

    let repository_entry =
        fs::read_to_string(workflow_root.join("repository.yml")).expect("读取 repository.yml 失败");
    let event_count = |source: &str, event: &str| {
        let expected = format!("{event}:");
        source
            .lines()
            .filter(|line| line.trim() == expected)
            .count()
    };
    if event_count(&repository_entry, "workflow_dispatch") != 1
        || event_count(&repository_entry, "workflow_call") != 0
    {
        violations
            .push("repository.yml: 必须且只能由一个 workflow_dispatch 接受显式调度".to_string());
    }
    for required in [
        "uses: ./.github/workflows/flow.yml",
        "pipeline: ${{ inputs.pipeline }}",
        "source_sha: ${{ inputs.source_sha }}",
        "secrets: inherit",
    ] {
        if !repository_entry.contains(required) {
            violations.push(format!("repository.yml: 缺少统一委派合同 {required}"));
        }
    }

    let reusable_flow =
        fs::read_to_string(workflow_root.join("flow.yml")).expect("读取 flow.yml 失败");
    if event_count(&reusable_flow, "workflow_call") != 1
        || event_count(&reusable_flow, "workflow_dispatch") != 0
    {
        violations.push(
            "flow.yml: 只能作为 workflow_call 可复用入口，禁止第二个显式调度入口".to_string(),
        );
    }
    for required in [
        "repository: VoyagerRhett/TATA",
        "path: .tata-flow",
        "FLOW_COMMIT_SHA",
        "git -C .tata-flow rev-parse HEAD",
        "uses: ./.tata-flow/tataconsole/flows/gmb/shared",
        "job: dispatch-product",
    ] {
        if !reusable_flow.contains(required) {
            violations.push(format!("flow.yml: 缺少冻结 TATA 中央流程合同 {required}"));
        }
    }

    // 每个消费中央流程的作业都必须在同一作业内完成冻结提交检出与回读；只检查全文件中
    // “曾经出现过”这些字符串会放过新增的未冻结调用。
    const CENTRAL_FLOW_USE: &str = "uses: ./.tata-flow/tataconsole/flows/gmb/shared";
    const LOCKED_REF: &str =
        "ref: \"${{ secrets[format('TATA_FLOW_COMMIT_SHA_{0}', inputs.lease_id)] }}\"";
    const LOCKED_TOKEN: &str =
        "token: \"${{ secrets[format('TATA_FLOW_READ_TOKEN_{0}', inputs.lease_id)] }}\"";
    const COMMIT_ENV: &str = "env: { FLOW_COMMIT_SHA: \"${{ secrets[format('TATA_FLOW_COMMIT_SHA_{0}', inputs.lease_id)] }}\" }";
    const COMMIT_READBACK: &str =
        "run: test \"$(git -C .tata-flow rev-parse HEAD)\" = \"$FLOW_COMMIT_SHA\"";
    let jobs_text = reusable_flow
        .split_once("\njobs:\n")
        .map(|(_, jobs)| jobs)
        .unwrap_or_else(|| {
            violations.push("flow.yml: 缺少 jobs 根节点".to_string());
            ""
        });
    let mut job_blocks: Vec<(String, String)> = Vec::new();
    let mut current_job: Option<(String, String)> = None;
    for line in jobs_text.lines() {
        let is_job_heading = line.starts_with("  ")
            && !line.starts_with("   ")
            && line.ends_with(':')
            && line.len() > 3;
        if is_job_heading {
            if let Some(job) = current_job.take() {
                job_blocks.push(job);
            }
            current_job = Some((line.trim_end_matches(':').trim().to_string(), String::new()));
        }
        if let Some((_, block)) = current_job.as_mut() {
            block.push_str(line);
            block.push('\n');
        }
    }
    if let Some(job) = current_job {
        job_blocks.push(job);
    }

    let mut central_job_count = 0;
    for (job_name, block) in &job_blocks {
        let central_call_count = block.matches(CENTRAL_FLOW_USE).count();
        if central_call_count == 0 {
            continue;
        }
        central_job_count += 1;
        for (contract, expected_count) in [
            (CENTRAL_FLOW_USE, 1),
            ("repository: VoyagerRhett/TATA", 1),
            (LOCKED_REF, 1),
            (LOCKED_TOKEN, 1),
            ("path: .tata-flow", 1),
            ("persist-credentials: false", 1),
            (COMMIT_ENV, 1),
            (COMMIT_READBACK, 1),
        ] {
            let actual_count = block.matches(contract).count();
            if actual_count != expected_count {
                violations.push(format!(
                    "flow.yml 作业 {job_name}: 冻结 TATA 委派合同 {contract} 应出现 {expected_count} 次，实际 {actual_count} 次"
                ));
            }
        }
    }
    let all_central_calls = reusable_flow.matches(CENTRAL_FLOW_USE).count();
    if central_job_count == 0 || central_job_count != all_central_calls {
        violations.push(format!(
            "flow.yml: 每个中央流程调用必须独占一个完成冻结检出与回读的作业，中央作业 {central_job_count} 个，调用 {all_central_calls} 次"
        ));
    }

    // 这里只限制 GitHub 会识别为本仓产品入口的一级产品根目录；内嵌上游依赖可能保留其
    // 来源仓库的 .github 元数据，但不会成为 GMB 仓库的可执行 Workflow。
    for product in [
        "citizenapp",
        "citizenchain",
        "citizenchatserver",
        "citizensdk",
        "citizenserve",
        "citizenwallet",
        "citizenweb",
    ] {
        let duplicate = repo_root.join(product).join(".github/workflows");
        if duplicate.exists() {
            violations.push(format!(
                "{}: 一级产品根目录禁止建立第二套 GMB GitHub Workflow",
                duplicate.display()
            ));
        }
    }

    assert!(
        violations.is_empty(),
        "GMB GitHub Workflow 统一委派守卫失败:\n{}",
        violations.join("\n")
    );
}

/// CitizenWallet 文档必须把公开 Android 平台名与官方 ABI 技术值分开表达。
#[test]
fn citizenwallet_documentation_separates_android_platform_from_abi() {
    let path = repo_root().join("citizenwallet/design-qa.md");
    let text =
        fs::read_to_string(&path).unwrap_or_else(|e| panic!("读取 {} 失败: {e}", path.display()));

    // Android 是公开平台名；`arm64-v8a` 只属于 Android 官方 ABI 技术值。
    assert!(
        text.contains("Android 的 `arm64-v8a` ABI 未签名 Release APK"),
        "{}: 缺少 Android 平台与 arm64-v8a ABI 的类型化表述",
        path.display()
    );
    assert!(
        !text.contains("Android ARM64"),
        "{}: 禁止把处理器架构拼进 Android 公开平台名",
        path.display()
    );
}

/// CitizenChain 源码注释必须用 Rust target triple 表达 `c_char` 的机器类型差异。
#[test]
fn citizenchain_device_password_uses_target_triples_for_c_char_types() {
    let path = repo_root().join("citizenchain/node/src/settings/device_password.rs");
    let text =
        fs::read_to_string(&path).unwrap_or_else(|e| panic!("读取 {} 失败: {e}", path.display()));

    for required in [
        "`aarch64-unknown-linux-gnu` 上为 `u8`",
        "`x86_64-unknown-linux-gnu` 上为 `i8`",
    ] {
        assert!(
            text.contains(required),
            "{}: 缺少官方 Rust target triple 与 c_char 类型合同 {required}",
            path.display()
        );
    }
    for forbidden in ["Linux ARM64", "ARM64 与 AMD64"] {
        assert!(
            !text.contains(forbidden),
            "{}: 禁止用架构拼接式公开平台名表达 Rust target 差异 {forbidden}",
            path.display()
        );
    }
}

/// CitizenChain macOS updater 必须把公开平台和交付用途拆成独立路径段。
#[test]
fn citizenchain_macos_updater_uses_typed_public_route() {
    let repo_root = repo_root();
    let tata_console_root = tata_flow_root()
        .parent()
        .expect("TATA_CONSOLE_FLOW_ROOT 必须位于 tataconsole/flows")
        .to_path_buf();
    let cases = [
        (
            "citizenchain/node/tauri.conf.json",
            repo_root.join("citizenchain/node/tauri.conf.json"),
            "/download/citizenchain/macOS/updater",
        ),
        (
            "citizenserve/src/downloads/citizenchain.ts",
            repo_root.join("citizenserve/src/downloads/citizenchain.ts"),
            "/download/citizenchain/macOS/updater",
        ),
        (
            "citizenserve/src/limits/catalog.ts",
            repo_root.join("citizenserve/src/limits/catalog.ts"),
            "macOS(?:\\/updater)?",
        ),
        (
            "TataConsole CitizenChainDownloadPublisher.swift",
            tata_console_root.join("app/Sources/CitizenChainDownloadPublisher.swift"),
            "/download/citizenchain/macOS/updater",
        ),
    ];

    let mut violations = Vec::new();
    for (label, path, required) in cases {
        let text = fs::read_to_string(&path)
            .unwrap_or_else(|e| panic!("读取 {} 失败: {e}", path.display()));
        if !text.contains(required) {
            violations.push(format!("{label}: 缺少类型化 macOS updater 路由 {required}"));
        }
        for forbidden in ["macos-arm64-updater", "macOS-updater"] {
            if text.contains(forbidden) {
                violations.push(format!("{label}: 禁止旧路由或复合平台名 {forbidden}"));
            }
        }
    }

    assert!(
        violations.is_empty(),
        "CitizenChain macOS updater 公开路由守卫失败:\n{}",
        violations.join("\n")
    );
}

/// CitizenChain 四端安装入口必须直接使用统一公开平台名，内部发布键不得泄漏到 URL。
#[test]
fn citizenchain_install_downloads_use_standard_public_routes() {
    let repo_root = repo_root();
    let tata_console_root = tata_flow_root()
        .parent()
        .expect("TATA_CONSOLE_FLOW_ROOT 必须位于 tataconsole/flows")
        .to_path_buf();
    let cases = [
        (
            "CitizenServe 下载映射",
            repo_root.join("citizenserve/src/downloads/citizenchain.ts"),
            [
                "'/download/citizenchain/macOS'",
                "'/download/citizenchain/Windows'",
                "'/download/citizenchain/LinuxARM'",
                "'/download/citizenchain/LinuxAMD'",
            ],
        ),
        (
            "CitizenWeb 下载菜单",
            repo_root.join("citizenweb/src/pages/Ecosystem.tsx"),
            [
                "'/download/citizenchain/macOS'",
                "'/download/citizenchain/Windows'",
                "'/download/citizenchain/LinuxARM'",
                "'/download/citizenchain/LinuxAMD'",
            ],
        ),
        (
            "TataConsole 下载发布验收",
            tata_console_root.join("app/Sources/CitizenChainDownloadPublisher.swift"),
            [
                "\"/download/citizenchain/macOS\"",
                "\"/download/citizenchain/Windows\"",
                "\"/download/citizenchain/LinuxARM\"",
                "\"/download/citizenchain/LinuxAMD\"",
            ],
        ),
    ];
    let forbidden_paths = [
        "/download/citizenchain/macos-arm64",
        "/download/citizenchain/windows-x86_64",
        "/download/citizenchain/linux-arm64",
        "/download/citizenchain/linux-amd64",
        "/download/citizenchain/linux-arm",
        "/download/citizenchain/linux-amd",
    ];
    let mut violations = Vec::new();
    for (label, path, required_paths) in cases {
        let text = fs::read_to_string(&path)
            .unwrap_or_else(|e| panic!("读取 {} 失败: {e}", path.display()));
        for required in required_paths {
            if !text.contains(required) {
                violations.push(format!("{label}: 缺少标准公开安装路径 {required}"));
            }
        }
        for forbidden in forbidden_paths {
            if text.contains(forbidden) {
                violations.push(format!("{label}: 禁止旧公开安装路径 {forbidden}"));
            }
        }
    }

    let catalog_path = repo_root.join("citizenserve/src/limits/catalog.ts");
    let catalog = fs::read_to_string(&catalog_path)
        .unwrap_or_else(|e| panic!("读取 {} 失败: {e}", catalog_path.display()));
    let typed_route = "citizenchain\\/(?:macOS(?:\\/updater)?|Windows|LinuxARM|LinuxAMD)";
    if !catalog.contains(typed_route) {
        violations.push(format!(
            "CitizenServe 限流白名单缺少标准公开安装路由 {typed_route}"
        ));
    }

    assert!(
        violations.is_empty(),
        "CitizenChain 四端公开安装路由守卫失败:\n{}",
        violations.join("\n")
    );
}

/// CitizenServe publication wire 与 TataConsole 动作输入是两个字段域，且必须共用一份跨仓 golden。
#[test]
fn citizenchain_download_publication_wire_is_cross_runtime_compatible() {
    let repo_root = repo_root();
    let tata_console_root = tata_flow_root()
        .parent()
        .expect("TATA_CONSOLE_FLOW_ROOT 必须位于 tataconsole/flows")
        .to_path_buf();
    let fixture_path =
        tata_console_root.join("test/citizenchain-download-publication-interop-v1.json");
    let fixture_text = fs::read_to_string(&fixture_path)
        .unwrap_or_else(|e| panic!("读取 {} 失败: {e}", fixture_path.display()));
    let fixture: Value = serde_json::from_str(&fixture_text)
        .unwrap_or_else(|e| panic!("解析 {} 失败: {e}", fixture_path.display()));
    let fixture_keys = fixture
        .as_object()
        .expect("下载发布互操作 golden 必须是 JSON 对象")
        .keys()
        .map(String::as_str)
        .collect::<BTreeSet<_>>();
    let expected_fixture_keys = [
        "action_tag_field",
        "contract_version",
        "download_path",
        "github_repository",
        "location",
        "platform",
        "publication_tag_field",
        "put_body_json",
        "snapshot_anchor",
        "snapshot_json",
    ]
    .into_iter()
    .collect::<BTreeSet<_>>();
    assert_eq!(fixture_keys, expected_fixture_keys, "golden 根字段闭集漂移");
    assert_eq!(fixture["contract_version"], 1);
    assert_eq!(fixture["github_repository"], "VoyagerRhett/GMB");
    assert_eq!(fixture["action_tag_field"], "release_tag");
    assert_eq!(fixture["publication_tag_field"], "version_tag");
    assert_eq!(fixture["platform"], "macos");
    assert_eq!(fixture["download_path"], "/download/citizenchain/macOS");
    assert_eq!(
        fixture["location"],
        "https://github.com/VoyagerRhett/GMB/releases/download/\
citizenchain-node-macos-v1.2.3/citizenchain-node-macos-arm64-v1.2.3.dmg"
    );
    assert_eq!(
        fixture["snapshot_anchor"],
        "ccdp:macos:1:b16f850a8f568f01f26e27b2ec6beba51d31f4b80d5b36b65b0351260dcd1906"
    );

    let put_body: Value = serde_json::from_str(
        fixture["put_body_json"]
            .as_str()
            .expect("golden put_body_json 必须是字符串"),
    )
    .expect("golden put_body_json 必须是合法 JSON");
    let put_keys = put_body
        .as_object()
        .expect("golden PUT body 必须是 JSON 对象")
        .keys()
        .map(String::as_str)
        .collect::<BTreeSet<_>>();
    assert_eq!(
        put_keys,
        ["expected_revision", "publication"]
            .into_iter()
            .collect::<BTreeSet<_>>()
    );
    let publication = put_body["publication"]
        .as_object()
        .expect("golden publication 必须是 JSON 对象");
    let publication_keys = publication
        .keys()
        .map(String::as_str)
        .collect::<BTreeSet<_>>();
    assert_eq!(
        publication_keys,
        ["asset_name", "asset_sha256", "source_sha", "version_tag"]
            .into_iter()
            .collect::<BTreeSet<_>>()
    );
    assert!(!publication.contains_key("release_tag"));

    let snapshot: Value = serde_json::from_str(
        fixture["snapshot_json"]
            .as_str()
            .expect("golden snapshot_json 必须是字符串"),
    )
    .expect("golden snapshot_json 必须是合法 JSON");
    let snapshot_object = snapshot
        .as_object()
        .expect("golden snapshot 必须是 JSON 对象");
    let snapshot_keys = snapshot_object
        .keys()
        .map(String::as_str)
        .collect::<BTreeSet<_>>();
    assert_eq!(
        snapshot_keys,
        [
            "asset_name",
            "asset_sha256",
            "platform",
            "published_at",
            "revision",
            "source_sha",
            "version_tag",
        ]
        .into_iter()
        .collect::<BTreeSet<_>>()
    );
    assert!(!snapshot_object.contains_key("release_tag"));

    let fixture_name = "citizenchain-download-publication-interop-v1.json";
    let serve_test_path =
        repo_root.join("citizenserve/test/citizenchain_download_publication.test.ts");
    let swift_test_path = tata_console_root.join("app/Tests/ViewContractTests.swift");
    let node_test_path = tata_console_root.join("test/native-ui.test.mjs");
    for path in [&serve_test_path, &swift_test_path, &node_test_path] {
        let text = fs::read_to_string(path)
            .unwrap_or_else(|e| panic!("读取 {} 失败: {e}", path.display()));
        assert!(
            text.contains(fixture_name),
            "{}: 必须消费唯一下载发布互操作 golden",
            path.display()
        );
    }

    let serve_source_path = repo_root.join("citizenserve/src/downloads/citizenchain.ts");
    let serve_source = fs::read_to_string(&serve_source_path)
        .unwrap_or_else(|e| panic!("读取 {} 失败: {e}", serve_source_path.display()));
    assert!(serve_source.contains("https://github.com/VoyagerRhett/GMB/releases/download/"));
    assert!(!serve_source.contains("ChineseFederation/GMB"));

    let swift_source_path =
        tata_console_root.join("app/Sources/CitizenChainDownloadPublisher.swift");
    let swift_source = fs::read_to_string(&swift_source_path)
        .unwrap_or_else(|e| panic!("读取 {} 失败: {e}", swift_source_path.display()));
    for required in [
        "\"version_tag\": input.releaseTag",
        "oldPublication[\"version_tag\"]",
        "\"revision\", \"source_sha\", \"version_tag\"",
        "Set(value.keys) == Set([\"product_id\", \"platform\", \"release_tag\", \"source_sha\"])",
        "https://github.com/VoyagerRhett/GMB/releases/download/",
    ] {
        assert!(
            swift_source.contains(required),
            "{}: 缺少跨字段域映射或权威仓库合同 {required}",
            swift_source_path.display()
        );
    }
    for forbidden in [
        "\"release_tag\": input.releaseTag",
        "oldPublication[\"release_tag\"]",
        "ChineseFederation/GMB",
    ] {
        assert!(
            !swift_source.contains(forbidden),
            "{}: 禁止 publication wire 旧字段或旧仓库所有者 {forbidden}",
            swift_source_path.display()
        );
    }
}

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
    let flow_root = tata_flow_root();
    let mut violations = Vec::new();

    for product in ["citizenapp", "citizenwallet"] {
        let workflow = format!("gmb/{product}/action.yml");
        let path = flow_root.join(&workflow);
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

    let workflow = "gmb/citizenchain-node/action.yml";
    let path = flow_root.join(workflow);
    let text =
        fs::read_to_string(&path).unwrap_or_else(|e| panic!("读取 {} 失败: {e}", path.display()));
    // 四个平台复用同一中央 Action；统一缓存指纹和共享适配器检查只维护一份真源。
    for required in [
        "**/package-lock.json",
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
    let flow_root = tata_flow_root();
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

    let workflow = "gmb/citizenchain-node/action.yml";
    let workflow_text = fs::read_to_string(flow_root.join(workflow))
        .unwrap_or_else(|e| panic!("读取 {workflow} 失败: {e}"));
    for required in [
        "从最终 DMG 提取并验证 macOS App",
        "com.apple.security.device.camera",
        "com.apple.security.cs.allow-jit",
        "com.apple.security.cs.allow-unsigned-executable-memory",
        "entitlement_key_path=",
        "plutil -extract \"$entitlement_key_path\"",
    ] {
        if !workflow_text.contains(required) {
            violations.push(format!("{workflow}: 缺少 macOS 摄像头宿主门禁 {required}"));
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
                "citizenchain/scripts/run.sh: TataConsole 产品入口禁止旧命令或 Debug 残留 {forbidden}"
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
    // 产品工作流已经集中到 TATA；本地脚本仍从 GMB 产品源码读取。
    for (relative, path) in [
        (
            "citizenchain/scripts/run.sh",
            repo_root.join("citizenchain/scripts/run.sh"),
        ),
        (workflow, flow_root.join(workflow)),
    ] {
        let text =
            fs::read_to_string(&path).unwrap_or_else(|e| panic!("读取 {relative} 失败: {e}"));
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

fn tata_flow_root() -> PathBuf {
    if let Some(path) = env::var_os("TATA_CONSOLE_FLOW_ROOT") {
        return PathBuf::from(path);
    }
    // 本机直接运行 cargo test 时从 GMB 与 TATA 的并列工作区解析；GitHub 始终显式注入环境变量。
    repo_root()
        .parent()
        .expect("GMB 必须位于三仓共同父目录")
        .join("TATA/tataconsole/flows")
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
