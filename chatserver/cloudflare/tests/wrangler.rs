use serde_json::Value;

fn config() -> Value {
    serde_json::from_str(include_str!("../wrangler.jsonc")).expect("wrangler.jsonc must be JSON")
}

#[test]
fn all_runtime_bindings_are_declared_once() {
    let config = config();
    assert_eq!(config["d1_databases"][0]["binding"], "CHAT_DB");
    assert_eq!(config["r2_buckets"][0]["binding"], "CHAT_ATTACHMENTS");
    assert_eq!(
        config["durable_objects"]["bindings"][0]["name"],
        "CHAT_REALTIME"
    );
    assert_eq!(config["triggers"]["crons"][0], "* * * * *");
    assert_eq!(config["vars"]["CHAT_APP_ID"], "replace.chat.app");
}

#[test]
fn durable_object_registration_is_not_an_application_schema_track() {
    let config = config();
    let registration = &config["migrations"];
    assert_eq!(registration.as_array().map(Vec::len), Some(1));
    assert_eq!(registration[0]["new_sqlite_classes"][0], "ChatRealtime");
    assert!(!std::path::Path::new(env!("CARGO_MANIFEST_DIR"))
        .join("migrations")
        .exists());
}

#[test]
fn public_urls_and_build_dependencies_are_secure_and_exact() {
    let source = include_str!("../wrangler.jsonc");
    assert!(!source.contains(concat!("http", "://")));
    assert!(!source.contains(concat!("ws", "://")));
    assert!(source.contains("worker-build --version 0.8.5 --locked"));
}
