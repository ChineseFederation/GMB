const INSTALL: &str = include_str!("../package/install.sh");
const UNINSTALL: &str = include_str!("../package/uninstall.sh");
const UNIT: &str = include_str!("../package/chatserver.service");

#[test]
fn installer_is_arm64_local_and_refuses_existing_state() {
    assert!(INSTALL.contains("aarch64|arm64"));
    assert!(INSTALL.contains("禁止覆盖或兼容安装"));
    assert!(INSTALL.contains("chatserver init"));
    assert!(INSTALL.contains("schema_initialized"));
    assert!(INSTALL.contains("chatserver purge"));
    assert!(!INSTALL.contains("curl "));
    assert!(!INSTALL.contains("wget "));
}

#[test]
fn systemd_and_uninstaller_enforce_private_runtime() {
    assert!(UNIT.contains("User=chatserver"));
    assert!(UNIT.contains("ProtectSystem=strict"));
    assert!(UNIT.contains("ReadWritePaths=/var/lib/chatserver"));
    assert!(UNINSTALL.contains("chatserver purge"));
    assert!(UNINSTALL.contains("rm -rf /etc/chatserver /var/lib/chatserver /usr/share/chatserver"));
}
