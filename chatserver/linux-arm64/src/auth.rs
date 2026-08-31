use axum::http::{header::AUTHORIZATION, HeaderMap};
use chatserver_core::{
    AuthenticatedAccess, AuthenticatedDevice, ChatAuthorization, ChatServerError,
};
use jsonwebtoken::{decode, Algorithm, DecodingKey, Validation};
use serde::Deserialize;

use crate::{config::AuthConfig, BoxError};

#[derive(Clone)]
pub struct Authenticator {
    decoding_key: DecodingKey,
    validation: Validation,
}

#[derive(Debug, Deserialize)]
struct Claims {
    sub: String,
    device_id: String,
    chat_enabled: bool,
    max_attachment_bytes: u64,
}

impl Authenticator {
    pub async fn load(config: &AuthConfig) -> Result<Self, BoxError> {
        let pem = tokio::fs::read(&config.ed25519_public_key).await?;
        let decoding_key = DecodingKey::from_ed_pem(&pem)?;
        let mut validation = Validation::new(Algorithm::EdDSA);
        validation.set_issuer(&[config.issuer.as_str()]);
        validation.set_audience(&[config.audience.as_str()]);
        validation.set_required_spec_claims(&["exp", "iss", "aud", "sub"]);
        validation.validate_exp = true;
        validation.validate_nbf = true;
        Ok(Self {
            decoding_key,
            validation,
        })
    }

    pub fn authenticate(
        &self,
        headers: &HeaderMap,
    ) -> Result<AuthenticatedAccess, ChatServerError> {
        let value = headers
            .get(AUTHORIZATION)
            .and_then(|value| value.to_str().ok())
            .ok_or(ChatServerError::Forbidden)?;
        let token = value
            .strip_prefix("Bearer ")
            .filter(|token| {
                !token.is_empty() && !token.bytes().any(|byte| byte.is_ascii_whitespace())
            })
            .ok_or(ChatServerError::Forbidden)?;
        let claims = decode::<Claims>(token, &self.decoding_key, &self.validation)
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
}
