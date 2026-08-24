import type { Env, SquareNotifyJob } from './types';
import { errorResponse } from './shared/http';
import { routeRequest } from './routes';
import { fanOutPage } from './feeds/notify_fanout';
import { runExpiredMembershipContentCleanup } from './membership/expiration_cleanup';
import { reconcileSubscriptions } from './membership/reconcile';
import { applyCors, cleanupSecurityState } from './security/request_guard';
import { cleanupExpiredUploads } from './uploads/service';
import { cleanupExpiredReservations } from './limits/usage';
import { cleanupExpiredSessionIndexes } from './auth/session_index';
import { reconcileFinalizedUserProjection } from './account/user_projection';
import { reconcileFinalizedMembershipProjection } from './membership/projection';
import { auditSquareR2Consistency } from './media/service';
import { cleanupExpiredChatPushEndpoints } from './chat/service';

export { Chat } from './chat/realtime';

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    try {
      return applyCors(request, env, await routeRequest(request, env));
    } catch (error) {
      return applyCors(request, env, errorResponse(error));
    }
  },

  // Workers Paid 的五分钟事件顺序执行四组各自有硬批次上限的任务；顺序执行避免并发峰值，
  // 任一组失败会终止本轮并由下一次 Cron 从各自游标续跑。每日 R2 巡检保持独立。
  async scheduled(_controller: ScheduledController, env: Env, ctx: ExecutionContext): Promise<void> {
    let label = 'unknown';
    let job: Promise<unknown>;
    if (_controller.cron === '*/5 * * * *') {
      label = 'periodic';
      job = (async () => {
        await Promise.all([
          cleanupExpiredUploads(env),
          cleanupSecurityState(env),
          cleanupExpiredReservations(env),
          cleanupExpiredSessionIndexes(env),
          cleanupExpiredChatPushEndpoints(env),
        ]);
        await reconcileFinalizedUserProjection(env);
        await reconcileFinalizedMembershipProjection(env);
        const result = await reconcileSubscriptions(env);
        if (
          isDailyCleanupTime(_controller.scheduledTime) &&
          result.finalized_chain_timestamp !== null
        ) {
          await runExpiredMembershipContentCleanup(
            env,
            result.finalized_chain_timestamp,
          );
        }
        return result;
      })();
    } else if (_controller.cron === '4 3 * * *') {
      label = 'r2-audit';
      job = auditSquareR2Consistency(env);
    } else {
      job = Promise.reject(new Error(`unknown cron: ${_controller.cron}`));
    }
    ctx.waitUntil(job.catch((error) => {
      console.error(
        `[scheduled-${label}] failed: ${error instanceof Error ? error.message : error}`
      );
    }));
  },

  // 广场发帖通知扇出：每条消息 = 一次发帖或一页续跑；fanOutPage 满页会把下一页续跑入队。
  // 单条成功 ack、失败 retry（最多 max_retries），不因一条拖垮整批。
  async queue(batch: MessageBatch<SquareNotifyJob>, env: Env): Promise<void> {
    await Promise.all(
      batch.messages.map(async (message) => {
        try {
          await fanOutPage(env, message.body);
          message.ack();
        } catch (error) {
          console.error(
            `[square-notify] fanout failed: ${error instanceof Error ? error.message : error}`,
          );
          message.retry();
        }
      }),
    );
  }
};

function isDailyCleanupTime(scheduledTime: number): boolean {
  const scheduled = new Date(scheduledTime);
  return scheduled.getUTCHours() === 3 && scheduled.getUTCMinutes() === 3;
}
