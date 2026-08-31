pub mod auth;
pub mod config;
pub mod push;
pub mod realtime;
pub mod server;
pub mod storage;

pub use config::Config;
pub use server::{router, Server};
pub use storage::postgres::PgStore;

/// Linux 服务端启动与管理命令统一使用的错误边界。
pub type BoxError = Box<dyn std::error::Error + Send + Sync>;

const CANONICAL_SCHEMA: &str = include_str!("../schema.sql");

/// 只允许对全新空 PostgreSQL 数据库执行唯一规范结构。
pub async fn initialize_schema(
    config: &Config,
    schema_path: &std::path::Path,
) -> Result<(), BoxError> {
    config.validate()?;
    let schema = tokio::fs::read_to_string(schema_path).await?;
    if schema != CANONICAL_SCHEMA {
        return Err(std::io::Error::new(
            std::io::ErrorKind::InvalidData,
            "schema.sql 与当前 ChatServer 唯一规范不一致",
        )
        .into());
    }
    PgStore::initialize_empty(&config.database, CANONICAL_SCHEMA).await
}

/// 卸载命令只删除完全匹配当前规范的 ChatServer 数据结构。
pub async fn purge_schema(config: &Config) -> Result<(), BoxError> {
    config.validate()?;
    PgStore::purge_canonical(&config.database).await
}

/// 启动前同时核验配置和数据库结构，任何漂移都直接失败。
pub async fn check_installation(config: &Config) -> Result<(), BoxError> {
    config.validate()?;
    let store = PgStore::connect(&config.database).await?;
    store.verify_schema().await?;
    store.close().await;
    Ok(())
}
