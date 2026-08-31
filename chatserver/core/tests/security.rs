use chatserver_core::{
    AuthenticatedAccess, AuthenticatedDevice, ChatAuthorization, PublishedKeyPackage,
};

#[test]
fn package_rejects_application_defined_or_expired_identity() {
    let actor = AuthenticatedDevice {
        user_id: "user-a".into(),
        device_id: "phone-a".into(),
    };
    let package = PublishedKeyPackage {
        user_id: "user-b".into(),
        device_id: "phone-b".into(),
        key_package_ref: "not-hex".into(),
        key_package: String::new(),
        cipher_suite: String::new(),
        not_before: 20,
        not_after: 10,
        last_resort: false,
    };
    assert!(package.validate_for(&actor, 100).is_err());
}

#[test]
fn signed_chat_authorization_caps_the_deployment_attachment_limit() {
    let access = AuthenticatedAccess {
        actor: AuthenticatedDevice {
            user_id: "user-a".into(),
            device_id: "phone-a".into(),
        },
        authorization: ChatAuthorization {
            chat_enabled: true,
            max_attachment_bytes: 10 * 1024 * 1024,
        },
    };
    assert_eq!(
        access.effective_max_attachment_bytes(100 * 1024 * 1024),
        Ok(10 * 1024 * 1024),
    );
    assert_eq!(access.effective_max_attachment_bytes(1024), Ok(1024),);
}

#[test]
fn disabled_or_zero_chat_authorization_fails_closed() {
    for authorization in [
        ChatAuthorization {
            chat_enabled: false,
            max_attachment_bytes: 1024,
        },
        ChatAuthorization {
            chat_enabled: true,
            max_attachment_bytes: 0,
        },
    ] {
        let access = AuthenticatedAccess {
            actor: AuthenticatedDevice {
                user_id: "user-a".into(),
                device_id: "phone-a".into(),
            },
            authorization,
        };
        assert!(access.validate().is_err());
        assert!(access.effective_max_attachment_bytes(1024).is_err());
    }
}
