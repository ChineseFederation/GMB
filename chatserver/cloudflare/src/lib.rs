pub mod api;
mod attachments;
mod auth;
mod push;
mod realtime;
mod store;

pub use realtime::ChatRealtime;
use worker::*;

#[event(fetch)]
pub async fn main(req: Request, env: Env, ctx: Context) -> Result<Response> {
    api::handle(req, env, ctx).await
}

#[event(scheduled)]
pub async fn scheduled(_event: ScheduledEvent, env: Env, _ctx: ScheduleContext) {
    let now = api::now_millis();
    if let Err(error) = push::drain(env.clone(), now).await {
        console_error!("ChatServer push outbox failed: {error}");
    }
    if let Err(error) = attachments::cleanup(env, now).await {
        console_error!("ChatServer cleanup failed: {error}");
    }
}
