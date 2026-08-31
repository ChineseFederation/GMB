use std::{env, path::PathBuf, process::ExitCode};

use chatserver_linux::{
    check_installation, initialize_schema, purge_schema, BoxError, Config, Server,
};

#[tokio::main]
async fn main() -> ExitCode {
    match run().await {
        Ok(()) => ExitCode::SUCCESS,
        Err(error) => {
            eprintln!("chatserver: {error}");
            ExitCode::FAILURE
        }
    }
}

async fn run() -> Result<(), BoxError> {
    let mut args = env::args_os().skip(1);
    let command = args
        .next()
        .and_then(|value| value.into_string().ok())
        .unwrap_or_else(|| "serve".to_owned());

    match command.as_str() {
        "serve" => {
            let path = next_path(&mut args, "/etc/chatserver/chatserver.toml");
            reject_extra_arguments(args)?;
            let config = Config::load(&path).await?;
            Server::build(config).await?.run().await
        }
        "check" => {
            let path = required_path(&mut args, "check 需要配置文件路径")?;
            reject_extra_arguments(args)?;
            let config = Config::load(&path).await?;
            check_installation(&config).await
        }
        "init" => {
            let path = required_path(&mut args, "init 需要配置文件路径")?;
            let schema = required_path(&mut args, "init 需要 schema.sql 路径")?;
            reject_extra_arguments(args)?;
            let config = Config::load(&path).await?;
            initialize_schema(&config, &schema).await
        }
        "purge" => {
            let path = required_path(&mut args, "purge 需要配置文件路径")?;
            reject_extra_arguments(args)?;
            let config = Config::load(&path).await?;
            purge_schema(&config).await
        }
        _ => Err(invalid_input("命令只能是 serve、check、init 或 purge")),
    }
}

fn next_path(args: &mut impl Iterator<Item = std::ffi::OsString>, fallback: &str) -> PathBuf {
    args.next()
        .map(PathBuf::from)
        .unwrap_or_else(|| PathBuf::from(fallback))
}

fn required_path(
    args: &mut impl Iterator<Item = std::ffi::OsString>,
    message: &str,
) -> Result<PathBuf, BoxError> {
    args.next()
        .map(PathBuf::from)
        .ok_or_else(|| invalid_input(message))
}

fn reject_extra_arguments(
    mut args: impl Iterator<Item = std::ffi::OsString>,
) -> Result<(), BoxError> {
    if args.next().is_some() {
        return Err(invalid_input("存在多余命令参数"));
    }
    Ok(())
}

fn invalid_input(message: &str) -> BoxError {
    std::io::Error::new(std::io::ErrorKind::InvalidInput, message).into()
}
