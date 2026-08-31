use chatserver_core::{
    AuthenticatedAccess, AuthenticatedDevice, ChatAuthorization, ChatServerError,
};
use jsonwebtoken::{decode, Algorithm, DecodingKey, Validation};
use serde::Deserialize;
use worker::{Env, Request};

const PUBLIC_KEY_SECRET: &str = "CHAT_AUTH_ED25519_PUBLIC_KEY";
const ISSUER_VAR: &str = "CHAT_AUTH_ISSUER";
const AUDIENCE_VAR: &str = "CHAT_AUTH_AUDIENCE";

#[derive(Debug, Deserialize)]
struct Claims {
    sub: String,
    device_id: String,
    chat_enabled: bool,
    max_attachment_bytes: u64,
}

/// Verifies the host-issued EdDSA JWT. Request headers never define identity.
pub fn authenticate(req: &Request, env: &Env) -> Result<AuthenticatedAccess, ChatServerError> {
    let authorization = req
        .headers()
        .get("authorization")
        .map_err(|_| ChatServerError::Forbidden)?
        .ok_or(ChatServerError::Forbidden)?;
    let token = authorization
        .strip_prefix("Bearer ")
        .filter(|value| !value.is_empty() && !value.bytes().any(|byte| byte.is_ascii_whitespace()))
        .ok_or(ChatServerError::Forbidden)?;

    let public_key = env
        .secret(PUBLIC_KEY_SECRET)
        .map_err(|_| ChatServerError::Forbidden)?
        .to_string();
    let issuer = env
        .var(ISSUER_VAR)
        .map_err(|_| ChatServerError::Forbidden)?
        .to_string();
    let audience = env
        .var(AUDIENCE_VAR)
        .map_err(|_| ChatServerError::Forbidden)?
        .to_string();

    let decoding_key =
        DecodingKey::from_ed_pem(public_key.as_bytes()).map_err(|_| ChatServerError::Forbidden)?;
    let mut validation = Validation::new(Algorithm::EdDSA);
    validation.set_issuer(&[issuer]);
    validation.set_audience(&[audience]);
    validation.set_required_spec_claims(&["exp", "iss", "aud", "sub"]);
    validation.validate_exp = true;
    validation.validate_nbf = true;

    let claims = decode::<Claims>(token, &decoding_key, &validation)
        .map_err(|_| ChatServerError::Forbidden)?
        .claims;
    let access = AuthenticatedAccess {
        actor: AuthenticatedDevice {
            user_id: claims.sub,
            device_id: claims.device_id,
        },
        authorization: ChatAuthorization {
            chat_enabled: claims.chat_enabled,
            max_attachment_bytes: claims.max_attachment_bytes,
        },
    };
    access.validate()?;
    Ok(access)
}
