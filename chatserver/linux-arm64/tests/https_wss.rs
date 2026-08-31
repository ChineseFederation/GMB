use chatserver_linux::{server::REALTIME_ROUTE, Config};

fn secure_config() -> String {
    r#"
[server]
bind = "[::1]:8443"
public_url = "https://chat.example.com"
app_id = "example.chat.app"
tls_certificate = "/tmp/cert.pem"
tls_private_key = "/tmp/key.pem"
cleanup_interval_seconds = 300

[database]
url = "postgresql://chatserver:secret@localhost/chatserver?sslmode=require"
max_connections = 4

[storage]
object_directory = "/tmp/chatserver-objects"
max_attachment_bytes = 1024

[auth]
issuer = "https://identity.example.com"
audience = "chatserver"
ed25519_public_key = "/tmp/jwt-public.pem"
"#
    .to_owned()
}

#[test]
fn accepts_only_secure_public_origin() {
    assert!(Config::from_toml(&secure_config()).is_ok());
    let insecure =
        secure_config().replacen("https://chat.example.com", "ftp://chat.example.com", 1);
    assert!(Config::from_toml(&insecure).is_err());
}

#[test]
fn realtime_is_on_the_same_tls_application() {
    assert_eq!(REALTIME_ROUTE, "/realtime");
    assert!(!secure_config().contains("plaintext"));
}

#[test]
fn deployment_has_one_explicit_push_application_identity() {
    assert!(secure_config().contains("app_id = \"example.chat.app\""));
}
